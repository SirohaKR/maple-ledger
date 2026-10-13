// 업데이트 내역 화면
// 서버 요청은 js/api/changelog.js 에 있어요.

async function changelog(el) {
  const r = await CommonApi.version();
  el.innerHTML = `<h2>업데이트 내역</h2>
    ${r.posts.length ? r.posts.map((p) => mdToHtml(postMd(p))).join("") : `<div class="card empty">아직 올라온 업데이트 내역이 없어요</div>`}
    ${isAdmin() ? `<p class="small muted">관리자: 관리 탭 → 업데이트 내역 관리에서 올리거나 숨길 수 있어요.</p>` : ""}`;
  try { localStorage.setItem("seen_version", r.version); } catch (e) {}
  markNewVersion();
}

views.changelog = changelog;
