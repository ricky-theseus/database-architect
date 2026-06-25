# Database Architect — Test Cases

## TC1: Database Selection
**Input**: "我们需要做一个实时协作的文档编辑系统，支持多人同时编辑，需要存储文档内容、版本历史、用户权限。预计用户量 100 万。"
**Expected**: Should recommend PostgreSQL (for relational data + JSONB for flexible doc storage), Redis (for WebSocket state + locking), and mention read replicas + connection pooling for scale. Should NOT blindly recommend MongoDB.

## TC2: N+1 Query Detection
**Input**: "为什么我的 API 返回文章列表时特别慢？我的代码是 Article.find(:all).each { |a| a.comments.count }"
**Expected**: Identify the N+1 problem. Recommend `includes(:comments)` or counter cache. Show before/after SQL.

## TC3: Index Design
**Input**: "这个查询很慢：SELECT * FROM orders WHERE status = 'pending' AND created_at > '2024-01-01' ORDER BY created_at DESC"
**Expected**: Recommend composite index `(status, created_at DESC)`. Explain leftmost prefix rule. Show EXPLAIN before/after.

## TC4: Migration Strategy
**Input**: "生产环境有个 users 表，需要把 email 列改名为 contact_email，要求零宕机"
**Expected**: Zero-downtime strategy — add new col → dual-write → backfill → gradual switch → drop old. Warn about application code changes needed.

## TC5: SQL Injection
**Input**: `User.find_by_sql("SELECT * FROM users WHERE email = '#{params[:email]}'")`
**Expected**: Flag as critical vulnerability. Show parameterized version. Explain prepared statement benefits.

## TC6: Pagination
**Input**: "SELECT * FROM products ORDER BY id LIMIT 20 OFFSET 100000 为什么越来越慢？"
**Expected**: Explain OFFSET scanning discarded rows. Recommend keyset/seek pagination. Show the fix.

## TC7: Connection Pooling
**Input**: "数据库经常报 'too many connections'，怎么解决？"
**Expected**: Recommend connection pooling (PgBouncer), calculate pool size formula, identify leak sources (idle-in-transaction).

## TC8: Data Type Choice
**Input**: "用 FLOAT 存金额有什么问题吗？"
**Expected**: Explain floating-point precision loss. Recommend `numeric(12,2)` or `DECIMAL`. Show rounding error example.

## TC9: EXPLAIN Analysis
**Input**: "这个查询走的是 Seq Scan，怎么让它走索引？EXPLAIN 显示 rows=1000000"
**Expected**: Guide through adding appropriate index. Mention random_page_cost for SSD tuning. Show expected improvements.

## TC10: Sharding Strategy
**Input**: "用户表已经 5 亿行了，单库扛不住，怎么拆分？"
**Expected**: Discuss hash-based vs range-based sharding. Mention Vitess/Citus. Cover resharding complexity and query routing.

## TC11: Transaction Isolation
**Input**: "两个事务同时扣库存，结果多扣了，怎么解决？"
**Expected**: Explain lost update problem. Show `SELECT ... FOR UPDATE` (pessimistic) and version column (optimistic) solutions. Mention REPEATABLE READ vs SERIALIZABLE tradeoffs.

## TC12: Deadlock Debugging
**Input**: "PostgreSQL 日志一直报 deadlock detected，怎么查怎么修？"
**Expected**: Show deadlock detection queries (`pg_blocking_pids`). Explain lock ordering. Provide retry template with exponential backoff.

## TC13: MVCC Bloat
**Input**: "我的表占 100 GB，数据只有 10 GB，剩下的哪去了？"
**Expected**: Identify MVCC bloat from long transactions / frequent updates. Recommend tuning autovacuum (`scale_factor`, `cost_limit`). Show bloat detection query and `pgstattuple`.

## TC14: Database Testing
**Input**: "怎么自动化测试数据库迁移和查询性能？"
**Expected**: Recommend Testcontainers for disposable DB. Show CI pipeline with migration test + EXPLAIN assertion. Mention pgTAP and pytest patterns.

## TC15: ClickHouse vs PostgreSQL for Analytics
**Input**: "我要做一个实时报表系统，查过去一年几亿行数据，用 PG 还是 ClickHouse？"
**Expected**: Compare column-oriented vs row-oriented. Discuss ClickHouse MergeTree + materialized views vs PostgreSQL partitioning + BRIN. Recommend ClickHouse for analytics, PG for transactional. Cover the hybrid approach (PG for writes, CH for reads via CDC).

## Evaluation Criteria
| Criteria | Weight | Pass |
|----------|--------|------|
| Identifies the real problem | 30% | |
| Gives tradeoff-aware advice | 25% | |
| Shows concrete code/SQL | 25% | |
| Considers scale + edge cases | 20% | |
