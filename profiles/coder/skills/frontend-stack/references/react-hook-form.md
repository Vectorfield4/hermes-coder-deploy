# React Hook Form v7

## Conventions

- Controlled inputs via `Controller` or `register`; use `zodResolver` from `@hookform/resolvers/zod` for validation (see `references/zod.md`).
- Defaults defined in the schema, mirrored in `defaultValues`.
- All forms typed from the Zod schema: `type FormValues = z.infer<typeof schema>`.

## Key pattern

```tsx
const schema = z.object({ email: z.string().email(), password: z.string().min(8) });
type FormValues = z.infer<typeof schema>;

const { control, handleSubmit, formState: { errors, isSubmitting } } = useForm<FormValues>({
  resolver: zodResolver(schema),
  defaultValues: { email: "", password: "" },
});

<form onSubmit={handleSubmit(onSubmit)} noValidate>
  <Controller
    name="email"
    control={control}
    render={({ field }) => (
      <TextField {...field} error={!!errors.email} helperText={errors.email?.message} />
    )}
  />
  <Button type="submit" disabled={isSubmitting}>Submit</Button>
</form>
```

## Rules

- Submit handler receives typed, validated values; type it as `SubmitHandler<FormValues>`.
- Server errors: map into `formState.errors` via `setError` (field-level) or `setFormError` (form-level).
- Reset after successful submit with `reset()` using the same defaults.
- Large forms: `useFieldArray` for repeatable groups.

## Pitfalls

- Forgetting `noValidate` so the browser and RHF both validate.
- Using `register` with MUI components — MUI needs `Controller`/`{...field}` to receive value + onChange.
- Mutating form values directly instead of through the controller.
