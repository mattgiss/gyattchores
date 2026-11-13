// Generates the levels for the chore-reward puzzle ("BLOCK OUT") shared by the iOS and Android apps.
//
//   node native/tools/puzzles.mjs
//
// writes
//   native/puzzles.json                       the level pack both apps ship
//   android/app/src/main/assets/puzzles.json  the same file, where the Android build picks it up
//   native/fixtures/puzzle-scenarios.json     test data: a solution and a random-play trace per
//                                             level, which both engines replay to prove they agree
//
// The rules: the board holds pink (P) and black (K) blocks, plus walls (#) on later levels. Tap one
// block, then a block of the other colour in the same row or column with nothing between them, and
// both disappear. Clear the board to level up. Blocks stand in each other's way, and a block can
// usually pair with more than one partner, so the order you clear them in decides whether you win.
//
// Every level is built backwards from a solution, so every level can be cleared. The pair placed
// first is the last one cleared: its line only has to be clear of the pairs already on the board,
// and pairs placed after it may sit on that line, which is what forces an order. A solver then
// works out how likely random tapping is to clear the board, and that number orders the difficulty.
//
// Output is deterministic (a seeded random generator), so CI can regenerate and diff.

import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const LEVELS = 200;

// ─── Rules ───────────────────────────────────────────────────────────────────

const opposite = (a, b) => (a === 'P' && b === 'K') || (a === 'K' && b === 'P');

/** True when the blocks at a and b can be matched on this board. */
function canMatch(cells, w, a, b) {
  if (a === b || !opposite(cells[a], cells[b])) return false;
  const ax = a % w, ay = Math.floor(a / w), bx = b % w, by = Math.floor(b / w);
  let step;
  if (ay === by) step = bx > ax ? 1 : -1;
  else if (ax === bx) step = by > ay ? w : -w;
  else return false;
  for (let i = a + step; i !== b; i += step) if (cells[i] !== '.') return false;
  return true;
}

/** Every legal match, each pair once, as [smaller index, larger index], in index order. */
function moves(cells, w) {
  const out = [];
  for (let a = 0; a < cells.length; a++) {
    if (cells[a] !== 'P' && cells[a] !== 'K') continue;
    for (let b = a + 1; b < cells.length; b++) if (canMatch(cells, w, a, b)) out.push([a, b]);
  }
  return out;
}

const remove = (cells, [a, b]) => { const c = cells.slice(); c[a] = '.'; c[b] = '.'; return c; };
const blocksLeft = cells => cells.reduce((n, c) => n + (c === 'P' || c === 'K'), 0);

// ─── Solver ──────────────────────────────────────────────────────────────────

/**
 * The chance that tapping a random legal match each turn clears the board (1 = can't lose, near 0 =
 * only careful play wins). Exact, over every reachable position.
 */
function winChance(cells, w) {
  const memo = new Map();
  const go = c => {
    const key = c.join('');
    if (memo.has(key)) return memo.get(key);
    let p;
    if (blocksLeft(c) === 0) p = 1;
    else {
      const ms = moves(c, w);
      p = ms.length === 0 ? 0 : ms.reduce((s, m) => s + go(remove(c, m)), 0) / ms.length;
    }
    memo.set(key, p);
    return p;
  };
  return go(cells);
}

// ─── Generator ───────────────────────────────────────────────────────────────

// mulberry32: small, fast, and the same numbers on every machine.
function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6D2B79F5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Size, pair count and walls for a level: the board grows and fills slowly. */
function shape(level) {
  const pairs = Math.min(2 + Math.floor((level - 1) / 5), 8);
  const w = Math.min(4 + Math.floor((level - 1) / 16), 6);
  const h = Math.min(5 + Math.floor((level - 1) / 10), 8);
  const walls = level < 15 ? 0 : Math.min(1 + Math.floor((level - 15) / 15), 5);
  return { w, h, pairs, walls };
}

/** How hard random tapping should find it: about a coin flip by level 10, rarely luck by 100. */
const target = level => level <= 3 ? 1 : Math.max(0.02, 0.85 * Math.exp(-(level - 3) / 28));

