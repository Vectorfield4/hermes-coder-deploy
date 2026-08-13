# Vitest 3

## Conventions

- Tests colocated or in `src/**/__tests__/`; run with `npm run test` (watch) / `npm run test:run` (CI).
- Setup file `src/test/setup.ts`: imports `@testing-library/jest-dom`, starts MSW server (see `references/msw.md`).
- Component tests use Testing Library (`render`, `screen`, `userEvent`) — no shallow enzyme-style tests.

## Key pattern

```tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";

it("renders greeting", () => {
  render(<Greeting name="Ada" />);
  expect(screen.getByText("Hello, Ada!")).toBeInTheDocument();
});

it("submits the form", async () => {
  const user = userEvent.setup();
  render(<LoginForm />);
  await user.type(screen.getByLabelText(/email/i), "a@b.dev");
  await user.click(screen.getByRole("button", { name: /submit/i }));
  expect(await screen.findByText(/success/i)).toBeInTheDocument();
});
```

## Rules

- Query by role/text, not CSS classes; use `findBy*` for async updates.
- Mock server responses via MSW handlers, not `vi.mock` of the fetch layer.
- Cover behavior, not implementation: assert on rendered UI and user interactions.
- Keep tests free of `waitFor` where `findBy*` suffices.

## Pitfalls

- Tests that leak state between runs — reset MSW handlers and stores in `afterEach`.
- Using real timers with animations — fake/advance timers or skip animation code paths.
- Asserting on exact HTML structure instead of accessible content.
