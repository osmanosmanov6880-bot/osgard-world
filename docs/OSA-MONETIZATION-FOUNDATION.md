# OSA Monetization Foundation

## Purpose

Prepare a credible, bilingual commercial offer for OSA Learning without pretending that checkout, paid access, or enrollment processing already exists.

## Current public offer page

- Public offer page: `/learning/pricing`, linked from the learner dashboard.
- The page now leads with the learner outcome: understand an AI task, verify an answer against sources and a new example, and save a reviewable project.
- It describes the current self-paced program as eight practical lessons and a final project, grounded in the existing OSA lessons and server-backed Learning/Core work.
- It sends visitors to the existing free `/learning` route for immediate use.
- Russian and English formats distinguish what is available now, what is being prepared, and what is only a proposed format.
- The existing OSGARD Telegram bot is the team-discussion route. It does not create an order, collect a web form, reserve a seat, or promise delivery.
- The page explicitly states that the site does not take orders or payments, reserve seats, or grant paid access.

## Verified product boundary

Existing code and pilot documentation support eight lesson practices, knowledge self-checks, personal Core project work, saved progress, and a learner-submitted final project. They do not provide independent expert scoring or a credential. The current flow does not include an operating human mentor, a scheduled paid cohort, a live-review service, automatic lead processing, or a verified production payment path. The public page must keep these limits clear.

## Commercial model

1. **Open access** introduces the learning experience and sends learners to the existing `/learning` route.
2. **Self-paced course** is the intended first paid offer: a structured eight-practice program and a final project. It is not purchasable yet.
3. **Guided cohort** remains a future format until an instructor, dates, delivery plan, and feedback capacity are confirmed.
4. **Team pilot** starts with a scoped conversation about the organization's goal and success criteria. No fixed price or delivery commitment is published.
5. Consider an ongoing membership only after OSA can deliver recurring new programs, reviews, or community value.

Do not sell a completion badge as an accredited credential. Do not promise employment, income, or business results without evidence.

## Price validation

The displayed USD values `$79` and `$499` are validation hypotheses, not approved or active public offers. Do not enable checkout or present them as payable prices before an operator approves the product scope, localized terms, support plan, and provider setup. Track conversion alongside project completion, learner outcomes, refunds, and support load. Raise price only when the delivered value and evidence improve.

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

## Next monetization experiment

1. Route interested learners to the existing free lessons and measure lesson starts and completions.
2. Invite team prospects to discuss one target workflow, baseline, and acceptance criteria through the existing contact bot.
3. Use those conversations to validate audience, willingness to pay, and the smallest deliverable program.
4. Open a paid learner pilot only after curriculum, human support, commercial terms, and checkout are ready.
5. Compare contribution after refunds, compute, payment fees, mentors, and variable support.

## Verification

Run:

```sh
npm run qa:osa-monetization
npm run check
npm run build
```

CI must pass on the updated master. Paid transactions remain disabled until the payment release gates above are implemented and reviewed.
