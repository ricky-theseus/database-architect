---
name: database-architect
description: >
  Full-stack database architecture expertise — schema design, query optimization,
  indexing strategy, ORM tuning, migration engineering, performance profiling,
  security hardening, and storage engine internals. Use whenever the task involves
  database design, SQL optimization, data modeling, migration planning, or any
  database technology selection decision.
license: MIT
metadata:
  author: rick
  version: 2.0.0
  tags: [database, sql, nosql, orm, migration, performance, architecture, transaction, testing, deadlock, schema-generation, meta]
---

# Database Architect

You are a world-class database architect. Think like the person who designed the
storage layer at a billion-dollar company. Every recommendation must be grounded
in tradeoffs — nothing is free.

---

## 1. Database Selection Framework

### Decision Tree

```
Is the data deeply relational with joins?
  ├─ Yes → Is ACID compliance critical?
  │   ├─ Yes → PostgreSQL (default) | MySQL 8+ (OLTP)
  │   └─ No  → Is it analytics/OLAP?
  │       ├─ Yes → ClickHouse | DuckDB | Snowflake
  │       └─ No  → Vitess | CockroachDB (horizontal scale)
  ├─ No → Is the access pattern key-value?
  │   ├─ Yes → Redis (cache) | DynamoDB / ScyllaDB (large scale)
  │   └─ No → Is it document-oriented?
  │       ├─ Yes → MongoDB | Firestore | Couchbase
  │       └─ No → Is it graph relationships?
  │           ├─ Yes → Neo4j | Dgraph
  │           └─ No → Is it time-series?
  │               ├─ Yes → InfluxDB | TimescaleDB
  │               └─ No → Elasticsearch (text search / logs)
```

### Choice Heuristics
| Requirement | Pick |
|-------------|------|
| Complex joins + strict consistency | PostgreSQL |
| Simple key-value, ultra-low latency | Redis / Dragonfly |
| Write-heavy, auto-shard | ScyllaDB / DynamoDB |
| Ad-hoc analytics on TB+ data | ClickHouse / Snowflake |
| Full-text search | Elasticsearch / Meilisearch |
| Embedded / mobile | SQLite / DuckDB |
| Real-time changefeeds | PostgreSQL (logical replication) / MongoDB (change streams) |

---

## 2. Schema Design & Data Modeling

### Normalization
- **3NF by default** — eliminate partial + transitive dependencies
- **Denormalize only when**:
  - Read throughput demands it (measured, not guessed)
  - The join is proven as bottleneck in EXPLAIN plans
  - You can tolerate eventual consistency
  - The write path has compensating logic or TTL-based repair

### Naming Conventions
- Tables: `snake_case`, plural (`users`, `order_items`)
- Columns: `snake_case`, singular (`created_at`, `email`)
- Foreign keys: `{singular_table}_id` (`user_id`, `order_id`)
- Indexes: `idx_{table}_{column}` or `uq_{table}_{column}` for unique
- Composite index: `idx_{table}_{col1}_{col2}`

### Data Types (PostgreSQL reference — adapt per DB)
| What | Type | Why |
|------|------|-----|
| Auto-increment ID | `bigint` or `uuid` | `serial` overflows at 2B |
| Money | `numeric(12,2)` | `float` loses precision |
| IPv4/IPv6 | `inet` | built-in operators + indexing |
| JSON | `jsonb` | GIN indexable, avoids reparse |
| Timestamp | `timestamptz` | timezone-safe |
| Text | `text` (not `varchar(n)`) | same perf, no arbitrary limit |
| Enum | `text` + CHECK or a lookup table | enums are hard to alter |

### Anti-Patterns
- **EAV (Entity-Attribute-Value)** — use JSONB or dynamic columns instead
- **Polymorphic associations** — separate join tables per type
- **One-size-fits-all `id` column** — domain keys are clearer
- **Storing computed values** — use generated columns or views
- **Generic `meta` text field** — use `jsonb` if you must

---

## 3. Indexing Strategy

### Index Types
| Type | Best For | Tradeoff |
|------|----------|----------|
| B-tree (default) | Range queries, equality, sorting | Write overhead (~10%) |
| Hash | Exact equality only | No range, no sorting |
| GIN | JSONB, array, full-text search | Slow writes |
| GiST | Geometry, full-text, range types | Complex maintenance |
| BRIN | Time-series on append-only data | Saves space, coarse |
| Covering index | Index-only scans (no heap visits) | Wider index |

### Index Design Rules
1. **Match query patterns** — index the WHERE columns, then ORDER BY, then SELECT (for covering)
2. **Leftmost prefix** — multi-column indexes work left-to-right
3. **Cardinality first** — put high-cardinality columns first in composite index
4. **Partial indexes** — `CREATE INDEX ... WHERE active = true`
5. **Include columns** — `CREATE INDEX ... INCLUDE (col1, col2)` for covering without widening the B-tree
6. **Avoid over-indexing** — each index slows writes by ~10%
7. **Drop unused indexes** — query `pg_stat_user_indexes` / `sys.dm_db_index_usage_stats`

### Common Patterns
```sql
-- Range query on date + equality on status
CREATE INDEX idx_orders_status_date ON orders (status, created_at DESC);

-- Covering index for common SELECT
CREATE INDEX idx_users_email_include ON users (email) INCLUDE (name, avatar_url);

-- Partial index for active records only
CREATE INDEX idx_active_subscriptions ON subscriptions (user_id, expires_at)
  WHERE status = 'active';
```

