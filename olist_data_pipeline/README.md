# Olist E-Commerce Data Pipeline

<p align="center">
  <img src="assets/pipeline_architecture.svg" width="920" alt="Animated architecture: raw CSVs flow through extract, transform, and load stages into a MySQL warehouse, feeding a SQL analytics layer">
</p>

An end-to-end batch ETL pipeline built on the [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (100k real orders, 2016 to 2018). Raw CSVs are validated, cleaned with pandas, loaded into a MySQL warehouse with enforced referential integrity, and analyzed through a layer of ten SQL queries that answer real business questions: revenue trends, cohort retention, RFM segmentation, seller rankings, and the operational link between late delivery and one-star reviews.

The pipeline is idempotent. Running it twice produces the same warehouse, not duplicated rows.

## Pipeline demo

<p align="center">
  <img src="assets/pipeline_demo.gif" width="760" alt="Terminal recording of the pipeline run: extract, transform, load, and validation stages logging in sequence">
</p>

## Architecture

The pipeline runs as three strictly separated stages, orchestrated by `src/pipeline.py`:

**Extract** (`src/extract.py`) confirms all nine raw files exist and that every file matches its expected column schema before anything else runs. A broken source file stops the pipeline immediately rather than surfacing as a corrupted warehouse an hour later.

**Transform** (`src/transform.py`) applies one documented cleaning function per table: timestamp parsing, text normalization, deduplication, and source-schema repairs. Every decision is commented with its reasoning, because the interview question is never *whether* the data was cleaned but *why* it was cleaned that way.

**Load** (`src/load.py`) creates the database and schema if absent, truncates all tables, inserts in foreign-key-safe order, and then validates that the row count in MySQL matches the row count in every DataFrame. A mismatch fails the run.

Structured logs stream to both the console and `logs/pipeline.log`.

## Data quality decisions

Real datasets arrive broken in specific ways. The interesting part of this project is how each defect is handled:

| Defect in the source data | Decision |
|---|---|
| `products` columns misspelled at source (`product_name_lenght`) | Renamed during transform so the warehouse is not stuck with the typo forever |
| `order_reviews` contains duplicate rows and repeated `(review_id, order_id)` pairs | Deduplicated keeping the most recent answer; the pair then becomes a valid composite primary key |
| `geolocation` has roughly 1M rows of GPS jitter for only ~19k zip prefixes | Aggregated to one representative coordinate per prefix, giving the table a real primary key |
| Undelivered orders have NULL delivery timestamps | Kept as NULL. An undelivered order is information, not dirt; analytics filter on `order_status` where it matters |
| Translation table is missing a few product categories | No foreign key from `products`; analytics use `LEFT JOIN` with `COALESCE` fallback |
| `customer_id` is unique per order, not per person | All customer-level analytics use `customer_unique_id`; query 09 documents the trap explicitly |

## Analytics layer

Ten queries in `sql/analytics/`, each headed by the business question it answers and the SQL techniques it demonstrates:

| # | File | Business question |
|---|---|---|
| 01 | `01_monthly_revenue_trend.sql` | Is the marketplace growing, and how fast month over month? |
| 02 | `02_top_categories_by_revenue.sql` | Which categories drive revenue, and how concentrated is it? |
| 03 | `03_delivery_performance_by_state.sql` | Where is delivery slow or unreliable? |
| 04 | `04_customer_cohort_retention.sql` | Do customers come back after their first purchase? |
| 05 | `05_rfm_customer_segmentation.sql` | Who are the best customers worth retaining? |
| 06 | `06_seller_performance_ranking.sql` | Which sellers combine high revenue with poor ratings? |
| 07 | `07_payment_behavior.sql` | How do customers pay, and do installments track order size? |
| 08 | `08_delivery_delay_vs_reviews.sql` | Does late delivery actually cause bad reviews? |
| 09 | `09_repeat_purchase_rate.sql` | What share of customers ever buy twice? |
| 10 | `10_freight_cost_by_region.sql` | Where does freight eat the margin? |

Techniques covered across the layer: CTEs and chained CTEs, `LAG`, `FIRST_VALUE`, `NTILE`, `DENSE_RANK`, window aggregates (`SUM() OVER ()`), boolean aggregation for percentages, `DATEDIFF` and `TIMESTAMPDIFF`, `NULLIF` guards, and minimum-volume `HAVING` filters.

## Project structure

```
olist-data-pipeline/
├── assets/                  architecture SVG and demo GIF
├── data/
│   ├── raw/                 place the 9 Kaggle CSVs here (gitignored)
│   └── processed/           intermediate outputs (gitignored)
├── logs/                    pipeline.log (gitignored)
├── sql/
│   ├── 01_schema.sql        warehouse DDL: keys, constraints, indexes
│   └── analytics/           the 10 analytical queries
├── src/
│   ├── config.py            paths, credentials from .env, expected schemas
│   ├── extract.py           file and column validation, CSV reading
│   ├── transform.py         per-table cleaning with documented reasoning
│   ├── load.py              schema creation, idempotent load, validation
│   └── pipeline.py          orchestrator: python -m src.pipeline
├── .env.example
├── .gitignore
└── requirements.txt
```

## Setup and usage

Requires Python 3.10+ and a local MySQL 8 server.

```bash
# 1. Clone and enter the project
git clone https://github.com/siddharthkumarx/olist-data-pipeline.git
cd olist-data-pipeline

# 2. Create a virtual environment and install dependencies
python -m venv venv
venv\Scripts\activate          # Windows
# source venv/bin/activate     # macOS / Linux
pip install -r requirements.txt

# 3. Configure database credentials
copy .env.example .env         # Windows (cp on macOS/Linux)
# edit .env with your MySQL user and password

# 4. Download the dataset
# https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
# Unzip all 9 CSVs into data/raw/

# 5. Run the pipeline
python -m src.pipeline
```

The run finishes with a validation report comparing expected against loaded row counts for every table. Analytics queries can then be executed in MySQL Workbench or from the client:

```bash
mysql -u your_user -p olist < sql/analytics/08_delivery_delay_vs_reviews.sql
```

## Verified behavior

The pipeline and all ten analytics queries were tested end-to-end against MySQL 8: schema creation, foreign-key-ordered loading, post-load row count validation, and a second full run confirming idempotency. Transform logic is additionally covered by assertions on every documented data quality decision, including review deduplication keeping the latest answer and geolocation collapse to unique zip prefixes.

## Roadmap

Planned extensions, in order: orchestration with Apache Airflow, transformation layer in dbt, cloud warehouse target, and a pytest suite formalizing the current assertion checks.

## Stack

Python 3.10, pandas, SQLAlchemy, PyMySQL, MySQL 8.
