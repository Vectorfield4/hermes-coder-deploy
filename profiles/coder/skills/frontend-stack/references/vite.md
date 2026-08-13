# Vite 7

## Conventions

- Config in `vite.config.ts` with `@vitejs/plugin-react` and the Vitest `test` block (jsdom, setup file).
- App entry: `index.html` → `/src/main.tsx`; assets under `public/` served at `/`.
- Env vars: `VITE_*` prefixed, read via `import.meta.env.VITE_*`.

## Key config

```ts
// vite.config.ts
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import { fileURLToPath } from "node:url";

export default defineConfig({
  plugins: [react()],
  resolve: { alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) } },
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: "./src/test/setup.ts",
  },
});
```

## Build

- `npm run build` runs `tsc -b && vite build` (type-check before bundling).
- Lazy-load heavy routes with dynamic `import()` — Vite code-splits automatically.
- Avoid barrel files; direct imports keep chunk graphs small.
- Environment-specific config: `defineConfig(({ mode }) => ...)`.

## Pitfalls

- Committing `dist/` (it is gitignored).
- Using `process.env` in client code — only `import.meta.env` works.
- Importing CSS globally instead of scoped MUI `sx`/`styled`.