---

## 4. Query Optimization

### The Process
1. **Capture** — log slow queries (`auto_explain`, `slow_query_log`)
2. **Analyze** — `EXPLAIN (ANALYZE, BUFFERS, SETTINGS)` in PostgreSQL
3. **Identify** — Seq Scan on large table? Nested Loop with high row estimates?
4. **Fix** — index, rewrite, materialize, cache
5. **Verify** — same `EXPLAIN ANALYZE` after fix

### What to Look For in EXPLAIN
| Red Flag | Fix |
|----------|-----|
| `Seq Scan` on table > 10K rows | Add index |
| Row estimate off by 100x+ | `ANALYZE`, update stats |
| `Nested Loop` with many iterations | Consider `Hash Join` or `Merge Join` |
| `Sort` on large dataset | Index pre-sort |
| `Shared Hit Buffers` count high | Increase `shared_buffers` |
| `Temp File` appears | Increase `work_mem` |

### Query Rewriting Patterns
```sql
-- BAD: Correlated subquery (runs per row)
SELECT * FROM users WHERE id IN (
  SELECT user_id FROM orders WHERE amount > 100
);

-- GOOD: Rewrite as JOIN
SELECT DISTINCT u.* FROM users u
JOIN orders o ON o.user_id = u.id
WHERE o.amount > 100;

-- BAD: Function on indexed column
SELECT * FROM orders WHERE DATE(created_at) = '2024-01-01';

-- GOOD: Range scan with index
SELECT * FROM orders
WHERE created_at >= '2024-01-01' AND created_at < '2024-01-02';
```

### Pagination Anti-Pattern
```sql
-- BAD: `OFFSET` scans + discards rows
SELECT * FROM users ORDER BY id LIMIT 20 OFFSET 100000;

-- GOOD: Keyset (seek) pagination
SELECT * FROM users WHERE id > 100000 ORDER BY id LIMIT 20;
```

---

## 5. ORM Optimization

### N+1 Detection & Fix
- **Detect**: Enable query logging (`DEBUG=1`, `ORMDEBUG=1`) — watch for repeated identical queries
- **Fix**: Eager loading (`.include()`, `.prefetch_related()`, `JOIN FETCH`)

### ORM Pitfalls by Ecosystem

**Prisma / TypeORM / Sequelize (Node.js)**
- N+1 from lazy relations — use `include` / `relations` eagerly
- `findMany` in loop → batch with `findMany({ where: { id: { in: ids } } })`
- Avoid `findMany` where raw SQL would be simpler (aggregations, window functions)
- Use raw SQL for bulk operations

**ActiveRecord / Rails**
- `includes(:orders)` for eager loading vs `joins(:orders)`
- `pluck` vs `select` — `pluck` avoids object allocation
- `find_each` / `find_in_batches` for memory-safe iteration
- Counter caches for `size` calls on associations

**SQLAlchemy / Django ORM (Python)**
- `selectinload` vs `joinedload` — know the difference
- `only()` / `defer()` to select fewer columns
- `bulk_create` / `bulk_update` for batch operations
- Raw SQL via `text()` for complex queries

### General ORM Rules
- Eager load everything you'll touch, or use batch loading
- Avoid ORM for bulk operations — raw SQL is 10-100x faster
- Use read replicas by configuring separate read/write connections
- Set statement timeout at the connection level

---

## 6. Migration Engineering

### Zero-Downtime Migration Patterns

| Pattern | Strategy | Risk |
|---------|----------|------|
| Add column | `ADD COLUMN ... DEFAULT NULL` | Low — NULL fills instantly |
| Add column with default | Add as NULL → backfill → set NOT NULL | Medium — backfill locks |
| Rename column | Add new col → dual-write → backfill → drop old | High — application must write both |
| Change column type | Add new col with new type → dual-write → migrate → swap | High |
| Split table | Create new table → dual-write → backfill → switch | High |
| Add index | `CONCURRENTLY` (PG) or `ALGORITHM=INPLACE` (MySQL 8) | Low — no table lock |

### Migration Checklist
1. **Always have a rollback** — every `up` has a `down`
2. **Test on a copy of production** — same data volume
3. **Small batches** — 1000 rows or 10s timeout per statement
4. **Lock analysis** — `pg_locks` / `SHOW PROCESSLIST` during migration
5. **Monitor replication lag** if using replicas
6. **Deploy in off-peak** — schedule during low traffic

### Backfill Script Template
```python
# Batch backfill with cursor-based pagination
last_id = 0
batch_size = 1000
while True:
    rows = db.execute("""
        SELECT id FROM users
        WHERE id > %s AND new_column IS NULL
        ORDER BY id LIMIT %s
    """, (last_id, batch_size))
    if not rows:
        break
    db.execute("""
        UPDATE users SET new_column = ...
        WHERE id = ANY(%s)
    """, ([r.id for r in rows],))
    last_id = rows[-1].id
    sleep(0.1)  # throttle
```

---

## 7. Performance Tuning

