// 앱으로 설치했을 때 쓰는 서비스 워커.
// 기록은 항상 서버에서 새로 받아야 해서 아무것도 저장(캐시)하지 않고, 서버에 못 닿을 때만 안내 화면을 보여 줘요.
const OFFLINE = `<!doctype html><html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>메이플 수익 장부</title>
<style>body{font-family:system-ui,sans-serif;background:#fff7ef;color:#3a2a20;display:grid;place-items:center;min-height:100vh;margin:0;text-align:center}
@media (prefers-color-scheme:dark){body{background:#14121c;color:#eee}}
button{margin-top:16px;padding:10px 20px;border:0;border-radius:999px;background:#ff7a3d;color:#fff;font-weight:700;font-size:15px}</style></head>
<body><div><div style="font-size:48px">🍁</div><h2>서버에 연결할 수 없어요</h2>
<p>인터넷이나 서버(NAS)가 켜져 있는지 확인해 주세요.</p><button onclick="location.reload()">다시 시도</button></div></body></html>`;

self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));

self.addEventListener("fetch", (e) => {
  if (e.request.mode !== "navigate") return; // 화면 이동만 챙기고 나머지는 브라우저에 맡김
  e.respondWith(fetch(e.request).catch(() => new Response(OFFLINE, { headers: { "content-type": "text/html; charset=utf-8" } })));
});
