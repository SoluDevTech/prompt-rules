# AI-Driven Development Workflow - Prompt Rules

A comprehensive multi-tool AI coding assistant configuration system that standardizes software development workflows across OpenCode, Claude Code, and GitHub Copilot.

## Overview

This repository provides unified AI agent configurations and prompt templates designed to:

- **Standardize development workflows** across multiple AI coding assistants
- **Enforce architectural best practices** (Hexagonal Architecture, SOLID, TDD)
- **Provide specialized agents** for each phase of software development
- **Integrate external tools** via MCP (Model Context Protocol)
- **Support multiple technology stacks** (FastAPI, NestJS, React, K3s)

## Supported AI Tools

| Tool | Configuration Location | Status |
|------|----------------------|--------|
| [OpenCode AI](https://opencode.ai) | `ai-driven/opencode/` | Full support |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `ai-driven/claude/` | Full support |
| [GitHub Copilot](https://github.com/features/copilot) | `ai-driven/copilot/` | Full support |

## Repository Structure

```
prompt-rules/
├── README.md                           # This file
├── .gitignore                          # Git ignore rules
└── ai-driven/                          # Main configuration directory
    ├── agents/                         # Shared agent definitions (source of truth)
    │   ├── product-owner.md
    │   ├── test-writer-python.md
    │   ├── test-writer-nestjs.md
    │   ├── test-writer-react.md
    │   ├── fastapi-hexagonal.md
    │   ├── nestjs-hexagonal.md
    │   ├── react-hexagonal.md
    │   ├── code-reviewer.md
    │   ├── code-simplifier.md
    │   ├── documentation-writer.md
    │   ├── tester-qa.md
    │   └── k3s-devops.md
    │
    ├── skills/                         # Shared skill definitions (source of truth)
    │   ├── sonarfix/
    │   ├── trivyfix/
    │   ├── feature-implementation/
    │   └── frontend-design/
    │
    ├── claude/                         # Claude Code configuration
    │   ├── .claude.example.json        # MCP server configuration template
    │   └── .claude/
    │       ├── CLAUDE.md               # Main workflow instructions
    │       ├── settings.local.json     # Local settings (git-ignored)
    │       ├── agents/                 # Agent prompt files (copy of shared agents)
    │       └── skills/                 # Claude-specific skills
    │           ├── sonarfix/
    │           ├── trivyfix/
    │           ├── feature-implementation/
    │           └── frontend-design/
    │
    ├── copilot/                        # GitHub Copilot configuration
    │   ├── mcp.json                    # MCP server configuration
    │   └── .github/
    │       ├── copilot-instructions.md # Main workflow instructions
    │       ├── agents/                 # Agent prompt files (copy of shared agents)
    │       └── skills/                 # Copilot-specific skills
    │           ├── sonarfix/
    │           ├── trivyfix/
    │           ├── feature-implementation/
    │           └── frontend-design/
    │
    ├── opencode/                       # OpenCode AI configuration
    │   └── .opencode/
    │       ├── opencode.example.json   # Agent registry & MCP config template
    │       ├── AGENTS.md               # Workflow documentation
    │       ├── package.json            # Plugin dependencies
    │       ├── agents/                 # Agent prompt files (copy of shared agents)
    │       └── skills/                 # OpenCode-specific skills
    │           ├── sonarfix/
    │           ├── trivyfix/
    │           ├── feature-implementation/
    │           └── frontend-design/
    │
    └── mcp/                            # MCP server infrastructure
        ├── docker-compose.yml          # Service definitions
        ├── env.atlassian.example       # Atlassian env template
        └── env.sonar.example           # SonarQube env template
```

## Specialized Agents

The system includes 12 specialized AI agents, each designed for a specific phase of development:

| Agent | Purpose | Model | Permissions |
|-------|---------|-------|-------------|
| `product-owner` | Requirements analysis, acceptance criteria, user stories | Claude Opus | Read-only |
| `test-writer-python` | TDD unit tests with pytest, pytest-asyncio, test doubles (fakes) | Claude Opus | Write, Edit |
| `test-writer-nestjs` | Unit/integration tests with Jest, Supertest for NestJS | Claude Opus | Write, Edit |
| `test-writer-react` | Unit/integration tests with Vitest, React Testing Library | Claude Opus | Write, Edit |
| `fastapi-hexagonal` | FastAPI backend with hexagonal architecture | Claude Opus | Write, Edit, Bash |
| `nestjs-hexagonal` | NestJS backend with hexagonal architecture | Claude Opus | Write, Edit, Bash |
| `react-hexagonal` | React frontend with hexagonal architecture | Claude Opus | Write, Edit, Bash |
| `code-reviewer` | Implementation planning and code review | Claude Opus | Read-only |
| `code-simplifier` | Code refactoring for clarity/maintainability | Claude Opus | Edit only |
| `documentation-writer` | README and API documentation generation | Claude Opus | Write, Edit |
| `tester-qa` | Manual and API testing verification | Claude Opus | Edit only |
| `k3s-devops` | K3s/Flux CD infrastructure management (GitOps) | Claude Opus | Write, Edit, Bash |

> **Note:** All agents declare `model: opus` in their frontmatter. Tools like OpenCode can override the model per-agent in their configuration (e.g., `opencode.json`).

## Development Workflow

All agents work together in a structured 5-phase development workflow:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AI-DRIVEN DEVELOPMENT WORKFLOW                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  PHASE 1: REQUIREMENTS                                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ product-owner (Claude Opus)                                          │    │
│  │ - Clarify requirements with stakeholders                             │    │
│  │ - Define acceptance criteria                                         │    │
│  │ - Create user stories                                                │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│                                    ▼                                         │
│  PHASE 2: TEST-FIRST DEVELOPMENT                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ test-writer-* (Claude Opus)                                          │    │
│  │ - Variants: test-writer-python, test-writer-nestjs, test-writer-react│    │
│  │ - Write failing unit tests (TDD)                                     │    │
│  │ - Define test doubles (fakes)                                        │    │
│  │ - Establish coverage targets (80%+)                                  │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│                                    ▼                                         │
│  PHASE 3: IMPLEMENTATION                                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ fastapi-hexagonal / nestjs-hexagonal / react-hexagonal               │    │
│  │ - Implement code following hexagonal architecture                    │    │
│  │ - Ensure all tests pass                                              │    │
│  │ - Follow SOLID principles                                            │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│                                    ▼                                         │
│  PHASE 4: QUALITY ASSURANCE                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ code-reviewer → code-simplifier                                      │    │
│  │ - Review for bugs, security issues, architecture compliance          │    │
│  │ - Refactor for clarity without changing functionality                │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│                                    ▼                                         │
│  PHASE 5: DOCUMENTATION & VERIFICATION                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ documentation-writer → tester-qa                                     │    │
│  │ - Update README, API documentation                                   │    │
│  │ - Manual/API testing verification                                    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  INFRASTRUCTURE (on-demand)                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ k3s-devops (Claude Opus)                                              │    │
│  │ - Kubernetes/GitOps infrastructure changes                           │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## End-to-End CI/CD Integration

The AI agents integrate seamlessly with your existing CI/CD pipeline. Here's the complete development cycle:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     END-TO-END DEVELOPMENT CYCLE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐                                                            │
│  │    JIRA      │  User writes tickets with requirements                     │
│  │   Tickets    │                                                            │
│  └──────┬───────┘                                                            │
│         │                                                                    │
│         │ MCP Atlassian                                                      │
│         ▼                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                     AI CODING AGENT                                   │   │
│  │                 (Claude Code / OpenCode / Copilot)                    │   │
│  │                                                                       │   │
│  │  Reads ticket → Orchestrates sub-agents automatically:                │   │
│  │                                                                       │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐     │   │
│  │  │  product-   │→│ test-       │→│ [stack]-    │→│ code-       │     │   │
│  │  │  owner      │ │ writer      │ │ hexagonal   │ │ reviewer    │     │   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘     │   │
│  │                                                                       │   │
│  └──────────────────────────────────┬───────────────────────────────────┘   │
│                                     │                                        │
│                                     ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                      USER PUSHES TO BRANCH                            │   │
│  └──────────────────────────────────┬───────────────────────────────────┘   │
│                                     │                                        │
│                                     ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                         CI PIPELINE                                   │   │
│  │                                                                       │   │
│  │  - Build & test                                                       │   │
│  │  - Static code analysis                                               │   │
│  │  - Security scanning                                                  │   │
│  │  - Coverage reports                                                   │   │
│  └──────────────────────────────────┬───────────────────────────────────┘   │
│                                     │                                        │
│                                     ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                     AI AGENT FIXES ISSUES                             │   │
│  │                                                                       │   │
│  │  User: "/sonarfix" or "/trivyfix"                                     │   │
│  │                                                                       │   │
│  │  Agent runs remediation skills → Fixes issues automatically           │   │
│  └──────────────────────────────────┬───────────────────────────────────┘   │
│                                     │                                        │
│                                     ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                USER PUSHES → CI → ...                                 │   │
│  │                                                                       │   │
│  │            (Loop until quality gate passes ✓)                         │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Quick Start

```bash
# 1. Start MCP services
cd ai-driven/mcp
cp env.atlassian.example .env.atlassian  # Configure your Jira credentials
docker-compose up -d

# 2. In your AI coding tool, just say:
"Implement ticket PROJ-123"

# The agent handles the rest: reads the ticket, orchestrates sub-agents,
# writes tests, implements code, reviews, and commits.
```

## Architecture & Principles

All implementation agents enforce these architectural patterns and principles:

### Hexagonal Architecture (Ports & Adapters)

```
┌─────────────────────────────────────────────────────────────────┐
│                     INFRASTRUCTURE LAYER                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  REST API   │  │  Database   │  │  External Services      │  │
│  │  Adapter    │  │  Adapter    │  │  (Queue, Cache, etc.)   │  │
│  └──────┬──────┘  └──────┬──────┘  └────────────┬────────────┘  │
│         │                │                      │                │
│  ┌──────┴────────────────┴──────────────────────┴──────┐        │
│  │                  APPLICATION LAYER                   │        │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────────┐ │        │
│  │  │ Use Cases  │  │ Input/     │  │ DTOs           │ │        │
│  │  │            │  │ Output     │  │                │ │        │
│  │  │            │  │ Ports      │  │                │ │        │
│  │  └─────┬──────┘  └────────────┘  └────────────────┘ │        │
│  └────────┼─────────────────────────────────────────────┘        │
│           │                                                      │
│  ┌────────┴─────────────────────────────────────────────┐        │
│  │                    DOMAIN LAYER                       │        │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────────┐  │        │
│  │  │ Entities   │  │ Value      │  │ Domain         │  │        │
│  │  │            │  │ Objects    │  │ Services       │  │        │
│  │  └────────────┘  └────────────┘  └────────────────┘  │        │
│  └──────────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────┘
```

### SOLID Principles

| Principle | Description |
|-----------|-------------|
| **Single Responsibility** | One reason to change per class/module |
| **Open/Closed** | Open for extension, closed for modification |
| **Liskov Substitution** | Subtypes must be substitutable for their base types |
| **Interface Segregation** | Many specific interfaces over one general interface |
| **Dependency Inversion** | Depend on abstractions, not concretions |

### Test-Driven Development (TDD)

- Write failing tests before implementation
- Use **test doubles (fakes)** for internal components
- Use **mocks only** for external services
- Target **minimum 80% code coverage**

## Supported Technology Stacks

### Backend: FastAPI (Python)

| Component | Technology |
|-----------|------------|
| Runtime | Python 3.11+ |
| Package Manager | UV |
| Validation | Pydantic V2 |
| Testing | pytest, pytest-asyncio |
| Containerization | Docker |

### Backend: NestJS (TypeScript)

| Component | Technology |
|-----------|------------|
| Runtime | Node.js 20+ |
| Package Manager | pnpm |
| Validation | Zod |
| Testing | Jest |
| DI | Injection tokens |

### Frontend: React (TypeScript)

| Component | Technology |
|-----------|------------|
| Runtime | Bun |
| Build Tool | Vite or Next.js |
| Styling | Tailwind CSS |
| Data Fetching | React Query |
| Linting/Formatting | Biome |

### Infrastructure: K3s DevOps

| Component | Technology |
|-----------|------------|
| Kubernetes | K3s |
| GitOps | Flux CD |
| Auth | Logto |
| Secrets | OpenBao |
| Storage | MinIO |
| DNS/CDN | Cloudflare |

## MCP Integrations

The system integrates with external tools via Model Context Protocol (MCP):

### Atlassian (Jira/Confluence)

Jira issue management and Confluence documentation integration.

```json
{
  "atlassian": {
    "type": "remote",
    "url": "http://localhost:9000/mcp",
    "enabled": true
  }
}
```

### Context7

Library documentation and code examples lookup. Runs in docker-compose on port 9021.

```json
{
  "context7": {
    "type": "remote",
    "url": "http://localhost:9021/mcp",
    "enabled": true
  }
}
```

### Chrome DevTools

Browser inspection and debugging via Chrome DevTools Protocol. Runs as a local npx command.

```json
{
  "chrome-devtools": {
    "command": "npx",
    "args": ["-y", "chrome-devtools-mcp@latest"]
  }
}
```

## Installation

### Prerequisites

- [Bun](https://bun.sh) runtime
- [Docker](https://docker.com) and Docker Compose
- Access to one of the supported AI tools (OpenCode, Claude Code, or GitHub Copilot)

### Setting Up MCP Servers

1. Navigate to the MCP directory:

```bash
cd ai-driven/mcp
```

2. Create environment files from templates:

```bash
cp env.atlassian.example .env.atlassian
cp env.sonar.example .env.sonar
```

3. Edit the environment files with your credentials.

4. Start the MCP services:

```bash
docker-compose up -d
```

### Setting Up OpenCode

1. Copy the `.opencode` directory to your project root:

```bash
cp -r ai-driven/opencode/.opencode /path/to/your/project/
```

2. Copy the shared agents:

```bash
cp ai-driven/agents/*.md /path/to/your/project/.opencode/agents/
```

3. Install plugin dependencies:

```bash
cd /path/to/your/project/.opencode
bun install
```

4. OpenCode will automatically detect the configuration.

### Setting Up Claude Code

1. Create the `.claude` directory and copy the workflow instructions:

```bash
mkdir -p /path/to/your/project/.claude
cp ai-driven/claude/.claude/CLAUDE.md /path/to/your/project/.claude/
```

2. Copy the MCP configuration template:

```bash
cp ai-driven/claude/.claude.example.json /path/to/your/project/.claude.json
```

3. Copy the shared agents:

```bash
cp -r ai-driven/agents /path/to/your/project/.claude/
```

4. Optionally copy skills:

```bash
cp -r ai-driven/claude/.claude/skills /path/to/your/project/.claude/
```

### Setting Up GitHub Copilot

1. Create the `.github` directory if it doesn't exist:

```bash
mkdir -p /path/to/your/project/.github
```

2. Copy the workflow instructions:

```bash
cp ai-driven/copilot/.github/copilot-instructions.md /path/to/your/project/.github/
```

3. Copy the MCP configuration:

```bash
cp ai-driven/copilot/mcp.json /path/to/your/project/
```

4. Copy the shared agents:

```bash
cp -r ai-driven/agents /path/to/your/project/.github/
```

## Skills

Additional skills are available for enhanced capabilities:

### sonarfix

SonarQube issue remediation workflow. Retrieves issues via MCP, groups them, presents a fix plan, and implements fixes in batches with test verification.

**Available for:** Claude Code, GitHub Copilot, OpenCode

### trivyfix

Trivy vulnerability remediation workflow. Runs trivy CLI scans, groups findings by severity and type, presents a fix plan, and implements fixes in batches with verification.

**Available for:** Claude Code, GitHub Copilot, OpenCode

### feature-implementation

Agent-based development workflow for implementation tasks. Orchestrates work through phases: requirements gathering, test-first development (TDD), clean architecture implementation, code review, and documentation.

**Available for:** Claude Code, GitHub Copilot, OpenCode

### frontend-design

Creates distinctive, production-grade UIs that avoid generic "AI-generated" aesthetics. Focuses on unique visual identity, intentional design choices, and polished user experiences.

**Available for:** Claude Code, GitHub Copilot, OpenCode

## Usage Examples

### Starting a New Feature

```
1. Invoke product-owner:
   "I need to implement user authentication with OAuth2"

2. Invoke test-writer:
   "Write tests for the authentication use cases defined by product-owner"

3. Invoke fastapi-hexagonal (or nestjs-hexagonal):
   "Implement the authentication feature to make all tests pass"

4. Invoke code-reviewer:
   "Review the authentication implementation"

5. Invoke code-simplifier:
   "Refactor the authentication code for better clarity"

6. Invoke documentation-writer:
   "Update the README with authentication documentation"

7. Invoke tester-qa:
   "Test the authentication endpoints manually"
```

### Infrastructure Changes

```
1. Invoke k3s-devops:
   "Add a new Redis deployment for session caching"
```

## File Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| React Components | PascalCase.tsx | `UserProfile.tsx` |
| React Hooks | camelCase.ts | `useUserProfile.ts` |
| Utilities | camelCase.ts | `formatDate.ts` |
| Python modules | snake_case.py | `user_repository.py` |
| Tests | *.test.ts/tsx or *_test.py | `UserService.test.ts` |

## Customization

### Adding New Agents

1. Create a new markdown file in `ai-driven/agents/`:

```markdown
---
name: my-custom-agent
description: Description of what the agent does
model: claude-sonnet
tools:
  - Read
  - Glob
  - Grep
  - Edit
  - Write
---

# My Custom Agent

Instructions for the agent...
```

2. Copy to the appropriate tool configuration directory.

3. For OpenCode, also update `opencode.json` with the agent configuration.

### Modifying Agent Permissions

Adjust the `tools` list in the agent's YAML frontmatter:

```yaml
tools:
  - Read      # Read files
  - Glob      # Find files by pattern
  - Grep      # Search file contents
  - Edit      # Modify existing files
  - Write     # Create new files
  - Bash      # Execute shell commands
```

### Changing AI Models

Update the `model` field in the agent's frontmatter:

```yaml
model: claude-sonnet  # For complex tasks requiring deep reasoning
model: claude-haiku   # For simpler, cost-effective tasks
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT

## Resources

- [OpenCode Documentation](https://opencode.ai/docs)
- [OpenCode GitHub](https://github.com/anomalyco/opencode)
- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [GitHub Copilot Documentation](https://docs.github.com/en/copilot)
- [Model Context Protocol](https://modelcontextprotocol.io/)