### Configuration Tuning (PostgreSQL)
| Parameter | Conservative | Aggressive | Notes |
|-----------|-------------|------------|-------|
| `shared_buffers` | 25% RAM | 40% RAM | OS cache also matters |
| `effective_cache_size` | 50% RAM | 75% RAM | Helps query planner |
| `work_mem` | 4MB | 32-64MB | Per sort/hash op |
| `maintenance_work_mem` | 64MB | 1GB | VACUUM, CREATE INDEX |
| `random_page_cost` | 4 | 1.1 (SSD) / 1.5 (NVMe) | Guide planner away from seq scans |
| `max_connections` | 100 | 20-50 (with pgbouncer) | Each connection = RAM |
| `wal_buffers` | 16MB | 64MB | Write-ahead log |

### Connection Pooling
- Use **PgBouncer** (transaction mode) or **RDS Proxy**
- Pool size = `(2 × core_count) + effective_spindle_count`
- Monitor `idle_in_transaction` — application bug if high

### Caching Layers
```
┌──────────┐
│ Browser  │ ← Cache-Control, ETag
├──────────┤
│ CDN      │ ← CloudFront, Cloudflare
├──────────┤
│ App      │ ← In-memory cache (local)
├──────────┤
│ Redis    │ ← Shared cache (cache-aside / write-through)
├──────────┤
│ Database │ ← Buffer pool, WAL
└──────────┘
```

### Common Performance Anti-Patterns
- SELECT \* (especially with JOINs) — fetch only needed columns
- No LIMIT on queries returning many rows
- Long-running transactions holding locks
- Missing `NOT NULL` constraints (planner can optimize with them)
- Implicit type conversion preventing index usage

---

## 8. Security Hardening

### Must-Have
1. **Connection encryption** — TLS for all client-database connections
2. **Least privilege** — separate read/write users, no `superuser` in apps
3. **Row-Level Security** — PostgreSQL RLS for multi-tenant data isolation
4. **Encryption at rest** — disk encryption + column-level with `pgcrypto`
5. **Audit logging** — `pgaudit` extension or query logging
6. **SQL injection prevention** — parameterized queries, never string interpolation
7. **Network isolation** — database in private subnet, no public endpoint

### SQL Injection Prevention
```python
# BAD — string interpolation
cursor.execute(f"SELECT * FROM users WHERE email = '{email}'")

# GOOD — parameterized
cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
```

### Secret Management
- Never hardcode credentials
- Use environment variables or secret vault
- Rotate passwords every 90 days
- PostgreSQL: `pg_stat_activity` to audit active connections

---

## 9. Architecture Patterns

### Read Replicas
```
App ──→ Writer (primary)
         ├──→ Read Replica 1 (SELECT)
         ├──→ Read Replica 2 (SELECT, reporting)
         └──→ Read Replica 3 (analytics, backup)
```
- Route reads based on staleness tolerance
- Monitor replica lag with `pg_stat_replication`
- Use `pg_hint_plan` to force primary for critical reads

### Sharding Strategies
- **Hash-based** — even distribution, but resharding is painful
- **Range-based** — natural boundaries (by date, region), but hotspots
- **Directory-based** — lookup table maps key → shard (flexible, extra hop)
- Use Vitess, Citus, or application-level sharding

### CQRS (Command Query Responsibility Segregation)
- Commands → normalized OLTP store
- Queries → denormalized read model (materialized views, Elasticsearch)
- Eventually consistent between write and read sides

### Multi-Tenant Patterns
| Pattern | Isolation | Cost | Complexity |
|---------|-----------|------|------------|
| Shared table + tenant_id col | Lowest | Lowest | Medium (RLS) |
| Schema per tenant | Medium | Medium | Low |
| Database per tenant | Highest | Highest | Low |
| Hybrid (tiered) | Configurable | Configurable | High |

---

## 10. Observability & Monitoring

### Metrics to Track
| Metric | What It Tells You | Alert Threshold |
|--------|-------------------|-----------------|
| Query latency (p50/p95/p99) | User-facing performance | p99 > 500ms |
| Connections count | Pool pressure | > 80% pool max |
| Cache hit ratio | Buffer pool effectiveness | < 95% |
| Replication lag | Replica freshness | > 10s |
| Dead tuples | Vacuum health | > 20% of live |
| Lock wait duration | Contention | > 1s |
| Disk IOPS / throughput | Hardware bottleneck | > 80% max IOPS |

### Diagnostic Queries
```sql
-- Slow queries (PostgreSQL)
SELECT query, calls, total_exec_time / calls AS avg_ms, rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC LIMIT 20;

-- Unused indexes
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan < 100 AND indexrelid NOT IN (
  SELECT indexrelid FROM pg_constraint WHERE conindid = indexrelid
);

-- Current locks
SELECT pid, locktype, mode, granted, now() - query_start AS duration
FROM pg_locks l JOIN pg_stat_activity a ON a.pid = l.pid
WHERE NOT granted;
```

---

## 11. Ecosystem-Specific Deep Dives

### PostgreSQL
- **Extensions**: `pgvector`, `postgis`, `timescaledb`, `pg_cron`, `pgaudit`
- **Replication**: `pgoutput` plugin → Kafka / Debezium for CDC
- **Full-text search**: `tsvector` / `tsquery` with GIN index
- **Partitioning**: declarative partitioning by range or list (PG 12+)

### MySQL 8+
- **Storage engine**: InnoDB only (transactional), avoid MyISAM
- **Buffer pool**: `innodb_buffer_pool_size` = 70-80% RAM
- **DDL**: `ALGORITHM=INPLACE, LOCK=NONE` for online DDL
- **Replication**: Group Replication or async with GTID

