#!/usr/bin/env python3
"""
Zero-downtime backfill script for PostgreSQL.

Safely backfills a new column in batches using cursor-based pagination
with configurable batch size and throttle delay.

Usage:
    # Dry run (count rows to process)
    python backfill.py --table users --column phone --value "'+86-1234567890'" --dry-run

    # Backfill with defaults (batch=1000, delay=100ms)
    python backfill.py --table users --column phone --value "'+86-1234567890'"

    # Backfill using subquery
    python backfill.py --table orders --column total_nt --value "total * 1.15"

    # Custom connection
    python backfill.py --table users --column phone --value "''" \
        --dsn "postgresql://user:pass@host:5432/db" --batch 5000 --delay 0.5

Requirements: psycopg2 or psycopg2-binary
"""

import argparse
import os
import sys
import time

try:
    import psycopg2
    from psycopg2 import sql
except ImportError:
    print("ERROR: psycopg2 is required. Install: pip install psycopg2-binary")
    sys.exit(1)


def get_dsn():
    return os.getenv(
        "DATABASE_URL",
        "postgresql://postgres:postgres@localhost:5432/postgres"
    )


def count_pending(conn, table, column):
    with conn.cursor() as cur:
        cur.execute(
            sql.SQL("SELECT COUNT(*) FROM {} WHERE {} IS NULL").format(
                sql.Identifier(table), sql.Identifier(column)
            )
        )
        return cur.fetchone()[0]


def batch_backfill(conn, table, column, value_expr, batch_size, delay, dry_run):
    table_id = sql.Identifier(table)
    col_id = sql.Identifier(column)
    pk = _detect_pk(conn, table)
    if not pk:
        print(f"ERROR: No primary key found on table '{table}'")
        sys.exit(1)

    total = count_pending(conn, table, column)
    if total == 0:
        print("No NULL rows to backfill. Nothing to do.")
        return

    print(f"Table: {table}")
    print(f"Column: {column}")
    print(f"Primary key: {pk}")
    print(f"Pending rows: {total}")
    print(f"Batch size: {batch_size}")
    print(f"Delay: {delay}s")
    print(f"Dry run: {dry_run}")
    print("-" * 50)

    if dry_run:
        print("DRY RUN — no updates performed.")
        return

    last_id = 0
    processed = 0
    errors = 0

    while processed < total:
        with conn.cursor() as cur:
            update = sql.SQL(
                "UPDATE {table} SET {col} = {value} "
                "WHERE {pk} > %s AND {col} IS NULL "
                "ORDER BY {pk} LIMIT %s"
            ).format(
                table=table_id, col=col_id,
                value=sql.SQL(value_expr),
                pk=sql.Identifier(pk)
            )
            try:
                cur.execute(update, (last_id, batch_size))
                affected = cur.rowcount
                conn.commit()

                if affected > 0:
                    # Get the max pk from this batch for next cursor
                    cur.execute(
                        sql.SQL("SELECT MAX({}) FROM {} WHERE {} = %s").format(
                            sql.Identifier(pk), table_id, col_id
                        ),
                        (value_expr.strip("'"),)
                    )
                    last_id = cur.fetchone()[0] or last_id
                    processed += affected
                    print(f"  Progress: {processed}/{total} ({processed*100//total}%) — batch: {affected}")
                else:
                    break
            except Exception as e:
                conn.rollback()
                errors += 1
                print(f"  ERROR on batch starting after id={last_id}: {e}")
                if errors >= 3:
                    print("FATAL: Too many consecutive errors. Aborting.")
                    sys.exit(1)

        if delay > 0:
            time.sleep(delay)

    print("-" * 50)
    print(f"Done. Processed: {processed}, Errors: {errors}")


def _detect_pk(conn, table):
    query = """
        SELECT a.attname
        FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid
            AND a.attnum = ANY(i.indkey)
        WHERE i.indrelid = %s::regclass
            AND i.indisprimary
        ORDER BY a.attnum
        LIMIT 1
    """
    with conn.cursor() as cur:
        cur.execute(query, (table,))
        row = cur.fetchone()
        return row[0] if row else None


def parse_args():
    parser = argparse.ArgumentParser(
        description="Zero-downtime backfill for PostgreSQL columns"
    )
    parser.add_argument("--table", required=True, help="Table name")
    parser.add_argument("--column", required=True, help="Column name to backfill")
    parser.add_argument("--value", required=True,
                        help="SQL expression for the value (e.g. '' or 'total * 1.15')")
    parser.add_argument("--dsn", default=None, help="PostgreSQL connection string")
    parser.add_argument("--batch", type=int, default=1000, help="Batch size (default: 1000)")
    parser.add_argument("--delay", type=float, default=0.1, help="Delay between batches in seconds (default: 0.1)")
    parser.add_argument("--dry-run", action="store_true", help="Count pending rows without updating")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    dsn = args.dsn or get_dsn()
    conn = psycopg2.connect(dsn)
    try:
        batch_backfill(conn, args.table, args.column, args.value,
                       args.batch, args.delay, args.dry_run)
    finally:
        conn.close()
