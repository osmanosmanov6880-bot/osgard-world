# OSGARD stacked PR integration / dry-run

This change does not merge, deploy or update production.

`scripts/release-pr-dependency-audit.py` validates a frozen metadata snapshot for PRs 107-122: existence, exact base branch, draft state, mergeability, immutable SHA syntax and duplicate numbers. Run `python3 scripts/release-pr-dependency-audit.py /private/pr-snapshot.json`. Snapshot records use `number`, `state`, `base`, `draft`, `mergeable`, `head_sha`. Obtain snapshot from authorized GitHub API and preserve fetched timestamps.

**Important:** PRs 103-106 are already included in the integration PR 107. Do not merge both layers without reviewing overlap. Pushing changes to `master` may invoke `deploy-frontend.yml`, depending on changed paths, even if merging was intended only for QA. Every downstream stacked PR needs its base retargeted or verified in order, and all CI rerun. The audit cannot prove the authenticity of a supplied JSON snapshot and does not itself grant merge permission.

Rollback of this proposal: leave the draft unmerged, or revert its own code commit after proper review. The workflow executes pure local tests only.