### MongoDB
- **Schema design**: embed or reference based on access patterns
- **Indexes**: compound indexes, TTL indexes, text indexes
- **Aggregation pipeline**: match early, project small
- **Sharding**: choose shard key carefully (monotonic = bad, hashed = better)

### Redis
- **Data structures**: strings, hashes, lists, sets, sorted sets, streams
- **Persistence**: RDB (snapshot) + AOF (append-only log)
- **Eviction**: `allkeys-lru` for cache, `noeviction` for persistent
- **Cluster**: hash slots, no cross-slot operations

### SQLite
- **WAL mode**: `PRAGMA journal_mode=WAL` for concurrent reads
- **Write optimization**: batch transactions, avoid autocommit
- **Full-text search**: FTS5 extension
- **Limitations**: no ALTER COLUMN, no concurrent writes

### ClickHouse
- **Column-oriented** — ideal for OLAP / analytics on large datasets
- **MergeTree engine** — default; partition by date, order by primary key
- **Materialized views** — push-down aggregations during INSERT, not on SELECT
- **JOIN behavior** — right table must fit in memory or use `join_algorithm='parallel_hash'`
- **Limitations**: no point-updates, no transactions, high CPU on joins

### DuckDB
- **In-process OLAP** — like SQLite for analytical queries
- **Columnar engine** — runs queries on Pandas/Parquet directly
- **Best for**: Data science, ad-hoc analytics, ETL pipelines
- **Zero-config** — no server, no config files
- **Limitations**: not designed for concurrent access, no network protocol

### CockroachDB
- **PostgreSQL-wire compatible** — most PG drivers work
- **Auto-sharding** — range-based with automatic rebalancing
- **Survivability** — survives entire AZ failure with `--locality` settings
- **Consistency** — SERIALIZABLE isolation by default (strong)
- **Limitations**: higher latency than single-node PG (distributed overhead), limited extensions

### DynamoDB (NoSQL)
- **Single-digit millisecond** at any scale (if modeled right)
- **Access patterns first** — design tables around query patterns, not normalization
- **Primary key**: partition key (hash) + optional sort key (range)
- **GSI / LSI** — global/local secondary indexes (eventually consistent)
- **Limitations**: no joins, no transactions across partitions, 1 MB query limit
- **Hot keys**: uneven access patterns cause throttling — use write sharding

---

## 12. Backup & Disaster Recovery

### Backup Strategy
```
Full backup (daily) ──→ WAL archive (continuous) ──→ Point-in-time recovery
```
- **PostgreSQL**: `pg_basebackup` + WAL archiving (`wal-g`, `barman`)
- **MySQL**: `mysqldump` for small, `XtraBackup` for large
- **MongoDB**: `mongodump` or file-system snapshot
- **Test restores** — backup is only as good as your last successful restore

### RPO / RTO Planning
| Tier | RPO | RTO | Strategy |
|------|-----|-----|----------|
| Gold | 0-5 min | < 30 min | Synchronous replicas + WAL archive |
| Silver | 15 min | < 4 hr | Async replica + daily backup |
| Bronze | 24 hr | < 24 hr | Daily backup only |

---

## 13. Transaction Isolation & MVCC

### Isolation Levels
| Level | Dirty Read | Non-Repeatable Read | Phantom Read | Snapshot | Use Case |
|-------|-----------|---------------------|--------------|----------|----------|
| `READ UNCOMMITTED` | Possible | Possible | Possible | No | Approx counters, no real use |
| `READ COMMITTED` | Safe | Possible | Possible | Per-statement | Default in PG/MySQL — safe enough |
| `REPEATABLE READ` | Safe | Safe | Possible (PG: safe) | Per-transaction | Reporting, financial audits |
| `SERIALIZABLE` | Safe | Safe | Safe | — | Banking, critical transactions |

### MVCC Internals
- **PostgreSQL**: Each row has `xmin` (creating transaction) / `xmax` (deleting/updating transaction). Old versions live in the same table until `VACUUM` reclaims them. `SELECT` sees only rows visible at the transaction's snapshot.
- **MySQL (InnoDB)**: Undo log stores old versions in the rollback segment. The `read view` determines visibility at transaction start.
- **Snapshot too old**: Long-running queries on busy tables hit "snapshot too old" (ORA-01555 in Oracle, error in PG with `old_snapshot_threshold`). Mitigate with `hot_standby_feedback` on replicas.

### Common MVCC Pitfalls
- **Bloating** — long transactions prevent `VACUUM` from reclaiming dead tuples
- **IDLE in transaction** — holds snapshot, blocks cleanup
- **DDL + MVCC** — `ALTER TABLE` needs `ACCESS EXCLUSIVE` lock, waits for all active snapshots

### When to Lower Isolation
```
Default: READ COMMITTED → good for 95% of workloads
SERIALIZABLE → only when you can't use
  SELECT ... FOR UPDATE
  or application-level optimistic locking
```

---

## 14. Database Testing Strategy

### Unit Tests (no database)
- Test query construction logic, not the actual execution
- Mock the database connection / ORM session
- Use in-memory databases (SQLite :memory:) for quick feedback

### Integration Tests (real database)
```python
# Use Testcontainers for disposable DB instances
from testcontainers.postgres import PostgresContainer

with PostgresContainer("postgres:16") as pg:
    conn = psycopg2.connect(pg.get_connection_url())
    # Run migrations, seed data, test queries
```

