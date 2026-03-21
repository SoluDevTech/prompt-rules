# UB-16: AI Worker & Database Tool Strategies

## Problem Statement

The MCP tool builder currently supports only HTTP-based tool strategies. Users who want to expose an LLM-powered tool (e.g., "summarize this text", "translate to French") or a database query tool (e.g., "look up user by ID") must stand up their own HTTP wrapper service, configure CORS, handle authentication, and maintain that infrastructure -- just to do something the platform should handle natively.

### Why it matters

HTTP is a universal strategy but a poor fit for the two most common non-HTTP use cases: calling an LLM and querying a database. Forcing users to build and host wrapper services increases setup time, introduces failure points, and raises the barrier to entry for non-developer users.

### Current situation

- `ToolStrategyPort.execute(args, config, context)` is the strategy interface.
- `HttpStrategyAdapter` is the sole implementation.
- Strategies are registered in a `Map<string, ToolStrategyPort>` in `dependencies.ts`.
- `mcp-tool.entity.ts` defines `ToolStrategy { type: 'http', config: HttpStrategyConfig }`.
- The DTO validates `type: z.literal('http')`.
- The frontend builder creates `HttpToolNode` nodes with an `HttpConfig` panel.
- The Python backend (`ubby-back`) mirrors the entity with `McpHttpToolConfig`.

### Design decisions (PO-approved)

- **AI Worker:** `prompt` is the only MCP-visible parameter. `model`, `systemPrompt`, `apiKey`, `apiUrl` are server-side config, never exposed to the MCP client.
- **Database:** Named parameters (`:userId`) in the query template are rewritten to positional `$N` placeholders at execution time. Parameters are defined as `Record<string, McpToolParameter>` and exposed to the MCP client.
- **Model field:** Free-text string following OpenRouter model ID convention (e.g., `google/gemini-2.5-pro`).
- **V1 scope:** AI Worker + Database strategies only. No other strategy types.

---

## Proposed Solution

### Overview

Add two new tool strategy implementations alongside the existing HTTP strategy. The AI Worker strategy calls the OpenRouter API with a user-supplied prompt and returns LLM-generated text. The Database strategy connects to PostgreSQL, executes a parameterized SQL query, and returns the result rows as JSON. Both strategies follow the existing `ToolStrategyPort` interface and plug into the strategy Map with zero changes to the execution pipeline.

### User Stories

- As a tool builder, I want to create an AI-powered tool by specifying a model and system prompt so that MCP clients can send a prompt and receive an LLM response without me hosting any service.
- As a tool builder, I want to create a database query tool by providing a connection string and SQL template so that MCP clients can query my database through named parameters without direct database access.
- As a tool builder, I want to configure database tools as read-only so that accidental mutations are prevented at the connection level.

---

## 1. ubby-mcp-api Changes (NestJS / TypeScript)

### 1.1 Entity Updates

**Modified file:** `src/domain/entities/mcp-tool.entity.ts`

Add two new config interfaces:

```typescript
export interface McpToolParameter {
  type: string       // JSON Schema type: 'string', 'number', 'boolean', 'integer'
  description: string
}

export interface AiWorkerStrategyConfig {
  model: string                                   // OpenRouter model ID, e.g. "google/gemini-2.5-pro"
  systemPrompt: string                            // System prompt injected before user prompt
  apiKey: string                                   // OpenRouter API key
  apiUrl?: string                                  // Default: "https://openrouter.ai/api/v1"
  parameters?: Record<string, McpToolParameter>    // Usually just { prompt: { type: 'string', description: '...' } }
}

export interface DatabaseStrategyConfig {
  connectionString: string                         // PostgreSQL connection string
  queryTemplate: string                            // SQL with :namedParams, e.g. "SELECT * FROM users WHERE id = :userId"
  readOnly: boolean                                // Default true. When true, use a read-only transaction.
  parameters?: Record<string, McpToolParameter>    // Named bind variables matching :params in the template
}
```

Widen the `ToolStrategy` type union:

