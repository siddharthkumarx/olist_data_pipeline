"""
Pipeline orchestrator.

Run with:
    python -m src.pipeline

Flow:  EXTRACT (validate + read raw CSVs)
    -> TRANSFORM (clean, dedupe, fix schema)
    -> LOAD (create schema, truncate, insert, validate)
"""

import logging
import sys
import time

from src import config, extract, load, transform


def setup_logging() -> None:
    """Log to both console and logs/pipeline.log."""
    config.LOG_DIR.mkdir(exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s | %(levelname)-7s | %(name)s | %(message)s",
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler(config.LOG_DIR / "pipeline.log", encoding="utf-8"),
        ],
    )


def run() -> None:
    setup_logging()
    logger = logging.getLogger("pipeline")

    start = time.perf_counter()
    logger.info("========== OLIST PIPELINE START ==========")

    logger.info("---- EXTRACT ----")
    raw = extract.extract_all()

    logger.info("---- TRANSFORM ----")
    tables = transform.transform_all(raw)

    logger.info("---- LOAD ----")
    load.load_all(tables)

    elapsed = time.perf_counter() - start
    logger.info("========== PIPELINE COMPLETE in %.1f s ==========", elapsed)


if __name__ == "__main__":
    run()
