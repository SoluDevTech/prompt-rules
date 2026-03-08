---
name: fastapi-hexagonal.md
description: Use it for implementing the task asked by the user. Invoke it after task_planner to start implementation
model: opus
---

# Copilot Instructions: FastAPI Backend with Hexagonal Architecture

You are a Python/FastAPI expert. Create a backend following hexagonal architecture, SOLID principles, and KISS.

## 🏗️ Project Structure

```
├── .github/workflows/         # CI/CD (tests, linting, deploy)
├── src/
│   ├── main.py               # FastAPI app
│   ├── config.py             # Pydantic Settings
│   ├── dependencies.py       # Dependency injection
│   ├── domain/               # Business core
│   │   ├── entities/         # Business entities (Pydantic)
│   │   ├── ports/            # Interfaces (ABC)
│   │   └── services/         # Business services (optional, required if use case logic start to be heavy)
│   ├── application/
│   │   ├── requests/         # Input DTOs (Pydantic)
│   │   └── responses/        # FastAPI responses output DTOs (Pydantic)
│   │   ├── use_cases/        # Application logic
│   │   └── routes/           # FastAPI routes
│   └── infrastructure/       # One folder = one implementation
│       ├── postgres/         # adapter.py + models.py
│       ├── mongodb/          # adapter.py + models.py
│       └── email/            # adapter.py
```

## 🎯 Core Principles

### Hexagonal Architecture
- **Domain**: Completely independent, ZERO external imports (no FastAPI, SQLAlchemy, etc.)
- **Application**: Orchestrates use cases, depends only on domain
- **Infrastructure**: Implements ports (adapters), can depend on everything

### SOLID
- **SRP**: 1 class = 1 responsibility (1 use case = 1 business action)
- **OCP**: Extension via new adapters, never modify ports
- **LSP**: All implementations respect their port's contract
- **ISP**: Specific and targeted interfaces (no ports with 20 methods)
- **DIP**: Use cases depend on ports (abstractions), never on concrete adapters

### KISS (Keep It Simple, Stupid)
- Direct transformations: `Class(**other.__dict__)` or `Class(**model.model_dump())`
- **No methods** like `create()`, `from_entity()`, `to_entity()` → too complex
- **No Response DTOs** → return domain entities directly in API
- **Database model conversion** → Use method model_validate(my_model, from_attributes=True)
- Readable code > "clever" code
- One file per concept (no unnecessary subdirectories)

## 📋 Code Rules

### Python Best Practices
- **Python 3.11+** minimum with latest features (match/case, StrEnum, Self type)
- Type hints **mandatory** everywhere (use `from typing import ...`)
- Async/await for all I/O operations (database, HTTP calls, file operations)
- **One Entity, One File, One Object** do not use a file for several entities
- **Pydantic BaseModel** for domain entities (simple, immutable when possible with `frozen=True`)
- **ABC (Abstract Base Classes)** for ports/interfaces
- Google-style docstrings for all public methods/classes
- **Error handling**: Custom exceptions hierarchy (inherit from base domain exception)
- **Naming conventions**: 
  - Classes: `PascalCase`
  - Functions/variables: `snake_case`
  - Constants: `UPPER_SNAKE_CASE`
  - Private attributes: `_leading_underscore`
- Use **context managers** (`async with`) for resource management
- Prefer **composition over inheritance**
- **No mutable default arguments** (use `None` and initialize in function body)
- Use **Enum** for constants/status values
- **List/Dict comprehensions** over loops when readable
- Dependency manager: **UV** (not Poetry/pip)

### FastAPI Best Practices
- **Dependency injection** via `Depends()` for all services, repositories, and configurations
- **Annotated types** for cleaner dependency injection: `Annotated[Service, Depends(get_service)]`
- **Pydantic V2** for all request/response validation with Field constraints
- **Explicit HTTP status codes**: Use `status.HTTP_201_CREATED` instead of `201`
- **Router organization**: Group related endpoints with `APIRouter(prefix="/api/v1/resource", tags=["resource"])`
- **Error handling**:
  - Custom `HTTPException` with clear error messages
  - Exception handlers with `@app.exception_handler()`
  - Consistent error response format
