/* R62: classify a REAL Godot autopilot button acknowledgement.
 * The software WebGL renderer can stall telemetry beyond a 10s polling
 * window; the action is confirmed ONLY after exactly one Godot pressed
 * event AND the requested flight state. A late ack is valid, not a rejection.
 */
export function cruiseClickAck(before, observed, desired) {
  if (!observed) return 'pending';
  if (typeof desired !== 'boolean' ||
      typeof observed.cruise !== 'boolean') return 'invalid';
  const initial = Number(before?.cruise_button_events);
  const actual = Number(observed?.cruise_button_events);
  if (!Number.isSafeInteger(initial) || initial < 0 ||
      !Number.isSafeInteger(actual) || actual < 0) return 'invalid';
  if (actual < initial) return 'invalid'; // engine reset, no fabricated pass
  if (actual === initial) return 'pending';
  if (actual > initial + 1) return 'duplicate'; // real double click
  return observed.cruise === desired ? 'confirmed' : 'rejected';
}
