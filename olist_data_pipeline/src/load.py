"""
LOAD step.

Responsibilities:
1. Create the database if it does not exist.
2. Create all tables from sql/01_schema.sql (idempotent).
3. Truncate tables, then load DataFrames in foreign-key-safe order.
4. Validate: row count in MySQL must equal row count in the DataFrame.

The pipeline is idempotent: running it twice produces the same
warehouse, not duplicated rows. That single property separates a
pipeline from a script.
"""

import logging

import pandas as pd
from sqlalchemy import create_engine, text

from src import config

logger = logging.getLogger(__name__)

# Load order matters: parents before children, so foreign keys resolve.
LOAD_ORDER = [
    "geolocation",
    "customers",
    "sellers",
    "product_category_translation",
    "products",
    "orders",
    "order_items",
    "order_payments",
    "order_reviews",
]


def create_database() -> None:
    """Connect at server level (no db selected) and create the database."""
    engine = create_engine(config.server_url())
    with engine.connect() as conn:
        conn.execute(
            text(
                f"CREATE DATABASE IF NOT EXISTS {config.DB_NAME} "
                "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
            )
        )
        conn.commit()
    engine.dispose()
    logger.info("Database '%s' ready.", config.DB_NAME)


def create_tables(engine) -> None:
    """Execute every statement in the schema file."""
    schema_sql = config.SCHEMA_FILE.read_text(encoding="utf-8")
    statements = [s.strip() for s in schema_sql.split(";") if s.strip()]
    with engine.connect() as conn:
        for statement in statements:
            conn.execute(text(statement))
        conn.commit()
    logger.info("Schema applied: %d statements executed.", len(statements))


def truncate_tables(engine) -> None:
    """Empty all tables so a re-run starts clean.

    FK checks are disabled only for the truncate itself - truncating a
    parent table with children is otherwise blocked by MySQL.
    """
    with engine.connect() as conn:
        conn.execute(text("SET FOREIGN_KEY_CHECKS = 0"))
        for table in LOAD_ORDER:
            conn.execute(text(f"TRUNCATE TABLE {table}"))
        conn.execute(text("SET FOREIGN_KEY_CHECKS = 1"))
        conn.commit()
    logger.info("All tables truncated (idempotent re-run).")


def load_table(engine, table: str, df: pd.DataFrame) -> None:
    df.to_sql(
        name=table,
        con=engine,
        if_exists="append",  # tables already exist with proper types/keys
        index=False,
        chunksize=5000,
        method="multi",
    )
    logger.info("Loaded %-30s %8d rows", table, len(df))


def validate_load(engine, tables: dict[str, pd.DataFrame]) -> None:
    """Compare DataFrame row counts against warehouse row counts."""
    logger.info("---- Post-load validation ----")
    all_ok = True
    with engine.connect() as conn:
        for table in LOAD_ORDER:
            expected = len(tables[table])
            actual = conn.execute(text(f"SELECT COUNT(*) FROM {table}")).scalar()
            status = "OK " if expected == actual else "FAIL"
            if expected != actual:
                all_ok = False
            logger.info(
                "%s  %-30s expected=%8d  loaded=%8d", status, table, expected, actual
            )
    if not all_ok:
        raise RuntimeError("Row count validation failed - see log above.")
    logger.info("Validation passed: all row counts match.")


def load_all(tables: dict[str, pd.DataFrame]) -> None:
    create_database()
    engine = create_engine(config.database_url())
    try:
        create_tables(engine)
        truncate_tables(engine)
        for table in LOAD_ORDER:
            load_table(engine, table, tables[table])
        validate_load(engine, tables)
    finally:
        engine.dispose()
