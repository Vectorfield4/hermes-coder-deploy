# Three.js + React Three Fiber v9

## Conventions

- Scenes built declaratively with R3F `<Canvas>`; imperative Three.js only for algorithms/helpers.
- Loaders cached (`useGLTF`); geometries/materials disposed to avoid GPU leaks.
- Drei utilities (`@react-three/drei`) for helpers: `<OrbitControls>`, `<Environment>`, `<Float>`, `<Text>`, `<PerspectiveCamera>`.

## Key pattern

```tsx
import { Canvas, useFrame } from "@react-three/fiber";
import { OrbitControls } from "@react-three/drei";

function RotatingCube() {
  const ref = useRef<THREE.Mesh>(null);
  useFrame((_, delta) => {
    if (ref.current) ref.current.rotation.y += delta;
  });
  return (
    <mesh ref={ref}>
      <boxGeometry args={[1, 1, 1]} />
      <meshStandardMaterial color="tomato" />
    </mesh>
  );
}

function Scene() {
  return (
    <Canvas camera={{ position: [3, 2, 3] }}>
      <ambientLight intensity={0.6} />
      <directionalLight position={[5, 5, 5]} />
      <RotatingCube />
      <OrbitControls />
    </Canvas>
  );
}
```

## Rules

- `useFrame` only for per-frame work; state changes go through R3F refs, not React state.
- Dispose resources: remove objects from scene and `geometry.dispose()` / `material.dispose()` on unmount.
- Use `frameloop="demand"` for static scenes; keep draw calls low.

## Pitfalls

- Mutating `position`/`scale` via React state every frame — re-renders the whole tree.
- Forgetting `color` space/gamma issues (textures may need `colorSpace = THREE.SRGBColorSpace`).
- Heavy shadows on mobile — cap `shadow-mapSize` and count of shadow-casting lights.
- Loading large GLB models without `useGLTF` suspense/lazy boundaries.
