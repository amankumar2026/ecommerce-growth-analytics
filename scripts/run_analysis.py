"""Run every analysis query and save each result as a CSV in reports/results/.

    python scripts/run_analysis.py
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from src.db import query, read_queries  # noqa: E402

RESULTS = ROOT / "reports" / "results"
FILES = ["00_data_quality_checks.sql", "03_sales_performance.sql", "04_customer_retention.sql",
         "05_customer_segments.sql", "06_delivery_and_reviews.sql"]


def main() -> None:
    RESULTS.mkdir(parents=True, exist_ok=True)
    for file in FILES:
        print(f"\n=== {file}")
        for name, sql in read_queries(file).items():
            df = query(sql)
            df.to_csv(RESULTS / f"{name}.csv", index=False)
            print(f"\n-- {name} ({len(df)} rows)")
            print(df.head(25).to_string(index=False))


if __name__ == "__main__":
    main()