```typescript
export type ToolStrategy =
  | { type: 'http'; config: HttpStrategyConfig }
  | { type: 'ai-worker'; config: AiWorkerStrategyConfig }
  | { type: 'database'; config: DatabaseStrategyConfig }
```

**REQ-001:** `ToolStrategy.type` SHALL accept `'http'`, `'ai-worker'`, and `'database'` as valid values.

**REQ-002:** `AiWorkerStrategyConfig.apiUrl` SHALL default to `"https://openrouter.ai/api/v1"` when not provided.

**REQ-003:** `DatabaseStrategyConfig.readOnly` SHALL default to `true` when not provided.

### 1.2 DTO Updates

**Modified file:** `src/infrastructure/dtos/create-mcp-server.dto.ts`

Update the Zod schema for tool strategy to accept the new types. The discriminated union validates config shape based on `type`:

```typescript
const AiWorkerStrategyConfigSchema = z.object({
  model: z.string().min(1),
  systemPrompt: z.string().min(1),
  apiKey: z.string().min(1),
  apiUrl: z.string().url().optional().default('https://openrouter.ai/api/v1'),
  parameters: z.record(McpToolParameterSchema).optional(),
})

const DatabaseStrategyConfigSchema = z.object({
  connectionString: z.string().min(1),
  queryTemplate: z.string().min(1),
  readOnly: z.boolean().optional().default(true),
  parameters: z.record(McpToolParameterSchema).optional(),
})

const ToolStrategySchema = z.discriminatedUnion('type', [
  z.object({ type: z.literal('http'), config: HttpStrategyConfigSchema }),
  z.object({ type: z.literal('ai-worker'), config: AiWorkerStrategyConfigSchema }),
  z.object({ type: z.literal('database'), config: DatabaseStrategyConfigSchema }),
])
```

**REQ-004:** The DTO SHALL reject `ai-worker` strategy configs with an empty `model` or `systemPrompt`.

**REQ-005:** The DTO SHALL reject `database` strategy configs with an empty `connectionString` or `queryTemplate`.

### 1.3 New Adapter: AI Worker Strategy

**New file:** `src/infrastructure/tools/ai-worker-strategy.adapter.ts`

Implements `ToolStrategyPort`. Execution flow:

1. Extract `prompt` from `args` (the MCP tool call arguments).
2. Build the OpenRouter API request:
   - URL: `${config.apiUrl}/chat/completions`
   - Headers: `Authorization: Bearer ${config.apiKey}`, `Content-Type: application/json`
   - Body: `{ model: config.model, messages: [{ role: 'system', content: config.systemPrompt }, { role: 'user', content: args.prompt }] }`
3. Send the request via `fetch` (Node native fetch).
4. Parse the response. Return the assistant message content as a plain text string.
5. On error (non-2xx, network failure, missing response content), throw a descriptive error that includes the HTTP status and model name but NOT the API key.

**REQ-006:** The adapter SHALL send requests to `${config.apiUrl}/chat/completions` using the OpenAI-compatible chat completions format.

**REQ-007:** The adapter SHALL include `config.systemPrompt` as a system message and `args.prompt` as a user message.

**REQ-008:** The adapter SHALL return `response.choices[0].message.content` as the tool result (plain text string).

**REQ-009:** On API error, the adapter SHALL throw an error containing the HTTP status code and model name but SHALL NOT leak the API key in error messages or logs.

**REQ-010:** If `args.prompt` is missing or empty, the adapter SHALL throw immediately with a descriptive error before making any API call.

### 1.4 New Adapter: Database Strategy

**New file:** `src/infrastructure/tools/database-strategy.adapter.ts`

Implements `ToolStrategyPort`. Execution flow:

1. Parse `config.queryTemplate` to extract named parameters (regex: `/:(\w+)/g`).
2. Rewrite the query: replace each `:paramName` with `$N` (positional placeholder), building the values array from `args` in the same order.
3. Validate that every named parameter in the template has a corresponding value in `args`. Throw if any are missing.
4. Connect to PostgreSQL using `pg` (node-postgres) library with `config.connectionString`.
5. If `config.readOnly` is true, wrap the query in a read-only transaction:
   ```sql
   BEGIN READ ONLY;
   <query>;
   COMMIT;
   ```
