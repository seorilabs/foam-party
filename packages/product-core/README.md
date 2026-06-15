# Foam Party Product Core

Engine-independent rules and use cases live here when they are extracted from the Godot prototype.

Current status: scaffold only. The shipped gameplay still lives in `godot/scripts/main.gd`.

## Boundary

- Allowed: domain entities, value objects, pure use cases, ports, pure tests.
- Forbidden: Godot scene tree, Firebase, AppsInToss, Google Play, App Store, ads, billing, network/client SDK imports.

Run:

```bash
npm run test:core
npm run check:architecture
```