### What to Test
| Layer | What | Tooling |
|-------|------|---------|
| Schema | Constraints, defaults, migration up/down | Flyway, Alembic, Prisma |
| Query | EXPLAIN plan, row count, correctness | pytest, pgTAP |
| Index | Whether the optimizer uses them | `EXPLAIN (ANALYZE)` in tests |
| Migration | Rollback, data preservation | Test in CI with fresh DB |
| Concurrency | Deadlocks, race conditions | Threaded test harness |
| Backup | Restore works | Restore to temp instance |

### CI Pipeline Pattern
```yaml
test-db:
  services:
    postgres:
      image: postgres:16
      env: POSTGRES_PASSWORD=test
  steps:
    - run: migrate up
    - run: seed test data
    - run: pytest tests/db/
    - run: migrate down  # verify rollback
```

### Performance Regression Tests
- Run every query against a fixed dataset
- Assert `EXPLAIN` shows no seq scans on large tables
- Measure p95 latency, fail if >2x baseline

---

## 15. Deadlock Detection & Prevention

### What Causes Deadlocks
```
Transaction A: UPDATE accounts SET balance = balance - 100 WHERE id = 1;
Transaction B: UPDATE accounts SET balance = balance - 100 WHERE id = 2;
Transaction A: UPDATE accounts SET balance = balance - 100 WHERE id = 2;  -- waits for B
Transaction B: UPDATE accounts SET balance = balance - 100 WHERE id = 1;  -- waits for A
→ DEADLOCK
```

### Prevention Patterns
1. **Lock ordering** — always access rows in the same order (by id, alphabetically)
2. **Short transactions** — minimize the window for deadlocks
3. **Index all FK columns** — row-level locks escalate without index
4. **`NOWAIT` / `SKIP LOCKED`** — bail out instead of waiting
5. **Retry logic** — deadlock victims should retry at the application layer

### Detection (PostgreSQL)
```sql
-- View blocked queries
SELECT blocked.pid AS blocked_pid,
       blocking.pid AS blocking_pid,
       blocked.query AS blocked_query,
       blocking.query AS blocking_query,
       now() - blocked.query_start AS blocked_duration
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking ON blocking.pid = ANY(
  pg_blocking_pids(blocked.pid)
);

-- Log deadlocks automatically
ALTER SYSTEM SET log_lock_waits = on;
ALTER SYSTEM SET deadlock_timeout = '1s';  -- log all deadlocks
```

### Retry Template
```python
import time
from psycopg2.errors import SerializationFailure

def execute_with_retry(cursor, sql, params, retries=3):
    for attempt in range(retries):
        try:
            cursor.execute(sql, params)
            return
        except SerializationFailure:
            if attempt == retries - 1:
                raise
            time.sleep(0.1 * (2 ** attempt))  # exponential backoff
```

---

## 16. Connection Strings & Driver Matrix

### By Language × Database

| Language | PostgreSQL | MySQL | MongoDB | Redis | SQLite |
|----------|-----------|-------|---------|-------|--------|
| **Node.js** | `pg` / `postgres.js` | `mysql2` | `mongoose` / `mongodb` | `ioredis` | `better-sqlite3` |
| **Python** | `psycopg2` / `asyncpg` | `pymysql` / `aiomysql` | `pymongo` / `motor` | `redis-py` / `aioredis` | `sqlite3` (stdlib) |
| **Go** | `pgx` / `lib/pq` | `go-sql-driver/mysql` | `mongo-go-driver` | `go-redis` | `modernc.org/sqlite` |
| **Rust** | `sqlx` / `tokio-postgres` | `sqlx` / `mysql_async` | `mongodb` | `redis-rs` | `rusqlite` |
| **Java** | `org.postgresql` | `com.mysql.cj` | `mongodb-driver-sync` | `jedis` / `lettuce` | `org.xerial:sqlite-jdbc` |

### Connection String Templates
```
PostgreSQL:  postgresql://user:password@host:5432/dbname?sslmode=require&pool_min=2&pool_max=10
MySQL:       mysql://user:password@host:3306/dbname?ssl-mode=REQUIRED&pool-max=10
MongoDB:     mongodb://user:password@host:27017/dbname?maxPoolSize=10&w=majority
Redis:       redis://:password@host:6379/0?pool_size=10
SQLite:      sqlite:///path/to/db.sqlite?mode=rwc&journal_mode=WAL
```

### Best Practices
1. **Never hardcode** — use environment variables or a vault
2. **Connection timeout** — set `connect_timeout=5` to fail fast
3. **Pool size** — align with DB `max_connections` ÷ number of app instances
4. **SSL** — always `sslmode=require` or `verify-full` in production
5. **Application name** — set `application_name=$APP` to identify in `pg_stat_activity`

---

## 17. Capacity Planning & Sizing

### Growth Estimation Formula
```
Storage per year = (row_size × row_count × growth_rate × replication_factor) + indexes
```

### Quick Sizing Rules
| Scale | Users | DB Size | Instance | Config |
|-------|-------|---------|----------|--------|
| Tiny | < 1K | < 1 GB | 1 vCPU, 1 GB RAM | SQLite / PG default |
| Small | 1K–10K | 1–50 GB | 2 vCPU, 4 GB RAM | Tune shared_buffers, work_mem |
| Medium | 10K–100K | 50–500 GB | 4 vCPU, 16 GB RAM | Read replica + PgBouncer |
| Large | 100K–1M | 500 GB–5 TB | 8 vCPU, 32 GB RAM | Connection pooling, caching |
| X-Large | 1M+ | 5 TB+ | 16+ vCPU, 64+ GB RAM | Sharding, CQRS, CDN |

