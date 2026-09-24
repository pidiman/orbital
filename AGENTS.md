
## Save safety (always apply)
- Save format is v2 JSON. New persisted state goes under `extensions`.
- All persisted dictionary keys must be strings (IDs as "12", grid cells as "x,y").
- Never persist derived/transient data: placement caches, connectivity, tube masks, visuals.
- Old saves must load with sensible defaults for any new field; migrate before validating.
- When adding or changing persisted state, extend `tests/save_key_roundtrip.gd`
  (save -> load -> save -> strict reload) and run it before finishing.

## Performance rules (always apply)
- No per-frame recalculation of things that change only on events (placement cells,
  connectivity, tube tiling, panel height). Invalidate on specific events, never on
  broad `model.changed`.
- Idle/parked ships must skip per-frame visual work.
- Remove temporary diagnostic logging before finishing.
