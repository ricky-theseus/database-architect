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
  version: 1.0.0
  tags: [database, sql, nosql, orm, migration, performance, architecture]
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
