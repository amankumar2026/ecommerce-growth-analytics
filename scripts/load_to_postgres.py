"""Create the database, the tables and the views, and load the CSV files.

    python scripts/load_to_postgres.py

Safe to run again: it drops and rebuilds everything.
"""

import sys
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from src.db import DATABASE_URL, get_engine, run_sql_file  # noqa: E402

OLIST = ROOT / "data" / "raw" / "olist"


def create_database_if_missing() -> None:
    # CREATE DATABASE cannot run inside a transaction, hence AUTOCOMMIT.
    admin = create_engine(DATABASE_URL.set(database="postgres"), isolation_level="AUTOCOMMIT")
    with admin.connect() as conn:
        exists = conn.execute(text("SELECT 1 FROM pg_database WHERE datname = :n"),
                              {"n": DATABASE_URL.database}).scalar()
        if not exists:
            conn.execute(text(f'CREATE DATABASE "{DATABASE_URL.database}"'))
            print("Created database", DATABASE_URL.database)


def read_tables() -> dict[str, pd.DataFrame]:
    """Read each CSV and keep only the columns the schema defines.
    Order matters: parent tables are loaded before the tables that
    reference them."""
    products = pd.read_csv(OLIST / "olist_products_dataset.csv").merge(
        pd.read_csv(OLIST / "product_category_name_translation.csv"),
        on="product_category_name", how="left")
    # Two categories have no English translation in the source file;
    # fall back to the original name so they are not lost.
    products["product_category"] = products["product_category_name_english"].fillna(
        products["product_category_name"])

    return {
        "customers": pd.read_csv(OLIST / "olist_customers_dataset.csv")[
            ["customer_id", "customer_unique_id", "customer_city", "customer_state"]],
        "sellers": pd.read_csv(OLIST / "olist_sellers_dataset.csv")[
            ["seller_id", "seller_city", "seller_state"]],
        "products": products[["product_id", "product_category"]],
        "orders": pd.read_csv(OLIST / "olist_orders_dataset.csv")[
            ["order_id", "customer_id", "order_status", "order_purchase_timestamp",
             "order_delivered_customer_date", "order_estimated_delivery_date"]],
        "order_items": pd.read_csv(OLIST / "olist_order_items_dataset.csv")[
            ["order_id", "order_item_id", "product_id", "seller_id", "price", "freight_value"]],
        "payments": pd.read_csv(OLIST / "olist_order_payments_dataset.csv"),
        "reviews": pd.read_csv(OLIST / "olist_order_reviews_dataset.csv")[
            ["review_id", "order_id", "review_score", "review_creation_date"]],
    }


def main() -> None:
    create_database_if_missing()
    run_sql_file("01_schema.sql")
    engine = get_engine()
    for name, df in read_tables().items():
        df.to_sql(name, engine, if_exists="append", index=False, chunksize=10_000, method="multi")
        print(f"{name:12s} {len(df):>8,} rows")
    run_sql_file("02_views.sql")
    print("Views created.")


if __name__ == "__main__":
    main()
