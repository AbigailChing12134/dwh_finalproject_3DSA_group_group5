import os
import logging
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.empty import EmptyOperator
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.utils.dates import days_ago

# --- CONFIGURATION ---
BASE_PATH = "/opt/airflow"
DATA_PATH = os.path.join(BASE_PATH, "data/raw")
SCRIPT_PATH = os.path.join(BASE_PATH, "scripts/ingest/ingest_data.py")
SILVER_SQL_PATH = os.path.join(BASE_PATH, "scripts/transform/silver_layer")
GOLD_SQL_PATH = os.path.join(BASE_PATH, "scripts/transform/gold_layer.sql")

DB_ENV = {
    'DB_HOST': 'postgres_dwh',
    'DB_USER': 'postgres',
    'DB_PASSWORD': 'postgres',
    'DB_NAME': 'bronze',
    'DB_PORT': '5432'
}
POSTGRES_CONN_ID = "dwh_postgres"

# --- FILES TO INGEST ---
FILES_TO_INGEST = [
    # Single Files
    {"path": "Business Department/product_list.xlsx", "table": "product_list_raw"},
    {"path": "Customer Management Department/user_credit_card.pickle", "table": "user_credit_card_raw"},
    {"path": "Customer Management Department/user_data.json", "table": "user_data_raw"},
    {"path": "Customer Management Department/user_job.csv", "table": "user_job_raw"},
    {"path": "Enterprise Department/merchant_data.html", "table": "merchant_data_raw"},
    {"path": "Enterprise Department/staff_data.html", "table": "staff_data_raw"},
    {"path": "Marketing Department/campaign_data.csv", "table": "campaign_data_raw"},
    {"path": "Marketing Department/transactional_campaign_data.csv", "table": "transactional_campaign_data_raw"},
    {"path": "Operations Department/order_delays.html", "table": "order_delays_raw"},
    # Multi-File Groups
    {"path": "Enterprise Department/order_with_merchant_data1.parquet", "table": "order_with_merchant_raw"},
    {"path": "Enterprise Department/order_with_merchant_data2.parquet", "table": "order_with_merchant_raw"},
    {"path": "Enterprise Department/order_with_merchant_data3.csv", "table": "order_with_merchant_raw"},
    {"path": "Operations Department/line_item_data_prices1.csv", "table": "line_item_prices_raw"},
    {"path": "Operations Department/line_item_data_prices2.csv", "table": "line_item_prices_raw"},
    {"path": "Operations Department/line_item_data_prices3.parquet", "table": "line_item_prices_raw"},
    {"path": "Operations Department/line_item_data_products1.csv", "table": "line_item_products_raw"},
    {"path": "Operations Department/line_item_data_products2.csv", "table": "line_item_products_raw"},
    {"path": "Operations Department/line_item_data_products3.parquet", "table": "line_item_products_raw"},
    {"path": "Operations Department/order_data_20200101-20200701.parquet", "table": "orders_raw"},
    {"path": "Operations Department/order_data_20200701-20211001.pickle", "table": "orders_raw"},
    {"path": "Operations Department/order_data_20211001-20220101.csv", "table": "orders_raw"},
    {"path": "Operations Department/order_data_20220101-20221201.xlsx", "table": "orders_raw"},
    {"path": "Operations Department/order_data_20221201-20230601.json", "table": "orders_raw"},
    {"path": "Operations Department/order_data_20230601-20240101.html", "table": "orders_raw"},
]


def check_dq_errors():
    hook = PostgresHook(postgres_conn_id=POSTGRES_CONN_ID)
    sql = "SELECT SUM(failed_rows) FROM silver.dq_summary WHERE severity = 'ERROR' AND created_at > NOW() - INTERVAL '1 hour';"
    records = hook.get_records(sql)
    error_count = records[0][0] if records and records[0][0] else 0
    if error_count > 0:
        raise ValueError(f"DQ Check Failed! {error_count} errors found.")


default_args = {'owner': 'airflow', 'start_date': days_ago(1), 'retries': 0}

