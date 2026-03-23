---
name: dbanalyze
description: Analyze a database schema by running SchemaCrawler lint and extracting the full schema via information_schema. Use this skill whenever the user wants to audit a database schema, check normalization, detect missing indexes, redundant indexes, nullable FK columns, inconsistent data types, design smells, or get improvement recommendations.
---

# DB Analyze — Lint & Schema Analysis

## What this skill does
Combines SchemaCrawler lint (structural issues) with a full schema extraction via `information_schema` (normalization, design analysis). Produces a prioritized action plan covering both technical and design issues.

---

## Prerequisites

SchemaCrawler wrapper at `/usr/local/bin/schemacrawler`:
```
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
/usr/local/opt/schemacrawler-17.1.4-bin/bin/schemacrawler.sh
```

psql must be available for the smart query.

---

## Step 1 — Run SchemaCrawler lint

```bash
schemacrawler \
  --server=<server> \
  --host=localhost \
  --port=5432 \
  --database=<database> \
  --schemas=public \
  --user=<user> \
  --password=<password> \
  --info-level=maximum \
  --command=lint
```

**Supported servers:** `postgresql`, `mysql`, `sqlserver`, `oracle`, `sqlite`, `db2`

**Connection conventions per project:**
- ubby → `--server=postgresql --database=ubby --user=ubby --password=ubby`
- pickpro → `--server=postgresql --database=pickpro --user=pickpro --password=pickpro`
- If the password is unknown, ask the user

---

## Step 2 — Extract full schema (smart query)

```bash
psql -U <user> -d <database> -c "
SELECT
  t.table_name,
  c.column_name,
  c.ordinal_position,
  c.data_type,
  c.is_nullable,
  c.column_default,
  tc.constraint_type,
  kcu.constraint_name,
  ccu.table_name  AS foreign_table,
  ccu.column_name AS foreign_column,
  ix.indexname,
  ix.indexdef
FROM information_schema.tables t
JOIN information_schema.columns c
  ON t.table_name = c.table_name AND t.table_schema = c.table_schema
LEFT JOIN information_schema.key_column_usage kcu
  ON c.table_name = kcu.table_name
  AND c.column_name = kcu.column_name
  AND c.table_schema = kcu.table_schema
LEFT JOIN information_schema.table_constraints tc
  ON kcu.constraint_name = tc.constraint_name
  AND kcu.table_schema = tc.table_schema
LEFT JOIN information_schema.referential_constraints rc
  ON tc.constraint_name = rc.constraint_name
LEFT JOIN information_schema.key_column_usage ccu
  ON rc.unique_constraint_name = ccu.constraint_name
LEFT JOIN pg_indexes ix
  ON t.table_name = ix.tablename
  AND c.column_name = ANY(string_to_array(
    regexp_replace(ix.indexdef, '.* USING .* \\((.*)\\)', '\\1'),
    ', '
  ))
WHERE t.table_schema = 'public'
  AND t.table_type = 'BASE TABLE'
ORDER BY t.table_name, c.ordinal_position;
"
```

---

## Step 3 — SchemaCrawler linter reference

| Linter | Description | Severity |
|--------|-------------|----------|
| `LinterColumnTypes` | Same column name, different types across tables | medium |
| `LinterForeignKeyMismatch` | FK type differs from referenced PK type | high |
| `LinterForeignKeySelfReference` | FK self-references PK — record cannot be deleted | medium |
| `LinterForeignKeyWithNoIndexes` | FK columns with no index — seq scans on lookups | high |
| `LinterNullColumnsInIndex` | Nullable columns in unique index — uniqueness not guaranteed | medium |
| `LinterNullIntendedColumns` | Default value is string `'NULL'` instead of actual NULL | medium |
| `LinterRedundantIndexes` | Index already covered by another index | high |
| `LinterTableAllNullableColumns` | All non-PK columns nullable — design smell | medium |
| `LinterTableCycles` | Cyclical FK relationships — delete/insert issues | high |
| `LinterTableEmpty` | Table has no data | low |
| `LinterTableWithBadlyNamedColumns` | Columns named according to forbidden patterns | medium |
| `LinterTableWithIncrementingColumns` | Columns `col1`, `col2` etc — denormalization indicator | medium |
| `LinterTableWithNoIndexes` | Table has no indexes at all | high |
| `LinterTableWithNoPrimaryKey` | Table has no primary key | high |
| `LinterTableWithNoRemarks` | Tables or columns with no comments | low |
| `LinterTableWithNoSurrogatePrimaryKey` | Composite PK — recommends surrogate key | low |
| `LinterTableWithPrimaryKeyNotFirst` | PK columns are not first in table | low |
| `LinterTableWithQuotedNames` | Names with spaces or SQL reserved words | medium |
| `LinterTableWithSingleColumn` | Table with no columns or only one column | medium |
| `LinterTooManyLobs` | Too many CLOB/BLOB columns (default: >1) | medium |
| `LinterCatalogSql` | Custom SQL lint at database level | configurable |
| `LinterTableSql` | Custom SQL lint per table | configurable |

---

## Step 4 — Noise filter

### Always ignore
| Lint | Reason |
|------|--------|
| `LinterTableWithNoRemarks` (low) | Not urgent in dev |
| `LinterTableEmpty` (low) | Expected on fresh dev databases |
| `LinterTableWithNoSurrogatePrimaryKey` (low) | Composite PKs valid on junction tables |
| `LinterTableWithPrimaryKeyNotFirst` (low) | Convention only, no functional impact |

