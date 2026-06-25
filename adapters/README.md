# Adapters — Use This Skill with Any AI Agent

This skill works across all major AI coding agents. Pick your tool and follow the instructions.

---

## OpenCode (native)

```bash
# Option A: symlink (auto-syncs with git pull)
ln -s "$PWD" ~/.config/opencode/skills/database-architect

# Option B: copy (static)
cp -r . ~/.config/opencode/skills/database-architect
```

Auto-loads when you mention databases, SQL, indexes, migrations, etc.
Manual: `/skill database-architect`

---

## Claude Code

Copy the condensed context to your project root:

```bash
cp adapters/CLAUDE.md /path/to/your/project/CLAUDE.md
```

Claude Code automatically reads `CLAUDE.md` at project root and applies the database architecture context to every conversation.

---

## Cursor

Copy the rules file:

```bash
cp adapters/cursor/.cursorrules /path/to/your/project/.cursorrules
```

Cursor applies these rules to all AI interactions in that project.

---

## GitHub Copilot

Copy the instructions into your repo:

```bash
mkdir -p /path/to/your/project/.github
cp adapters/copilot/.github/copilot-instructions.md /path/to/your/project/.github/copilot-instructions.md
```

Copilot reads `.github/copilot-instructions.md` and applies it as context.

---

## Scripts

All agents can use these:

| Script | Usage |
|--------|-------|
| `scripts/diagnostics.sql` | `psql -U user -d db -f scripts/diagnostics.sql` — full health check |
| `scripts/backfill.py` | `python scripts/backfill.py --table users --column phone --value "''"` |
| `scripts/migration-check.sql` | `psql -U user -d db -f scripts/migration-check.sql` — pre-migration safety |
