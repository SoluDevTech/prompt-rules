# UB-24: Log Categorization, Filtering, and Canvas Integration

## Problem Statement

MCP server logs are currently dumped into a single undifferentiated stream. Developers working on Ubby projects cannot quickly isolate platform events (server start/stop, auth), MCP protocol exchanges, or individual tool call traces. There is no way to access logs contextually from the visual canvas where servers and tools are represented as nodes.

### Why it matters

Debugging a failing tool call today means scrolling through an interleaved stream of lifecycle events, auth failures, HTTP requests, and MCP protocol messages. This slows down incident response and makes the log panel nearly useless once a server has been running for a while.

### Current situation

- All log types are mixed in a single list per server.
- Ring buffer holds only 50 entries per server -- recent history is lost quickly.
- No server-side filtering: the full buffer is returned on every poll.
- Frontend polls every 60 seconds -- too slow for live debugging.
- Canvas nodes (RootNode, HttpNode) have no connection to logs.

## Proposed Solution

### Overview

Add a `category` dimension to every log entry (platform | mcp | tool), expose filtering through query parameters on the existing API, and build tabbed filtering plus canvas-integrated log access in the frontend. Keep the terminal aesthetic (Option A); do not redesign the log panel.

### User Stories

- As a developer, I want to filter logs by category (platform / mcp / tool) so that I can focus on the type of event I am investigating.
- As a developer, I want to see a badge on canvas nodes showing log counts so that I notice activity without opening the log panel.
- As a developer, I want to click a node badge to open the log panel pre-filtered to that node's category so that I jump straight to relevant entries.
- As a developer, I want to search logs by text so that I can find a specific error message or tool name quickly.
- As a developer, I want to expand a log entry to see its full structured payload so that I can inspect request/response details.

---

## 1. Data Model Changes (ubby-mcp-api)

### 1.1 LogEntry Entity

**File:** `src/domain/entities/log-entry.entity.ts` (or wherever LogEntry is defined)

Add two new fields to the LogEntry type/interface:

```typescript
// New fields to add
category: 'platform' | 'mcp' | 'tool';
toolName?: string; // populated only when category === 'tool'
```

**Mapping rules** (derive `category` from existing `StructuredLogType`):

| StructuredLogType   | category   | toolName        |
|---------------------|------------|-----------------|
| server_lifecycle    | platform   | undefined       |
| auth_failure        | platform   | undefined       |
| mcp_tool_call       | mcp        | undefined       |
| http_request        | tool       | extracted from request context |

The `toolName` field is populated only for `http_request` entries, extracted from the tool configuration that triggered the HTTP call. The value should match the tool's `name` as declared in the MCP server manifest.

### 1.2 Ring Buffer Size

**File:** wherever the ring buffer size constant is defined (likely in the log storage service or a constants file)

Change the maximum entries per server from 50 to 200.

**REQ-001:** The ring buffer per MCP server instance SHALL hold a maximum of 200 log entries (up from 50).

### 1.3 Log Creation

**File:** `src/adapters/mcp-use.adapter.ts` (and any other call sites of `logDebug` / log creation)

Every code path that creates a LogEntry must set the `category` field based on the mapping table above. The `toolName` field must be set when the log entry is associated with a specific tool's HTTP request.

**REQ-002:** Every newly created LogEntry SHALL include a `category` field derived from its `StructuredLogType` using the mapping table.

**REQ-003:** LogEntry creation for `http_request` type SHALL include the `toolName` field when the originating tool can be identified from context.

---

## 2. API Changes

### 2.1 ubby-mcp-api

**File:** the controller/router handling `GET /mcp/:id/logs`

Add optional query parameters:

| Parameter  | Type   | Values                        | Default | Description                          |
|------------|--------|-------------------------------|---------|--------------------------------------|
| category   | string | `platform`, `mcp`, `tool`     | (none)  | Filter by log category               |
| toolName   | string | any tool name                 | (none)  | Filter by tool name (implies category=tool) |

**Behavior:**
- No query params: return all logs (current behavior preserved).
- `?category=platform`: return only entries with `category === 'platform'`.
- `?toolName=myTool`: return only entries with `toolName === 'myTool'` (implicitly `category === 'tool'`).
- `?category=tool&toolName=myTool`: same as above, explicit.
- `?category=mcp&toolName=myTool`: return empty array (mcp category entries never have toolName). This is not an error.