### Always escalate
| Lint | Priority |
|------|----------|
| `LinterRedundantIndexes` | P1 |
| `LinterTableWithNoPrimaryKey` | P1 |
| `LinterForeignKeyWithNoIndexes` | P1 |
| `LinterForeignKeyMismatch` | P1 |
| `LinterNullColumnsInIndex` | P1 |
| `LinterTableCycles` | P1 |
| `LinterColumnTypes` | P2 |
| `LinterTableAllNullableColumns` | P2 |
| `LinterForeignKeySelfReference` | P2 |

---

## Step 5 — Normalization analysis (from smart query output)

Using the smart query output, analyze the schema for:

### 1NF violations
- Columns with incrementing names (`contact1`, `contact2`) → denormalization
- Array or JSON columns hiding multi-valued attributes
- Columns that appear to store comma-separated values

### 2NF violations (composite PKs only)
- Non-key columns that depend on only part of a composite PK
- Example: `order_items(order_id, product_id, product_name)` — `product_name` depends only on `product_id`

### 3NF violations
- Transitive dependencies between non-key columns
- Example: `users(id, zip_code, city)` — `city` depends on `zip_code`, not on `id`
- Look for columns that could live in a separate lookup table

### Design smells (beyond normal forms)
- Table with `user_id` AND a junction table for users → ambiguous ownership, rename to `owner_id`
- Inconsistent naming conventions (`lastsaved_at` vs `last_saved_at`)
- Junction tables with surrogate key instead of composite PK
- JSONB columns hiding relational data that should be normalized
- Nullable FK columns on junction tables

---

## Step 6 — Prioritization grid

### P1 — Fix before next deployment
- Redundant indexes → `DROP INDEX`
- FK without index → `CREATE INDEX`
- Unique index with nullable columns → `NOT NULL`
- Table without PK
- FK data type mismatch → align types

### P2 — Fix this week
- Heterogeneous `id` types across tables → document or homogenize
- Fully nullable tables → constrain mandatory columns
- 3NF violations → extract to lookup tables
- Self-referencing FK → verify `ON DELETE` strategy

### P3 — Continuous improvement
- Missing column remarks → `COMMENT ON COLUMN`
- Naming inconsistencies
- Composite PKs on junction tables instead of surrogate keys

---

## Step 7 — Generate correction SQL

### Drop redundant indexes
```sql
SELECT indexname, indexdef FROM pg_indexes
WHERE tablename = '<table>' AND schemaname = 'public';

DROP INDEX public.<redundant_index>;
```

### Create index on missing FK
```sql
CREATE INDEX <table>_<column>_idx ON public.<table> (<column>);
```

### Set nullable column to NOT NULL
```sql
SELECT COUNT(*) FROM public.<table> WHERE <column> IS NULL;
-- If 0:
ALTER TABLE public.<table> ALTER COLUMN <column> SET NOT NULL;
```

### Extract 3NF violation to lookup table
```sql
CREATE TABLE <lookup_table> (
  id SERIAL PRIMARY KEY,
  <dependent_column> TEXT NOT NULL UNIQUE
);

ALTER TABLE <source_table>
  ADD COLUMN <lookup_id> INT REFERENCES <lookup_table>(id);

-- Migrate data
INSERT INTO <lookup_table> (<dependent_column>)
  SELECT DISTINCT <dependent_column> FROM <source_table>;

UPDATE <source_table> s
  SET <lookup_id> = l.id
  FROM <lookup_table> l
  WHERE s.<dependent_column> = l.<dependent_column>;

ALTER TABLE <source_table> DROP COLUMN <dependent_column>;
```

---

## Step 8 — Generate Alembic migration

```python
"""fix schema analysis issues

Revision ID: <rev>
Revises: <prev>
Create Date: <date>
"""
from alembic import op
import sqlalchemy as sa

def upgrade():
    # Drop redundant indexes
    op.drop_index('<redundant_index>', table_name='<table>')

    # Create missing FK indexes
    op.create_index('<table>_<column>_idx', '<table>', ['<column>'])

    # Set FK columns to NOT NULL
    op.alter_column('<table>', '<column>', nullable=False)

def downgrade():
    op.create_index('<redundant_index>', '<table>', ['<column>'])
    op.drop_index('<table>_<column>_idx', table_name='<table>')
    op.alter_column('<table>', '<column>', nullable=True)
```

---

## Step 9 — Custom linter config (YAML)

```yaml
linters:
  - id: schemacrawler.tools.linter.LinterTableWithNoRemarks
    run: false
  - id: schemacrawler.tools.linter.LinterTableWithNoPrimaryKey
    severity: critical
  - id: schemacrawler.tools.linter.LinterTooManyLobs
    config:
      max-large-objects: 3
  - id: schemacrawler.tools.linter.LinterCatalogSql
    config:
      message: "Tables without created_at column"
      sql: >
        SELECT table_name FROM information_schema.columns
        WHERE table_schema = 'public'
        GROUP BY table_name
        HAVING SUM(CASE WHEN column_name = 'created_at' THEN 1 ELSE 0 END) = 0
        LIMIT 1
```

```bash
schemacrawler \
  --server=postgresql \
  --host=localhost \
  --port=5432 \
  --database=<database> \
  --schemas=public \
  --user=<user> \
  --password=<password> \
  --info-level=maximum \
  --command=lint \
  --linter-configs=schemacrawler-linter-config.yaml
```

---

## Step 10 — Expected response format

1. **Summary**: SchemaCrawler high/medium/low counts + normalization issues found
2. **P1**: structural lints with ready-to-use SQL
3. **P2**: design smells and normalization violations with impact explanation
4. **P3**: naming and convention issues
5. **What we ignore** and why
6. **Alembic migration** if the user wants to version the corrections