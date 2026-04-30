# Agent Guardrails

- Keep `CanvasNode` base abstractions in `packages/infinite_canvas`.
- Keep package-level style primitives/base contracts in `packages/infinite_canvas/lib/src/node/node_style.dart`.
- Do **not** add app-specific node-style subclasses (for example `TextNodeStyle`, `LineNodeStyle`, `TriangleNodeStyle`) to the package.
- Do **not** move app node implementations (`RectNode`, `CircleNode`, `TriangleNode`, `LineNode`, `TextNode`) into package-level inheritance trees.
- App-level node-style extensions and typed style subclasses must stay in app code under `lib/`.
- Always explain what functions do.
