# HORIZON R26 — OSGARD Play page layout stabilization
Source failure: CI workflow 40109265663, job 120917573397.

Real mobile laboratory recorded initial-load CLS 0.2998129232013242, above
the hard budget of 0.10, while loading /play under emulated 3G and 4x
CPU slowdown, viewport 390x844. This is NOT a physical-device Core Web
Vitals percentile (p75), and we do not claim that it is.

The Playwright trace's PerformanceObserver records the dominant shift
at 2160 ms and reveals the precise source:
- before: FOOTER.brand-footer at y=590.797, height=253.203;
- after: FOOTER removed from visible viewport as the lazy game page mounts.
- React PlayHome hero min-height is 960px on <=600px phones.
- OsgardRouteSkeleton reserved only 70svh (approximately 591px on this viewport).

Fix: match the loading-skeleton footprint to the actual Play hero at
desktop, tablet and phone breakpoints; other product routes retain
their own existing route-skeleton dimensions. No fake metrics, disabled
transitions, blocked links or CLS-budget changes.

Dedicated native Chromium mobile lab must retain CLS <=0.10 and verify
the primary action. General 270-test browser suite remains required; its
INHERIT R12 test failure is separately tracked and must not be dismissed
as proof of an Omega gameplay defect.
