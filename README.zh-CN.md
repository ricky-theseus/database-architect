<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://img.shields.io/badge/Database%20Architect-%234A90E2?style=for-the-badge&labelColor=1a1a1a&logo=postgresql">
  <img alt="Database Architect" src="https://img.shields.io/badge/Database%20Architect-%234A90E2?style=for-the-badge&labelColor=ffffff&logo=postgresql">
</picture>

# Database Architect — OpenCode Skill

> 全栈数据库架构专家技能。Schema 设计、查询优化、索引策略、ORM 调优、迁移工程、性能剖析、安全加固、容量规划、灾备方案。

[English](./README.md) | **中文**

---

## 📋 能力全景

| 领域 | 覆盖内容 |
|------|---------|
| **数据库选型** | PostgreSQL / MySQL / MongoDB / Redis / SQLite / ClickHouse / DuckDB / CockroachDB / DynamoDB 等 20+ 种数据库的决策树 |
| **Schema 设计** | 范式化 vs 反范式化、命名规范、数据类型最佳实践、反模式清单 |
| **索引策略** | B-tree / GIN / GiST / BRIN / 部分索引 / 覆盖索引，复合索引列序设计 |
| **查询优化** | EXPLAIN 分析、查询重写、分页优化（Keyset vs Offset）、子查询转换 |
| **事务与 MVCC** | 隔离级别详解、MVCC 内部机制、快照管理、常见陷阱 |
| **ORM 优化** | N+1 检测与修复、批量操作、裸 SQL 降级策略（Prisma / ActiveRecord / SQLAlchemy） |
| **死锁处理** | 死锁成因、预防模式、检测 SQL、重试模板 |
| **迁移工程** | 零宕机迁移 5 种模式、回滚策略、回填脚本模板、锁分析 |
| **性能调优** | PostgreSQL 16+ 配置参数、连接池计算（PgBouncer）、多级缓存架构 |
| **安全加固** | TLS / RLS / 行级加密 / 审计日志 / SQL 注入防御 / 密钥管理 |
| **架构模式** | 读写分离 / 分片（Hash/Range/Directory）/ CQRS / 多租户 4 种方案 |
| **数据库测试** | 单元测试、集成测试（Testcontainers）、CI 管道、性能回归测试 |
| **连接管理** | 5 种语言 × 5 种数据库的连接串模板，驱动推荐，池化策略 |
| **Schema 生成** | 🆕 从需求到生产级 SQL — 完整 schema、索引、RLS、数据字典 |
| **Schema 模板** | 🆕 领域蓝本：多租户 SaaS、电商、CMS、IoT — 开箱即用 |
| **迁移自动生成** | 🆕 从 schema diff 到迁移 SQL，含 UP/DOWN、零宕机规则 |
| **Schema 审计** | 🆕 自动 schema 审查，打分 + 优先级排序 + 自动生成修复迁移 |
| **容量规划** | 增长估算公式、分级规格表（Tiny 到 X-Large）、扩容信号 |
| **可观测性** | 8 个关键指标 + 告警阈值 + 诊断查询 |
| **灾备** | 全量+WAL 归档、RPO/RTO 三级规划 |

---

## 🚀 安装

```bash
# 方案一：从 GitHub 克隆
git clone https://github.com/ricky-theseus/database-architect.git

# 方案二：复制到本地技能目录
cp -r database-architect ~/.config/opencode/skills/

# 方案三：直接安装（如果发布了 npm 包）
npm install -g @ricky-theseus/database-architect
```

---

## 🎯 使用方式

当你在 OpenCode 中提及任何数据库相关问题时，此 skill 会自动加载。

**手动加载：**
```
/skill database-architect
```

**触发关键词：**
数据库设计、SQL 优化、索引、ORM、迁移、性能、安全、选型、备份、连接池、死锁、事务隔离、测试、容量规划

---

## 📚 教学文档

