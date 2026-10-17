# Live PR chain audit — 2026-10-17

**Purpose.** Eliminate trust in hand-entered snapshots of PR metadata. The default mode of `scripts/live-release-pr-audit.py` requests PRs #107–124 from the canonical GitHub REST API over HTTPS and passes the validated fields to the established `release-pr-dependency-audit.py` policy. A separate explicit mode verifies consolidated draft PR #128 and inclusion of all current dependency heads #107–127.

## Consolidated draft review

After master advanced through PRs #129–131, the original PR #107 became independently unmergeable. The consolidated candidate already contains its work and the later master changes. The old chain audit correctly continues to block a standalone chain merge; that result does not describe the ancestry or mergeability of PR #128.

For the single consolidated review, use the event's immutable **PR head SHA**, not the synthetic `GITHUB_SHA` used by GitHub Actions checkout:

```sh
python3 scripts/live-release-pr-audit.py --consolidated-pr 128 --expected-head <40-character-pr-head-sha> --repository .
```

This mode accepts only the canonical repository, PR #128, head branch `integration/consolidated-release-candidate-2026-10-17`, and base `master`. The live candidate must be open, draft, unmerged, explicitly mergeable, and have the expected head. It checks the live draft dependency chain #107–127 and verifies every unique current head as an ancestor of that exact candidate. It reads the actual `master` Git ref and requires it to be included as well. Independent mergeability of those already included subordinate PRs is not used as evidence for the consolidated candidate.

The repository must contain full history. Read-only Git checks reject missing commits, shallow history, grafts/replacements, ancestry failures, and a checkout that does not contain the candidate with the same tree. A clean synthetic PR merge is accepted only when these checks hold. All dependency metadata, the candidate and master are fetched again after the ancestry checks; any observed movement or unconfirmed candidate state blocks the result. The successful path performs 46 bounded API reads. API errors, redirects, foreign repository data, changed dependency refs, malformed records and oversized responses also block it.

CI supplies its GitHub token with explicit `contents: read` and `pull-requests: read` permissions through `OSGARD_PR_AUDIT_TOKEN` to avoid the low unauthenticated request quota. It is used only in the canonical API request header and is omitted from reports. No write permission is granted. Local use can omit the token; rate-limit errors block the audit instead of accepting stale data. The two matching observations are review evidence, not an atomic snapshot of all GitHub refs or a guarantee against later movement.

The separate success status is `ready_for_consolidated_review`, with immutable head/master/dependency and checkout evidence. It does **not** mark the original chain ready. Both modes report `merge_performed: false` and `deploy_performed: false`; neither authorizes a merge or deployment. CI uses this mode only for PR #128 and keeps the default chain audit for other pull requests.

## Original independent chain review

Run this only from an environment with permitted outbound access to `api.github.com`:

```sh
python3 scripts/live-release-pr-audit.py --out /tmp/osgard-pr-audit-new.json
python3 -m unittest discover -s tests -p test_live_release_pr_audit.py -v
```

The default chain audit is **read-only**, makes at most 18 PR metadata calls and never merges, deploys or changes branch settings. It blocks redirects, foreign repository data, mismatched PR numbers and oversized responses. Its output uses exclusive creation (`open("x")`) to avoid clobbering older audit reports.

**Known boundaries.** The policy intentionally blocks when GitHub reports `mergeable: null`, when a PR has been retargeted, or when one PR isn't in draft state. GitHub can transiently return null during mergeability computation; rerun rather than treating null as proof. The report contains no signed attestation and is not authorization to merge.

**Release risks.** PR #107 already aggregates the earlier #103–106 work. `.github/workflows/deploy-frontend.yml` can deploy on pushes to master matching its path filters. No merge or production deploy should follow merely from a successful audit.

## Earlier live verification on 2026-10-17

The connected GitHub API was queried for every PR #107–124. At that earlier point all eighteen were open, marked draft, reported mergeable=true and retained their exact expected base refs. This historical snapshot is superseded for PR #107 mergeability by the later master changes described above. Before any review decision, re-fetch live state and compare immutable SHAs; a `master` push can trigger deployment.
