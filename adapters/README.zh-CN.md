# 适配器 — 在任何 AI Agent 中使用本技能

支持所有主流 AI 编程助手，选择你的工具按指引配置。

---

## OpenCode（原生）

```bash
# 方案 A：软链接（git pull 后自动同步）
ln -s "$PWD" ~/.config/opencode/skills/database-architect

# 方案 B：复制（静态）
cp -r . ~/.config/opencode/skills/database-architect
```

提及数据库/SQL/索引/迁移等关键词时自动加载。手动：`/skill database-architect`

---

## Claude Code

复制精简版上下文到项目根目录：

```bash
cp adapters/CLAUDE.md /path/to/your/project/CLAUDE.md
```

Claude Code 自动读取根目录的 `CLAUDE.md`，每次对话都有数据库架构上下文。

---

## Cursor

复制规则文件：

```bash
cp adapters/cursor/.cursorrules /path/to/your/project/.cursorrules
```

Cursor 在项目的所有 AI 交互中应用这些规则。

---

## GitHub Copilot

复制指引到仓库：

```bash
mkdir -p /path/to/your/project/.github
cp adapters/copilot/.github/copilot-instructions.md /path/to/your/project/.github/copilot-instructions.md
```

Copilot 读取 `.github/copilot-instructions.md` 作为上下文。

---

## 脚本（所有 Agent 通用）

| 脚本 | 用法 |
|--------|-------|
| `scripts/diagnostics.sql` | `psql -U user -d db -f scripts/diagnostics.sql` — 一键健康检查 |
| `scripts/backfill.py` | `python scripts/backfill.py --table users --column phone --value "''"` — 零宕机回填 |
| `scripts/migration-check.sql` | `psql -U user -d db -f scripts/migration-check.sql` — 迁移前安全检查 |