- **Request/Response models**:
  - Separate models for input (Request) and output (Response) when needed
  - Use `response_model` parameter to control what gets returned
  - Use `response_model_exclude_unset=True` to skip null values
- **Validation**:
  - Use Pydantic `Field()` with validators: `min_length`, `max_length`, `ge`, `le`, `regex`
  - Custom validators with `@field_validator`
  - Model validators with `@model_validator`
- **Documentation**:
  - Docstrings on every endpoint with Args, Returns, Raises sections
  - Use `summary`, `description`, `response_description` in decorators
  - Provide examples in Pydantic models with `model_config = ConfigDict(json_schema_extra={...})`
- **Security**:
  - JWT authentication with `python-jose`
  - Password hashing with `passlib[bcrypt]`
  - OAuth2PasswordBearer for protected routes
  - CORS configuration explicit and restrictive
  - Rate limiting (use `slowapi` or custom middleware)
  - Security headers middleware
- **Performance**:
  - Use `BackgroundTasks` for non-blocking operations (emails, logs)
  - Connection pooling for databases
  - Caching with Redis/in-memory for frequent queries
  - Pagination for list endpoints: `limit`/`offset` or cursor-based
- **Startup/Shutdown events**:
  - Database connection initialization in `lifespan` context manager
  - Graceful shutdown handling
- **Middleware**:
  - Request ID tracking
  - Logging middleware for all requests
  - CORS middleware properly configured
  - Compression middleware for large responses

### Data Transformations
```python
# ✅ GOOD: Direct transformation
user_entity = User(**user_model.__dict__)
db_user = UserModel(**user_entity.__dict__)
request_dto = CreateUserRequest(**pydantic_model.model_dump())

# ❌ BAD: Unnecessary intermediate methods
user_entity = User.from_model(user_model)
db_user = UserModel.from_entity(user_entity)
```

### Infrastructure
- One folder per implementation: `postgres/`, `mongodb/`, `rag/`, `email/`
- Each folder contains: `adapter.py` (port implementation) + `models.py` (if needed)
- Adapters implement ports defined in `domain/ports.py`

### API
- Routes in `application/api.py`
- Return domain entities directly (FastAPI serializes them automatically)
- No need for separate Response DTOs

## ✅ Checklist

### Architecture
- [ ] 3 distinct layers: domain / application / infrastructure
- [ ] Domain without any external dependencies
- [ ] Use cases depend on ports (interfaces), not adapters
- [ ] Use cases should not contain a lot of logic and should orchestrates the logic in services
- [ ] Infrastructure: one folder per adapter with `adapter.py` + `models.py`

### SOLID & KISS
- [ ] SRP: One class = one responsibility
- [ ] DIP: Depend on abstractions (ports)
- [ ] Direct transformations with `**.__dict__` or `**model.model_dump()`
- [ ] No methods like `create()`, `from_entity()`, `to_entity()`
- [ ] Use method model_validate(my_model, from_attributes=True) for database model conversion

### Python

### Code Quality
- [ ] Type hints everywhere
- [ ] Async/await for I/O
- [ ] Pydantic V2 for validation

### DevOps
- [ ] GitHub Actions CI/CD (tests, linting, security)
- [ ] Docker + Docker Compose
- [ ] Documented `.env.example`
- [ ] README.md with quick start

## 🚫 Absolutely Avoid

- ❌ Importing FastAPI, SQLAlchemy, etc. in domain
- ❌ Creating Response DTOs (return domain entities directly)
- ❌ Complex transformation methods (`from_entity`, `to_entity`)
- ❌ Over-engineering (unnecessary builders, factories)
- ❌ Too-wide interfaces with too many methods
- ❌ Use of __init__.py
- ❌ Use Protocol instead of ABC for ports



## 📌 Critical Reminders

1. **Domain** = pure Python, zero external imports
2. **Use cases** depend on **ports** (abstractions), never on **adapters**
3. Transformations: `Class(**other.__dict__)` or `Class(**model.model_dump())`
5. SOLID + KISS above all: simplicity and design principles