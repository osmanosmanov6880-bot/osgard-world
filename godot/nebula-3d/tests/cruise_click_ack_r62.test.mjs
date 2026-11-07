import test from 'node:test';
import assert from 'node:assert/strict';
import {cruiseClickAck} from './cruise_click_ack_r62.mjs';

test('R62: actual one-event delayed cruise ON is confirmed, not timed out', () => {
  const before = {cruise: false, cruise_button_events: 1};
  assert.equal(cruiseClickAck(before,
    {cruise: false, cruise_button_events: 1}, true), 'pending');
  assert.equal(cruiseClickAck(before,
    {cruise: true, cruise_button_events: 2}, true), 'confirmed');
});
test('R62: actual late one-event cruise OFF is a valid action', () => {
  const before = {cruise: true, cruise_button_events: 1};
  assert.equal(cruiseClickAck(before,
    {cruise: true, cruise_button_events: 1}, false), 'pending');
  // Exact real GitHub R62 failure: state changed to false on event #2.
  assert.equal(cruiseClickAck(before,
    {cruise: false, cruise_button_events: 2}, false), 'confirmed');
});
test('R62: state-only spoof never substitutes for real Godot button', () => {
  assert.equal(cruiseClickAck({cruise_button_events: 0},
    {cruise: true, cruise_button_events: 0}, true), 'pending');
  assert.equal(cruiseClickAck({cruise_button_events: 0},
    {cruise: false, cruise_button_events: 0}, false), 'pending');
});
test('R62: real rejected button is not counted as a pass', () => {
  assert.equal(cruiseClickAck({cruise_button_events: 4},
    {cruise: false, cruise_button_events: 5}, true), 'rejected');
  assert.equal(cruiseClickAck({cruise_button_events: 4},
    {cruise: true, cruise_button_events: 5}, false), 'rejected');
});
test('R62: double activation and engine telemetry reset fail closed', () => {
  assert.equal(cruiseClickAck({cruise_button_events: 1},
    {cruise: true, cruise_button_events: 3}, true), 'duplicate');
  assert.equal(cruiseClickAck({cruise_button_events: 8},
    {cruise: false, cruise_button_events: 1}, false), 'invalid');
  assert.equal(cruiseClickAck({cruise_button_events: 'bad'},
    {cruise: true, cruise_button_events: 2}, true), 'invalid');
  assert.equal(cruiseClickAck({cruise_button_events: 0},
    {cruise: 'true', cruise_button_events: 1}, true), 'invalid');
});
test('R62: no telemetry remains pending, never a fake success', () => {
  assert.equal(cruiseClickAck({cruise_button_events: 0},null,true),'pending');
});
