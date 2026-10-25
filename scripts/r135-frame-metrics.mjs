// W12. Frame CALLBACK timing in a visible browser. This is NOT GPU frame time.
// Unit tests may use synthetic fixtures; only actual on-device raw samples can
// be evidence about a specific user-attested physical device.
export function summarizeRafIntervalsMs(values) {
  if (!Array.isArray(values) || values.length < 120)
    throw new Error('Not enough visible, consecutive rAF intervals: at least 120 required')
  if (values.some(x => typeof x !== 'number' || !Number.isFinite(x) || x <= 0 || x > 5000))
    throw new Error('Invalid frame interval: do not discard stalls or invent samples')
  const sorted = [...values].sort((a,b) => a - b)
  const quantile = p => sorted[Math.floor((sorted.length - 1) * p)]
  const slowCount = Math.max(1, Math.ceil(sorted.length * .01))
  const worst = sorted.slice(-slowCount)
  const worstMean = worst.reduce((sum,x) => sum + x, 0) / worst.length
  const sum = sorted.reduce((total,x) => total + x, 0)
  return {
    interval_count: sorted.length,
    sum_visible_interval_ms: Number(sum.toFixed(3)),
    p50_interval_ms: Number(quantile(.5).toFixed(3)),
    p95_interval_ms: Number(quantile(.95).toFixed(3)),
    p99_interval_ms: Number(quantile(.99).toFixed(3)),
    maximum_interval_ms: Number(sorted.at(-1).toFixed(3)),
    callback_pacing_one_percent_low_fps: Number((1000 / worstMean).toFixed(2)),
    worst_one_percent_interval_count: slowCount,
    fraction_intervals_over_33_3ms: Number((values.filter(x => x > 33.333).length / values.length).toFixed(4)),
    fraction_intervals_over_50ms: Number((values.filter(x => x > 50).length / values.length).toFixed(4)),
    metric_scope: 'visible-page requestAnimationFrame callback pacing; NOT actual Godot/GPU render-completion frametimes'
  }
}
