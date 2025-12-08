import os
import sys
import logging
import json
import argparse
import pandas as pd
from sqlalchemy import create_engine

# Try importing Pyarrow for Parquet support
try:
    import pyarrow as pa
    from pyarrow.parquet import ParquetFile
except ImportError:
    pa = None
    ParquetFile = None

# Configure Logging
LOG_FMT = "%(asctime)s %(levelname)s: %(message)s"
logging.basicConfig(level=logging.INFO, format=LOG_FMT)
logger = logging.getLogger("ingest")

DEFAULT_CHUNK = 100_000


def make_engine_from_parts(db_url=None, user=None, password=None, host=None, port=None, db=None):
    """Creates a SQLAlchemy engine."""
    if db_url:
        return create_engine(db_url)
    if not all([user, password, host, port, db]):
        raise ValueError("Either --db_url or all of --user/--password/--host/--port/--db must be provided")
    url = f"postgresql://{user}:{password}@{host}:{port}/{db}"
    return create_engine(url)


def get_write_mode(index, if_exists_arg):
    if if_exists_arg == 'append':
        return 'append'
    return 'replace' if index == 0 else 'append'


def cleanup_df(df):
    """
    Standardizes schema:
    1. Renames 'Unnamed: 0' -> 'source_index'
    2. Adds 'source_index' as NULL if missing
    """
    rename_map = {}
    for col in df.columns:
        if str(col).startswith("Unnamed:"):
            rename_map[col] = "source_index"

    if rename_map:
        logger.info(f"Renaming artifact columns: {rename_map}")
        df = df.rename(columns=rename_map)

    if 'source_index' not in df.columns:
        df['source_index'] = None

    return df


def ingest_csv_chunks(file_path, table_name, engine, chunksize, if_exists, dtype_map):
    logger.info(f"Processing CSV {file_path}...")

    # --- AUTO-DETECT SEPARATOR ---
    # We sniff the first line to see if it uses tabs or commas
    sep = ','  # Default to comma
    try:
        with open(file_path, 'r') as f:
            first_line = f.readline()
            if '\t' in first_line and ',' not in first_line:
                sep = '\t'
                logger.info("Detected Tab-Separated Value (TSV) file.")
    except Exception as e:
        logger.warning(f"Could not sniff separator, defaulting to comma: {e}")
    # -----------------------------

    csv_iterator = pd.read_csv(file_path, iterator=True, chunksize=chunksize, sep=sep)

    for i, df_chunk in enumerate(csv_iterator):
        df_chunk = cleanup_df(df_chunk)
        mode = get_write_mode(i, if_exists)
        df_chunk.to_sql(name=table_name, con=engine, if_exists=mode, index=False, dtype=dtype_map)
        logger.info(f"Inserted chunk {i + 1} (mode={mode})")


def ingest_parquet_batches(file_path, table_name, engine, batch_size, if_exists, dtype_map):
    logger.info(f"Processing Parquet {file_path}...")
    if not ParquetFile:
        logger.error("Pyarrow not installed.")
        sys.exit(1)
    pf = ParquetFile(file_path)
    for i, batch in enumerate(pf.iter_batches(batch_size=batch_size)):
        df = batch.to_pandas()
        df = cleanup_df(df)
        mode = get_write_mode(i, if_exists)
        df.to_sql(name=table_name, con=engine, if_exists=mode, index=False, dtype=dtype_map)
        logger.info(f"Inserted batch {i + 1} (mode={mode})")


def ingest_json_lines(file_path, table_name, engine, chunksize, if_exists, dtype_map):
    logger.info(f"Processing JSON {file_path}...")
    try:
        df = pd.read_json(file_path)
        df = cleanup_df(df)
        mode = get_write_mode(0, if_exists)
        df.to_sql(name=table_name, con=engine, if_exists=mode, index=False, dtype=dtype_map)
        logger.info(f"Inserted standard JSON (mode={mode})")
        return
    except ValueError:
        pass

    reader = pd.read_json(file_path, lines=True, chunksize=chunksize)
    for i, df_chunk in enumerate(reader):
        df_chunk = cleanup_df(df_chunk)
        mode = get_write_mode(i, if_exists)
        df_chunk.to_sql(name=table_name, con=engine, if_exists=mode, index=False, dtype=dtype_map)
        logger.info(f"Inserted JSONL chunk {i + 1} (mode={mode})")


def ingest_simple(file_path, table_name, engine, if_exists, dtype_map, loader_func):
    logger.info(f"Processing file {file_path}...")
    if loader_func == pd.read_html:
        dfs = pd.read_html(file_path)
        df = dfs[0] if dfs else pd.DataFrame()
    else:
        df = loader_func(file_path)

    df = cleanup_df(df)
    mode = get_write_mode(0, if_exists)
    df.to_sql(name=table_name, con=engine, if_exists=mode, index=False, dtype=dtype_map)
    logger.info(f"Ingested {len(df)} rows (mode={mode})")


def main(args):
    source = args.path
    if not os.path.exists(source):
        logger.error(f"Path does not exist: {source}")
        sys.exit(2)

    try:
        engine = make_engine_from_parts(
            db_url=args.db_url, user=args.user, password=args.password,
            host=args.host, port=args.port, db=args.db
        )
    except Exception as e:
        logger.error(f"DB Connection failed: {e}")
        sys.exit(1)

    dtype_map = json.loads(args.dtype_json) if args.dtype_json else None

    s = source.lower()
    if s.endswith(".csv"):
        ingest_csv_chunks(source, args.table_name, engine, args.chunksize, args.if_exists, dtype_map)
    elif s.endswith(".parquet"):
        ingest_parquet_batches(source, args.table_name, engine, args.batch_size, args.if_exists, dtype_map)
    elif s.endswith(".json") or s.endswith(".jsonl"):
        ingest_json_lines(source, args.table_name, engine, args.chunksize, args.if_exists, dtype_map)
    elif s.endswith(".xlsx") or s.endswith(".xls"):
        ingest_simple(source, args.table_name, engine, args.if_exists, dtype_map, pd.read_excel)
    elif s.endswith(".pkl") or s.endswith(".pickle"):
        ingest_simple(source, args.table_name, engine, args.if_exists, dtype_map, pd.read_pickle)
    elif s.endswith(".html") or s.endswith(".htm"):
        ingest_simple(source, args.table_name, engine, args.if_exists, dtype_map, pd.read_html)
    else:
        logger.error(f"Unsupported format: {source}")
        sys.exit(3)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--path", required=True)
    parser.add_argument("--table_name", required=True)
    parser.add_argument("--if_exists", default="replace", choices=["replace", "append"])

    # DB Args
    parser.add_argument("--db_url", default=os.getenv("DB_URL"))
    parser.add_argument("--user", default=os.getenv("DB_USER"))
    parser.add_argument("--password", default=os.getenv("DB_PASSWORD"))
    parser.add_argument("--host", default=os.getenv("DB_HOST"))
    parser.add_argument("--port", default=os.getenv("DB_PORT", "5432"))
    parser.add_argument("--db", default=os.getenv("DB_NAME"))

    parser.add_argument("--chunksize", type=int, default=DEFAULT_CHUNK)
    parser.add_argument("--batch_size", type=int, default=DEFAULT_CHUNK)
    parser.add_argument("--use_copy", action="store_true")
    parser.add_argument("--dtype_json")

    main(parser.parse_args())