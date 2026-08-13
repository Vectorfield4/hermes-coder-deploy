# Zustand v5

## Conventions

- One store per domain in `src/stores/<domain>.ts` (e.g. `useAuthStore`, `useCartStore`).
- Selectors are passed to the hook; never select the whole store in components.

## Key patterns

```ts
// src/stores/useAuthStore.ts
import { create } from "zustand";

type AuthState = {
  user: User | null;
  token: string | null;
  login: (user: User, token: string) => void;
  logout: () => void;
};

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  token: null,
  login: (user, token) => set({ user, token }),
  logout: () => set({ user: null, token: null }),
}));
```

```tsx
// components subscribe to a selector, not the store
const user = useAuthStore((s) => s.user);
```

## Rules

- Selector must return a primitive or a memoized reference, otherwise it re-renders on every store change:
  `useAuthStore((s) => s.user?.id ?? null)` — not `useAuthStore((s) => s.user)`.
- Do not put server data in Zustand — that is TanStack Query's job.
- Store only client/UI state (auth, cart, filters, form-wide state).
- Slice pattern: split a large store into multiple `createStore` slices combined with `create`.

## Pitfalls

- Mutating state outside the `set` updater.
- Recreating objects in selectors (`{ ...s.user }`) — causes infinite re-render loops.
- Using Zustand for server cache — duplicates TanStack Query.
