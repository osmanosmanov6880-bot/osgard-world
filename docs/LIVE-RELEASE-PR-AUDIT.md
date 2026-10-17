# Live PR chain audit — 2026-10-17

**Purpose.** Eliminate trust in hand-entered snapshots of PR metadata for #107–124. `scripts/live-release-pr-audit.py` requests each pull request from the canonical GitHub REST API over HTTPS and passes the validated fields to the established `release-pr-dependency-audit.py` policy.

Run this only from an environment with permitted outbound access to `api.github.com`:

```sh
python3 scripts/live-release-pr-audit.py --out /tmp/osgard-pr-audit-new.json
python3 -m unittest discover -s tests -p test_live_release_pr_audit.py -v
```

The audit is **read-only**, makes at most 18 PR metadata calls and never merges, deploys or changes branch settings. It blocks redirects, foreign repository data, mismatched PR numbers and oversized responses. Its output uses exclusive creation (`open("x")`) to avoid clobbering older audit reports.

**Known boundaries.** The policy intentionally blocks when GitHub reports `mergeable: null`, when a PR has been retargeted, or when one PR isn't in draft state. GitHub can transiently return null during mergeability computation; rerun rather than treating null as proof. The report contains no signed attestation and is not authorization to merge.

**Release risks.** PR #107 already aggregates the earlier #103–106 work. `.github/workflows/deploy-frontend.yml` can deploy on pushes to master matching its path filters. No merge or production deploy should follow merely from a successful audit.

## Live verification on 2026-10-17

The connected GitHub API was queried for every PR #107–124. All eighteen were open, marked draft, reported mergeable=true and retained their exact expected base refs. This establishes a point-in-time dependency map, not permission to merge. Before merge, re-fetch live state and compare immutable SHAs; `master` push can trigger deployment.
