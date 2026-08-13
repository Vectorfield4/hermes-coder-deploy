# Biome 2

## Conventions

- Biome is the only linter/formatter; ESLint/Prettier are not used.
- Config in `biome.json` (extends the recommended config, adjusted to repo taste).
- Commands: `npm run lint` (`biome check .`), `npm run format` (`biome format --write .`), fix in CI via `biome ci .`.

## Key config

```json
{
  "$schema": "https://biomejs.dev/schemas/2.0.0/schema.json",
  "files": { "ignore": ["dist", "build", "storybook-static", "node_modules"] },
  "formatter": { "enabled": true, "indentStyle": "space", "indentWidth": 2 },
  "linter": { "enabled": true, "rules": { "recommended": true } },
  "javascript": { "formatter": { "quoteStyle": "double", "semicolons": "always" } }
}
```

## Rules

- Run `biome check` before pushing; CI fails on violations.
- Use `--write` for formatting-only fixes; review `--safe` refactors carefully.
- Prefer Biome's built-in `noExplicitAny`/`noUndeclaredVariables` guards over `ts-ignore`.

## Pitfalls

- Mixed formatting (Prettier artifacts) — run one formatter only.
- `.gitignore` not covering `storybook-static`/`dist`, so lint scans build output.
- Disabling rules globally instead of with a documented, per-file suppression comment.
