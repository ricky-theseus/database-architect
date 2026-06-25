# Schema Templates

Production-ready SQL schema blueprints for common domains.

## Usage

```bash
# Generate from template
cp templates/saas.sql /path/to/project/init.sql
# Customize for your needs
vim /path/to/project/init.sql
```

## Templates

| Template | Domain | Key Patterns |
|----------|--------|-------------|
| `saas.sql` | Multi-tenant SaaS | Tenant isolation via RLS, feature flags, tiered plans |
| `ecommerce.sql` | E-Commerce | Products, inventory, orders, payments |
| `cms.sql` | Content / Blog | Authors, posts with full-text search, tags |
| `iot.sql` | IoT / Time-Series | Partitioned readings, device registry |

## Template Format

Every template follows the standard output format defined in SKILL.md §19.2:

1. Extensions
2. Enums
3. Tables (with COMMENTS)
4. Indexes (separate from tables)
5. Foreign Keys (separate from tables)
6. Row-Level Security (if applicable)