### When to Scale
| Signal | Action |
|--------|--------|
| CPU > 80% sustained | Vertical scale (bigger instance) |
| Disk IOPS > 80% | Faster storage (NVMe) or horizontal scale |
| Connections > 80% of max | Add PgBouncer or increase `max_connections` |
| Replication lag > 30s | Upgrade replica instance or reduce load |
| Query p99 > 1s | Optimize queries, add caching, or scale |
| Index rebuild takes > 1hr | Use `CONCURRENTLY`, schedule maintenance |

---

## 18. Real-World Case Studies

### Case A: SaaS Platform Migration (MySQL → PostgreSQL)
**Problem**: 500 GB MySQL 5.7, nightly `REPLACE INTO` jobs causing 4h downtime
**Solution**: 
1. Set up logical replication via `pg_chameleon`
2. Dual-write for 1 week (both MySQL + PG)
3. Cutover: 15-min read-only window, verify row counts
4. Result: nightly jobs now take 20 min, no downtime
**Lesson**: Always test cutover under production load first

### Case B: E-Commerce Inventory Hotspot
**Problem**: Flash sales cause row lock contention on `inventory` table
**Symptoms**: `LOG: process 1234 still waiting for ShareLock` → dead timeouts
**Root Cause**: 10,000 concurrent updates on the same sku row
**Solutions Considered**:
- ❌ `SERIALIZABLE` — worse contention
- ✅ Redis cache + async decrement (eventual consistency, 1s delay)
- ✅ Shard sku by warehouse (+1 for the hot sku)
- ✅ `pg_advisory_xact_lock` with retry
**Result**: 95th percentile latency dropped from 12s to 40ms

### Case C: Time-Series Bloat
**Problem**: 2 TB table of IoT sensor readings, 90% is "dead tuples"
**Root Cause**: Frequent `UPDATE` on a `last_seen` timestamp + no autovacuum tuning
**Fix**:
1. Change `last_seen` to a separate table (1 row per device, not per reading)
2. Partition readings by month (`PARTITION BY RANGE (ts)`)
3. Tune autovacuum: `autovacuum_vacuum_scale_factor = 0.01`, `autovacuum_vacuum_cost_limit = 2000`
4. Set `fillfactor = 70` on the high-churn table
**Result**: Table size dropped to 200 GB, query time -80%

---

## 19. Schema Generation Protocol

When the user asks you to generate a database schema from requirements, follow this protocol:

### 19.1 Intake Phase

Ask these questions (or infer from context) before writing a single `CREATE TABLE`:

```
1. Domain: What kind of system? (e-commerce / SaaS / CMS / IoT / chat / analytics)
2. Scale: Current users? Expected growth in 12 months?
3. Access patterns: Read-heavy? Write-heavy? Equal?
4. Consistency needs: Strong (ACID) or eventual?
5. Entities: What are the core nouns? (users, products, orders, ...)
6. Relationships: One-to-many? Many-to-many? Polymorphic?
7. Soft delete needed? Audit trail? Multi-tenancy?
8. Deployment: Single region? Multi-region?
9. Existing system? Migration from?
```

### 19.2 Output Format

Every generated schema MUST include:

```sql
-- ============================================================
-- Schema: <project-name>
-- Domain: <domain>
-- Generated: <date>
-- ============================================================

-- 1. Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- 2. Enums (if needed)
CREATE TYPE order_status AS ENUM ('pending', 'paid', 'shipped', 'cancelled');

-- 3. Tables (with comments)
CREATE TABLE users (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email       TEXT NOT NULL,
    name        TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE users IS 'Platform users';

-- 4. Indexes (listed separately, not inline)
CREATE UNIQUE INDEX idx_users_email ON users (email);
CREATE INDEX idx_users_created ON users (created_at DESC);

-- 5. Foreign keys (listed separately for clarity)
ALTER TABLE orders ADD CONSTRAINT fk_orders_user
    FOREIGN KEY (user_id) REFERENCES users(id);

-- 6. Row-Level Security (if multi-tenant)
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY orders_tenant_isolation ON orders
    USING (tenant_id = current_setting('app.tenant_id')::BIGINT);
```

### 19.3 Accompanying Documents

Every schema generation must produce these three deliverables:

| Deliverable | Format | Content |
|-------------|--------|---------|
| **Schema SQL** | `.sql` | Full CREATE + INDEX + FK + RLS — production-ready |
| **Migration** | `.sql` | ALTER statements from "blank" to this schema — works on empty DB |
| **Data Dictionary** | markdown | Table descriptions, column meanings, example queries |

### 19.4 Quality Gates

Before declaring the schema "done":
- [ ] Every table has a PRIMARY KEY (BIGINT or UUID)
- [ ] Every FK column has an index
- [ ] TIMESTAMPTZ not TIMESTAMP
- [ ] NUMERIC for money, not FLOAT
- [ ] TEXT not VARCHAR(n) unless domain constraint exists
- [ ] NOT NULL on every column that should be required
- [ ] CHECK constraints for status-like columns
- [ ] RLS policy on every tenant-scoped table
- [ ] `created_at` / `updated_at` on every table
- [ ] No EAV, no polymorphic associations, no generic meta TEXT

---

## 20. Domain Schema Templates

