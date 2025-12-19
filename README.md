# End-to-End Data Engineering Pipeline (Medallion Architecture)
⋆❅*𖢔𐂂꙳𝓜𝓮𝓻𝓻𝔂 𝓬𝓱𝓻𝓲𝓼𝓽𝓶𝓪𝓼⋆꙳•❅*‧ ‧*❆ ₊⋆

This project implements a complete Data Warehouse pipeline using **Apache Airflow**, **Docker**, and **PostgreSQL**. It follows the **Medallion Architecture** (Bronze → Silver → Gold) to transform raw data into a Star Schema optimized for analytics.

This project ingests raw data from multiple formats (CSV, JSON, Parquet, Excel, HTML, Pickle), cleans and validates it, and transforms it into a Star Schema ready for analytics.

°❆🎄⋆.ೃ࿔🎁*:･:*🦌°❆🎄⋆.ೃ࿔🎁*:･:*🦌°❆🎄⋆.ೃ࿔🎁*:･:*🦌°❆🎄⋆.ೃ࿔🎁*:･:*🦌°❆🎄⋆.ೃ࿔🎁*:･:*🦌°❆🎄⋆.ೃ࿔🎁*:･:*🦌°❆🎄⋆.ೃ࿔🎁*:･:*🦌°❆🎄⋆.ೃ࿔🎁*:･:*🦌°❆🎄⋆.ೃ࿔🎁*:･:*🦌

# Architecture Overview

1.  **Bronze Layer (Raw):**
    - Ingests data "as-is" from the `data/raw` folder.
    - Handles schema evolution (adds `source_index` to preserve lineage).
    - Supports `append` mode for multi-part files.
2.  **Silver Layer (Cleaned & Validated):**
    - Staged Execution: Dimensions run in parallel first; Facts run second.
    - Data Quality Checks: Enforces non-null constraints and correct data types.
    - Invalid Handling: Bad rows are quarantined in `invalid_` tables; good rows move to `valid_`.
3.  **Gold Layer (Aggregated):**
    - **Star Schema:** Denormalized Dimension tables (`dim_user`, `dim_product`) and Fact tables (`fact_order`).
    - **Business Ready:** Optimized for reporting (Revenue, Sales Performance, Delays).

*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄

# Getting Started

### 1. Prerequisites
To run the pipeline, you must have the following installed:
* **Docker Desktop** (Installed & Running with WSL 2 enabled).
* **pgAdmin 4** (Optional, for viewing data schemas).
* **Data** (in case of complications involving data on github, download directly on drive to preserve integrity)
  
### 2. Installation & Setup

1.  **Download the repository**
    Clone or download this repository.
    **for data, due to size limitations please access the link** https://drive.google.com/drive/folders/1nuLa1Chepulb6ewbPmtRifycDPRFr05n?usp=drive_link

3.  **Prepare the Environment**
    Ensure your folder structure looks like this:
    ```text
    .
    ├── dags/                  # Airflow DAGs (contains dwh_pipeline.py)
    ├── data/raw/              # Source Data (CSV, JSON, etc.)
    ├── scripts/               # Python & SQL Scripts
    ├── infra/                 # Docker config
    ├── docker-compose.yaml    # Docker Orchestration
    ├── Dockerfile             # Docker instructions
    ├── plugins                # plugins, if to be added in the future
    ├── License                # License
    └── README.md
    ```
just download it as is and you wont run into any problems, after downloading, put the project folder in your home folder on linux

3.  **Launch the Pipeline**
    Open your **Ubuntu (WSL)** terminal and navigate to the project folder:
 
    ```bash
    cd ~/dwh_finalproject_3DSA_group_5-Week-4-Progress-
    ```
    *(Replace with your actual folder path).*


    Run the following commands to build and start the containers:

    ```bash
    # 1. Build the custom image (Installs Pandas/SQLAlchemy) and Init DB
    docker-compose up -d --build

    # 2. Build the airflow containers
    docker-compose up airflow-init
    
    # 3. Start the Services (Airflow Webserver, Scheduler, Postgres)
    docker-compose up -d
    ```

4.  **Verify Services are Running**
    ```bash
    docker ps
    ```
    *You should see healthy containers for `airflow-webserver`, `airflow-scheduler`, and `postgres_dwh`.*

