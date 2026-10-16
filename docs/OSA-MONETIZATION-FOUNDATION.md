# OSA Monetization Foundation

## Purpose

Prepare a credible, bilingual commercial offer for OSA Learning without pretending that checkout, paid access, or enrollment processing already exists.

## Implemented in this branch

- Public offer page at \`/learning/pricing\`, linked from the learner dashboard.
- Russian and English copy for four offer levels: open access, self-paced course, guided cohort, and team pilot.
- Proposed validation prices: USD 79 for a self-paced program and USD 499 for a guided cohort. These are hypotheses, not approved or active public offers.
- Offer framing based on practical assignments, a final project, feedback, and a measurable team pilot.
- Explicit launch-state disclosure: no order, payment, seat reservation, or paid access is currently available.
- Smoke check registered as \`npm run qa:osa-monetization\` and added to the OSA quality workflow.

## Commercial model

1. **Open access** introduces the learning experience and sends learners to the existing \`/learning\` route.
2. **Self-paced course** is a one-time purchase for a structured program and a final project.
3. **Guided cohort** adds scheduled group reviews and instructor feedback.
4. **Team pilot** scopes one organization's skill objective, baseline assessment, practice, and outcome report.
5. Consider an ongoing membership only after OSA can deliver recurring new programs, reviews, or community value.

Do not sell a completion badge as an accredited credential. Do not promise employment, income, or business results without evidence.

## Release gates before taking payment

- Choose and configure an approved payment provider and supported merchant account.
- Implement server-side checkout creation and verified signed webhooks.
- Persist orders, refunds, subscriptions, and entitlements in server-owned storage.
- Gate paid materials on server-verified entitlements; never trust a browser flag.
- Define cancellation, refund, renewal, tax, and customer-support flows.
- Add duplicate-webhook/idempotency handling, audit records, and reconciliation.
- Test success, decline, cancellation, refund, webhook retry, and expired access in the provider's test environment.
- Have an operator review the final localized public price and offer terms.
- Run production checks before enabling purchase buttons.

## Price validation

Treat the displayed USD values as internal experiment candidates. Interview target learners and run a small paid cohort before making them active prices. Track conversion alongside project completion, learner outcomes, refunds, and support load. Raise price only when the delivered value and evidence improve.

## Verification

Run:

\`\`\`sh
npm run qa:osa-monetization
npm run check
npm run build
\`\`\`

CI must pass on the updated feature branch. The production site and paid transactions remain unchanged until the payment release gates above are implemented and reviewed.
