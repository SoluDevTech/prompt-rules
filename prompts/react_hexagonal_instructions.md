# Copilot Instructions: React App with Hexagonal Architecture

You are a React/TypeScript expert. Create a React application following hexagonal architecture, SOLID principles, and KISS.

## 🏗️ Project Structure

```
├── src/
│   ├── application/          # Application layer (UI)
│   │   ├── components/       # React components (presentational + container)
│   │   ├── hooks/            # Custom React hooks (business logic consumption)
│   │   ├── pages/            # Page components (route-level)
│   │   └── providers/        # Context providers (state management)
│   ├── domain/               # Domain layer (business logic)
│   │   ├── entities/         # Domain entities (business models)
│   │   ├── ports/            # Interfaces/contracts (repositories, services)
│   │   └── lib/              # Domain utilities (pure functions)
│   └── infrastructure/       # Infrastructure layer (external dependencies)
│       ├── api/              # API clients (HTTP, GraphQL)
│       ├── assets/           # Static assets (images, fonts, icons)
│       └── config/           # Configuration implementations
├── tests/
│   ├── unit/                 # Unit tests
│   └── doubles/              # Mock implementations (test doubles)
├── .github/workflows/        # CI/CD
├── package.json
├── tsconfig.json
├── biome.json                # Biome config (linter + formatter)
└── vite.config.ts            # or next.config.js
```

## 🎯 Core Principles

### Hexagonal Architecture
- **Domain**: Pure TypeScript, ZERO React/UI dependencies (no JSX, no hooks, no components)
- **Application**: UI layer, consumes domain through hooks, can use React freely
- **Infrastructure**: External adapters (API clients, storage), implements domain ports

### SOLID
- **SRP**: One component = one responsibility, one hook = one business concern
- **OCP**: Extend via new implementations (adapters), never modify interfaces (ports)
- **LSP**: All implementations respect their port's contract
- **ISP**: Small, focused interfaces (no god interfaces)
- **DIP**: Application depends on domain ports, never on infrastructure adapters

### KISS (Keep It Simple, Stupid)
- Simple, flat component structure (avoid over-nesting)
- Direct prop passing (avoid prop drilling with composition)
- Pure functions for transformations
- Minimal state management (use React state/context, avoid Redux unless needed)
- Clear naming: `useUserProfile` not `useData`, `UserCard` not `Card`

## 📋 Code Rules

### TypeScript Best Practices
- **TypeScript strict mode** enabled (`strict: true` in tsconfig)
- **Explicit types** everywhere (no `any`, use `unknown` if needed)
- **Interface for objects**, `type` for unions/intersections
- **Enums** or **const assertions** for constants
- **Generic types** for reusable components/hooks
- **Type guards** for runtime type checking
- **Discriminated unions** for state management
- **Utility types**: `Partial`, `Pick`, `Omit`, `Record`, etc.
- **No implicit any**: All function parameters and return types typed

### React Best Practices
- **Functional components only** (no class components)
- **TypeScript with React**: Use `React.FC` sparingly, prefer explicit prop types
- **Hooks rules**:
  - Custom hooks start with `use` prefix
  - Only call hooks at top level (no conditionals)
  - Extract complex logic into custom hooks
  - Use `useMemo` and `useCallback` for optimization (not prematurely)
- **Component patterns**:
  - **Presentational components**: Pure UI, receive props, no business logic
  - **Container components**: Connect to domain via hooks, pass data to presentational
  - **Compound components**: Related components working together (using context)
- **Props**:
  - Destructure props in function signature
  - Use `children` prop for composition
  - Optional props with `?` and defaults with destructuring
  - Avoid boolean props like `isActive`, prefer enums/unions
- **State management**:
  - Local state with `useState` for component-specific state
  - `useReducer` for complex state logic
  - Context + hooks for shared state (avoid prop drilling)
  - External state management (Zustand, Jotai) for global state if needed
- **Performance**:
  - `React.memo` for expensive components (measure first)
  - `useMemo` for expensive computations
  - `useCallback` for stable function references
  - Lazy loading with `React.lazy` and `Suspense`
  - Virtual scrolling for long lists (react-window, @tanstack/react-virtual)
- **Error handling**:
  - Error boundaries for component errors
  - Try-catch in async operations
  - Loading and error states in hooks
- **Styling**:
  - Tailwind CSS (utility-first, recommended)
  - CSS Modules (scoped styles)
  - Styled-components (CSS-in-JS)
  - Avoid inline styles (except dynamic values)
- **Responsive Design**:
  - **Mobile-first approach**: Design for mobile, then scale up
  - **Tailwind breakpoints**: `sm:`, `md:`, `lg:`, `xl:`, `2xl:` (use consistently)
  - **Fluid typography**: Use `clamp()` for responsive font sizes
  - **Responsive images**: 
    - Use `<picture>` for art direction
    - `srcset` and `sizes` for resolution switching
    - Lazy loading with `loading="lazy"`
  - **Container queries**: Use `@container` for component-level responsiveness
  - **Touch targets**: Minimum 44x44px for interactive elements (mobile)
  - **Responsive spacing**: Use Tailwind spacing scale consistently
  - **Test on real devices**: Don't rely only on browser DevTools
  - **Breakpoint strategy**:
    - Mobile: < 640px (sm)
    - Tablet: 640px - 1024px (md, lg)
    - Desktop: > 1024px (xl, 2xl)
  - **Layout patterns**:
    - Stack on mobile, grid/flex on desktop
    - Hamburger menu on mobile, full nav on desktop
    - Single column on mobile, multi-column on desktop
  - **Performance**: 
    - Avoid unnecessary re-renders on resize
    - Use CSS media queries over JS when possible
    - Debounce resize event handlers

