# Storybook 9

## Conventions

- One story per component in `src/components/<Area>/<Name>.stories.tsx` (CSF3).
- Configured in `.storybook/main.ts` (framework `@storybook/react-vite`) + `.storybook/preview.tsx`.
- All stories wrap with the app `ThemeProvider` and providers (QueryClient, MSW, router) so they render like real usage.

## Key pattern

```tsx
import type { Meta, StoryObj } from "@storybook/react";
import { Button } from "./Button";

const meta = {
  title: "Components/Button",
  component: Button,
  args: { children: "Click me", variant: "contained" },
} satisfies Meta<typeof Button>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Primary: Story = {};
export const Disabled: Story = { args: { disabled: true } };
```

## Rules

- Use `args` + controls over hardcoded variants; keep stories interaction-free unless a play function is needed.
- Cover the meaningful variants and states (loading, empty, error) for the component.
- MSW handles any network calls a story makes.

## Pitfalls

- Stories that hit real APIs (must be mocked).
- Missing providers → theme/router/query errors in preview.
- Duplicating component code in stories instead of using args.
