export type OSAEventName = 'learning_dashboard_view' | 'learning_assessment_view' | 'learning_assessment_submitted'
export type OSAEvent = { event: OSAEventName; timestamp: string; properties?: Record<string, string | number | boolean> }

/** Explicitly opt-in, privacy-first event hook. No analytics service or user identifier is configured. */
export function trackOSAEvent(event: OSAEventName, properties?: OSAEvent['properties']): void {
  if (typeof window === 'undefined') return
  try {
    window.dispatchEvent(new CustomEvent<OSAEvent>('osa:analytics', { detail: { event, timestamp: new Date().toISOString(), properties } }))
  } catch { /* Analytics must never block learning. */ }
}
