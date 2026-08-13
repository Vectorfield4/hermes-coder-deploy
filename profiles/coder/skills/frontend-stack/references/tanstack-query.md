# TanStack Query v5

## Conventions

- Query hooks in `src/hooks/queries.ts` (or per-domain files). No raw `fetch` in components.
- `QueryClientProvider` wraps the app in `main.tsx`; client configured with sensible defaults.
- Query keys are arrays: `["projects"]`, `["project", id]`, `["project", id, "tasks"]`.
- Server state lives here, not in Zustand.

## Key pattern

```tsx
export function useProject(id: string) {
  return useQuery({
    queryKey: ["project", id],
    queryFn: () => api.getProject(id),
    enabled: !!id,
  });
}
```

- Mutations return `useMutation`; on success invalidate/update cache:

```tsx
const qc = useQueryClient();
const mutation = useMutation({
  mutationFn: (input: CreateTaskInput) => api.createTask(input),
  onSuccess: () => qc.invalidateQueries({ queryKey: ["tasks"] }),
});
```

- Optimistic updates: `onMutate` sets the cache, `onError` rolls back, `onSettled` invalidates.
- Derived selectors: `select: (data) => data.filter(...)` to keep render values cheap.

## Rules

- `staleTime` for static data; `refetchOnWindowFocus` where freshness matters.
- Single `queryFn` per key shape; no inline untyped fetchers.
- Cache invalidation by key prefix, not exact key, so all dependent queries refresh.

## Pitfalls

- Putting query data into Zustand and re-fetching — double state.
- Omitting `queryKey` dependencies → stale/wrong data after param change.
- Mutations without cache sync → UI drift after write.
