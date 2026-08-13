# MUI v7

## Conventions

- Theming in `src/theme.ts`: `createTheme`, `ThemeProvider` in `main.tsx`, dark mode via `mode: "dark"` or `useMediaQuery`.
- Styling via `sx` prop for one-offs; `styled` components for reusable variants. No Tailwind, no CSS files for layout.
- Grid layout: v7 `Grid` uses `size` prop (not `item`): `<Grid size={{ xs: 12, md: 6 }}>`.
- Responsive breakpoints in `sx`: `{ xs: ..., sm: ..., md: ..., lg: ... }`.

## Key patterns

```tsx
<Box sx={{ display: "flex", gap: 2, flexWrap: "wrap" }}>
  <Typography variant="h6" sx={{ fontWeight: 600 }}>
    Title
  </Typography>
  <Button variant="contained" startIcon={<AddIcon />} onClick={onAdd}>
    Add
  </Button>
</Box>
```

- Override theme at one level: `sx={{ color: (t) => t.palette.primary.main }}`.
- Icons: `@mui/icons-material`, import named icons only.
- Forms: use MUI `TextField`/`Select`/`Checkbox` with React Hook Form (see `references/react-hook-form.md`); pass RHF props via `{...field}`.

## Pitfalls

- Applying `gap` to `Grid` directly (use `spacing` on the Grid container).
- Importing components from `@mui/material/...` deep paths unnecessarily — import from `@mui/material`.
- Overusing `sx` with magic numbers instead of theme tokens (`theme.spacing`, palette, typography).
- Missing `aria-label` on icon-only buttons.
