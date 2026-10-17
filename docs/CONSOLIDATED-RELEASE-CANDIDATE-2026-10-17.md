# OSGARD consolidated release candidate — 2026-10-17

## Current review scope

The candidate now includes application and service changes as well as the original release/backup gates. The next integration starts from PR #128 head `02a08becdb6047bf8363f4e9408ef9dbd209ae75` and includes actual master ref `c472c47904a2b9cd47d04d689eeba947e6b6864f` (PRs #134–136). The prepared merge preserves both Games portal and Core-owned legacy-console browser suites, their account controller, INHERIT handoff, and existing delivery safeguards.

This stage adds verified active-run recovery and account history to the opt-in Core arena at `/games/remix/arena/` and `/api/core/remix/v1/`. Every state read, continued input and cached input acknowledgement checks the persisted input prefix before accepting the snapshot. Invalid journal/checkpoint/state combinations return `503 / replay_integrity` without a write. Account history exposes bounded metadata only; opening an entry fetches and verifies its challenge and state. Browser storage loss can therefore be recovered through the same account without creating a replacement run. A delayed history 401 waits until an in-flight acknowledgement or pending operation has been preserved.

The existing published legacy console uses its separate Core-owned `/api/remix/v2` guard. Its bearer is intentionally sent to the fixed same-origin guard and Core auth endpoints, and is not forwarded to the legacy game process. Core itself still rejects legacy API paths. The new arena recovery proof does not establish active simulation recovery or verified replay for that legacy service.

Lighthouse report acceptance now rejects missing, incomplete, malformed, errored, wrong-page and wrong-profile reports. It requires the actual pinned mobile/desktop measurement configuration and all four categories and five metrics. The existing thresholds and score rounding are preserved. All four retained real reports pass structural validation; their existing performance failures still fail acceptance: SkillCred 70/92 and Games mobile TBT 553.5 ms against 500 ms. No new public audit or performance improvement is claimed.

See [the active-run contract and recovery evidence](REMIX-ACTIVE-RECOVERY-2026-10-17.md), [current published-release evidence](BRIEF-COMPLETION-2026-10-17.md), and [draft PR #128](https://github.com/osmanosmanov6880-bot/osgard-world/pull/128). The exact new commit/tree and its fresh CI results belong to the PR; previous-head checks are historical evidence.

## Local verification of this stage

| Check | Result |
| --- | --- |
| All 25 Python families listed by Integrated Quality Suite | 442 passed, no failures or skips; includes 37 service, 5 history HTTP and 4 active recovery tests |
| Complete REMIX UI regression suite | 14 passed, no failures; four new history cases and all ten existing auth/retry/restore/polling cases |
| Combined desktop/mobile ecosystem browser suite | 86 passed, six profile-specific skips, no retries (`--retries=0`); both portal and incoming owned-console suites retained |
| Targeted integration commands | Nine passed; the game-interface gate executes guest/owned request boundaries instead of its obsolete blanket Core-token prohibition |
| Active run: process kill, restart, snapshot restore and continuation | 12 checks, 81 HTTP responses, four processes, one SIGKILL; final result and full replay equal the uninterrupted run |
| Old/new service compatibility probe | 15 serialized responses and all four arena tables equal after continuing old-created SQLite; no schema migration |
| Lighthouse report regression suite | 20 passed; actual saved reports remain valid and retain their failing performance outcomes |
| TypeScript and production build | Passed |

The 390 px mobile history screenshot was inspected; the 21-run pagination case checks the bounded scrolling panel, unique rows and absence of horizontal overflow. Test accounts and restored databases are isolated local fixtures. Only the sanitized recovery JSON is retained as source evidence or uploaded by CI; database/session material is excluded.

## Acceptance gates

- Integrated safety CI on consolidated head: required, green
- Full real-site build, ZIP archive and 19 game route contract: required, green
- Read-only live GitHub audit of PR #128: required, with exact event head, actual master ref and inclusion of all current dependency heads #107–127; see [the consolidated audit mode](LIVE-RELEASE-PR-AUDIT.md)
- Every prior stacked PR: draft, open, based on its expected parent, and its current head included in the consolidated candidate. Independent chain-merge readiness remains a separate default audit and can stay blocked after master advances
- Production deploy workflows on `master`: inspect and evaluate before merging; at least `deploy-frontend.yml` has filtered push-to-master triggers
- External staging and physical-device acceptance: separately required for launch; local browser/HTTP checks do not stand in for those environments
- Core and active arena restoration: real isolated HTTP/backup drills are demonstrated; production-backup rehearsal and operator signoff remain separate

## Consolidation policy

Use this single draft PR against `master` for a complete reviewer diff. **Do not independently merge the subordinate PR chain #107–127 AND this rollup**, as it overlaps the same commits. The rollup is for review, staging approval and rollback planning, NOT automatic production release. Do not close subordinate PRs or merge until the release operator reviews deployment-triggering workflow conditions.

## Reproduction

```sh
python3 -m unittest discover -s tests -p 'test_*.py' -v
npm ci
npm run build
npm run qa:zion-local
npm run qa:remix-ui
npm run qa:lighthouse-reports
npm run qa:remix-recovery -- --work-dir /tmp/osgard-remix-review --report /tmp/osgard-remix-review.json
```

Review in GitHub PR checks for complete release-bundle acceptance and SHA binding.

## Stop conditions

- Any check fails or is missing
- The consolidated candidate's live state is null/unmergeable, its head/base changes during audit, a dependency is retargeted or absent from candidate history, or the latest master is not included
- Release zip checksums or manifest mismatch
- Stage origin is unverified or staging HTTP missing
- No operator rollback/recovery signoff
- Push-to-master deploy effects not reviewed

Status: `DRAFT_FOR_REVIEW`; merged=false; production_deployed=false; payments_activated=false.
