# MSW 2

## Conventions

- Handlers in `src/test/handlers.ts` — one handler per API route, shared by tests and dev/storybook.
- Server instance for tests (node), browser worker (`/mockServiceWorker.js`) for dev.
- Every API call the app makes must have a handler; a missing handler fails tests loudly.

## Key pattern

```ts
// src/test/handlers.ts
import { http, HttpResponse } from "msw";

export const handlers = [
  http.get("/api/projects", () => HttpResponse.json([{ id: "p1", name: "Demo" }])),
  http.post("/api/tasks", async ({ request }) => {
    const body = await request.json();
    return HttpResponse.json({ id: "t1", ...body }, { status: 201 });
  }),
];
```

```ts
// src/test/setup.ts
import { setupServer } from "msw/node";
import { handlers } from "./handlers";

export const server = setupServer(...handlers);
beforeAll(() => server.listen({ onUnhandledRequest: "error" }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

## Rules

- Use realistic, typed payloads matching the Zod schemas.
- Error-path handlers added per-test with `server.use(...)` overrides.
- Delay optional; do not rely on default latency in tests.

## Pitfalls

- Leaving `onUnhandledRequest` permissive — masks missing handlers.
- Mocking at the `fetch` layer with `vi.spyOn` instead of MSW.
- Forgetting to register the worker in dev (`worker.start()` in `main.tsx`).
