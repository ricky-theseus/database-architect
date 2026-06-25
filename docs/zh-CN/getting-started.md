# 数据库架构入门指南

> 面向开发者的数据库架构设计教程。从建表到百万级并发，逐步深入。

---

## 第一章：从建表开始

### 1.1 你的第一张表

```sql
CREATE TABLE users (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email       TEXT NOT NULL,
    name        TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_users_email ON users (email);
```

**为什么这样设计？**
- `BIGINT` 而不是 `SERIAL`：SERIAL 最大 21 亿，BIGINT 几乎不会溢出
- `TEXT` 而不是 `VARCHAR(255)`：PostgreSQL 中两者性能一样，TEXT 没有无意义的长度限制
- `TIMESTAMPTZ` 而不是 `TIMESTAMP`：带时区的时间戳，避免时区转换 Bug
- 唯一索引在 email 上：保证邮箱不重复，且查询加速

### 1.2 关联表

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

**关键点：**
- `user_id` 是外键 — 保证数据完整性
- `NUMERIC(12,2)` 存金额 — 杜绝浮点数精度问题
- `CHECK` 约束而不是 ENUM — 修改约束更灵活
- 两个索引：一个查用户订单，一个查状态+时间排序

---

## 第二章：理解查询性能

### 2.1 用 EXPLAIN 看真相

```sql
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT * FROM orders WHERE status = 'pending' ORDER BY created_at DESC LIMIT 20;
```

输出解读：
```
Limit  (cost=0.42..153.24 rows=20 width=72)  ← 估算成本
  ->  Index Scan Backward using idx_orders_status_created on orders
        (cost=0.42..7652.82 rows=1001 width=72)  ← 实际 1001 行匹配
        Index Cond: (status = 'pending'::text)
        Buffers: shared hit=42  ← 全部来自缓存，没有磁盘读
```

**危险信号速查表：**

| EXPLAIN 输出 | 含义 | 怎么办 |
|-------------|------|--------|
| `Seq Scan` on 10万+ rows | 全表扫描 | 加索引 |
| 估算行数 vs 实际行数差 100x+ | 统计信息过期 | `ANALYZE` |
| `Temp File` 出现 | 内存不够排序 | 增大 `work_mem` |
| `Shared Hit` 很少 | 缓存命中率低 | 增大 `shared_buffers` |

### 2.2 常见的慢查询模式

```sql
-- 慢：函数包裹了索引列
SELECT * FROM orders WHERE DATE(created_at) = '2024-06-01';
-- 快：范围查询走索引
SELECT * FROM orders WHERE created_at >= '2024-06-01' AND created_at < '2024-06-02';

-- 慢：子查询每行执行一次（相关子查询）
SELECT * FROM users WHERE id IN (SELECT user_id FROM orders WHERE amount > 100);
-- 快：JOIN 让优化器有更多选择
SELECT DISTINCT u.* FROM users u JOIN orders o ON o.user_id = u.id WHERE o.amount > 100;

-- 慢：OFFSET 翻页（越翻越慢）
SELECT * FROM users ORDER BY id LIMIT 20 OFFSET 100000;
-- 快：Keyset 分页（始终快）
SELECT * FROM users WHERE id > 100000 ORDER BY id LIMIT 20;
```

---

## 第三章：索引设计实战

### 3.1 索引类型选择

| 场景 | 索引类型 | 例子 |
|------|---------|------|
| 等值查询 + 范围查询 | B-tree（默认） | `WHERE status = 'active' AND created_at > '2024-01-01'` |
| JSON 字段查询 | GIN | `WHERE metadata @> '{"key": "value"}'` |
| 全文搜索 | GIN (tsvector) | `WHERE to_tsvector('english', body) @@ to_tsquery('database')` |
| 地理位置 | GiST | `WHERE ST_DWithin(location, ST_MakePoint(116.4, 39.9), 1000)` |
| 时间序列（只追加） | BRIN | `WHERE ts BETWEEN '2024-01-01' AND '2024-01-02'` |

### 3.2 复合索引设计规则

```sql
-- 查询：WHERE status = 'pending' ORDER BY created_at DESC
-- 索引应该：
CREATE INDEX idx_orders_status_created ON orders (status, created_at DESC);
--          ↑ 等值查询放前面     ↑ 排序放后面

-- 覆盖索引：查询只需要 name 和 email
CREATE INDEX idx_users_email ON users (email) INCLUDE (name);
--                            ↑ 用于 WHERE 和 JOIN  ↑ 直接存在索引里，不用回表
```