with DAG('medallion_full_pipeline', default_args=default_args, schedule_interval=None, catchup=False,
         template_searchpath=[BASE_PATH]) as dag:
    start = EmptyOperator(task_id='start')
    bronze_done = EmptyOperator(task_id='bronze_layer_complete')

    # 1. BRONZE LAYER
    table_files_map = {}
    for f in FILES_TO_INGEST:
        table_files_map.setdefault(f['table'], []).append(f['path'])

    for table, files in table_files_map.items():
        previous_task = start
        for i, file_path in enumerate(files):
            safe_name = file_path.split('/')[-1].replace('.', '_').replace('-', '_').lower()
            mode = "replace" if i == 0 else "append"
            cmd = f"python {SCRIPT_PATH} --path '{os.path.join(DATA_PATH, file_path)}' --table_name {table} --if_exists {mode}"
            task = BashOperator(task_id=f"ingest_{safe_name}", bash_command=cmd, env=DB_ENV)
            previous_task >> task
            previous_task = task
        previous_task >> bronze_done

    # 2. SILVER LAYER SETUP
    setup_file = 'enhanced_validations_common.sql'
    silver_setup = PostgresOperator(
        task_id='silver_layer_setup',
        postgres_conn_id=POSTGRES_CONN_ID,
        sql=f"scripts/transform/silver_layer/{setup_file}"
    )
    bronze_done >> silver_setup

    # 3. SILVER LAYER (Processing)
    silver_dimensions_done = EmptyOperator(task_id='silver_dimensions_complete')
    silver_facts_done = EmptyOperator(task_id='silver_facts_complete')

    if os.path.exists(SILVER_SQL_PATH):
        all_sql_files = sorted([f for f in os.listdir(SILVER_SQL_PATH) if f.endswith('.sql')])

        # FIX: Added '99_dq_views.sql' to skip list so it doesn't run in the loop
        skip_files = ['gold_layer.sql', 'silver_validation_guard.sql', 'silver_build.sql', '99_dq_views.sql',
                      setup_file]

        for sql_file in all_sql_files:
            if sql_file in skip_files: continue

            task = PostgresOperator(
                task_id=f"silver_{sql_file.replace('.sql', '').replace('.', '_')}",
                postgres_conn_id=POSTGRES_CONN_ID,
                sql=f"scripts/transform/silver_layer/{sql_file}"
            )

            # Dimensions run AFTER Setup, Facts run AFTER Dimensions
            if any(k in sql_file.lower() for k in ['user', 'merchant', 'staff', 'product', 'dq_base']):
                silver_setup >> task >> silver_dimensions_done
            else:
                silver_dimensions_done >> task >> silver_facts_done

    # 4. SILVER DQ VIEWS (Runs AFTER facts are done)
    if os.path.exists(os.path.join(SILVER_SQL_PATH, '99_dq_views.sql')):
        dq_views = PostgresOperator(
            task_id='silver_create_dq_views',
            postgres_conn_id=POSTGRES_CONN_ID,
            sql="scripts/transform/silver_layer/99_dq_views.sql"
        )
        silver_facts_done >> dq_views

    # 5. SILVER BUILD
    silver_build = PostgresOperator(
        task_id='silver_build_final_tables',
        postgres_conn_id=POSTGRES_CONN_ID,
        sql="scripts/transform/silver_layer/silver_build.sql"
    )

    # Build runs after facts are done
    silver_facts_done >> silver_build

    # 6. DQ CHECK & GOLD
    dq_check = PythonOperator(task_id='dq_gatekeeper_check', python_callable=check_dq_errors)

    if os.path.exists(GOLD_SQL_PATH):
        run_gold = PostgresOperator(task_id='gold_layer_aggregation', postgres_conn_id=POSTGRES_CONN_ID,
                                    sql="scripts/transform/gold_layer.sql")

        # Link both paths
        silver_build >> dq_check >> run_gold
        if 'dq_views' in locals():
            dq_views >> dq_check