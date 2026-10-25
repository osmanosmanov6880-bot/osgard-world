# NEBULA R40 — one-time isolated HTTPS QA deployment

This change adds a reviewed, exactly pinned **staging-only** push trigger.
When this pull request is merged, a push containing the new
`.github/nebula-r40-qa-one-shot-source.json` triggers the existing
`NEBULA R40 isolated device QA staging` workflow. It may publish only the
verified R40 PR #375 artifact from successful native CI #40173218842,
provided the PR head remains the pinned commit.

Before any SSH activation, the workflow checks GitHub workflow identity,
current PR head, exact artifact provenance, SHA-256 manifest, WebAssembly
magic and PCK size. SSH activation uses the same frontend lock as production,
but writes only `/games/remix/nebula-r40-qa/`. It never overwrites the
public R38 path `/games/remix/arena-v2/nebula-3d/`.

The one-shot trigger is a dedicated new file path: future routine changes to
this workflow or other files do not automatically stage again. The workflow
also supports explicit `workflow_dispatch` for later approved field tests.
This is **a public QA URL**, not final production R40. Do not claim phone
FPS, thermals, AAA fidelity or hardware approval based on it. Do not upload
private 108 JSON reports / 12 screen captures to this public repository.

On failure, inspect the run logs and preserve R38. Physical approval must
precede any production promotion, including an independent allowlist change.
