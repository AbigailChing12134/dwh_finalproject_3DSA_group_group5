import os
import glob
import re
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.empty import EmptyOperator
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.utils.dates import days_ago

# =================================================
# CONFIGURATION
# =================================================
BASE_PATH = "/opt/airflow"
DATA_PATH = os.path.join(BASE_PATH, "data/raw")
SCRIPT_PATH = os.path.join(BASE_PATH, "scripts/ingest/ingest_data.py")
SILVER_SQL_PATH = os.path.join(BASE_PATH, "scripts/transform/silver_layer")
GOLD_SQL_PATH = os.path.join(BASE_PATH, "scripts/transform/gold_layer.sql")

DB_ENV = {
    "DB_HOST": "postgres_dwh",
    "DB_USER": "postgres",
    "DB_PASSWORD": "postgres",
    "DB_NAME": "bronze",
    "DB_PORT": "5432",
}
POSTGRES_CONN_ID = "dwh_postgres"

# =================================================
# ONLY ALLOW REAL DATA FILE TYPES
# =================================================
ALLOWED_EXTENSIONS = (
    ".csv",
    ".parquet",
    ".json",
    ".xlsx",
    ".pickle",
    ".html",
)

FILES_TO_INGEST = [
    # Business
    {"path": "Business Department/", "pattern": "product_list*.*", "table": "product_list_raw"},

    # Customer Management
    {"path": "Customer Management Department/", "pattern": "user_credit_card*.*", "table": "user_credit_card_raw"},
    {"path": "Customer Management Department/", "pattern": "user_data*.*", "table": "user_data_raw"},
    {"path": "Customer Management Department/", "pattern": "user_job*.*", "table": "user_job_raw"},

    # Enterprise
    {"path": "Enterprise Department/", "pattern": "merchant_data*.*", "table": "merchant_data_raw"},
    {"path": "Enterprise Department/", "pattern": "staff_data*.*", "table": "staff_data_raw"},
    {"path": "Enterprise Department/", "pattern": "order_with_merchant_data*.*", "table": "order_with_merchant_raw"},

    # Marketing
    {"path": "Marketing Department/", "pattern": "campaign_data*.*", "table": "campaign_data_raw"},
    {"path": "Marketing Department/", "pattern": "transactional_campaign_data*.*", "table": "transactional_campaign_data_raw"},

    # Operations
    {"path": "Operations Department/", "pattern": "order_delays*.*", "table": "order_delays_raw"},
    {"path": "Operations Department/", "pattern": "line_item_data_prices*.*", "table": "line_item_prices_raw"},
    {"path": "Operations Department/", "pattern": "line_item_data_products*.*", "table": "line_item_products_raw"},
    {"path": "Operations Department/", "pattern": "order_data_*.*", "table": "orders_raw"},
]
# =================================================
# DATA QUALITY CHECK
# =================================================
def check_dq_errors():
    hook = PostgresHook(postgres_conn_id=POSTGRES_CONN_ID)
    sql = """
        SELECT COALESCE(SUM(failed_rows), 0)
        FROM silver.dq_summary
        WHERE severity = 'ERROR'
          AND created_at > NOW() - INTERVAL '1 hour';
    """
    result = hook.get_first(sql)
    if result and result[0] > 0:
        raise ValueError(f"DQ Check Failed! {result[0]} errors found.")

default_args = {
    "owner": "airflow",
    "start_date": days_ago(1),
    "retries": 0,
}