### Domain Layer Rules
- **Pure TypeScript**: No React imports, no JSX, no hooks
- **Entities**: Simple classes or interfaces representing business models
- **Ports**: Interfaces defining contracts (repository, service)
- **Business logic**: Pure functions in `lib/`
- **Validation**: Use **Zod** for schema validation and type inference
  - Define schemas in domain entities
  - Use `z.infer<typeof schema>` for type extraction
  - Validate data at boundaries (API responses, user inputs)
- **No side effects**: Domain should be testable without UI

### Application Layer Rules
- **Custom hooks** for domain interaction:
  - `useUser()` to fetch/manage user
  - `useAuth()` for authentication logic
  - `useForm()` for form state management
- **Components**:
  - Small, focused components (<200 lines)
  - Single responsibility
  - Composable and reusable
- **Pages**: Route-level components, compose smaller components
- **Providers**: Context providers for shared state

### Infrastructure Layer Rules
- **API clients**: Implement domain ports
  - Axios, fetch, or GraphQL clients
  - Handle HTTP errors, retries, timeouts
  - Transform API responses to domain entities
- **Configuration**: Environment variables, feature flags
- **Storage**: LocalStorage, SessionStorage, IndexedDB wrappers

### Testing
- **Bun test** for unit tests (built-in, fast)
- **React Testing Library** for component tests
- **Test principles**:
  - Test behavior, not implementation
  - Query by accessible elements (getByRole, getByLabelText)
  - Avoid testing internal state
  - Mock external dependencies (API, storage)
- **Test doubles** for domain ports (mock repositories)
- **Coverage**: Minimum 70% for critical business logic
- Use **Zod schemas** in tests for data validation

### File Naming Conventions
- Components: `PascalCase.tsx` (e.g., `UserProfile.tsx`)
- Hooks: `camelCase.ts` (e.g., `useUserProfile.ts`)
- Utilities: `camelCase.ts` (e.g., `formatDate.ts`)
- Types: `PascalCase.ts` or `types.ts` (e.g., `User.ts` or `user.types.ts`)
- Tests: `*.test.tsx` or `*.spec.tsx`

## ✅ Checklist

### Architecture
- [ ] 3 distinct layers: domain / application / infrastructure
- [ ] Domain is pure TypeScript (no React dependencies)
- [ ] Application layer uses domain through custom hooks
- [ ] Infrastructure implements domain ports

### SOLID & KISS
- [ ] SRP: One component/hook = one responsibility
- [ ] DIP: Application depends on domain ports, not infrastructure
- [ ] Simple, flat structure (avoid deep nesting)
- [ ] Clear, descriptive naming

### TypeScript
- [ ] Strict mode enabled
- [ ] All types explicit (no `any`)
- [ ] Interfaces for ports (domain contracts)
- [ ] Type guards for runtime checks

### React
- [ ] Functional components only
- [ ] Custom hooks for business logic
- [ ] Proper state management (local → context → external)
- [ ] Error boundaries for error handling
- [ ] Performance optimization (measured, not premature)
- [ ] Responsive design (mobile-first, tested on real devices)
- [ ] Accessible (ARIA labels, keyboard navigation, semantic HTML)

### Testing
- [ ] Unit tests for domain logic
- [ ] Component tests with React Testing Library
- [ ] Mock infrastructure adapters
- [ ] Coverage ≥ 70%

### DevOps
- [ ] GitHub Actions CI/CD (tests, linting, build)
- [ ] Biome for linting and formatting
- [ ] TypeScript compiler checks in CI
- [ ] Docker for deployment (optional)

## 🚫 Absolutely Avoid

- ❌ React imports in domain layer (no hooks, no JSX, no components)
- ❌ Direct API calls in components (use hooks that consume domain)
- ❌ Prop drilling (use composition or context)
- ❌ Class components (use functional components)
- ❌ `any` type (use `unknown` or proper types)
- ❌ Premature optimization (measure first)
- ❌ God components (>300 lines, do everything)
- ❌ Testing implementation details (test behavior)
- ❌ Fixed pixel widths (use responsive units: %, rem, vw/vh)
- ❌ Desktop-only designs (mobile traffic is 50%+ globally)
- ❌ Ignoring touch interactions (hover states don't work on mobile)
- ❌ Tiny touch targets (<44px on mobile)

## 📌 Critical Reminders

1. **Domain** = pure TypeScript, zero React dependencies
2. **Application** consumes domain via **custom hooks**
3. **Infrastructure** implements **domain ports** (adapters pattern)
4. Use **TypeScript strict mode** with explicit types everywhere
5. **Test behavior, not implementation** with React Testing Library
6. **Mobile-first responsive design** with Tailwind breakpoints
7. **Touch targets** minimum 44x44px on mobile
8. SOLID + KISS: simplicity and design principles above all

## 📦 Recommended Stack

- **Runtime**: Bun (fast package manager, test runner, bundler)
- **Build tool**: Vite (fast) or Next.js (SSR/SSG)
- **Language**: TypeScript (strict mode)
- **UI Library**: React 18+
- **Styling**: Tailwind CSS
- **State**: React Context + hooks, or Zustand/Jotai for complex cases
- **Forms**: React Hook Form + Zod validation
- **Validation**: Zod (schema validation + type inference)
- **Data fetching**: TanStack Query (React Query)
- **Testing**: Bun test + React Testing Library
- **Linting/Formatting**: Biome (fast all-in-one tool, replaces ESLint + Prettier)