6. Execute the parameterized query. Return the result rows as a JSON array string.
7. Always close/release the connection after execution (use `try/finally`).
8. On error (connection failure, SQL error), throw a descriptive error that includes the error message but NOT the full connection string (redact credentials).

**REQ-011:** The adapter SHALL rewrite `:namedParam` placeholders to `$N` positional parameters in the order they first appear in the query template.

**REQ-012:** The adapter SHALL throw if any named parameter in the template has no corresponding value in `args`.

**REQ-013:** When `readOnly` is true, the adapter SHALL execute the query inside a `BEGIN READ ONLY` transaction.

**REQ-014:** The adapter SHALL return result rows as a JSON-serialized array (string).

**REQ-015:** On connection or SQL error, the adapter SHALL NOT include the connection string credentials in error messages. It SHALL redact the connection string to show only `host:port/dbname`.

**REQ-016:** The adapter SHALL always release the database client back to the pool in a `finally` block, even on error.

**REQ-017:** The adapter SHALL throw if `args` contains parameters not defined in the query template (prevent injection of unexpected values).

**REQ-018:** The adapter SHALL coerce `args` values based on the parameter's declared `type`: `'integer'` and `'number'` types are parsed to numbers, `'boolean'` types convert `"true"`/`"false"` strings to booleans. If coercion fails (e.g., non-numeric string for an integer parameter), the adapter SHALL throw with a descriptive error.

### 1.5 Strategy Registration

**Modified file:** `src/infrastructure/dependencies.ts`

Add the two new strategies to the Map:

```typescript
strategyMap.set('ai-worker', new AiWorkerStrategyAdapter())
strategyMap.set('database', new DatabaseStrategyAdapter())
```

**REQ-019:** Both strategies SHALL be registered at application startup and available for tool execution without restart.

### 1.6 Dependencies (npm)

**Modified file:** `package.json`

Add `pg` (node-postgres) as a production dependency:

```
"pg": "^8.13.0"
```

Add `@types/pg` as a dev dependency.

The AI Worker adapter uses Node native `fetch` (available in Node 18+). No additional HTTP client dependency needed.

---

## 2. ubby-front Changes (React / TypeScript / Vite)

### 2.1 New Entities

**New file:** `src/domain/entities/AiWorkerNode.ts`

```typescript
import { z } from 'zod/v4'

export const AiWorkerNodeDataSchema = z.object({
  label: z.string(),
  model: z.string().min(1),
  systemPrompt: z.string().min(1),
  apiKey: z.string().min(1),
  apiUrl: z.string().url().optional().default('https://openrouter.ai/api/v1'),
  description: z.string().optional().default(''),
  parameters: z.record(z.object({
    type: z.string(),
    description: z.string(),
  })).optional().default({ prompt: { type: 'string', description: 'The prompt to send to the AI model' } }),
})

export type AiWorkerNodeData = z.infer<typeof AiWorkerNodeDataSchema>
```

**New file:** `src/domain/entities/DatabaseNode.ts`

```typescript
import { z } from 'zod/v4'

export const DatabaseNodeDataSchema = z.object({
  label: z.string(),
  connectionString: z.string().min(1),
  queryTemplate: z.string().min(1),
  readOnly: z.boolean().optional().default(true),
  description: z.string().optional().default(''),
  parameters: z.record(z.object({
    type: z.string(),
    description: z.string(),
  })).optional().default({}),
})

export type DatabaseNodeData = z.infer<typeof DatabaseNodeDataSchema>
```

**Modified file:** `src/domain/entities/index.ts`

Export both new entities.

### 2.2 New Flow Nodes

**New file:** `src/application/components/nodes/AiWorkerNode.tsx`

