// GyattChores used to be a web app at this address, with a service worker that cached it for
// offline use. The site is now a plain page about the native app, so this worker's only job is
// to retire the old one: browsers that still have it fetch this file, which clears the cached
// app, unregisters itself, and reloads any open tab so it shows the new site.
//
// Keep this file in place. Deleting it would leave old installs running the cached web app.

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) await caches.delete(key);
    await self.registration.unregister();
    for (const client of await self.clients.matchAll({ type: 'window' })) client.navigate(client.url);
  })());
});
