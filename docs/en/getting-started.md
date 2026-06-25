# Database Architecture: Getting Started

> A hands-on tutorial for developers. From your first `CREATE TABLE` to millions of concurrent users.

---

## Chapter 1: Your First Tables

### 1.1 The Users Table

```sql
CREATE TABLE users (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email       TEXT NOT NULL,
    name        TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_users_email ON users (email);
```

**Why this design?**
- `BIGINT` over `SERIAL`: SERIAL overflows at 2.1B, BIGINT won't overflow in your lifetime
- `TEXT` over `VARCHAR(255)`: Same performance in PostgreSQL, no arbitrary limits
- `TIMESTAMPTZ` over `TIMESTAMP`: Timezone-aware, prevents DST bugs
- Unique index on email: Enforces uniqueness + speeds up login queries

### 1.2 The Orders Table

```sql
CREATE TABLE orders (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id),
    total       NUMERIC(12,2) NOT NULL,
    status      TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'paid', 'shipped', 'cancelled')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_orders_user_id ON orders (user_id);
CREATE INDEX idx_orders_status_created ON orders (status, created_at DESC);
```

**Key decisions:**
- Foreign key on `user_id` — referential integrity at the DB level
- `NUMERIC(12,2)` for money — protects against float rounding errors
- `CHECK` constraint instead of ENUM — easier to alter later
- Two indexes: one for user lookups, one for status + time sorting

---

## Chapter 2: Understanding Query Performance

### 2.1 Reading EXPLAIN Output

```sql
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT * FROM orders WHERE status = 'pending' ORDER BY created_at DESC LIMIT 20;
```

```
Limit  (cost=0.42..153.24 rows=20 width=72)
  ->  Index Scan Backward using idx_orders_status_created on orders
        (cost=0.42..7652.82 rows=1001 width=72)
        Index Cond: (status = 'pending'::text)
        Buffers: shared hit=42
```

**Red flags reference:**

| EXPLAIN Output | Problem | Fix |
|----------------|---------|-----|
| `Seq Scan` on 100K+ rows | Full table scan | Add index |
| Row estimate off by 100x+ | Stale statistics | `ANALYZE` |
| `Temp File` appears | Sort spills to disk | Increase `work_mem` |
| Low `Shared Hit` count | Poor cache hit ratio | Increase `shared_buffers` |

### 2.2 Common Slow Query Patterns

```sql
-- SLOW: Function wraps indexed column
SELECT * FROM orders WHERE DATE(created_at) = '2024-06-01';
-- FAST: Range scan uses index
SELECT * FROM orders WHERE created_at >= '2024-06-01' AND created_at < '2024-06-02';

-- SLOW: Correlated subquery (runs once per row)
SELECT * FROM users WHERE id IN (SELECT user_id FROM orders WHERE amount > 100);
-- FAST: JOIN lets optimizer choose the plan
SELECT DISTINCT u.* FROM users u JOIN orders o ON o.user_id = u.id WHERE o.amount > 100;

-- SLOW: OFFSET pagination (gets slower with each page)
SELECT * FROM users ORDER BY id LIMIT 20 OFFSET 100000;
-- FAST: Keyset pagination (always fast)
SELECT * FROM users WHERE id > 100000 ORDER BY id LIMIT 20;
```

---

## Chapter 3: Index Design in Practice

### 3.1 Choosing Index Types

| Scenario | Index Type | Example |
|----------|-----------|---------|
| Equality + range | B-tree (default) | `WHERE status = 'active' AND created_at > '2024-01-01'` |
| JSON field query | GIN | `WHERE metadata @> '{"key": "value"}'` |
| Full-text search | GIN (tsvector) | `WHERE to_tsvector('english', body) @@ to_tsquery('database')` |
| Geospatial | GiST | `WHERE ST_DWithin(location, ST_MakePoint(116.4, 39.9), 1000)` |
| Time-series (append-only) | BRIN | `WHERE ts BETWEEN '2024-01-01' AND '2024-01-02'` |

