// Lightweight pre-merge validation for the single-file app.
// Catches the failure that actually hurts here: a syntax error in the inline
// app script ships a white screen, since there's no build step to catch it.
import { readFileSync } from 'node:fs';
import * as Babel from '@babel/standalone';

let failed = 0;
const fail = (m) => { console.error('✗ ' + m); failed++; };
const pass = (m) => console.log('✓ ' + m);

// 1) manifest.json is valid JSON
try { JSON.parse(readFileSync('manifest.json', 'utf8')); pass('manifest.json is valid JSON'); }
catch (e) { fail('manifest.json invalid: ' + e.message); }

// 2) sw.js parses as valid JS
try { new Function(readFileSync('sw.js', 'utf8')); pass('sw.js parses'); }
catch (e) { fail('sw.js syntax error: ' + e.message); }

// 3) the inline JSX app script compiles
try {
  const html = readFileSync('index.html', 'utf8');
  const m = html.match(/<script type="text\/babel">([\s\S]*?)<\/script>/);
  if (!m) fail('no <script type="text/babel"> block found in index.html');
  else { Babel.transform(m[1], { presets: ['react'] }); pass('index.html app script compiles'); }
} catch (e) { fail('index.html JSX compile error: ' + e.message); }

console.log(failed ? `\n${failed} check(s) failed` : '\nAll checks passed');
process.exit(failed ? 1 : 0);