- [入门指南](./docs/zh-CN/getting-started.md) — 从零开始掌握数据库架构
- [SQL 优化实战](./docs/zh-CN/sql-optimization.md) — EXPLAIN 详解与查询重写
- [索引设计指南](./docs/zh-CN/index-design.md) — 索引类型、选择与调优
- [迁移工程手册](./docs/zh-CN/migration-handbook.md) — 零宕机迁移完整指南
- [数据库选型决策](./docs/zh-CN/database-selection.md) — 20+ 场景的选型分析

---

## 📦 Schema 模板

生产级 SQL 蓝本，开箱即用：

| 模板 | 领域 | 文件 |
|------|------|------|
| 🏢 多租户 SaaS | RLS 租户隔离、功能开关、审计日志 | [`templates/saas.sql`](./templates/saas.sql) |
| 🛒 电商 | 商品、库存、订单、支付、分类 | [`templates/ecommerce.sql`](./templates/ecommerce.sql) |
| 📝 CMS / 博客 | 作者、全文搜索、标签、评论 | [`templates/cms.sql`](./templates/cms.sql) |
| 📡 IoT / 时序 | 分区 readings、设备注册、自动分区维护 | [`templates/iot.sql`](./templates/iot.sql) |

告诉 AI "生成一个电商数据库"或"给我一个 SaaS schema"——它会以这些模板为起点，按你的需求定制。

## 🛠 脚本工具

开箱即用的数据库运维脚本：

| 脚本 | 功能 | 用法 |
|------|------|------|
| [`scripts/diagnostics.sql`](./scripts/diagnostics.sql) | 14 项健康检查：慢查询、锁、bloat、连接数、缓存命中率 | `psql -U postgres -d yourdb -f scripts/diagnostics.sql` |
| [`scripts/backfill.py`](./scripts/backfill.py) | 零宕机列回填，批量 + 节流 | `python scripts/backfill.py --table users --column phone --value "''"` |
| [`scripts/migration-check.sql`](./scripts/migration-check.sql) | 迁移前安全检测：长事务、阻塞锁、复制延迟 | `psql -U postgres -d yourdb -f scripts/migration-check.sql` |

## 🤖 多 Agent 适配

本 skill 支持所有主流 AI 编程助手，复制对应适配器文件到项目即可：

| Agent | 文件 | 配置方法 |
|-------|------|---------|
| **OpenCode** | [`adapters/opencode/SKILL.md`](./adapters/opencode/SKILL.md) | 软链接到 `~/.config/opencode/skills/` |
| **Claude Code** | [`adapters/CLAUDE.md`](./adapters/CLAUDE.md) | 复制到项目根目录命名为 `CLAUDE.md` |
| **Cursor** | [`adapters/cursor/.cursorrules`](./adapters/cursor/.cursorrules) | 复制到项目根目录 |
| **GitHub Copilot** | [`adapters/copilot/.github/copilot-instructions.md`](./adapters/copilot/.github/copilot-instructions.md) | 复制到仓库的 `.github/` 目录 |

详细配置见 [`adapters/README.zh-CN.md`](./adapters/README.zh-CN.md)

## 🧪 测试

参见 [TEST_CASES.md](./TEST_CASES.md) 获取覆盖 15 个场景的测试用例。

---

## 📊 项目状态

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0.0 | 2026-06-25 | 初始发布：12 个核心章节 |
| v1.1.0 | 2026-06-25 | 新增：事务 & MVCC、测试策略、死锁处理、连接串矩阵、容量规划、实战案例 |
| v1.2.0 | 2026-06-25 | 扩展：ClickHouse / DuckDB / CockroachDB / DynamoDB 深度指南、多语言 README、教学文档 |
| v2.0.0 | 2026-06-26 | **Meta 层**：Schema 生成协议、领域模板、迁移生成、Schema 审计。4 个领域 SQL 模板 |

---

## 📄 License

MIT © [ricky-theseus](https://github.com/ricky-theseus)
