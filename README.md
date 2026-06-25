<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://img.shields.io/badge/Database%20Architect-%234A90E2?style=for-the-badge&labelColor=1a1a1a&logo=postgresql">
  <img alt="Database Architect" src="https://img.shields.io/badge/Database%20Architect-%234A90E2?style=for-the-badge&labelColor=ffffff&logo=postgresql">
</picture>

# Database Architect — OpenCode Skill

> Full-stack database architecture expertise for OpenCode AI. Schema design, query optimization, indexing strategy, ORM tuning, migration engineering, performance profiling, security hardening, capacity planning, and disaster recovery.

**English** | [中文](./README.zh-CN.md)

---

## Coverage

| Area | Details |
|------|---------|
| **Database Selection** | Decision tree for 20+ databases: PostgreSQL, MySQL, MongoDB, Redis, SQLite, ClickHouse, DuckDB, CockroachDB, DynamoDB |
| **Schema Design** | Normalization vs denormalization, naming conventions, data type best practices, anti-pattern catalog |
| **Indexing Strategy** | B-tree / GIN / GiST / BRIN / Partial / Covering indexes, composite index column order |
| **Query Optimization** | EXPLAIN analysis, query rewriting, keyset pagination, subquery transformation |
| **Transaction & MVCC** | Isolation levels deep-dive, MVCC internals, snapshot management, common pitfalls |
| **ORM Optimization** | N+1 detection & fix, batch operations, raw SQL fallback (Prisma / ActiveRecord / SQLAlchemy) |
| **Deadlock Handling** | Root causes, prevention patterns, detection SQL, retry template |
| **Migration Engineering** | 5 zero-downtime patterns, rollback strategies, backfill script, lock analysis |
| **Performance Tuning** | PostgreSQL 16+ config parameters, connection pooling (PgBouncer), multi-level caching |
| **Security Hardening** | TLS / RLS / encryption at rest / audit logging / SQL injection prevention / secrets management |
| **Architecture Patterns** | Read replicas / sharding (hash/range/directory) / CQRS / multi-tenant (4 strategies) |
| **Database Testing** | Unit vs integration tests, Testcontainers, CI pipeline patterns, performance regression tests |
| **Connection Management** | 5 languages × 5 databases connection string templates, driver recommendations, pooling |
| **Capacity Planning** | Growth estimation formulas, sizing tiers (Tiny to X-Large), scaling signals |
| **Observability** | 8 key metrics, alert thresholds, diagnostic queries |
| **Backup & DR** | Full + WAL archive, RPO/RTO planning (3 tiers) |

---

## Quick Start

```bash
# Clone to your OpenCode skills directory
git clone https://github.com/ricky-theseus/database-architect.git

# Or copy directly
cp -r database-architect ~/.config/opencode/skills/
```

Then restart OpenCode. The skill auto-loads when you mention any database-related topic.

**Manual load:**
```
/skill database-architect
```

---

## Documentation

- [Getting Started Guide](./docs/en/getting-started.md) — Database architecture from zero
- [SQL Optimization Deep Dive](./docs/en/sql-optimization.md) — EXPLAIN mastery
- [Index Design Guide](./docs/en/index-design.md) — Index types, selection, tuning
- [Migration Handbook](./docs/en/migration-handbook.md) — Zero-downtime complete guide
- [Database Selection Guide](./docs/en/database-selection.md) — 20+ scenario analysis

---

## Testing

See [TEST_CASES.md](./TEST_CASES.md) for 15+ test scenarios covering all major areas.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| v1.0.0 | 2026-06-25 | Initial release: 12 core sections |
| v1.1.0 | 2026-06-25 | Added: Transaction & MVCC, Testing Strategy, Deadlocks, Connection Matrix, Capacity Planning, Case Studies |
| v1.2.0 | 2026-06-25 | Extended: ClickHouse / DuckDB / CockroachDB / DynamoDB deep dives, multi-language README, teaching docs |

---

## License

MIT © [ricky-theseus](https://github.com/ricky-theseus)
