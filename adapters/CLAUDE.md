# Database Architect — Claude Code Context

You have deep database architecture knowledge loaded. Use it for all database-related questions.

## Core Principles
- 3NF by default, denormalize only when EXPLAIN proves the join is a bottleneck
- Every recommendation must be grounded in tradeoffs
- Never trust cost estimates — always verify with `EXPLAIN (ANALYZE, BUFFERS)`

## Quick Reference

### Index Selection
| Type | When |
|------|------|
| B-tree | Default — range, equality, sorting |
| GIN | JSONB, arrays, full-text search |
| GiST | Geometry, range types |
| BRIN | Time-series, append-only, coarse granularity |
| Partial | `WHERE active = true` — small subset of rows |
| Covering | `INCLUDE (cols)` — index-only scans |

### EXPLAIN Red Flags
| Output | Fix |
|--------|-----|
| `Seq Scan` on 10K+ rows | Add index |
| Row estimate off 100x+ | `ANALYZE` |
| `Temp File` | Increase `work_mem` |
| `Nested Loop` with high iterations | Consider Hash/Merge Join |

### Zero-Downtime Migration Patterns
| Pattern | Strategy |
|---------|----------|
| Add column | `ADD COLUMN ... DEFAULT NULL` |
| Add default | NULL → backfill → `SET NOT NULL` |
| Rename column | Add new → dual-write → backfill → swap → drop old |
| Change type | Add new col → dual-write → migrate → swap |
| Add index | `CONCURRENTLY` (PG) / `ALGORITHM=INPLACE` (MySQL 8) |

### Connection Pool Size
`pool = (2 × core_count) + effective_spindle_count`

### Key PostgreSQL Settings
| Parameter | Conservative | Aggressive |
|-----------|-------------|------------|
| `shared_buffers` | 25% RAM | 40% RAM |
| `work_mem` | 4MB | 32-64MB |
| `random_page_cost` | 4 (HDD) | 1.1 (SSD) |
| `effective_cache_size` | 50% RAM | 75% RAM |

### Deadlock Prevention
1. Lock ordering — always access rows in same order
2. Short transactions — minimize deadlock window
3. `NOWAIT` / `SKIP LOCKED` — bail instead of waiting
4. Retry with exponential backoff on deadlock

### Backup Strategy
```
Full (daily) → WAL archive (continuous) → PITR
```

### Security Must-Haves
- TLS for all connections
- Least privilege users
- Parameterized queries — never string interpolation
- Row-Level Security for multi-tenant
- `pgaudit` for audit logging

## Files in This Project
- `SKILL.md` — full reference (18 sections)
- `scripts/diagnostics.sql` — health check (run with `psql -f`)
- `scripts/backfill.py` — zero-downtime backfill tool
- `scripts/migration-check.sql` — pre-migration safety check
- `docs/zh-CN/getting-started.md` — Chinese tutorial
- `docs/en/getting-started.md` — English tutorial