A ReactFlow custom node matching the existing `HttpToolNode` pattern:
- Icon: `Bot` from `lucide-react` (or similar AI-representative icon).
- Color accent: purple/violet to differentiate from HTTP (blue) nodes.
- Displays the model name as subtitle text.
- Single input handle (left), single output handle (right).
- Click opens the config panel.

**New file:** `src/application/components/nodes/DatabaseNode.tsx`

A ReactFlow custom node matching the existing `HttpToolNode` pattern:
- Icon: `Database` from `lucide-react`.
- Color accent: green to differentiate from HTTP (blue) and AI (purple) nodes.
- Displays truncated query template as subtitle text.
- Single input handle (left), single output handle (right).
- Click opens the config panel.

### 2.3 New Config Panels

**New file:** `src/application/components/config/AiWorkerConfig.tsx`

Config panel displayed in the sidebar when an AI Worker node is selected. Fields:

| Field         | Input type   | Validation                  | Notes                                           |
|---------------|-------------|-----------------------------|-------------------------------------------------|
| Tool Name     | Text input   | Required, min 1 char        | Maps to `label`                                 |
| Description   | Text area    | Optional                    | Tool description for MCP                        |
| Model         | Text input   | Required, min 1 char        | Placeholder: `google/gemini-2.5-pro`            |
| System Prompt | Text area    | Required, min 1 char        | Multi-line, resizable                           |
| API Key       | Password input| Required, min 1 char       | Masked by default, toggle to reveal             |
| API URL       | Text input   | Optional, must be valid URL | Default value pre-filled: `https://openrouter.ai/api/v1` |

**REQ-020:** The API Key field SHALL be masked (password type) by default with a toggle button to reveal.

**REQ-021:** The Model field SHALL display a placeholder showing the OpenRouter model ID format.

**New file:** `src/application/components/config/DatabaseConfig.tsx`

Config panel displayed in the sidebar when a Database node is selected. Fields:

| Field             | Input type   | Validation                  | Notes                                           |
|-------------------|-------------|-----------------------------|-------------------------------------------------|
| Tool Name         | Text input   | Required, min 1 char        | Maps to `label`                                 |
| Description       | Text area    | Optional                    | Tool description for MCP                        |
| Connection String | Password input| Required, min 1 char       | Masked by default, toggle to reveal             |
| Query Template    | Code editor  | Required, min 1 char        | Monospace font, syntax-highlighted if feasible   |
| Read Only         | Toggle switch| Boolean                     | Default: on (true)                              |
| Parameters        | Dynamic list | Key-value pairs             | Name, type (dropdown: string/number/boolean/integer), description |

The parameters section:
- Displays detected `:namedParam` placeholders from the query template as read-only parameter names.
- Allows the user to set the type and description for each detected parameter.
- Auto-detects parameters when the query template changes (parse `:(\w+)` pattern).
- If the user modifies the query template and a parameter is removed, the corresponding row disappears. If a new parameter is added, a new row appears with default type `string`.

**REQ-022:** The Connection String field SHALL be masked (password type) by default with a toggle button to reveal.

**REQ-023:** The parameters list SHALL auto-populate based on `:namedParam` placeholders detected in the query template.

**REQ-024:** The Read Only toggle SHALL default to `true` (on).

### 2.4 Toolbox / Menu Items

**Modified file:** `src/application/components/toolbox/ToolboxItems.ts` (or equivalent menu/toolbox file)

Add two new draggable items:

```typescript
{
  type: 'ai-worker',
  label: 'AI Worker',
  icon: 'Bot',          // lucide-react icon
  description: 'Call an LLM via OpenRouter',
}
```

```typescript
{
  type: 'database',
  label: 'Database',
  icon: 'Database',     // lucide-react icon
  description: 'Query a PostgreSQL database',
}
```

### 2.5 Config Bar / Sidebar

**Modified file:** `src/application/components/config/ConfigBar.tsx` (or equivalent)

Add cases for the new node types so that selecting an AI Worker or Database node renders the appropriate config panel:

