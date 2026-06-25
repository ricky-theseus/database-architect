# Database Architect — OpenCode Skill

> 全栈数据库架构专家技能 — Schema 设计、查询优化、索引策略、ORM 调优、迁移工程、性能剖析、安全加固

## 能力覆盖

- **数据库选型** — PostgreSQL / MySQL / MongoDB / Redis / SQLite / ClickHouse 等 15+ 种数据库的决策树
- **Schema 设计** — 范式化 vs 反范式化、命名规范、数据类型最佳实践、反模式清单
- **查询优化** — EXPLAIN 分析、查询重写、分页优化、子查询转换
- **索引策略** — B-tree / GIN / GiST / BRIN / 部分索引 / 覆盖索引，复合索引列序设计
- **ORM 优化** — N+1 检测与修复、批量操作、裸 SQL 降级策略（Prisma / ActiveRecord / SQLAlchemy）
- **迁移工程** — 零宕机迁移模式、回滚策略、回填脚本模板
- **性能调优** — PostgreSQL 配置参数、连接池计算、多级缓存架构
- **安全加固** — TLS / RLS / 加密 / 审计 / SQL 注入防御
- **架构模式** — 读写分离 / 分片 / CQRS / 多租户
- **可观测性** — 关键指标、告警阈值、诊断查询
- **灾备** — 全量+WAL 归档、RPO/RTO 分级规划

## 使用

当涉及数据库相关的任务时，OpenCode 会自动加载此 skill。你也可以手动加载：

```
/skill database-architect
```

## 安装

```bash
# 克隆到 OpenCode skills 目录
git clone https://github.com/<your-username>/database-architect.git
# 或复制到本地 skills 目录
cp -r database-architect ~/.config/opencode/skills/
```

## 测试

参见 [TEST_CASES.md](./TEST_CASES.md) 获取 10 个覆盖主要场景的测试用例。

## License

MIT
