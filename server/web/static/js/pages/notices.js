// 공지 화면
// 서버 요청은 js/api/notices.js 에 있어요.

const NOTICE_KIND = { "notice-update": "업데이트", notice: "공지", "notice-event": "이벤트" };

async function notices(el) {
  const nt = await NoticesApi.list();
  const f = state.noticeKind || "all";
  const t = todayStr();
  const rows = nt.rows.filter((n) => f === "all" || (f === "matched" ? n.matched : n.kind === f));
  el.innerHTML = `
    <div class="row spread"><h2>공지</h2>
      <div class="row">${nt.last_check ? `<span class="small muted">마지막 확인 ${new Date(+nt.last_check * 1000).toLocaleString("ko-KR", { month: "numeric", day: "numeric", hour: "2-digit", minute: "2-digit" })}</span>` : ""}
        ${nt.alerts.length ? `<button id="nt-seen">알림 ${nt.alerts.length}건 확인</button>` : ""}
        ${state.settings.nexon_key_set ? `<button class="primary" id="nt-check">🔄 새로 확인</button>` : ""}</div></div>
    <p class="small muted">1시간마다 넥슨 공지를 확인해요. 업데이트 공지 본문에 감시 단어(<b>${esc(state.settings.notice_keywords || "없음")}</b>, <a href="#settings">설정</a>에서 변경)가 나오면 표시하고 대시보드에 알려줘요.</p>
    <div class="tabs">${[["all", "전체"], ["notice-update", "업데이트"], ["notice", "공지"], ["notice-event", "이벤트"], ["matched", "감시 단어"]]
      .map(([k, v]) => `<button data-nk="${k}" class="${f === k ? "on" : ""}">${v}</button>`).join("")}</div>
    <div class="card">${rows.map((n) => {
      const ongoing = n.date_start && n.date_end && n.date_start <= t && t <= n.date_end;
      return `<div class="notice ${n.matched && !n.seen ? "hot" : ""}">
        <span class="pill ${n.kind === "notice-update" ? "" : n.kind === "notice-event" ? "monthly" : "daily"}">${NOTICE_KIND[n.kind] || n.kind}</span>
        <div style="flex:1;min-width:0"><a href="${esc(n.url)}" target="_blank" rel="noopener">${esc(n.title)}</a>
          ${n.matched ? ` <span class="pill over">${esc(n.matched)}</span>` : ""}
          ${n.date_start ? `<div class="small muted">기간 ${n.date_start} ~ ${n.date_end || ""} ${ongoing ? '<span class="pill api">진행 중</span>' : ""}</div>` : ""}</div>
        <span class="small muted" style="white-space:nowrap">${n.date}</span></div>`;
    }).join("") || `<div class="empty">공지가 없어요${state.settings.nexon_key_set ? " — 새로 확인을 눌러 보세요" : ""}</div>`}</div>`;
  el.onclick = (e) => {
    const b = e.target.closest("button");
    if (!b) return;
    if (b.dataset.nk) { state.noticeKind = b.dataset.nk; notices(el); }
    if (b.id === "nt-seen") guard(async () => { await NoticesApi.markSeen(); notices(el); });
    if (b.id === "nt-check") {
      b.disabled = true; b.textContent = "확인 중…";
      guard(async () => { const r = await NoticesApi.checkNow(); toast(`확인 완료${r.found ? ` · 감시 단어 ${r.found}건` : ""}`); }).finally(() => notices(el));
    }
  };
}

views.notices = notices;
