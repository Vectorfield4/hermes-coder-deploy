# React 19

## Conventions in this stack

- Functional components with hooks only; never class components.
- One component per file in `src/components/<Area>/<Name>.tsx`; default export.
- Props typed with a `type` (not interface) named `<Name>Props`.
- Components stay presentational; data comes from TanStack Query, shared state from Zustand.

## Key patterns

- Derived state during render, not in effects.
- Functional `setState` for stable callbacks.
- Expensive initial state via lazy initializer: `useState(() => compute())`.
- Memoize only expensive subtrees (`React.memo`); avoid `memo` on trivial primitives.
- Move interaction logic to event handlers; reserve effects for synchronization.

## React 19 specifics

- `use()` reads resources (promises/context) inside components.
- `ref` is available as a regular prop on function components.
- `<form action={...}>` supports actions; `useActionState` for pending state.
- `startTransition` / `useTransition` for non-urgent updates.
- `useDeferredValue` for expensive renders driven by fast input.

## Pitfalls

- Do not define components inside components (remounts every render).
- Do not subscribe to a store value only used in callbacks — subscribe to a derived boolean.
- Avoid barrel imports for components; import the file directly.
- No `any`; prefer `unknown` + narrowing.