/** One random level built backwards from its solution, or null if the board filled up. */
function candidate(level, r) {
  const { w, h, pairs, walls } = shape(level);
  const cells = Array(w * h).fill('.');
  const empty = () => cells.flatMap((c, i) => (c === '.' ? [i] : []));
  for (let k = 0; k < walls; k++) { const e = empty(); cells[e[Math.floor(r() * e.length)]] = '#'; }
  const solution = [];
  for (let k = 0; k < pairs; k++) {
    // Every way to place this pair: two empty cells in line with nothing between them.
    const options = [];
    for (const a of empty()) for (const b of empty()) {
      if (b <= a) continue;
      const trial = cells.slice(); trial[a] = 'P'; trial[b] = 'K';
      if (canMatch(trial, w, a, b)) options.push([a, b]);
    }
    if (!options.length) return null;
    // Prefer placements that sit on an earlier-placed pair's line, so that pair has to wait.
    const blocks = ([a, b]) => solution.filter(([x, y]) => between(w, x, y, a) || between(w, x, y, b)).length;
    const best = Math.max(...options.map(blocks));
    const pool = r() < 0.7 ? options.filter(o => blocks(o) === best) : options;
    const [a, b] = pool[Math.floor(r() * pool.length)];
    const pinkFirst = r() < 0.5;
    cells[a] = pinkFirst ? 'P' : 'K'; cells[b] = pinkFirst ? 'K' : 'P';
    solution.unshift([a, b]);
  }
  return { w, h, cells, solution };
}

/** True when cell i lies strictly between cells a and b on their shared row or column. */
function between(w, a, b, i) {
  const ax = a % w, ay = Math.floor(a / w), bx = b % w, by = Math.floor(b / w), ix = i % w, iy = Math.floor(i / w);
  if (ay === by) return iy === ay && ix > Math.min(ax, bx) && ix < Math.max(ax, bx);
  if (ax === bx) return ix === ax && iy > Math.min(ay, by) && iy < Math.max(ay, by);
  return false;
}

function makeLevel(level) {
  const r = rng(0x9E3779B1 ^ level * 2654435761);
  const goal = target(level);
  let best = null;
  for (let tries = 0; tries < 60; tries++) {
    const c = candidate(level, r);
    if (!c) continue;
    const first = moves(c.cells, c.w).length;
    // From level 4 on there's always a choice to make on the first tap.
    if (level >= 4 && first < 2) continue;
    c.chance = winChance(c.cells, c.w);
    if (!best || Math.abs(Math.log(c.chance / goal)) < Math.abs(Math.log(best.chance / goal))) best = c;
  }
  if (!best) throw new Error(`no level ${level}`);
  return best;
}

/** A random-play game from the start: each step's legal-move count, then the move taken. */
function trace(lv, r) {
  let cells = lv.cells.slice();
  const steps = [];
  for (;;) {
    const ms = moves(cells, lv.w);
    if (!ms.length) return { steps, cleared: blocksLeft(cells) === 0 };
    const m = ms[Math.floor(r() * ms.length)];
    steps.push({ legal: ms.length, move: m });
    cells = remove(cells, m);
  }
}

// ─── Write ───────────────────────────────────────────────────────────────────

const levels = Array.from({ length: LEVELS }, (_, i) => makeLevel(i + 1));

const pack = {
  about: 'Levels for the puzzle unlocked by a submitted chore card. Generated by native/tools/puzzles.mjs; do not edit by hand.',
  version: 1,
  // Each level: width, height, and its cells row by row. P pink, K black, # wall, . empty.
  levels: levels.map(l => ({ w: l.w, h: l.h, cells: l.cells.join('') })),
};
const packJson = JSON.stringify(pack, null, 1) + '\n';
writeFileSync(join(root, 'native/puzzles.json'), packJson);
writeFileSync(join(root, 'android/app/src/main/assets/puzzles.json'), packJson);

const tr = rng(20261113);
const fixtures = {
  generatedBy: 'native/tools/puzzles.mjs',
  levels: levels.map((l, i) => ({
    level: i + 1,
    chance: Number(l.chance.toFixed(4)),
    solution: l.solution,
    trace: trace(l, tr),
  })),
};
mkdirSync(join(root, 'native/fixtures'), { recursive: true });
writeFileSync(join(root, 'native/fixtures/puzzle-scenarios.json'), JSON.stringify(fixtures) + '\n');

const show = [1, 2, 4, 10, 25, 50, 100, 150, 200].map(n => `${n}:${levels[n - 1].w}x${levels[n - 1].h}/${levels[n - 1].solution.length}p ${(levels[n - 1].chance * 100).toFixed(1)}%`);
console.log(`wrote ${LEVELS} levels — ${show.join('  ')}`);