*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄

## Running the Pipeline

1.  **Access Airflow UI**
    - Open your browser and go to: **http://localhost:8080**
    - **Username:** `admin`
    - **Password:** `admin`

2.  **Trigger the DAG**
    - Find the DAG named **`medallion_full_pipeline`**.
    - Toggle the **ON/OFF** switch to **ON**.
    - Click the **Play Button** under "Actions" to trigger a run.

3.  **Monitor Progress**
    - Click on the DAG name to see the **Graph View**.
    - Watch the tasks turn **Dark Green** (Success).
    - The pipeline flow:
        1.  `silver_layer_setup` (Creates Schema)
        2.  `ingest_...` (Bronze Ingestion)
        3.  `silver_...` (Silver Validation)
        4.  `dq_gatekeeper_check` (Quality Check)
        5.  `gold_layer_aggregation` (Final Star Schema Build, this takes a while and my be heavy on the memory, you can try to allot more memory to wsl by doing the first step on troubleshooting).

*Note: The Gold aggregation is resource-intensive and may take 10-20 minutes.*

*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄✩‧₊*ੈ🎄

## Viewing the Data (pgAdmin 4)

To inspect the final tables and Entity-Relationship Diagram (ERD):

### 1. Connect pgAdmin to Docker
1.  Open **pgAdmin 4**.
2.  Right-click **Servers** > **Register** > **Server...**
3.  **General Tab:** Name it `Medallion Pipeline`.
4.  **Connection Tab:**
    - **Host:** `localhost`
    - **Port:** `5432`
    - **Maintenance database:** `bronze`  *(Important!)*
    - **Username:** `postgres`
    - **Password:** `postgres`
5.  Click **Save**.

### 2. View the Gold Data
1.  Expand **Docker DWH** > **Databases** > **bronze** > **Schemas**.
2.  Go to **gold** > **Tables**.
3.  Right-click `fact_order` > **View/Edit Data** > **All Rows**.

### 3. Generate ERD (Star Schema Diagram)

1.  Right-click on the database **`bronze`**.
2.  Select **ERD Tool**.
3.  (If blank) Click the **Generate ERD** button (Database icon in toolbar).
4.  You will see the relationships between `fact_order` and the dimension tables (`dim_user`, `dim_product`, etc.).

---

## Linking an Existing Tableau Dashboard

If you already have a pre-built Tableau dashboard, you can swap the data source to the PostgreSQL instance running inside the Docker container.

### 1. Update the Data Connection

1.  Open your Tableau workbook (.twb or .twbx).
2.  Go to the Data menu at the top and select your existing data source > Edit Connection.
3.  Enter the Docker PostgreSQL credentials:

    - **Server:** localhost
    - **Port:** 5432
    - **Database:** bronze
    - **Username:** postgres
    - **Password:** postgres

4.  Click Sign In.

---

### 2. Map to the Gold Layer

1.  In the Data Source tab, ensure the Schema is set to gold.
2.  If your existing dashboard used different table names, Tableau may show red exclamation marks on your fields.
3.  Replace References:
    - Right-click on a broken field in the Data pane
    - Select Replace References
    - Map the old field name to the new field name from:
        - fact_order
        - dim_user
        - dim_product
        - other dim_ tables

---

### 3. Verify the Star Schema

1.  Ensure that your Fact table (fact_order) is at the center of your joins.
2.  Confirm that your Dimension tables (dim_user, dim_product, etc.) are joined via Left Joins to ensure no sales data is lost if a dimension record is missing.


## Troubleshooting
*Issue: "Input/output error" or Docker crashes*
* *Fix:* WSL ran out of memory. 
    1.  Create a .wslconfig file in your Windows User Home (C:\Users\YourUser\.wslconfig).
    2.  Paste this configuration:

    
ini
    [wsl2]
    memory=12GB
    swap=4GB
    autoMemoryReclaim=dropcache 
    

    3.  Run wsl --shutdown in PowerShell (Admin).
    4.  Restart Docker Desktop.