### 3.2 Composite Index Rules

```sql
-- Query: WHERE status = 'pending' ORDER BY created_at DESC
-- Index should match the query pattern:
CREATE INDEX idx_orders_status_created ON orders (status, created_at DESC);
--          ↑ equality first            ↑ sort matches ORDER BY

-- Covering index: avoid heap lookups
CREATE INDEX idx_users_email ON users (email) INCLUDE (name);
--                            ↑ WHERE/JOIN column  ↑ stored in index, no table access
```

**Leftmost prefix rule:**
Index `(a, b, c)` can serve:
- ✅ `WHERE a = 1`
- ✅ `WHERE a = 1 AND b = 2`
- ✅ `WHERE a = 1 AND b = 2 AND c = 3`
- ❌ `WHERE b = 2` (skips a)
- ❌ `WHERE c = 3` (skips a and b)

---

## Chapter 4: Transactions & Concurrency

### 4.1 Isolation Levels

```sql
-- Check current level
SHOW transaction_isolation;

-- Set for session
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
```

| Level | Dirty Read | Non-Repeatable Read | Phantom Read | When to Use |
|-------|-----------|---------------------|--------------|-------------|
| READ COMMITTED (default) | Safe | Possible | Possible | 95% of workloads |
| REPEATABLE READ | Safe | Safe | Safe in PG | Financial reporting |
| SERIALIZABLE | Safe | Safe | Safe | Critical transactions |

### 4.2 Lost Update Problem

```sql
-- Transaction A              Transaction B
BEGIN;                         BEGIN;
SELECT stock FROM products     SELECT stock FROM products
  WHERE id = 1;  -- 10           WHERE id = 1;  -- 10
UPDATE products SET stock      UPDATE products SET stock
  = 10 - 1 WHERE id = 1;        = 10 - 1 WHERE id = 1;
COMMIT;                        COMMIT;
-- Result: stock = 9 (should be 8 — one sale was lost!)
```

**Solutions:**
```sql
-- Option 1: Row lock (pessimistic)
BEGIN;
SELECT stock FROM products WHERE id = 1 FOR UPDATE;
UPDATE products SET stock = stock - 1 WHERE id = 1;
COMMIT;

-- Option 2: Optimistic locking with version
UPDATE products SET stock = stock - 1, version = version + 1
WHERE id = 1 AND version = 5;
-- Retry if 0 rows affected
```

---

## Chapter 5: Safe Migrations

### 5.1 Adding a Column

```sql
-- Step 1: Add column (NULL allowed, instant)
ALTER TABLE users ADD COLUMN phone TEXT;

-- Step 2: Backfill in batches
UPDATE users SET phone = '' WHERE phone IS NULL AND id BETWEEN 0 AND 1000;
-- ... wait 100ms ...
UPDATE users SET phone = '' WHERE phone IS NULL AND id BETWEEN 1001 AND 2000;

-- Step 3: Add NOT NULL (requires brief lock)
ALTER TABLE users ALTER COLUMN phone SET NOT NULL;
```

### 5.2 Zero-Downtime Column Rename

```
Old column: email → New column: contact_email

1. Add contact_email column (nullable)
2. Dual-write: write to both email AND contact_email
3. Backfill historical data (batches)
4. Read from contact_email only
5. Drop email column (deferred, low priority)
```

> ⚠️ Never run DDL during peak hours. Set `lock_timeout = '5s'` first.

---

## Next Steps

- [SQL Optimization Deep Dive](./sql-optimization.md) — EXPLAIN mastery
- [Index Design Guide](./index-design.md) — From single to covering indexes
- [Migration Handbook](./migration-handbook.md) — Zero-downtime complete guide
- [Database Selection Guide](./database-selection.md) — 20+ scenarios analyzed