```typescript
case 'ai-worker':
  return <AiWorkerConfig node={selectedNode} onUpdate={handleUpdate} />
case 'database':
  return <DatabaseConfig node={selectedNode} onUpdate={handleUpdate} />
```

### 2.6 Node Factory

**Modified file:** `src/application/utils/nodeFactory.ts` (or equivalent)

Add factory cases for creating new nodes of each type with sensible defaults:

```typescript
case 'ai-worker':
  return {
    type: 'ai-worker',
    data: {
      label: 'AI Worker',
      model: '',
      systemPrompt: '',
      apiKey: '',
      apiUrl: 'https://openrouter.ai/api/v1',
      description: '',
      parameters: { prompt: { type: 'string', description: 'The prompt to send to the AI model' } },
    },
  }

case 'database':
  return {
    type: 'database',
    data: {
      label: 'Database Query',
      connectionString: '',
      queryTemplate: '',
      readOnly: true,
      description: '',
      parameters: {},
    },
  }
```

### 2.7 ReactFlow Node Type Registration

**Modified file:** `src/application/components/flow/FlowCanvas.tsx` (or wherever `nodeTypes` is defined)

Register the new custom node components:

```typescript
const nodeTypes = {
  httpTool: HttpToolNode,
  'ai-worker': AiWorkerNode,
  database: DatabaseNode,
}
```

---

## 3. ubby-back Changes (Python / FastAPI)

### 3.1 Entity Updates

**Modified file:** `src/domain/entities/mcp_server.py`

Add two new config dataclasses:

```python
@dataclass
class McpToolParameter:
    type: str          # 'string', 'number', 'boolean', 'integer'
    description: str

@dataclass
class McpAiWorkerToolConfig:
    model: str
    system_prompt: str
    api_key: str
    api_url: str = "https://openrouter.ai/api/v1"
    parameters: dict[str, McpToolParameter] | None = None

@dataclass
class McpDatabaseToolConfig:
    connection_string: str
    query_template: str
    read_only: bool = True
    parameters: dict[str, McpToolParameter] | None = None
```

Update `McpToolStrategy.type` to accept new values:

```python
@dataclass
class McpToolStrategy:
    type: str   # 'http' | 'ai-worker' | 'database'
    config: McpHttpToolConfig | McpAiWorkerToolConfig | McpDatabaseToolConfig
```

### 3.2 Config Serialization

**Modified file:** `src/infrastructure/repositories/mcp_server_config_extractor.py` (or equivalent serializer)

Update the config extraction/serialization logic to handle the new strategy types. When building the config dict to send to ubby-mcp-api:

- For `ai-worker`: serialize `model`, `systemPrompt` (camelCase for API), `apiKey`, `apiUrl`, and `parameters`.
- For `database`: serialize `connectionString` (camelCase), `queryTemplate`, `readOnly`, and `parameters`.

**REQ-025:** The serializer SHALL convert Python snake_case field names to camelCase when sending configs to ubby-mcp-api.

### 3.3 No New Routes Needed

The existing deploy flow (`POST /mcp/deploy/{project_id}`) already passes the full tool config through to ubby-mcp-api. No new routes are needed in ubby-back for V1. The ubby-back acts as a pass-through for the tool strategy config.

---

## 4. Files to Modify Per Repository

### ubby-mcp-api (NestJS / TypeScript)

| File (exact path)                                              | Change                                                |
|----------------------------------------------------------------|-------------------------------------------------------|
| `src/domain/entities/mcp-tool.entity.ts`                       | Add `AiWorkerStrategyConfig`, `DatabaseStrategyConfig`, widen `ToolStrategy` union |
| `src/infrastructure/dtos/create-mcp-server.dto.ts`             | Add Zod schemas for new strategy types, update discriminated union |
| `src/infrastructure/tools/ai-worker-strategy.adapter.ts`       | **NEW** -- AI Worker strategy adapter                  |
| `src/infrastructure/tools/database-strategy.adapter.ts`        | **NEW** -- Database strategy adapter                   |
| `src/infrastructure/dependencies.ts`                           | Register `ai-worker` and `database` strategies in the Map |
| `package.json`                                                 | Add `pg` and `@types/pg` dependencies                  |
| `test/unit/ai-worker-strategy.adapter.spec.ts`                 | **NEW** -- Unit tests for AI Worker adapter            |
| `test/unit/database-strategy.adapter.spec.ts`                  | **NEW** -- Unit tests for Database adapter             |
| `test/unit/create-mcp-server.dto.spec.ts`                      | Update to cover new strategy type validation           |

