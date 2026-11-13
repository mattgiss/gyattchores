#!/usr/bin/env node
// Generates named test scenarios for the native apps' engine ports.
//
// golden.js checks the ports against one big random history. This adds small,
// named cases aimed at the rules that are easy to get subtly wrong: sync
// duplicates, midnight boundaries, the minutes fallbacks, escalation tiers,
// streak breaks, and the admin-code hash. Like golden.js it lifts the engine
// straight out of index.html and records the web app's own answers.
//
//   node native/tools/scenarios.mjs
//
// Writes native/fixtures/engine-scenarios.json. Re-run whenever the engine in
// index.html changes; a failing native test then names the case that drifted.

process.env.TZ = 'UTC';   // fixtures are defined in UTC; native tests use a UTC calendar

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');   // repo root
const html = readFileSync(resolve(root, 'index.html'), 'utf8');

// ── Lift the engine out of index.html ────────────────────────────────────────
const between = (startMarker, endMarker) => {
  const s = html.indexOf(startMarker), e = html.indexOf(endMarker);
  if (s < 0 || e < 0 || e <= s) throw new Error(`engine markers not found: ${startMarker} … ${endMarker}`);
  return html.slice(s, e);
};
const hashLine = html.split('\n').find(l => l.startsWith('const hashCode'));
const adminLine = html.split('\n').find(l => l.startsWith('const ADMIN_CODE_HASH'));
if (!hashLine || !adminLine) throw new Error('hashCode / ADMIN_CODE_HASH not found');
const engineSrc = between('// ─── PLAYERS', '// ─── CHORE ROW');

const NOW = Date.UTC(2026, 10, 11, 15, 30, 0);   // frozen clock: 2026-11-11T15:30:00Z
const DAY = 86400000;
class FrozenDate extends Date {
  constructor(...a) { if (a.length === 0) super(NOW); else super(...a); }
  static now() { return NOW; }
}
const store = new Map();
const localStorage = { getItem: k => store.get(k) ?? null, setItem: (k, v) => store.set(k, v), removeItem: k => store.delete(k) };

const E = new Function('Date', 'localStorage', `
  const STORAGE_KEY = 'gyattchores_logs';
  ${hashLine}
  ${adminLine}
  ${engineSrc}
  return { PLAYERS, CHORE_POOL, DAILY_MINUTES, LOG_DAYS, ADMIN_CODE_HASH, hashCode,
           neglectDays, enrichChore, pickableChores, suggestFill,
           momentumMult, xpToNext, getXP, toVersion, getRank, getStreak,
           choreMinutes, minutesByDay, recentDays };
`)(FrozenDate, localStorage);

// ── Deterministic scenario builders ──────────────────────────────────────────
const mulberry32 = seed => () => {
  seed |= 0; seed = seed + 0x6D2B79F5 | 0;
  let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
  t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
  return ((t ^ t >>> 14) >>> 0) / 4294967296;
};
const midnight = daysAgo => Date.UTC(2026, 10, 11) - daysAgo * DAY;
let seq = 0;
const log = (player, choreId, daysAgo, { status = 'approved', minutes, msIntoDay = 12 * 3600000, points } = {}) => {
  const c = E.CHORE_POOL.find(c => c.id === choreId);
  const l = {
    id: `fx_${++seq}`, playerId: player.id, playerName: player.name,
    choreId, choreName: c ? c.name : choreId,
    points: points ?? (c ? c.pts : 7),
    timestamp: midnight(daysAgo) + msIntoDay, status,
  };
  if (minutes !== undefined) l.minutes = minutes;
  return l;
};
const [P1, P2] = E.PLAYERS;
const ids = E.CHORE_POOL.map(c => c.id);

const scenarios = [];
const add = (name, logs) => scenarios.push({ name, logs });

add('empty', []);

add('single approved today', [log(P1, 'make-bed', 0, { minutes: 3 })]);

add('pending and rejected never count', [
  log(P1, 'make-bed', 0, { status: 'pending', minutes: 3 }),
  log(P1, 'scrub-toilet', 0, { status: 'rejected', minutes: 5 }),
  log(P2, 'dog-poop', 1, { status: 'pending', minutes: 5 }),
]);

{ // 14-day unbroken streak for P1 (momentum caps at 2x), sporadic P2
  const logs = [];
  for (let d = 0; d < 14; d++) {
    ['load-dishwasher', 'sweep-kitchen', 'wipe-counters', 'fold-laundry'].forEach((id, i) =>
      logs.push(log(P1, id, d, { minutes: [5, 6, 4, 10][i], msIntoDay: (16 + i) * 3600000 })));
  }
  [0, 1, 4, 5, 6, 11].forEach(d => logs.push(log(P2, 'vacuum-living-room', d, { minutes: 10 })));
  add('14-day streak vs sporadic', logs);
}

add('streak broken: nothing today', [
  log(P1, 'make-bed', 1, { minutes: 3 }), log(P1, 'make-bed', 2, { minutes: 3 }), log(P1, 'make-bed', 3, { minutes: 3 }),
]);

add('sync duplicates collapse to one per chore per day', [
  log(P1, 'scrub-toilet', 0, { minutes: 9, msIntoDay: 10 * 3600000 }),
  log(P1, 'scrub-toilet', 0, { minutes: 5, msIntoDay: 11 * 3600000 }),   // duplicate row, different minutes
  log(P1, 'scrub-toilet', 0, { msIntoDay: 12 * 3600000 }),               // duplicate row, no minutes
  log(P1, 'scrub-toilet', 1, { minutes: 5 }),
  log(P1, 'make-bed', 0, { minutes: 3 }),
]);