**REQ-004:** `GET /mcp/:id/logs` SHALL accept optional query parameters `category` and `toolName` for server-side filtering.

**REQ-005:** When both `category` and `toolName` are provided, the filter SHALL be an AND conjunction.

**REQ-006:** Invalid category values SHALL return a 400 Bad Request with a descriptive error message.

**Validation:** Add DTO validation for the query parameters (class-validator or equivalent per project conventions).

### 2.2 ubby-back

**File:** the controller/service handling `GET /mcp/deploy/{project_id}/logs`

This endpoint proxies to ubby-mcp-api. It currently aggregates logs from all servers of a project.

**Changes:**
- Forward `category` and `toolName` query parameters to each underlying ubby-mcp-api call.
- No additional business logic; pure pass-through of filters.

**REQ-007:** `GET /mcp/deploy/{project_id}/logs` SHALL forward `category` and `toolName` query parameters to the upstream ubby-mcp-api requests.

---

## 3. Frontend Changes (ubby-front)

### 3.1 Log Panel Tabs

**File:** `src/components/Logs.tsx` (or the component rendering the log panel)

Add a tab bar above the terminal-style log list:

```
[ All ] [ Platform ] [ MCP ] [ Tools ]
```

- "All" is selected by default and shows every log entry (current behavior).
- Selecting a tab calls the API with the corresponding `category` parameter.
- Active tab is visually highlighted (underline or background, consistent with existing UI tokens).
- Tab switch triggers an immediate API call; do not rely on next polling cycle.

**REQ-008:** The log panel SHALL display tabs for All, Platform, MCP, and Tools categories.

**REQ-009:** Selecting a tab SHALL immediately fetch logs filtered by the corresponding category.

### 3.2 Text Search

**File:** `src/components/Logs.tsx`

Add a search input field between the tabs and the log list.

- Client-side filtering on the currently loaded log entries.
- Matches against: log message text, toolName, StructuredLogType, timestamp.
- Case-insensitive substring match.
- Debounced input (300ms) to avoid excessive re-renders.
- Clear button (X) to reset search.

**REQ-010:** The log panel SHALL include a text search field that filters displayed entries client-side.

**REQ-011:** Search SHALL be case-insensitive and match against message, toolName, type, and timestamp fields.

### 3.3 Canvas Node Badges

**Files:**
- `src/components/canvas/RootNode.tsx` (or equivalent)
- `src/components/canvas/HttpNode.tsx` (or equivalent)

Add a small circular badge to each node:

| Node      | Badge shows count of | Category filter on click |
|-----------|----------------------|--------------------------|
| RootNode  | `mcp` category logs  | Opens log panel with MCP tab active |
| HttpNode  | `tool` category logs | Opens log panel with Tools tab active, toolName pre-set |

**Badge behavior:**
- Badge displays total count of logs in that category (from the most recent poll).
- If count is 0, the badge is hidden.
- If count exceeds 99, display "99+".
- Badge uses a neutral color (not red/orange) -- these are informational, not error indicators. If specific error-level entries exist in the category, the badge turns orange.
- Badge count resets concept: since logs are a ring buffer, the badge always shows the total count in that category, not "unread" count. Keep it simple.

**REQ-012:** RootNode SHALL display a badge with the count of `mcp` category log entries.

**REQ-013:** HttpNode SHALL display a badge with the count of `tool` category log entries for the tool it represents.

**REQ-014:** Clicking a badge SHALL open the log panel with the corresponding category tab pre-selected.

**REQ-015:** HttpNode badge click SHALL also pre-fill the toolName filter matching that node's tool.

### 3.4 Polling Interval

**File:** wherever the polling interval constant is set (likely in the Logs component or a hooks/config file)

Change polling interval from 60 seconds to 10 seconds.

**REQ-016:** Log polling interval SHALL be 10 seconds (down from 60 seconds).

**Note:** This is a 6x increase in API call frequency. Acceptable because:
- Logs endpoint is lightweight (in-memory ring buffer, no DB).
- Filtering server-side reduces payload size.
- Only active log panel polls; canvas badge counts can use a lighter summary endpoint or piggyback on existing polling.