### ubby-front (React / TypeScript / Vite)

| File (exact path)                                              | Change                                                |
|----------------------------------------------------------------|-------------------------------------------------------|
| `src/domain/entities/AiWorkerNode.ts`                          | **NEW** -- Zod schema and type for AI Worker node data |
| `src/domain/entities/DatabaseNode.ts`                          | **NEW** -- Zod schema and type for Database node data  |
| `src/domain/entities/index.ts`                                 | Export new entities                                    |
| `src/application/components/nodes/AiWorkerNode.tsx`            | **NEW** -- ReactFlow custom node for AI Worker         |
| `src/application/components/nodes/DatabaseNode.tsx`            | **NEW** -- ReactFlow custom node for Database          |
| `src/application/components/config/AiWorkerConfig.tsx`         | **NEW** -- Config panel for AI Worker                  |
| `src/application/components/config/DatabaseConfig.tsx`         | **NEW** -- Config panel for Database                   |
| `src/application/components/toolbox/ToolboxItems.ts`           | Add AI Worker and Database items                       |
| `src/application/components/config/ConfigBar.tsx`              | Handle `ai-worker` and `database` node types           |
| `src/application/utils/nodeFactory.ts`                         | Add factory cases for new node types                   |
| `src/application/components/flow/FlowCanvas.tsx`               | Register new node types in `nodeTypes`                 |
| `src/test/domain/entities/AiWorkerNode.test.ts`                | **NEW** -- Zod schema tests                            |
| `src/test/domain/entities/DatabaseNode.test.ts`                | **NEW** -- Zod schema tests                            |
| `src/test/application/components/nodes/AiWorkerNode.test.tsx`  | **NEW** -- Node component tests                        |
| `src/test/application/components/nodes/DatabaseNode.test.tsx`  | **NEW** -- Node component tests                        |
| `src/test/application/components/config/AiWorkerConfig.test.tsx`| **NEW** -- Config panel tests                         |
| `src/test/application/components/config/DatabaseConfig.test.tsx`| **NEW** -- Config panel tests                         |

### ubby-back (Python / FastAPI)

| File (exact path)                                              | Change                                                |
|----------------------------------------------------------------|-------------------------------------------------------|
| `src/domain/entities/mcp_server.py`                            | Add `McpToolParameter`, `McpAiWorkerToolConfig`, `McpDatabaseToolConfig`, update `McpToolStrategy` |
| `src/infrastructure/repositories/mcp_server_config_extractor.py`| Handle new strategy types in serialization            |
| `tests/unit/test_mcp_server_entity.py`                         | Add tests for new entity types                         |
| `tests/unit/test_mcp_server_config_extractor.py`               | Add tests for new strategy serialization               |

---

## 5. Acceptance Criteria

### Happy Path

