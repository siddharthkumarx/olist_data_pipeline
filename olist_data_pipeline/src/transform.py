"""
TRANSFORM step.

Every function takes a raw DataFrame and returns a cleaned one.
Each cleaning decision is documented, because in an interview the
question is never "did you clean the data?" - it is "WHY did you
clean it that way?"

Known quirks in the Olist dataset (all handled below):
  * products: two column names are misspelled at the source
    ("lenght" instead of "length").
  * order_reviews: contains duplicate rows and duplicate
    (review_id, order_id) pairs.
  * geolocation: ~1M rows but only ~19k unique zip prefixes -
    the same prefix appears thousands of times with tiny GPS jitter.
  * orders: timestamp columns arrive as plain strings, with NULLs
    for orders that were never delivered.
"""

import logging

import pandas as pd

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Small shared helpers
# ---------------------------------------------------------------------------
def _to_datetime(df: pd.DataFrame, columns: list[str]) -> pd.DataFrame:
    """Parse string columns to datetime. errors='coerce' turns garbage
    values into NaT instead of crashing the whole pipeline."""
    for col in columns:
        df[col] = pd.to_datetime(df[col], errors="coerce")
    return df


def _clean_text(df: pd.DataFrame, columns: list[str]) -> pd.DataFrame:
    """Strip whitespace and lowercase free-text columns so that
    'Sao Paulo ' and 'sao paulo' group together in SQL."""
    for col in columns:
        df[col] = df[col].astype("string").str.strip().str.lower()
    return df


# ---------------------------------------------------------------------------
# One transform function per table
# ---------------------------------------------------------------------------
def transform_customers(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df = _clean_text(df, ["customer_city"])
    df["customer_state"] = df["customer_state"].str.upper().str.strip()
    return df


def transform_sellers(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df = _clean_text(df, ["seller_city"])
    df["seller_state"] = df["seller_state"].str.upper().str.strip()
    return df


def transform_geolocation(df: pd.DataFrame) -> pd.DataFrame:
    """Collapse ~1M jittery GPS points into one row per zip prefix.

    Why: the raw file repeats each prefix thousands of times with
    slightly different coordinates. For analytics we only need a single
    representative point per prefix, so we take the mean lat/lng and the
    first city/state. 1M rows -> ~19k rows, and the table gains a real
    primary key.
    """
    df = df.copy()
    df = _clean_text(df, ["geolocation_city"])
    df["geolocation_state"] = df["geolocation_state"].str.upper().str.strip()

    aggregated = (
        df.groupby("geolocation_zip_code_prefix", as_index=False)
        .agg(
            geolocation_lat=("geolocation_lat", "mean"),
            geolocation_lng=("geolocation_lng", "mean"),
            geolocation_city=("geolocation_city", "first"),
            geolocation_state=("geolocation_state", "first"),
        )
    )
    logger.info(
        "Geolocation deduplicated: %d raw rows -> %d unique zip prefixes",
        len(df),
        len(aggregated),
    )
    return aggregated


def transform_orders(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    timestamp_cols = [
        "order_purchase_timestamp",
        "order_approved_at",
        "order_delivered_carrier_date",
        "order_delivered_customer_date",
        "order_estimated_delivery_date",
    ]
    df = _to_datetime(df, timestamp_cols)
    df["order_status"] = df["order_status"].str.strip().str.lower()
    # NULL delivery dates are kept on purpose: an undelivered order is
    # real information, not dirty data. Analytics queries filter on
    # order_status = 'delivered' where it matters.
    return df


def transform_order_items(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df = _to_datetime(df, ["shipping_limit_date"])
    return df


def transform_payments(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["payment_type"] = df["payment_type"].str.strip().str.lower()
    return df


def transform_reviews(df: pd.DataFrame) -> pd.DataFrame:
    """Deduplicate reviews.

    The raw file contains (a) fully identical duplicate rows and
    (b) the same (review_id, order_id) pair appearing more than once
    with different answer timestamps. We keep the most recent answer,
    because that reflects the final state of the review.
    (review_id, order_id) then becomes a valid composite primary key.
    """
    df = df.copy()
    df = _to_datetime(df, ["review_creation_date", "review_answer_timestamp"])

    before = len(df)
    df = df.drop_duplicates()
    df = (
        df.sort_values("review_answer_timestamp")
        .drop_duplicates(subset=["review_id", "order_id"], keep="last")
    )
    logger.info("Reviews deduplicated: %d -> %d rows", before, len(df))
    return df


def transform_products(df: pd.DataFrame) -> pd.DataFrame:
    """Fix source-data misspellings so the warehouse is not stuck
    with 'lenght' forever. Category NULLs are kept as NULL - inventing
    an 'unknown' category would silently distort category analytics."""
    df = df.copy()
    df = df.rename(
        columns={
            "product_name_lenght": "product_name_length",
            "product_description_lenght": "product_description_length",
        }
    )
    return df


def transform_category_translation(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    return df.drop_duplicates(subset=["product_category_name"])


# ---------------------------------------------------------------------------
# Orchestrator for this step
# ---------------------------------------------------------------------------
def transform_all(raw: dict[str, pd.DataFrame]) -> dict[str, pd.DataFrame]:
    """Apply every transform. Returns a dict keyed by *target table name*.

    The keys here must match the table names created in sql/01_schema.sql -
    load.py relies on that contract.
    """
    transformed = {
        "customers": transform_customers(raw["olist_customers_dataset.csv"]),
        "sellers": transform_sellers(raw["olist_sellers_dataset.csv"]),
        "geolocation": transform_geolocation(raw["olist_geolocation_dataset.csv"]),
        "product_category_translation": transform_category_translation(
            raw["product_category_name_translation.csv"]
        ),
        "products": transform_products(raw["olist_products_dataset.csv"]),
        "orders": transform_orders(raw["olist_orders_dataset.csv"]),
        "order_items": transform_order_items(raw["olist_order_items_dataset.csv"]),
        "order_payments": transform_payments(raw["olist_order_payments_dataset.csv"]),
        "order_reviews": transform_reviews(raw["olist_order_reviews_dataset.csv"]),
    }
    for table, df in transformed.items():
        logger.info("Transformed %-30s %8d rows ready to load", table, len(df))
    return transformed
