"""Export the clean views as CSV files for Power BI (a star schema).

    python scripts/export_powerbi.py

Power BI can also connect to PostgreSQL directly. CSV files are used so
the dashboard can be opened on any machine without a database.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from src.db import query, read_queries  # noqa: E402

OUT = ROOT / "powerbi" / "data"

EXPORTS = {
    # Fact table: one row per delivered order
    "fact_orders": """
        SELECT order_id, customer_unique_id, order_date, revenue, freight, items,
               delivery_days, delivered_late::int AS delivered_late,
               review_score, customer_order_number
        FROM v_orders""",
    # Fact table: one row per item sold
    "fact_order_items": """
        SELECT order_id, order_item_id, customer_unique_id, order_date,
               product_category, price, freight_value
        FROM v_order_items
        JOIN (SELECT order_id, customer_unique_id FROM v_orders) o USING (order_id)""",
    # Dimension: one row per customer, with cohort and RFM segment
    "dim_customer": """
        SELECT c.customer_unique_id, c.customer_state, c.first_order_date, c.cohort_month,
               c.orders, c.revenue, r.recency_days, r.r_score, r.m_score, r.segment
        FROM v_customers c
        JOIN v_customer_rfm r USING (customer_unique_id)""",
    # Dimension: one row per product category, with a readable label
    "dim_category": """
        SELECT DISTINCT product_category,
               INITCAP(REPLACE(product_category, '_', ' ')) AS category_name
        FROM v_order_items""",
    # Dimension: one row per calendar day
    "dim_date": "SELECT * FROM dim_date",
    # Cohort retention is calculated in SQL (see 04_customer_retention.sql)
    "cohort_retention": read_queries("04_customer_retention.sql")["cohort_retention"],
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, sql in EXPORTS.items():
        df = query(sql)
        df.to_csv(OUT / f"{name}.csv", index=False)
        size_mb = (OUT / f"{name}.csv").stat().st_size / 1e6
        print(f"{name:18s} {len(df):>8,} rows  {size_mb:5.1f} MB")


if __name__ == "__main__":
    main()
