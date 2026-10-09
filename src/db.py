"""Database connection and small helpers for running SQL files."""

import os
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

ROOT = Path(__file__).resolve().parent.parent
SQL_DIR = ROOT / "sql"
load_dotenv(ROOT / ".env")

DATABASE_URL = URL.create(
    "postgresql+psycopg2",
    username=os.getenv("POSTGRES_USER", "postgres"),
    password=os.getenv("POSTGRES_PASSWORD", ""),
    host=os.getenv("POSTGRES_HOST", "localhost"),
    port=int(os.getenv("POSTGRES_PORT", "5432")),
    database=os.getenv("POSTGRES_DB", "ecommerce_analytics"),
)


def get_engine():
    return create_engine(DATABASE_URL)


def run_sql_file(name: str) -> None:
    """Execute a whole .sql file (used for schema and view definitions)."""
    sql = (SQL_DIR / name).read_text(encoding="utf-8")
    with get_engine().begin() as conn:
        # The raw cursor is used so a "%" inside the SQL file is not
        # mistaken for a parameter placeholder.
        conn.connection.cursor().execute(sql)


def read_queries(name: str) -> dict[str, str]:
    """Split an analysis file into {query name: SQL}.

    Each query in the file starts with a line like:  -- name: monthly_revenue
    """
    queries, current = {}, None
    for line in (SQL_DIR / name).read_text(encoding="utf-8").splitlines():
        if line.startswith("-- name:"):
            current = line.split(":", 1)[1].strip()
            queries[current] = ""
        elif current:
            queries[current] += line + "\n"
    return queries


def query(sql: str) -> pd.DataFrame:
    with get_engine().connect() as conn:
        return pd.read_sql(text(sql), conn)
