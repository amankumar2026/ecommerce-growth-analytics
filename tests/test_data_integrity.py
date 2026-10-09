"""Checks that the clean views are consistent with the raw tables and
with each other. They need the PostgreSQL database to be loaded.

    python -m pytest tests
"""

import pandas as pd
import pytest

from src.db import ROOT, query, read_queries


def scalar(sql: str):
    return query(sql).iloc[0, 0]


def test_one_row_per_order():
    assert scalar("SELECT COUNT(*) - COUNT(DISTINCT order_id) FROM v_orders") == 0


def test_only_delivered_orders_inside_the_window():
    outside = scalar("""
        SELECT COUNT(*) FROM v_orders v JOIN orders o USING (order_id)
        WHERE o.order_status <> 'delivered'
           OR v.order_date < DATE '2017-01-01' OR v.order_date > DATE '2018-08-31'""")
    assert outside == 0


def test_revenue_matches_the_raw_tables():
    """Revenue in the view must equal an independent sum over raw tables."""
    raw = scalar("""
        SELECT SUM(i.price) FROM order_items i JOIN orders o USING (order_id)
        WHERE o.order_status = 'delivered'
          AND o.order_purchase_timestamp >= '2017-01-01'
          AND o.order_purchase_timestamp <  '2018-09-01'""")
    assert scalar("SELECT SUM(revenue) FROM v_orders") == raw


def test_order_and_item_views_agree():
    assert scalar("SELECT SUM(revenue) FROM v_orders") == scalar("SELECT SUM(price) FROM v_order_items")
    assert scalar("SELECT SUM(items) FROM v_orders") == scalar("SELECT COUNT(*) FROM v_order_items")


def test_customer_view_agrees_with_orders():
    assert scalar("SELECT SUM(orders) FROM v_customers") == scalar("SELECT COUNT(*) FROM v_orders")
    assert scalar("SELECT SUM(revenue) FROM v_customers") == scalar("SELECT SUM(revenue) FROM v_orders")
    assert scalar("SELECT COUNT(*) FROM v_customers") == scalar(
        "SELECT COUNT(DISTINCT customer_unique_id) FROM v_orders")


def test_every_customer_has_exactly_one_segment():
    assert scalar("SELECT COUNT(*) FROM v_customer_rfm") == scalar("SELECT COUNT(*) FROM v_customers")
    assert scalar("SELECT COUNT(*) FROM v_customer_rfm WHERE segment IS NULL") == 0


def test_first_orders_equal_number_of_customers():
    first_orders = scalar("SELECT COUNT(*) FROM v_orders WHERE customer_order_number = 1")
    assert first_orders == scalar("SELECT COUNT(*) FROM v_customers")


def test_cohort_month_zero_is_always_100_percent():
    cohorts = query(read_queries("04_customer_retention.sql")["cohort_retention"])
    month_zero = cohorts[cohorts["months_since_first"] == 0]
    assert (month_zero["retention_pct"] == 100).all()
    assert month_zero["cohort_customers"].sum() == scalar("SELECT COUNT(*) FROM v_customers")


def test_shares_add_up_to_100():
    segments = query(read_queries("05_customer_segments.sql")["rfm_segments"])
    assert segments["customer_share_pct"].sum() == pytest.approx(100, abs=0.5)
    assert segments["revenue_share_pct"].sum() == pytest.approx(100, abs=0.5)


def test_powerbi_export_matches_the_database():
    data = ROOT / "powerbi" / "data"
    orders = pd.read_csv(data / "fact_orders.csv")
    items = pd.read_csv(data / "fact_order_items.csv")
    assert len(orders) == scalar("SELECT COUNT(*) FROM v_orders")
    assert orders["revenue"].sum() == pytest.approx(float(scalar("SELECT SUM(revenue) FROM v_orders")))
    assert items["price"].sum() == pytest.approx(orders["revenue"].sum())
