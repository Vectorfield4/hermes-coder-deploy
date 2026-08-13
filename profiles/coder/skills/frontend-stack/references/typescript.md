# TypeScript 5

## Conventions

- Strict mode always (`"strict": true`); no `any`, no `// @ts-ignore`.
- `unknown` for untyped external data, then narrow.
- Path alias `@/` → `src/` in both `tsconfig` and `vite.config.ts`.
- Types that describe data/API use `type`; interfaces only for object shapes to be extended/implemented.
- Enums discouraged — prefer union types (`type Role = "admin" | "user"`).

## Key patterns

```ts
// schema-first types (Zod) — see references/zod.md
type User = z.infer<typeof userSchema>;

// discriminated unions for status
type TaskStatus = "ready" | "blocked" | "done" | "cancelled";
```

- Generic components: constrain with `extends`; avoid over-generalizing.
- `satisfies` operator to keep literal inference while checking shape.
- Use `ReadonlyArray<T>` / `as const` where the data is immutable.

## Pitfalls

- Implicit `any` from destructuring untyped JSON — type it from the Zod schema.
- `import type` for type-only imports (verbatimModuleSyntax is on).
- Ignoring null/undefined in props — model optionality explicitly.
