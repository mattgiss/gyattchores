// Pre-merge check for the website. There is no build step, so this catches what would
// otherwise only show up on the live site: a broken script, a link to a page that isn't
// there, or the family's database finding its way back onto a public page.
import { readFileSync, existsSync, readdirSync } from 'node:fs';

let failed = 0;
const fail = (m) => { console.error('✗ ' + m); failed++; };
const pass = (m) => console.log('✓ ' + m);

// 1) sw.js parses, and is still the worker that retires the old web app's cache
try {
  const sw = readFileSync('sw.js', 'utf8');
  new Function(sw);
  if (/registration\.unregister\(\)/.test(sw) && /caches\.delete/.test(sw)) pass('sw.js parses and retires the old cache');
  else fail('sw.js no longer clears the old cache and unregisters; old installs would keep the cached web app');
} catch (e) { fail('sw.js syntax error: ' + e.message); }

const pages = readdirSync('.').filter((f) => f.endsWith('.html')).concat(existsSync('privacy/index.html') ? ['privacy/index.html'] : []);

for (const page of pages) {
  const html = readFileSync(page, 'utf8');

  // 2) inline scripts parse
  let scripts = 0, bad = 0;
  for (const m of html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g)) {
    scripts++;
    try { new Function(m[1]); } catch (e) { bad++; fail(`${page}: inline script syntax error: ${e.message}`); }
  }
  if (scripts && !bad) pass(`${page}: ${scripts} inline script(s) parse`);

  // 3) links and images that point inside the site exist
  const missing = [];
  for (const m of html.matchAll(/(?:href|src)="(\/[^"#?]*)/g)) {
    const path = m[1] === '/' ? 'index.html' : m[1].slice(1);
    if (!existsSync(path) && !existsSync(path + '/index.html')) missing.push(m[1]);
  }
  if (missing.length) fail(`${page}: links to missing files: ${[...new Set(missing)].join(', ')}`);
  else pass(`${page}: internal links resolve`);
}

// 4) the front page is a plain page: no app, no database, nothing loaded from elsewhere
{
  const html = readFileSync('index.html', 'utf8');
  if (/supabase/i.test(html)) fail('index.html mentions Supabase: the public front page must not reach a database');
  else pass('index.html does not reach a database');
  if (/text\/babel|serviceWorker\.register/.test(html)) fail('index.html still carries the web app or registers a service worker');
  else pass('index.html is not the web app');
  const outside = [...html.matchAll(/<(?:script|link|img|iframe)[^>]*(?:src|href)="(https?:\/\/[^"]+)"/g)]
    .map((m) => m[1]).filter((u) => !u.startsWith('https://doyourwork.today/'));
  if (outside.length) fail('index.html loads from other sites: ' + outside.join(', '));
  else pass('index.html loads nothing from other sites');
}

console.log(failed ? `\n${failed} check(s) failed` : '\nAll checks passed');
process.exit(failed ? 1 : 0);