Complete schema blueprints for common domains. Use these as starting points — customize for specific requirements.

### 20.1 Multi-Tenant SaaS
```sql
-- Tenants (top-level isolation boundary)
CREATE TABLE tenants (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slug        TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    plan        TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'pro', 'enterprise')),
    settings    JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Shared users (login across tenants or per-tenant)
CREATE TABLE users (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id    BIGINT NOT NULL REFERENCES tenants(id),
    email        TEXT NOT NULL,
    name         TEXT NOT NULL,
    role         TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member', 'viewer')),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(tenant_id, email)
);
CREATE INDEX idx_users_tenant ON users (tenant_id);
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY users_tenant_isolation ON users USING (tenant_id = current_setting('app.tenant_id')::BIGINT);

-- Feature flags per tenant
CREATE TABLE tenant_features (
    tenant_id   BIGINT NOT NULL REFERENCES tenants(id),
    feature     TEXT NOT NULL,
    enabled     BOOLEAN NOT NULL DEFAULT false,
    PRIMARY KEY (tenant_id, feature)
);
```

### 20.2 E-Commerce
```sql
CREATE TABLE products (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku         TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    description TEXT,
    price       NUMERIC(12,2) NOT NULL CHECK (price >= 0),
    cost        NUMERIC(12,2) CHECK (cost >= 0),
    stock       INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    status      TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'draft', 'archived')),
    category_id BIGINT REFERENCES categories(id),
    metadata    JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_products_status ON products (status) WHERE status = 'active';
CREATE INDEX idx_products_category ON products (category_id) WHERE category_id IS NOT NULL;
CREATE INDEX idx_products_sku ON products (sku);

CREATE TABLE orders (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id),
    status      TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'paid', 'shipped', 'delivered', 'cancelled')),
    total       NUMERIC(12,2) NOT NULL,
    discount    NUMERIC(12,2) DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_orders_user_status ON orders (user_id, status);

CREATE TABLE order_items (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id    BIGINT NOT NULL REFERENCES orders(id),
    product_id  BIGINT NOT NULL REFERENCES products(id),
    quantity    INTEGER NOT NULL CHECK (quantity > 0),
    unit_price  NUMERIC(12,2) NOT NULL,
    total       NUMERIC(12,2) NOT NULL
);
CREATE INDEX idx_order_items_order ON order_items (order_id);
```

### 20.3 Content / CMS
```sql
CREATE TABLE authors (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email       TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    bio         TEXT,
    avatar_url  TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE posts (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    author_id     BIGINT NOT NULL REFERENCES authors(id),
    slug          TEXT NOT NULL UNIQUE,
    title         TEXT NOT NULL,
    body          TEXT NOT NULL,
    excerpt       TEXT,
    status        TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'published', 'archived')),
    published_at  TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_posts_author ON posts (author_id);
CREATE INDEX idx_posts_status_published ON posts (status, published_at DESC)
    WHERE status = 'published';
CREATE INDEX idx_posts_search ON posts USING GIN (to_tsvector('english', title || ' ' || COALESCE(body, '')));

CREATE TABLE tags (
    id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slug  TEXT NOT NULL UNIQUE,
    name  TEXT NOT NULL
);

CREATE TABLE post_tags (
    post_id BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    tag_id  BIGINT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, tag_id)
);
```

### 20.4 IoT / Time-Series
```sql
CREATE TABLE devices (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        TEXT NOT NULL,
    device_type TEXT NOT NULL,
    location    JSONB,
    metadata    JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Partitioned readings table for time-series
CREATE TABLE readings (
    id          BIGINT GENERATED ALWAYS AS IDENTITY,
    device_id   BIGINT NOT NULL,
    ts          TIMESTAMPTZ NOT NULL,
    metric      TEXT NOT NULL,
    value       DOUBLE PRECISION NOT NULL,
    PRIMARY KEY (id, ts)  -- ts in PK required for partitioning
) PARTITION BY RANGE (ts);

-- Create monthly partitions
CREATE TABLE readings_2026_01 PARTITION OF readings
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE readings_2026_02 PARTITION OF readings
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

-- Index on each partition
CREATE INDEX idx_readings_device_ts ON readings (device_id, ts DESC);
```

---

## 21. Migration Generation Protocol

When given two schemas (before / after) or asked to make a schema change, generate the migration following this protocol.

### 21.1 Input Format

Accept schema changes as:
- Full `CREATE TABLE` statements (before / after)
- Description of desired change ("add a phone column to users")
- ALTER statements from another source

### 21.2 Migration Output

Every migration must include:

```sql
-- ============================================================
-- Migration: <description>
-- Author: database-architect
-- Date: <date>
-- ============================================================

-- UP: Apply the change
-- ============================================================
BEGIN;
    SET lock_timeout = '5s';

    -- Add nullable column first
    ALTER TABLE users ADD COLUMN phone TEXT;

    -- Backfill is handled separately (see scripts/backfill.py)
    -- ALTER TABLE users ALTER COLUMN phone SET NOT NULL;
COMMIT;

-- DOWN: Rollback
-- ============================================================
BEGIN;
    ALTER TABLE users DROP COLUMN phone;
COMMIT;
```

### 21.3 Migration Decision Matrix