add('minutes fallbacks: base tier, then points', [
  log(P1, 'fold-laundry', 0),                                  // no minutes -> base tier 10
  log(P1, 'vacuum-living-room', 0),                            // no minutes -> base tier 10
  log(P1, 'retired-chore', 0, { points: 7 }),                  // unknown chore -> points
  log(P1, 'scrub-toilet', 0, { minutes: 15 }),                 // explicit escalated minutes
  log(P2, 'retired-chore', 0, { points: 30 }),
]);

add('midnight boundaries', [
  log(P1, 'make-bed', 0, { minutes: 3, msIntoDay: 0 }),                 // 00:00:00.000 today
  log(P1, 'dog-poop', 1, { minutes: 5, msIntoDay: DAY - 1 }),           // 23:59:59.999 yesterday
  log(P1, 'water-plants', 2, { minutes: 4, msIntoDay: 1 }),
  log(P2, 'make-bed', 29, { minutes: 3, msIntoDay: 0 }),                // oldest day in the 30-day window
  log(P2, 'dog-poop', 30, { minutes: 25, msIntoDay: DAY - 1 }),         // just outside the window
]);

add('escalation tiers', [
  log(P1, 'wipe-dining-table', 1, { minutes: 4 }),    // tierDays [0,1,3]: 1 day  -> tier 1
  log(P1, 'dog-poop', 3, { minutes: 5 }),             // tierDays [0,1,3]: 3 days -> tier 2
  log(P1, 'scrub-toilet', 2, { minutes: 5 }),         // tierDays [0,3,7]: 2 days -> tier 0
  log(P1, 'wipe-microwave', 8, { minutes: 3 }),       // tierDays [0,4,8]: 8 days -> tier 2
  log(P1, 'make-bed', 0, { minutes: 3, msIntoDay: 15 * 3600000 + 29 * 60000 }),   // done a minute ago
]);

for (const seed of [1, 7, 42]) {   // long random histories: every rule interacting at once
  const rnd = mulberry32(seed), logs = [];
  for (let d = 0; d < 75; d++) for (const p of [P1, P2]) {
    if (rnd() < (p === P1 ? 0.25 : 0.5)) continue;
    const n = 1 + Math.floor(rnd() * 6), used = new Set();
    for (let k = 0; k < n; k++) {
      const id = rnd() < 0.04 ? 'retired-chore' : ids[Math.floor(rnd() * ids.length)];
      if (used.has(id) && rnd() < 0.8) continue;   // mostly unique, occasionally a duplicate row
      used.add(id);
      const c = E.CHORE_POOL.find(c => c.id === id);
      const r = rnd();
      const status = r < 0.8 ? 'approved' : r < 0.9 ? 'pending' : 'rejected';
      const minutes = rnd() < 0.3 || !c ? undefined : c.tiers[Math.floor(rnd() * 3)];
      logs.push(log(p, id, d, { status, minutes, msIntoDay: Math.floor(rnd() * DAY) }));
    }
  }
  add(`random history seed ${seed}`, logs);
}

// ── Ask the web engine for the answers ───────────────────────────────────────
const newestFirst = logs => [...logs].sort((a, b) => b.timestamp - a.timestamp);   // loadLogs() order

const out = {
  generatedFrom: 'index.html',
  now: NOW,
  timeZone: 'UTC',
  dailyMinutes: E.DAILY_MINUTES,
  logDays: E.LOG_DAYS,
  adminCodeHash: E.ADMIN_CODE_HASH,
  players: E.PLAYERS,
  chorePool: E.CHORE_POOL,
  hashVectors: ['', 'a', '1234', 'gyatt', 'GYATTCHORES', 'pässwörd ✓', '0000', 'correct horse battery staple']
    .map(input => ({ input, hash: E.hashCode(input) })),
  versions: Array.from({ length: 35 }, (_, i) => ({ level: i + 1, version: E.toVersion(i + 1), xpToNext: E.xpToNext(i + 1) })),
  momentum: Array.from({ length: 14 }, (_, i) => ({ streak: i, mult: E.momentumMult(i) })),
  ranks: [0, 1, 59, 60, 61, 139, 140, 500, 1234, 9999, 123456].map(xp => ({ xp, ...E.getRank(xp) })),
  scenarios: scenarios.map(({ name, logs }) => {
    const sorted = newestFirst(logs);
    const days = E.recentDays();
    return {
      name,
      logs: sorted,
      players: E.PLAYERS.map(p => {
        const pool = E.pickableChores(p.id, sorted);
        const byDay = E.minutesByDay(p.id, sorted);
        const pickSets = [[], [pool[0].id], [pool[pool.length - 1].id], ['fold-laundry', 'make-bed'], ['scrub-toilet', 'sweep-bathroom', 'dog-poop']];
        return {
          playerId: p.id,
          xp: E.getXP(p.id, sorted),
          streak: E.getStreak(p.id, sorted),
          minutesByDay: days.map(d => byDay[d] || 0),
          pickable: pool.map(c => ({ id: c.id, neglectDays: c.neglectDays, currentMinutes: c.currentMinutes, escalLevel: c.escalLevel })),
          fills: pickSets.map(picked => ({ picked, result: E.suggestFill(picked, pool, E.DAILY_MINUTES) })),
        };
      }),
    };
  }),
};

const targets = [
  'native/fixtures/engine-scenarios.json',
];
for (const t of targets) {
  const path = resolve(root, t);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(out, null, 1) + '\n');
  console.log(`wrote ${t} — ${out.scenarios.length} scenarios, ${out.scenarios.reduce((s, x) => s + x.logs.length, 0)} logs`);
}
