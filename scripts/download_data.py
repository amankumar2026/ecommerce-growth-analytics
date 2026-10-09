"""Download the Olist e-commerce dataset from Kaggle into data/raw/olist/.

    python scripts/download_data.py

No Kaggle account is needed: kagglehub can fetch public datasets.
Source: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
"""

import shutil
from pathlib import Path

import kagglehub

RAW = Path(__file__).resolve().parent.parent / "data" / "raw"
DATASETS = {
    "olistbr/brazilian-ecommerce": RAW / "olist",
}

for slug, target in DATASETS.items():
    source = Path(kagglehub.dataset_download(slug))
    target.mkdir(parents=True, exist_ok=True)
    for file in source.glob("*.csv"):
        if "geolocation" in file.name:      # 61 MB and not used in this project
            continue
        shutil.copy(file, target / file.name)
        print(f"{slug}: {file.name}")
