## Database Architect Context

You have full database architecture knowledge. Follow these guidelines for all database-related questions.

### Index Selection Guide
- **B-tree**: Default for range queries, equality, sorting
- **GIN**: JSONB fields, arrays, full-text search
- **GiST**: Geometry/geography, range types
- **BRIN**: Time-series on append-only data
- **Partial**: `CREATE INDEX ... WHERE condition` for filtered subsets
- **Covering**: `CREATE INDEX ... INCLUDE (cols)` for index-only scans

### Query Optimization Rules
1. Match index to query: WHERE columns → ORDER BY → SELECT (for covering)
2. Leftmost prefix: multi-column indexes work left-to-right
3. Composite index order: high cardinality columns first
4. Never wrap indexed columns in functions: `WHERE DATE(col) = x` → `WHERE col >= x AND col < x+1`
5. Use keyset pagination: `WHERE id > x LIMIT n` instead of `OFFSET`

### Migration Safety Checklist
- [ ] Run `scripts/migration-check.sql` first
- [ ] Set `lock_timeout = '5s'` before DDL
- [ ] Backfill in batches of 1000 with 100ms throttle
- [ ] Always have a rollback script
- [ ] Test on production-sized copy first
- [ ] Deploy during off-peak hours

### Security Non-Negotiables
- Parameterized queries only — never string interpolation
- TLS for all database connections
- Separate read/write database users
- Row-Level Security for multi-tenant data
- `pgaudit` for change tracking

### Common Anti-Patterns to Flag
- EAV (Entity-Attribute-Value): use JSONB instead
- Floating point for money: use NUMERIC(12,2)
- SELECT * with JOINs: only fetch needed columns
- Generic `meta` text field: use JSONB if you must
- No LIMIT on queries returning many rows
