/**
 * Genesis Dashboard Service Worker v2.6.0
 * Strategy: Cache-First with Versioned Invalidation for Core Local Assets
 */

const CACHE_NAME = 'genesis-pwa-v2.6.1';

// Core Local Assets: 100% Reliable Local Shell (All-or-Nothing)
const CORE_LOCAL_ASSETS = [
    '/',
    '/static/index.html?v=2.6.1',
    '/static/style.css?v=2.6.1',
    '/static/app.js?v=2.6.1',
    '/static/manifest.json',
    '/static/icon-192.png',
    '/static/icon-512.png'
];

// Optional External Assets: Isolated caching to prevent install failures on network glitches
const OPTIONAL_ASSETS = [
    'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&family=JetBrains+Mono:wght@400;600;700&display=swap'
];

// 1. Install Phase: Cache Local Assets first, gracefully fetch external fonts
self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME).then(async (cache) => {
            // Core local files cache
            await cache.addAll(CORE_LOCAL_ASSETS);
            // Non-blocking optional fonts cache
            for (const url of OPTIONAL_ASSETS) {
                try {
                    await cache.add(url);
                } catch (e) {
                    console.warn('[SW] Optional external asset skipped:', url);
                }
            }
        }).then(() => self.skipWaiting())
    );
});

// 2. Activate Phase: Purge old cache versions and claim clients immediately
self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((keys) => {
            return Promise.all(
                keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
            );
        }).then(() => self.clients.claim())
    );
});

// 3. Fetch Phase: Network-First with Cache Fallback for instant update propagation
self.addEventListener('fetch', (event) => {
    const url = new URL(event.request.url);

    // Bypass API routes and WebSocket requests
    if (url.pathname.startsWith('/api') || url.pathname.startsWith('/ws')) {
        return;
    }

    event.respondWith(
        fetch(event.request)
            .then((response) => {
                if (response && response.status === 200 && response.type === 'basic') {
                    const responseClone = response.clone();
                    caches.open(CACHE_NAME).then((cache) => cache.put(event.request, responseClone));
                }
                return response;
            })
            .catch(() => caches.match(event.request))
    );
});
