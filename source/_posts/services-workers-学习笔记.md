---
title: service Worker 学习笔记
author: blog-author
date: 2026-02-03 20:30:00
categories:
- 前端相关

tags:
- 前端知识
- 工作积累
- 浏览器
- 整体优化

---

# Service Worker 学习笔记

## 定义
Service Worker（SW）是运行在浏览器后台的脚本，能拦截网络请求、控制缓存、离线访问、推送通知和后台同步。

## 作用
1. 加速加载：缓存静态资源，减少重复请求。
2. 离线可用：网络断开仍能访问已缓存页面。
3. 精细化控制：不同资源用不同缓存策略。

## 关键机制
1. 作用域（scope）
`/sw.js` 的 scope 一般是 `/`，它会控制整个站点。
scope 以 SW 脚本所在路径为上限，不能控制其上级目录。

2. 生命周期
1. `install`：安装，通常预缓存静态资源。
2. `activate`：激活，清理旧缓存、接管页面（`clients.claim()`）。
3. `fetch`：拦截请求，执行缓存策略。

3. 更新规则
只要 `sw.js` 内容变化，浏览器就会下载新 SW。
`skipWaiting()` + `clients.claim()` 可以让新 SW 更快接管。

## 最小可用 SW 示例

### sw.js
```js
const CACHE_NAME = 'app:v1';
const PRE_CACHE = [
  '/',
  '/index.html',
  '/assets/app.css',
  '/assets/app.js'
];

self.addEventListener('install', event => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(PRE_CACHE))
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))
    )).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const { request } = event;
  if (request.method !== 'GET') return;

  // 静态资源 cache-first
  if (request.destination === 'script' || request.destination === 'style') {
    event.respondWith(
      caches.match(request).then(res => res || fetch(request))
    );
    return;
  }

  // API network-only
  if (new URL(request.url).pathname.startsWith('/api/')) {
    event.respondWith(fetch(request));
    return;
  }
});
```

### 注册
```js
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/sw.js', { scope: '/' });
}
```

## 常见缓存策略
1. cache-first：优先缓存，适合静态资源。
2. network-first：优先网络，缓存兜底，适合首页 HTML。
3. stale-while-revalidate：先用缓存，后台更新，适合图标/字典类资源。
4. network-only：完全走网络，适合 API。

## 线上常见问题
1. SW 把 API 当成静态资源缓存。
2. `sw.js` 被 CDN 缓存，导致更新不生效。
3. scope 过大，拦截了不该拦截的路径。
4. 缓存了 204、空 JSON 或跨域的 `opaque` 响应。

## 实战调试流程（Chrome）
1. DevTools → Application → Service Workers
检查是否 `activated` 且 `controlling`。
2. DevTools → Application → Cache Storage
查看是否缓存了 API 响应。
3. Network 面板
看请求是否标记为 `from ServiceWorker`。
4. 勾选 `Disable cache`
确认是 SW 缓存问题还是后端问题。

## 总结
SW 的核心不是“能缓存”，而是“明确哪些能缓存、哪些绝不能缓存”。
把策略写清楚、路径写清楚、更新机制写清楚，才是稳定的 SW。
