# React Router v7

## Setup

- App is mounted inside `RouterProvider` with `createBrowserRouter` in `src/main.tsx`.
- Route tree lives in `src/router.tsx` (or inline in `main.tsx`).

## Conventions

- Data-loading lives in TanStack Query, not router loaders — keep routes thin.
- Lazy-load heavy feature pages with `lazy` + `Suspense`.
- Links: `<Link>` / `<NavLink>` (active state via `className` callback).
- Params: `useParams`; search params: `useSearchParams` (never parse `window.location`).

## Key APIs

```tsx
const router = createBrowserRouter([
  { path: "/", element: <Layout />, children: [
      { index: true, element: <HomePage /> },
      { path: "login", element: <LoginPage /> },
      { path: "profile", element: <ProfilePage /> },
      { path: "*", element: <NotFoundPage /> },
  ] },
]);
```

```tsx
const navigate = useNavigate();
const { id } = useParams();
const [params, setParams] = useSearchParams();
```

## Pitfalls

- Do not use `<a href>` for internal navigation — causes full reloads.
- Match paths with relative links inside nested routes; use `../` sparingly.
- Keep route elements memoized/static where possible to avoid remount churn.