# =================================================
# DAG
# =================================================
with DAG(
    dag_id="medallion_full_pipeline",
    default_args=default_args,
    schedule_interval=None,
    catchup=False,
    template_searchpath=[BASE_PATH],
) as dag:

    start = EmptyOperator(task_id="start")
    bronze_done = EmptyOperator(task_id="bronze_layer_complete")

    # =================================================
    # BRONZE INGESTION (EXTENSION WHITELIST)
    # =================================================
    for cfg in FILES_TO_INGEST:
        base_dir = os.path.join(DATA_PATH, cfg["path"])
        raw_files = glob.glob(os.path.join(base_dir, cfg["pattern"]))

        files = sorted(
            f for f in raw_files
            if os.path.isfile(f)
            and f.lower().endswith(ALLOWED_EXTENSIONS)
        )

        previous_task = start

        for i, file_path in enumerate(files):
            safe_name = re.sub(
                r"[^a-zA-Z0-9_.-]",
                "_",
                os.path.basename(file_path)
            ).lower()

            mode = "replace" if i == 0 else "append"

            cmd = (
                f"python {SCRIPT_PATH} "
                f"--path '{file_path}' "
                f"--table_name {cfg['table']} "
                f"--if_exists {mode}"
            )

            task = BashOperator(
                task_id=f"ingest_{cfg['table']}_{safe_name}",
                bash_command=cmd,
                env=DB_ENV,
            )

            previous_task >> task
            previous_task = task

        previous_task >> bronze_done

    # =========================================================
    # 2. SILVER LAYER SETUP
    # =========================================================
    setup_file = 'enhanced_validations_common.sql'

    silver_setup = PostgresOperator(
        task_id='silver_layer_setup',
        postgres_conn_id=POSTGRES_CONN_ID,
        sql=f"scripts/transform/silver_layer/{setup_file}"
    )

    bronze_done >> silver_setup

    # =========================================================
    # 3. SILVER TRANSFORMS
    # =========================================================
    silver_dimensions_done = EmptyOperator(task_id='silver_dimensions_complete')
    silver_facts_done = EmptyOperator(task_id='silver_facts_complete')

    if os.path.exists(SILVER_SQL_PATH):
        all_sql_files = sorted(f for f in os.listdir(SILVER_SQL_PATH) if f.endswith('.sql'))

        skip_files = [
            'gold_layer.sql',
            'silver_validation_guard.sql',
            'silver_build.sql',
            '99_dq_views.sql',
            setup_file
        ]

        for sql_file in all_sql_files:
            if sql_file in skip_files:
                continue

            task = PostgresOperator(
                task_id=f"silver_{sql_file.replace('.sql', '').replace('.', '_')}",
                postgres_conn_id=POSTGRES_CONN_ID,
                sql=f"scripts/transform/silver_layer/{sql_file}"
            )

            if any(k in sql_file.lower() for k in ['user', 'merchant', 'staff', 'product', 'dq_base']):
                silver_setup >> task >> silver_dimensions_done
            else:
                silver_dimensions_done >> task >> silver_facts_done

    # =========================================================
    # 4. SILVER DQ VIEWS
    # =========================================================
    if os.path.exists(os.path.join(SILVER_SQL_PATH, '99_dq_views.sql')):
        dq_views = PostgresOperator(
            task_id='silver_create_dq_views',
            postgres_conn_id=POSTGRES_CONN_ID,
            sql="scripts/transform/silver_layer/99_dq_views.sql"
        )
        silver_facts_done >> dq_views

    # =========================================================
    # 5. SILVER BUILD
    # =========================================================
    silver_build = PostgresOperator(
        task_id='silver_build_final_tables',
        postgres_conn_id=POSTGRES_CONN_ID,
        sql="scripts/transform/silver_layer/silver_build.sql"
    )

    silver_facts_done >> silver_build

    # =========================================================
    # 6. DQ GATEKEEPER + GOLD
    # =========================================================
    dq_check = PythonOperator(
        task_id='dq_gatekeeper_check',
        python_callable=check_dq_errors
    )

    if os.path.exists(GOLD_SQL_PATH):
        run_gold = PostgresOperator(
            task_id='gold_layer_aggregation',
            postgres_conn_id=POSTGRES_CONN_ID,
            sql="scripts/transform/gold_layer.sql"
        )

        silver_build >> dq_check >> run_gold
        if 'dq_views' in locals():
            dq_views >> dq_check