- [ ] Given a tool with strategy type `ai-worker`, model `google/gemini-2.5-pro`, and a system prompt "You are a translator", when the MCP client calls the tool with `{ prompt: "Translate 'hello' to French" }`, then the tool returns the LLM's text response (e.g., "Bonjour").
- [ ] Given a tool with strategy type `database`, connection string pointing to a running PostgreSQL instance, and query template `SELECT name, email FROM users WHERE id = :userId`, when the MCP client calls the tool with `{ userId: "123" }`, then the tool returns the matching rows as a JSON array string.
- [ ] Given a database tool with `readOnly: true`, when the query executes, then the SQL runs inside a `BEGIN READ ONLY` transaction.
- [ ] Given the toolbox in the frontend builder, when the user drags an "AI Worker" item onto the canvas, then a purple AI Worker node appears with default empty configuration.
- [ ] Given the toolbox in the frontend builder, when the user drags a "Database" item onto the canvas, then a green Database node appears with default empty configuration and readOnly toggled on.
- [ ] Given an AI Worker node is selected, when the user opens the config panel, then fields for model, system prompt, API key, API URL, and description are displayed.
- [ ] Given a Database node is selected and the user types `SELECT * FROM orders WHERE status = :status AND customer_id = :customerId` in the query template, then the parameters section auto-populates with `status` and `customerId` rows.
- [ ] Given a complete AI Worker configuration in the builder, when the user deploys the MCP server, then ubby-back serializes the config correctly (camelCase) and ubby-mcp-api registers the strategy and the tool is callable.
- [ ] Given a complete Database configuration in the builder, when the user deploys the MCP server, then the tool is callable and returns query results.

### Error Cases

- [ ] Given an AI Worker tool with an invalid API key, when the tool is called, then the error message includes the HTTP status (e.g., 401) and model name but does NOT include the API key.
- [ ] Given an AI Worker tool with an unreachable `apiUrl`, when the tool is called, then a network error is returned with a descriptive message.
- [ ] Given an AI Worker tool call with no `prompt` argument, when the tool is called, then it throws immediately with "Missing required parameter: prompt" before making any API call.
- [ ] Given a Database tool with an invalid connection string, when the tool is called, then the error message does NOT include the full connection string credentials.
- [ ] Given a Database tool with query `SELECT * FROM users WHERE id = :userId` and the call provides `{ name: "John" }` (missing `userId`), then the adapter throws with "Missing required parameter: userId".
- [ ] Given a Database tool call that provides `{ userId: "123", extraParam: "hack" }` where `extraParam` is not in the template, then the adapter throws with "Unexpected parameter: extraParam".
- [ ] Given the DTO receives a strategy type `ai-worker` with an empty `model` field, then validation rejects the request with a 400 error.
- [ ] Given the DTO receives a strategy type `database` with an empty `connectionString`, then validation rejects the request with a 400 error.

### Edge Cases

- [ ] Given a Database query template with the same named parameter used twice (`SELECT * FROM t WHERE a = :id OR b = :id`), then the rewriter produces `SELECT * FROM t WHERE a = $1 OR b = $1` (single positional parameter, single value).
- [ ] Given a Database query template with no named parameters (`SELECT count(*) FROM users`), then the tool executes with an empty values array and returns the count.
- [ ] Given an AI Worker tool where the LLM returns an empty string as content, then the tool returns an empty string (not null, not an error).
- [ ] Given a Database query that returns zero rows, then the tool returns `"[]"` (empty JSON array string).
- [ ] Given a Database tool with `readOnly: false`, then the query runs without the read-only transaction wrapper, and mutations (INSERT, UPDATE, DELETE) succeed.
- [ ] Given the OpenRouter API returns a response with no `choices` array or empty `choices`, then the adapter throws a descriptive error ("No response generated by model").
- [ ] Given a Database tool parameter declared as `type: 'integer'` and the MCP client passes `{ userId: "42" }`, then the adapter coerces `"42"` to `42` before binding to the SQL query.
- [ ] Given a Database tool parameter declared as `type: 'integer'` and the MCP client passes `{ userId: "not-a-number" }`, then the adapter throws a coercion error before executing the query.

---

## 6. Out of Scope

- **Other database engines** (MySQL, SQLite, MongoDB). V1 is PostgreSQL only.
- **Connection pooling configuration.** The adapter creates a single client per execution. Pooling optimization is a future concern.
- **Streaming LLM responses.** The AI Worker returns the full response after completion. No SSE/streaming in V1.
- **Model validation against OpenRouter's model list.** The model field is free-text; invalid models will produce an API error at call time.
- **Query builder / visual query editor.** The query template is plain text SQL.
- **Saved API keys / secrets management.** API keys and connection strings are stored as-is in the tool config. Encryption at rest is a future concern.
- **Rate limiting on AI Worker calls.** No per-tool rate limiting in V1.
- **Other strategy types beyond HTTP, AI Worker, and Database.**