**最左前缀原则：**
索引 `(a, b, c)` 能匹配的查询：
- ✅ `WHERE a = 1`
- ✅ `WHERE a = 1 AND b = 2`
- ✅ `WHERE a = 1 AND b = 2 AND c = 3`
- ❌ `WHERE b = 2`（跳过了 a）
- ❌ `WHERE c = 3`（跳过了 a 和 b）

---

## 第四章：事务与并发

### 4.1 隔离级别速览

```sql
-- 查看当前隔离级别
SHOW transaction_isolation;

-- 设置隔离级别（会话级）
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
```

**四种级别：**

| 级别 | 脏读 | 不可重复读 | 幻读 | 建议场景 |
|------|------|-----------|------|---------|
| READ UNCOMMITTED | 可能 | 可能 | 可能 | 基本不用 |
| READ COMMITTED（默认） | 安全 | 可能 | 可能 | 95% 的业务场景 |
| REPEATABLE READ | 安全 | 安全 | PostgreSQL 安全 | 财务对账 |
| SERIALIZABLE | 安全 | 安全 | 安全 | 极严格的金融操作 |

### 4.2 常见并发问题

**丢失更新：**
```sql
-- 事务 A                   事务 B
BEGIN;                       BEGIN;
SELECT stock FROM products   SELECT stock FROM products
  WHERE id = 1;  -- 10         WHERE id = 1;  -- 10
UPDATE products SET stock     UPDATE products SET stock
  = 10 - 1 WHERE id = 1;       = 10 - 1 WHERE id = 1;
COMMIT;                      COMMIT;
-- 结果：stock = 9（应该 = 8，卖了两次只减了一次！）
```

**解决：**
```sql
-- 方案 1：行锁
BEGIN;
SELECT stock FROM products WHERE id = 1 FOR UPDATE;
UPDATE products SET stock = stock - 1 WHERE id = 1;
COMMIT;

-- 方案 2：乐观锁（用版本号）
UPDATE products SET stock = stock - 1, version = version + 1
WHERE id = 1 AND version = 5;
-- 如果 version 不对，影响行数为 0，重试
```

---

## 第五章：迁移实战

### 5.1 安全的加列操作

```sql
-- 第一步：加列（允许 NULL，瞬间完成）
ALTER TABLE users ADD COLUMN phone TEXT;

-- 第二步：逐步回填
-- 分批更新，每次 1000 行，间隔 100ms
UPDATE users SET phone = '' WHERE phone IS NULL AND id BETWEEN 0 AND 1000;
-- ... 等待 100ms ...
UPDATE users SET phone = '' WHERE phone IS NULL AND id BETWEEN 1001 AND 2000;

-- 第三步：加 NOT NULL 约束（需要锁，但很快）
ALTER TABLE users ALTER COLUMN phone SET NOT NULL;
```

### 5.2 零宕机改列名

```
旧列 email → 新列 contact_email

1. 加 contact_email 列（NULL 允许）
2. 应用代码改为双写：同时写 email 和 contact_email
3. 回填历史数据（分批）
4. 应用代码改为只读 contact_email
5. 验证无误后，删除 email 列
```

> ⚠️ **生产线规则**：永远不要在高峰期执行 DDL。先用 `SET lock_timeout = '5s'` 避免长时间锁表。

---

## 第六章：常见误区

### ❌ 用 FLOAT 存金额
```sql
-- 错
CREATE TABLE products (price FLOAT);
INSERT INTO products VALUES (0.1 + 0.2);  -- 存的是 0.30000000000000004

-- 对
CREATE TABLE products (price NUMERIC(12,2));
INSERT INTO products VALUES (0.1 + 0.2);  -- 精确的 0.30
```

### ❌ 每个表都加一个通用 meta 字段
```sql
-- 错
CREATE TABLE users (meta TEXT);  -- 没人知道里面存什么

-- 对（如果真需要）
CREATE TABLE users (meta JSONB);
CREATE INDEX idx_users_meta ON users USING GIN (meta);
```

### ❌ SELECT * 加上 JOIN
```sql
-- 错：查到 50 列但只用 3 列
SELECT * FROM users JOIN orders ON users.id = orders.user_id;

-- 对：只取需要的列
SELECT users.name, orders.total, orders.created_at
FROM users JOIN orders ON users.id = orders.user_id;
```

---

## 下一步

- [SQL 优化实战](./sql-optimization.md) — 深入 EXPLAIN，掌握查询艺术
- [索引设计指南](./index-design.md) — 从单索引到复合索引到覆盖索引
- [迁移工程手册](./migration-handbook.md) — 零宕机迁移完整指南
- [数据库选型决策](./database-selection.md) — 20+ 场景的选型分析
