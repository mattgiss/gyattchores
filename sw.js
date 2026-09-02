// GyattChores Service Worker
// Caches the app shell for reliable offline use and fast repeat loads.

const CACHE = 'gyattchores-v3';

// Local app shell — these must cache for the app to load offline, so a failure
// here should fail the install (and the worker retries on the next load).
const LOCAL_SHELL = [
  '/',
  '/index.html',
  '/manifest.json',
  '/apple-touch-icon.png',
  '/gyattchores-logo-transparent.svg',
];

// Third-party CDN assets — nice to have cached, but a flaky CDN at install time
// must NOT block the whole install (addAll is all-or-nothing). Cached
// best-effort; whatever misses is filled in later by the fetch handler.
const CDN_ASSETS = [
  'https://unpkg.com/react@18.3.1/umd/react.production.min.js',
  'https://unpkg.com/react-dom@18.3.1/umd/react-dom.production.min.js',
  'https://unpkg.com/@babel/standalone@7.29.7/babel.min.js',
];

self.addEventListener('install', (e) => {
  e.waitUntil((async () => {
    const c = await caches.open(CACHE);
    await c.addAll(LOCAL_SHELL);                              // required
    await Promise.allSettled(CDN_ASSETS.map((u) => c.add(u))); // best-effort
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// Network-first for the app shell and Supabase; cache-first for static assets.
self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);

  // Always go to network for Supabase sync — never serve stale API data.
  if (url.hostname.endsWith('supabase.co')) {
    e.respondWith(fetch(e.request).catch(() => new Response('', { status: 503 })));
    return;
  }

  // Network-first for the page itself (navigations, index.html): this worker
  // file rarely changes between deploys, so a cache-first shell would keep
  // installed clients on an old build indefinitely. Fresh copy when online,
  // cached copy as the offline fallback. Cache-busted probes (?cb=) are the
  // build-freshness check — don't let them pile up in the cache.
  const isShell = e.request.mode === 'navigate' || url.pathname === '/' || url.pathname === '/index.html';
  if (isShell && url.origin === self.location.origin) {
    e.respondWith(
      fetch(e.request).then((response) => {
        if (response.ok && !url.search) {
          const clone = response.clone();
          caches.open(CACHE).then((c) => c.put(e.request, clone));
        }
        return response;
      }).catch(() => caches.match(e.request).then((c) => c || caches.match('/index.html')))
    );
    return;
  }

  // Cache-first for everything else (icons, manifest, CDN assets).
  e.respondWith(
    caches.match(e.request).then((cached) => {
      if (cached) return cached;
      return fetch(e.request).then((response) => {
        if (response.ok && e.request.method === 'GET') {
          const clone = response.clone();
          caches.open(CACHE).then((c) => c.put(e.request, clone));
        }
        return response;
      });
    })
  );
});
