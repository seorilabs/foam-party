# Foam Party Product Core

Engine-independent rules and use cases live here when they are extracted from the Godot prototype.

Shipped engine-independent washing, scoring, economy, progression, and coaching rules live here. Godot scene/input/rendering orchestration remains in `godot/scripts/main.gd`.

Wash mutation rates are centralized in `src/domain/game_config.gd`; `src/use_cases/wash_rules.gd` owns formulas and state transitions without embedding balance coefficients.

## Boundary

- Allowed: domain entities, value objects, pure use cases, ports, pure tests.
- Forbidden: Godot scene tree, Firebase, AppsInToss, Google Play, App Store, ads, billing, network/client SDK imports.

Run:

```bash
npm run test:core
npm run check:architecture
```
