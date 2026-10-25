# OSGARD R135 W14 — independent simulated fault learning records

**Scope**: a local-only Godot save migration and independently displayed learning progress. This is an unshipped, stacked candidate on W13; public W11 remains unchanged.

## Actual gameplay data

Each of the 3 simulated diagnostic faults (optical, airflow, service interlock) separately records:
- Attempt count, including an abandoned challenge when a new case is started.
- Best earned score (0–150) and fastest successfully completed elapsed time.
- Total recorded mistakes, including wrong order/view and unsafe simulated hatch actions.
- Persisted completion flags, plus the older global best score for backwards compatibility.

These values are stored in Godot `user://r135_challenge_record.cfg`, **not on a server**. No connected industrial sensors, physical machine data, account IDs or cloud telemetry are involved. The completed-case HUD displays its own best score and number of attempts.

## Schema migration and integrity

V1 saved `progress.best_score` and `progress.cleared_cases` only.
V2 preserves those keys and adds `progress.schema_version=2`,
`case_attempts`, `case_best_scores`, `case_best_seconds`, and
`case_total_mistakes`.

Malformed or absent case arrays revert to independent safe defaults. Stored values are individually bounded, with a no-record time sentinel of -1.0. **Do not invent per-fault history from an old global high score.** A missing/corrupt ConfigFile starts from safe defaults; local save errors are surfaced in QA.

## Acceptance

- Real Godot native test must complete 3 distinct simulated faults, read the actual ConfigFile, instantiate a new controller, and prove per-fault scores/attempts survive reload.
- Migration fixture consisting of only old V1 keys must recover global best and previously cleared flags, with three new attempt counts remaining zero (not fabricated).
- Browser Chromium PC and emulated Pixel must still pass W12's all-case diagnosis, W13 safe-first mission, real controls, 3D caption, binary ZIP and Nginx WASM/PCK.
- Check that completed-case HUD displays case-specific `BEST` and `RUNS`, and is not clipped in original screenshots before final merge.
- W14 gets **its own version string**; a source merge does not publish the game and must never substitute W11's permanent archive or SHA.

## Boundaries

No physical Android/iPhone measurements exist. This is a simulated learning record, not an industrial qualification or proof of AAA/8K fidelity. Full hardware acceptance, accessible UI, extended educational content and protected deployment are future separately verified gates.
