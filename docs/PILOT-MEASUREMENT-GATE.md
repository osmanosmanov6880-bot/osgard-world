# OSGARD — Pilot Measurement Gate v1
**Status:** preparation for a real pilot, NOT observed market results.

This isolated standard-library utility measures the commercial and educational claims from the October 17 master plan without touching production, personal account information, Stripe, or Core databases.

## Input
Provide UTF-8 CSV with exactly one `baseline` and one `pilot` record for each task identifier. Required columns:

```csv
task_id,variant,elapsed_minutes,completed,human_minutes,corrections,revenue,refunds,compute_cost,payment_fees,mentor_cost,support_cost,novel_skill_pass
task-01,baseline,30,true,5,1,0,0,0,0,0,0,
task-01,pilot,10,true,1,0,5,0,1,0,1,1,true
```

All amounts must use the **same currency**, documented outside the CSV. Time and monetary values are nonnegative; corrections are whole numbers. A missing variable cost is **an error, not zero**. An explicit zero means a real verified zero, not an unknown estimate. `novel_skill_pass` may be empty (unknown), but incomplete skill evidence blocks a scale decision. Use pseudonymous task IDs, never names or email addresses. Do not place real commercial/customer records in GitHub.

## Execute
```sh
python3 scripts/pilot-scorecard.py /secure/path/pilot.csv --output /secure/path/scorecard.json
python3 -m unittest discover -s tests -p test_pilot_scorecard.py -v
```

The tool uses paired tasks and rejects duplicate observations and malformed numeric data. Scale readiness requires at least **20 fully paired tasks**, no unpaired records, pilot completion >=85%, >=3x median time reduction measured on at least 20 mutually completed task pairs, positive pilot variable contribution, and recorded novel-task outcomes. This gate is intentionally strict: a smaller sample or any missing measurement is **not evidence of success**.

## Measurement protocol
1. Define one representative audience and a fixed task set before testing. Document task difficulty, eligibility, time limit, assistance rules, and how participants are assigned to baseline/pilot. Randomization or a credible matched design is required for causal claims.
2. Begin timing at the same trigger for both variants; stop only at the same acceptance criterion. Record failures as `completed=false`, not omitted data.
3. Capture human assistance, corrections, compute use, payment fees, mentor time, refunds and variable support with receipts or exportable system evidence. Blind-review task acceptance when possible.
4. Use a previously unseen skill exercise for `novel_skill_pass`; retain a separate pre-test/control for genuine improvement claims. Simply recording post-test pass rates does not demonstrate learning gain.
5. Preserve source evidence, pilot design, timestamp, currency, version and a SHA-256 digest of the input **in a private controlled workspace**. Review failed tasks and missing data before scaling.
6. Do not enable production payments or claim a successful commercial pilot solely because this scorecard has passing synthetic tests.

## Risks and decisions
- **Secret rotation:** the SSH private key previously pasted in chat must be treated as compromised. Remove its public key from the server and CI authorized access after confirming a replacement deploy identity; rotate related credentials as appropriate. This change does NOT perform rotation.
- **Payment gate:** real merchant selection, signed webhook verification against that merchant's test environment, explicit refund acceptance and legal/commercial review are independent required approvals.
- **Low sample / selection bias:** successful-pair speedup can overstate benefits; completion rate and unresolved failures are shown separately.
- **Ownership:** OSGARD Supreme Director approves the experiment and access to real data; Learning owns educational rubric; Commerce owns unit costs; Core owns access and audit boundaries.