### 3.5 Expandable Log Entries

**File:** `src/components/Logs.tsx` (or a new `LogEntry.tsx` sub-component)

Each log line in the terminal view becomes expandable:

- **Collapsed (default):** timestamp | category icon | type | one-line message (current rendering, preserved).
- **Expanded (on click):** full structured JSON payload displayed in a code block below the collapsed line. Use the existing JSON parsing that Logs.tsx already performs, but show the complete object instead of the summary.
- Only one entry expanded at a time (accordion behavior) OR multiple (your call during implementation, but accordion is recommended for the terminal feel).

**REQ-017:** Each log entry SHALL be expandable to reveal its full structured payload.

**REQ-018:** Collapsed view SHALL preserve the current rendering format (timestamp, icon, type, message).

---

## 4. Files to Modify Per Repository

### ubby-mcp-api

| File (approximate path)                              | Change                                              |
|------------------------------------------------------|-----------------------------------------------------|
| `src/domain/entities/log-entry.entity.ts`            | Add `category` and `toolName` fields                |
| `src/domain/types/structured-log-type.ts` (if separate) | Add `LogCategory` type                           |
| Ring buffer config (constants or service file)        | Change max size 50 -> 200                           |
| `src/adapters/mcp-use.adapter.ts`                    | Set `category` and `toolName` on every log creation |
| Log storage service (in-memory store)                 | Add filtering logic by category/toolName            |
| Logs controller (`GET /mcp/:id/logs`)                 | Accept & validate query params, pass to service     |
| DTO for logs query (new file or extend existing)      | Validate `category` enum, `toolName` string         |
| Unit tests for log filtering                          | New test file or extend existing                    |

### ubby-back

| File (approximate path)                              | Change                                              |
|------------------------------------------------------|-----------------------------------------------------|
| MCP logs proxy controller                             | Forward `category` and `toolName` query params      |
| MCP logs proxy service                                | Pass query params to upstream API call              |
| Unit tests for proxy                                  | Verify query params are forwarded                   |

### ubby-front

| File (approximate path)                              | Change                                              |
|------------------------------------------------------|-----------------------------------------------------|
| `src/components/Logs.tsx`                             | Add tabs, search, expandable entries                |
| `src/components/Logs.tsx` or `src/hooks/useLogs.ts`  | Update API call to include query params, 10s poll   |
| `src/components/canvas/RootNode.tsx`                  | Add badge with mcp log count, click handler         |
| `src/components/canvas/HttpNode.tsx`                  | Add badge with tool log count, click handler        |
| `src/api/mcp.ts` (or equivalent API client)          | Update logs endpoint call to accept filter params   |
| Log-related types (`src/types/` or co-located)        | Add `LogCategory`, update `LogEntry` type           |
| New: `src/components/LogEntry.tsx` (optional)         | Expandable log entry sub-component                  |

---

## 5. Acceptance Criteria

### Happy Path

- [ ] Given a server with mixed log types, when I select the "Platform" tab, then only server_lifecycle and auth_failure entries are displayed.
- [ ] Given a server with tool logs, when I select the "Tools" tab, then only http_request entries are displayed.
- [ ] Given the "Tools" tab is active, when I type a tool name in the search field, then only logs matching that tool name are shown.
- [ ] Given a RootNode on the canvas with 5 MCP log entries, when I look at the node, then I see a badge showing "5".
- [ ] Given an HttpNode badge showing "3", when I click the badge, then the log panel opens with the Tools tab active and that node's tool pre-filtered.
- [ ] Given the log panel is open, when 10 seconds pass, then the log list refreshes with the latest entries.
- [ ] Given a collapsed log entry, when I click on it, then it expands to show the full structured JSON payload.
- [ ] Given the API receives `?category=platform`, when logs are returned, then only entries with category "platform" are in the response.

### Error Cases

- [ ] Given an invalid category value (e.g., `?category=invalid`), when the API is called, then it returns 400 Bad Request with a descriptive message.
- [ ] Given the ubby-mcp-api is unreachable, when ubby-back proxies a logs request, then it returns an appropriate error (503 or similar) and the frontend displays a non-blocking error message.
- [ ] Given a toolName that does not exist in any log, when filtering by that toolName, then an empty log list is returned (not an error).

