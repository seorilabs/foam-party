import { describe, expect, it } from 'vitest'
import {
  buildMpRequestBody,
  ga4SessionId,
  parseParams,
  sanitizeEventName,
  sanitizeParamName,
} from './firebaseRuntime'

describe('sanitizeParamName', () => {
  it('lowercases and replaces non [a-z0-9_] with underscore', () => {
    expect(sanitizeParamName(' Ad Group ID! ')).toBe('ad_group_id_')
  })
})

describe('sanitizeEventName', () => {
  it('caps the GA4 event name at 40 chars', () => {
    expect(sanitizeEventName('e'.repeat(50))).toHaveLength(40)
  })
})

describe('parseParams', () => {
  it('keeps only scalar params and sanitizes keys', () => {
    expect(parseParams('{"Level":3,"nested":{"x":1},"ok":true}')).toEqual({
      level: 3,
      ok: true,
    })
  })

  it('returns {} for invalid JSON', () => {
    expect(parseParams('not json')).toEqual({})
  })
})

describe('buildMpRequestBody', () => {
  it('wraps the event with session_id + engagement_time_msec so GA4 counts an engaged session', () => {
    const body = JSON.parse(buildMpRequestBody('cid-1', 'level_complete', { level: '3' }, 'sess-1'))
    expect(body).toEqual({
      client_id: 'cid-1',
      events: [
        {
          name: 'level_complete',
          params: { level: '3', session_id: 'sess-1', engagement_time_msec: 100 },
        },
      ],
    })
  })
})

describe('ga4SessionId', () => {
  it('reuses the id within the 30-min window and rolls after inactivity', () => {
    const base = 1_000_000
    const first = ga4SessionId(base)
    // +5 min: still the same session.
    expect(ga4SessionId(base + 5 * 60 * 1000)).toBe(first)
    // +40 min since the last event: a fresh session id.
    expect(ga4SessionId(base + 45 * 60 * 1000)).not.toBe(first)
  })
})