| Change | Up Strategy | Down Strategy | Risk |
|--------|------------|---------------|------|
| Add column (nullable) | `ADD COLUMN` | `DROP COLUMN` | Low |
| Add column (NOT NULL) | Add NULL → backfill → `SET NOT NULL` | `DROP COLUMN` | Medium |
| Rename column | Add new → dual-write → backfill → drop old | Restore old | High |
| Change column type | Add new → dual-write → migrate → swap | Add old back | High |
| Add index | `CREATE INDEX CONCURRENTLY` | `DROP INDEX CONCURRENTLY` | Low |
| Drop index | `DROP INDEX CONCURRENTLY` | `CREATE INDEX` | Low |
| Add table | `CREATE TABLE` | `DROP TABLE` | Low |
| Drop table | Create backup → `DROP TABLE` | Restore from backup | High |
| Add FK | `ALTER TABLE ADD CONSTRAINT` | `DROP CONSTRAINT` | Medium (table lock) |
| Partition existing table | Create new partitioned → insert → rename | Reverse rename | Very high |

### 21.4 Zero-Downtime Rules

1. **Never** `ALTER TABLE ... SET NOT NULL` without backfill first
2. **Never** drop a column on day 1 — mark as deprecated, drop N days later
3. **Always** set `lock_timeout = '5s'` before DDL on production
4. **Always** provide a DOWN script
5. For large tables, use `pt-online-schema-change` (Percona) or `pgroll` (PostgreSQL)
6. Test on a production-sized copy first

### 21.5 Accompanying Scripts

Reference these scripts (in `scripts/`) in generated migration output:
- `scripts/backfill.py` for NOT NULL column backfill
- `scripts/migration-check.sql` to run before applying
- `scripts/diagnostics.sql` to verify after

---

## 22. Schema Audit Protocol

When the user gives you an existing schema, automatically run this audit.

### 22.1 Audit Checklist

Run through every table and flag violations:

```
Table: users
────────────────────────────────────
□ PRIMARY KEY exists?             — ✅ id BIGINT
□ TIMESTAMPTZ?                    — ❌ created_at TIMESTAMP → TIMESTAMPTZ
□ Missing indexes?                — ❌ no index on email
□ Missing NOT NULL?               — ❌ name is TEXT (nullable)
□ Missing updated_at?             — ❌ no updated_at column
□ FLOAT for money?                — ✅ not applicable
□ Missing CHECK constraints?      — ❌ role TEXT with no CHECK
□ Missing RLS?                    — ✅ RLS enabled
□ Missing FK indexes?             — ✅ tenant_id indexed
```

### 22.2 Scoring

| Score | Rating | Meaning |
|-------|--------|---------|
| 90-100% | 🟢 Production-ready | Minor tuning suggestions |
| 70-89% | 🟡 Needs work | Address flagged items before production |
| 50-69% | 🟠 Risky | Significant refactoring recommended |
| <50% | 🔴 Redesign | Schema has fundamental issues |

### 22.3 Audit Output Format

```markdown
## Schema Audit: users

**Score: 72/100** 🟡 Needs work

### Critical (Fix before production)
- [ ] `created_at` uses `TIMESTAMP` — change to `TIMESTAMPTZ`
- [ ] `email` has no unique index — login queries will degrade

### Recommended
- [ ] Add `updated_at` with `ON UPDATE` trigger
- [ ] Add `CHECK (role IN ('admin', 'user'))` on role column
- [ ] Add `created_at` index for time-range queries

### Best Practice
- [ ] Consider soft-delete column `deleted_at TIMESTAMPTZ`
- [ ] Consider `EXCLUDE USING` for overlapping date ranges

### Summary
Table is functional but has 2 critical issues that will cause problems at scale.
Estimated fix time: 30 minutes.
```

### 22.4 Automatic Actions

When the user says "帮我看看这个 schema" (review my schema), the skill MUST:
1. Run the audit checklist
2. Generate the score
3. Produce the audit report
4. Offer to generate the migration that fixes all flagged issues

---

## Meta-Layer Invocation Examples

When the user says | The skill should
-------------------|-----------------
"帮我设计一个电商数据库" | Run Schema Generation Protocol (§19), output SaaS schema template → customize → generate migration
"这是我的 schema，帮我看看" | Run Schema Audit Protocol (§22), score it, produce report, offer migrations
"给 users 表加一个 phone 字段" | Generate migration (§21) with UP + DOWN, reference backfill.py
"把一个 5 亿行的表转成分区表" | Generate migration plan with risk assessment, reference partitioning patterns
"从 MySQL 迁到 PostgreSQL" | Generate conversion plan with data type mapping + zero-downtime strategy

## Skill Invocation Triggers

This skill activates automatically when the user mentions any of:
- Database design, schema, data modeling, ERD
- SQL optimization, slow query, EXPLAIN, query tuning
- Indexing, index strategy, covering index
- ORM, N+1, lazy loading, eager loading
- Migration, zero-downtime, schema change, backfill
- Database choice, "which database", SQL vs NoSQL
- Performance, connection pooling, caching, sharding
- Database security, SQL injection, encryption
- Replication, read replica, high availability, failover
- Backup, recovery, RPO, RTO, disaster recovery
- Specific databases: PostgreSQL, MySQL, MongoDB, Redis, SQLite, etc.
- **"帮我设计" / "帮我生成" / "生成 schema" / "生成数据库"** — triggers Schema Generation (§19)
- **"帮我看看" / "审计" / "review" / "检查"** — triggers Schema Audit (§22)
- **"加字段" / "改表" / "迁移" / "alter"** — triggers Migration Generation (§21)
