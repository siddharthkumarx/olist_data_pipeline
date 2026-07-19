"""
EXTRACT step.

Responsibilities:
1. Confirm every expected raw file exists in data/raw/.
2. Confirm every file contains exactly the columns we expect.
3. Read each file into a pandas DataFrame.

Nothing is cleaned or changed here. Extract only observes and reports -
if the source data is broken, the pipeline should stop *now*, not after
half the warehouse is loaded.
"""

import logging

import pandas as pd

from src import config

logger = logging.getLogger(__name__)


def validate_raw_files() -> None:
    """Raise FileNotFoundError if any expected raw CSV is missing."""
    missing = [
        name
        for name in config.EXPECTED_FILES
        if not (config.RAW_DATA_DIR / name).exists()
    ]
    if missing:
        raise FileNotFoundError(
            f"Missing raw files in {config.RAW_DATA_DIR}: {missing}. "
            "Download the Olist dataset from Kaggle and place all 9 CSVs there."
        )
    logger.info("All %d expected raw files found.", len(config.EXPECTED_FILES))


def validate_columns(name: str, df: pd.DataFrame) -> None:
    """Raise ValueError if a file's columns differ from the expected schema."""
    expected = set(config.EXPECTED_FILES[name])
    actual = set(df.columns)
    if expected != actual:
        raise ValueError(
            f"Schema mismatch in {name}. "
            f"Missing: {sorted(expected - actual)} | Unexpected: {sorted(actual - expected)}"
        )


def extract_all() -> dict[str, pd.DataFrame]:
    """Read every raw CSV into a dict of DataFrames keyed by file name."""
    validate_raw_files()

    frames: dict[str, pd.DataFrame] = {}
    for name in config.EXPECTED_FILES:
        path = config.RAW_DATA_DIR / name
        df = pd.read_csv(path)
        validate_columns(name, df)
        frames[name] = df
        logger.info("Extracted %-45s %8d rows", name, len(df))

    return frames
