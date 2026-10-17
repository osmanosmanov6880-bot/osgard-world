# OSGARD consolidated release candidate — 2026-10-17

## Audited baseline

GitHub compare `master...integration/consolidated-release-candidate-2026-10-17`: 121 commits ahead, 0 behind, 62 changed paths. The changes are concentrated in CI workflows, release/backup security scripts, negative/regression tests, and runbooks; no application content changes were returned in the compared file list.

## Acceptance gates

- Integrated safety CI on consolidated head: required, green
- Full real-site build, ZIP archive and 19 game route contract: required, green
- Read-only live GitHub PR dependency audit: required, green at time of review
- Every prior stacked PR: draft, open and based on immediate prior branch before consolidation
- Production deploy workflows on `master`: inspect and evaluate before merging; at least `deploy-frontend.yml` has filtered push-to-master triggers
- External staging HTTP and browser game UI: not demonstrated by offline build; separately required for launch
- Core restoration with real isolated backup: not demonstrated by mocked Docker tests; separately required for launch

## Consolidation policy

Use this single draft PR against `master` for a complete reviewer diff. **Do not independently merge the subordinate PR chain #107–127 AND this rollup**, as it overlaps the same commits. The rollup is for review, staging approval and rollback planning, NOT automatic production release. Do not close subordinate PRs or merge until the release operator reviews deployment-triggering workflow conditions.

## Reproduction

```sh
python3 -m unittest discover -s tests -p 'test_*.py' -v
npm ci
npm run build
npm run qa:zion-local
```

Review in GitHub PR checks for complete release-bundle acceptance and SHA binding.

## Stop conditions

- Any check fails or is missing
- Live PR dependency check returns null/unmergeable or changed base
- Release zip checksums or manifest mismatch
- Stage origin is unverified or staging HTTP missing
- No operator rollback/recovery signoff
- Push-to-master deploy effects not reviewed

Status: `DRAFT_FOR_REVIEW`; merged=false; production_deployed=false; payments_activated=false.