*Issue: "Relation does not exist" or Schema Errors*
* *Fix:* The database is out of sync with the code. Reset it:
    
    docker-compose down --volumes
    docker-compose up -d --build
    docker-compose up airflow-init
    docker-compose up -d
    

*Issue: Airflow UI not loading*
* *Fix:* Wait 60 seconds for the webserver to boot. If it persists, restart it:
    
    docker-compose restart airflow-webserver
    

*Issue: Pipeline seems stuck*
* *Fix:* Check if it's actually working (high CPU usage) or frozen (zero CPU usage):
    
    docker stats
    

*Issue: pgAdmin cannot connect due to incorrect password*
* *Fix:* Sometimes PostgreSQL services on Windows cause connection issues.
    1. Press *Windows + R*, type services.msc, and press *Enter*.
    2. Look for *PostgreSQL* (any PostgreSQL-related service).
    3. Stop the service.
    4. Try connecting to pgAdmin again.

*Notes*
* Code patterns and configurations were adapted from references *[5]*, *[6]*, and *[7]*.
* Large Language Models referenced in *[8]* and *[9]* were used to check and validate the pipeline implementation.


                ˗ ˏ ˋ ★ˎˊ ˗    ༺𝓜𝓮𝓻𝓻𝔂༻༺𝓒𝓱𝓻𝓲𝓼𝓽𝓶𝓪𝓼༻  ˗ ˏ ˋ ★ˎˊ ˗   

---

## Data Visualization (Tableau)

The final Gold-layer Star Schema produced by this pipeline is consumed by a Tableau dashboard.

**Tableau Public Dashboard:**  
https://public.tableau.com/app/profile/liza.marie.valdez/viz/DMW-FinalDashboard/Dashboard1#1

The dashboard connects directly to the PostgreSQL data warehouse 


---

⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⠀⠀⣤⣶⢄⡿⢿⣭⣁⠴⡤⡀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⠂⠤⡀⠰⠁⠀⠀⠀⠀⠀⠉⠓⢦⡀⠉⠛⢮⡊⢂⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⢄⠈⠋⠐⠒⡦⢤⣀⡀⠀⠀⠀⠈⢢⡀⠀⢳⡀⠆⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠑⠁⠐⠜⠉⠒⢄⡀⠀⠀⠱⡀⣈⢸⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⠇⠀⠀⢠⢤⡀⠀⠀⠀⠀⠀⣀⣄⡉⠢⡀⠀⢳⠑⢦⡄⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡏⢈⠍⠁⢖⠂⡤⡀⠸⡟⢀⣤⠄⡲⠂⠩⡙⢧⡌⢡⠒⠁⠲⡀
⠀⠀⠀⠀⠀⠀⠀⠀⠈⢉⣇⠈⠤⠠⠜⠒⠛⠧⠜⠳⠬⠟⠉⠣⠄⠤⢁⣹⠉⠹⣀⢀⣠⠃
⣠⠴⠒⠲⢦⣄⠀⠀⠀⠀⠘⢦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡴⠁⠈⠀⠀⠀⠀⠀
⡇⠀⠀⠘⣀⠜⢷⡀⠀⠀⠀⠀⠙⣷⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⢾⠁⠀⠀⠀⠀⠀⠀⠀⠀
⠙⠦⣄⡀⠀⠀⠐⢳⠀⠀⠀⢀⡾⢁⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣧⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠉⢢⡀⠐⠚⡇⠀⠀⡾⠃⠀⠊⠀⠀⠀⠀⠀⠀⠀⠀⠀⡉⠘⣆⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢣⠀⠀⣷⠀⢸⠃⠒⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠐⠺⡆⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠈⡄⠀⣿⠀⡿⠀⠒⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⡈⢳⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⢱⠀⢸⣰⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢹⡀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⢇⠈⢿⡇⠀⠀⠀⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⠇⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠈⢆⠀⠃⠀⠀⠀⠰⡀⠀⠀⠀⡆⠀⠀⠀⢠⠀⠀⠀⣸⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠳⣀⠀⠀⠀⠀⢳⠀⠀⠀⡇⠀⠀⠀⠎⠀⢀⡴⠃⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁⠒⠠⠤⠤⣕⣀⣄⢇⣀⣀⠞⠒⠚⠉⠀⠀⠀⠀⠀⠀⠀⠀
