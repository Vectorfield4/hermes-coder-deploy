# Zod 4

## Conventions

- Schemas live next to the data they describe (`src/schemas/*.ts`) and are the single source of truth for types: `type X = z.infer<typeof xSchema>`.
- Used for: form validation (via zodResolver), API response parsing, and environment variable validation.

## Key patterns

```ts
import { z } from "zod";

export const userSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1).max(80),
  email: z.string().email(),
  role: z.enum(["admin", "user"]),
  createdAt: z.string().datetime(),
});
export type User = z.infer<typeof userSchema>;
```

- Optional/nullable: `z.string().optional()` vs `z.string().nullable()` — be explicit.
- Cross-field rules: `z.object({...}).superRefine((data, ctx) => {...})`.
- Preprocess unknown input: `z.unknown().pipe(z.string())` or `z.coerce.number()`.
- Parse API responses with `schema.parse(data)`; catch with `safeParse` in fallback paths.

## Pitfalls

- Using `z.any()` — defeats type safety; use `z.unknown()` + narrowing.
- Redundant validation logic in components instead of the schema.
- Defining the same shape twice (schema + interface) — derive the type from the schema.
- Failing to keep API and form schemas in sync with the backend contract.
