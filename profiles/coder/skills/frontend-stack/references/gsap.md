# GSAP 3

## Conventions

- Use `useGSAP` from `@gsap/react` inside components; it auto-cleans up animations on unmount.
- All animations are set up once per mount (or on state deps); no animation tweens in render.

## Key pattern

```tsx
import { useGSAP } from "@gsap/react";
import gsap from "gsap";

function Hero() {
  const scope = useRef<HTMLDivElement>(null);
  useGSAP(() => {
    gsap.fromTo(".hero-title",
      { opacity: 0, y: 24 },
      { opacity: 1, y: 0, duration: 0.8, ease: "power3.out" });
  }, { scope });
  return <div ref={scope}>...</div>;
}
```

- Scroll-triggered: `gsap.registerPlugin(ScrollTrigger)` then `scrollTrigger: { trigger, start: "top 80%", toggleActions: "play none none reverse" }`.
- Timelines: `gsap.timeline({ defaults: { duration: 0.6, ease: "power2.out" } })` for sequenced reveals.
- Respect `prefers-reduced-motion`: gate animations behind `matchMedia("(prefers-reduced-motion: reduce)")`.

## Pitfalls

- Animating every render (no deps array in `useGSAP`).
- Leaving tweens running after unmount (missing scope cleanup).
- Forgetting `ScrollTrigger.refresh()` after layout-shifting content loads.
- Animating CSS that MUI controls via `sx` — target inner elements with class names, not MUI internals.