---

## 7. Implementation Order

Strict sequential order across repositories:

### Phase 1: ubby-mcp-api (backend strategies)

1. Update `src/domain/entities/mcp-tool.entity.ts` -- add `AiWorkerStrategyConfig`, `DatabaseStrategyConfig`, widen `ToolStrategy` union.
2. Update `src/infrastructure/dtos/create-mcp-server.dto.ts` -- add Zod schemas, update discriminated union.
3. Add `pg` and `@types/pg` to `package.json`.
4. Create `src/infrastructure/tools/ai-worker-strategy.adapter.ts`.
5. Create `src/infrastructure/tools/database-strategy.adapter.ts`.
6. Update `src/infrastructure/dependencies.ts` -- register both new strategies.
7. Write unit tests: `test/unit/ai-worker-strategy.adapter.spec.ts`, `test/unit/database-strategy.adapter.spec.ts`, update `test/unit/create-mcp-server.dto.spec.ts`.

### Phase 2: ubby-back (entity + serialization)

8. Update `src/domain/entities/mcp_server.py` -- add new config dataclasses, update `McpToolStrategy`.
9. Update `src/infrastructure/repositories/mcp_server_config_extractor.py` -- handle new strategy serialization.
10. Write unit tests: `tests/unit/test_mcp_server_entity.py`, `tests/unit/test_mcp_server_config_extractor.py`.

### Phase 3: ubby-front (UI)

11. Create `src/domain/entities/AiWorkerNode.ts` and `src/domain/entities/DatabaseNode.ts`.
12. Export from `src/domain/entities/index.ts`.
13. Create `src/application/components/nodes/AiWorkerNode.tsx` and `DatabaseNode.tsx`.
14. Create `src/application/components/config/AiWorkerConfig.tsx` and `DatabaseConfig.tsx`.
15. Add items to `src/application/components/toolbox/ToolboxItems.ts`.
16. Update `src/application/components/config/ConfigBar.tsx` -- add cases for new types.
17. Update `src/application/utils/nodeFactory.ts` -- add factory cases.
18. Update `src/application/components/flow/FlowCanvas.tsx` -- register node types.
19. Write tests for new entities, nodes, and config panels.

---

## 8. Open Questions

None. All decisions have been confirmed by the PO.

---

## 9. Technical Notes

- **Node-postgres connection strategy:** Each `DatabaseStrategyAdapter.execute()` call creates a new `pg.Client`, connects, runs the query, and disconnects. This is intentionally simple for V1. If performance becomes an issue, a connection pool (`pg.Pool`) per unique connection string can be introduced later, but this adds complexity around pool lifecycle management.
- **Named parameter rewriting:** The regex `/:(\w+)/g` will match parameters inside SQL string literals (e.g., `WHERE name = ':notAParam'`). For V1, this is an accepted limitation. Users should not put colons inside string literals in their templates. A more sophisticated SQL parser is out of scope.
- **OpenRouter API compatibility:** OpenRouter uses the OpenAI-compatible chat completions format. The adapter is intentionally simple -- it does not handle function calling, tool use, or multi-turn conversations. It sends a single system + user message pair and returns the first choice's content.
- **Security note on stored credentials:** API keys and connection strings are stored in plain text in the tool config (same as HTTP strategy configs with auth headers). This is consistent with the current approach. A future ticket should address encryption at rest for sensitive config values across all strategy types.
- **`readOnly` enforcement:** The `BEGIN READ ONLY` transaction is enforced at the PostgreSQL protocol level. If a user sets `readOnly: false`, the adapter allows mutations. The UI should clearly indicate this with a warning label next to the toggle.
- **Parameter type coercion:** The database adapter receives all `args` values as strings from MCP. For `integer` and `number` typed parameters, the adapter should coerce the string to a number before binding. For `boolean`, coerce `"true"`/`"false"` strings. This prevents PostgreSQL type mismatch errors.