### Edge Cases

- [ ] Given the ring buffer is full (200 entries), when a new log is added, then the oldest entry is evicted and the new one is added (FIFO preserved).
- [ ] Given a server with 0 logs in a category, when that tab is selected, then an empty state message is displayed ("No platform logs yet" or similar).
- [ ] Given a node whose tool has 0 logs, then no badge is displayed on that node (not a badge showing "0").
- [ ] Given logs contain special characters or very long messages, when expanded, then the JSON is displayed correctly without breaking the layout.
- [ ] Given more than 99 logs in a category, when the badge is rendered, then it displays "99+".
- [ ] Given the user switches tabs rapidly, when multiple API calls are in flight, then only the result of the most recent call is displayed (race condition handling -- cancel or ignore stale responses).
- [ ] Given polling is active on filtered view, when new logs arrive that do not match the filter, then the displayed list does not change unexpectedly.

---

## 6. Out of Scope

- **Log persistence / database storage.** Logs remain in-memory ring buffers. Persistence is a future consideration.
- **Log export** (download, copy-to-clipboard of full log). Not in this ticket.
- **Log levels / severity filtering** (info, warn, error). Not in this ticket. The existing type-based coloring in the frontend is preserved but no new severity filter is added.
- **WebSocket / SSE for real-time streaming.** Polling at 10s is the mechanism. Real-time push is a future enhancement.
- **Redesign of the log panel UI.** We keep the terminal aesthetic (Option A). No layout overhaul.
- **Aggregated cross-server log view changes.** The ubby-back aggregation endpoint adds filter forwarding only; no new aggregation logic.
- **Log rotation policies or TTL.** The ring buffer eviction is sufficient for now.

---

## 7. Implementation Order

Strict sequential order across repositories:

### Phase 1: ubby-mcp-api (backend data model + API)

1. Add `LogCategory` type and update `LogEntry` entity with `category` and `toolName` fields.
2. Update ring buffer max size to 200.
3. Update all log creation call sites to set `category` (and `toolName` where applicable).
4. Add filtering logic in the log storage/service layer.
5. Update the `GET /mcp/:id/logs` endpoint to accept and validate query params.
6. Write unit tests for: category mapping, filtering, ring buffer size, invalid params.

### Phase 2: ubby-back (proxy layer)

7. Update the logs proxy controller/service to forward `category` and `toolName` query params.
8. Write unit tests verifying param forwarding.

### Phase 3: ubby-front (UI)

9. Update TypeScript types to include `category` and `toolName` on LogEntry.
10. Update the API client to pass filter parameters.
11. Implement tab bar with category filtering.
12. Implement text search.
13. Change polling interval to 10 seconds.
14. Implement expandable log entries.
15. Add badges to RootNode and HttpNode.
16. Add click-to-open-filtered behavior on badges.
17. Handle edge cases: race conditions on tab switch, empty states, badge overflow.

---

## 8. Open Questions

- [ ] **toolName extraction:** In `mcp-use.adapter.ts`, is the tool name always available in context when creating an `http_request` log? If not, what fallback should be used? (Empty string? "unknown"?)
- [ ] **Badge count source:** Should canvas badges make a separate lightweight API call (e.g., `GET /mcp/:id/logs/counts`) to avoid fetching full log payloads just for counts? Or reuse the polling data from the log panel?
- [ ] **Multiple servers per project:** When ubby-back aggregates logs from multiple servers, should the badge on a RootNode show counts only for that specific server, or aggregated? (Recommendation: per-server, since each RootNode represents one server.)

---

## 9. Technical Notes

- The `category` field is derived, not user-set. It is always computed from `StructuredLogType` at creation time. There is no API to change it after the fact.
- Filtering is done in-memory on the ring buffer. With a max of 200 entries per server, linear scan is acceptable. No indexing needed.
- The frontend should use `AbortController` to cancel in-flight requests when the user switches tabs, preventing race conditions.
- The polling interval change (60s to 10s) should be behind a configuration constant, not hardcoded in the component, to allow easy adjustment later.
- Badge counts on canvas nodes should be derived from the same polling data used by the log panel when it is open, to avoid duplicate API calls. When the log panel is closed, a lightweight poll (or the existing project status poll) should provide counts.
