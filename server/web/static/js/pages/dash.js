// 대시보드 화면
// 서버 요청은 js/api/dash.js 에 있어요.

async function dash(el) {
  const [s, nt] = await Promise.all([DashApi.stats(12), NoticesApi.list().catch(() => ({ rows: [], alerts: [] }))]);
  const cur = s.series[s.series.length - 1] || { boss: 0, hunt: 0, etc: 0, spend: 0 };
  const sum = (k) => s.series.reduce((a, w) => a + w[k], 0);
  const sumMonthly = s.monthly.reduce((a, m) => a + m.total, 0);
  const thisMonth = s.monthly[s.monthly.length - 1]?.total || 0;
  el.innerHTML = `
    <h2>대시보드</h2>
    ${nt.alerts.length ? `<div class="card alert"><div class="row spread"><b>📢 공지에 감시 단어가 나왔어요</b><button id="nt-seen">확인</button></div>
      ${nt.alerts.map((n) => `<div class="small"><a href="${esc(n.url)}" target="_blank" rel="noopener">${esc(n.title)}</a> <span class="pill over">${esc(n.matched)}</span> <span class="muted">${n.date}</span></div>`).join("")}
      <div class="small muted" style="margin-top:6px">결정석 가격이 바뀌었으면 <a href="#bosses">보스 가격표</a>에 적용일과 함께 새 가격을 넣어 주세요.</div></div>` : ""}
    ${state.chars.length ? "" : `<div class="card">캐릭터가 아직 없어요. <a href="#settings">설정</a>에서 넥슨 API 키를 넣고 <a href="#chars">캐릭터</a>에서 불러와 주세요.</div>`}
    <div class="tiles">
      <div class="card tile hero"><div class="label">이번 주 순수익</div><div class="value">${fmt(cur.boss + cur.hunt + cur.etc - cur.spend)}</div>
        <div class="small" style="opacity:.9">수익 ${fmt(cur.boss + cur.hunt + cur.etc)} − 지출 ${fmt(cur.spend)} · 월간 보스 ${fmt(thisMonth)} 별도</div></div>
      <div class="card tile boss"><div class="label">이번 주 보스 결정석</div><div class="value">${fmt(cur.boss)}</div></div>
      <div class="card tile hunt"><div class="label">이번 주 사냥 (부수입·조각 포함)</div><div class="value">${fmt(cur.hunt)}</div>
        <div class="small muted">메소 시급 평균 ${fmt(s.hunt_per_hour)} · 총 ${Math.floor(s.hunt_minutes / 60)}시간</div></div>
      <div class="card tile etc"><div class="label">이번 주 기타 수익</div><div class="value">${fmt(cur.etc)}</div>
        ${s.pending.count ? `<div class="small muted">미판매 ${s.pending.count}건 · 예상 ${fmt(s.pending.amount)}</div>` : ""}</div>
    </div>
    <div class="card">
      <div class="row spread"><h3>주간 수익 · 최근 12주 합계 <span style="color:var(--accent)">${fmt(sum("boss") + sum("hunt") + sum("etc") + sumMonthly)}</span>
        <span class="small muted">지출 ${fmt(sum("spend"))} · 순수익 ${fmt(sum("boss") + sum("hunt") + sum("etc") + sumMonthly - sum("spend"))}</span></h3>
        <div class="legend"><span><i style="background:var(--boss)"></i>보스</span><span><i style="background:var(--hunt)"></i>사냥</span><span><i style="background:var(--etc)"></i>기타</span></div></div>
      ${barChart(s.series)}
    </div>
    <div class="grid">
      <div class="card" style="grid-column: span 2"><div class="row spread"><h3>캐릭터별 (최근 12주)</h3>
        <div class="row"><span class="small muted">지출은 장부 시작일(${s.ledger_start}) 이후만</span><button id="dash-refresh">🔄 새로고침</button></div></div>
        <div class="table-wrap"><table><thead><tr><th>캐릭터</th><th class="num">보스</th><th class="num">사냥</th><th class="num">기타</th><th class="num">지출</th><th class="num">순수익</th></tr></thead><tbody>
        ${s.per_char.map((r) => `<tr><td>${esc(r.name)}</td><td class="num">${fmt(r.boss)}</td><td class="num">${fmt(r.hunt)}</td><td class="num">${fmt(r.etc)}</td><td class="num" style="color:var(--warn)">${r.spend ? "-" + fmt(r.spend) : ""}</td>
          <td class="num"><b>${fmt(r.boss + r.hunt + r.etc - r.spend)}</b></td></tr>`).join("") || `<tr><td colspan="6" class="empty">기록이 없어요</td></tr>`}
        </tbody></table></div></div>
      <div class="card"><h3>월간 보스</h3>
        <table><tbody>${s.monthly.map((m) => `<tr><td>${m.month}</td><td class="num">${fmt(m.total)}</td></tr>`).join("")}</tbody></table></div>
    </div>`;
  el.onclick = (e) => {
    if (e.target.id === "nt-seen") guard(async () => { await NoticesApi.markSeen(); dash(el); });
    if (e.target.id === "dash-refresh") { e.target.disabled = true; dash(el).then(() => toast("새로고침했어요")); }
    if (e.target.id === "nt-check") guard(async () => { const r = await NoticesApi.checkNow(); toast(`확인 완료${r.found ? ` · 감시 단어 ${r.found}건` : ""}`); dash(el); });
  };
}

function barChart(series) {
  const W = 760, H = 230, pad = { l: 8, r: 8, t: 18, b: 24 };
  const tot = (s) => s.boss + s.hunt + s.etc;
  const max = Math.max(1, ...series.map(tot));
  const bw = (W - pad.l - pad.r) / series.length;
  const y = (v) => ((H - pad.t - pad.b) * v) / max;
  const bars = series.map((s, i) => {
    const x = pad.l + i * bw + bw * 0.18, w = bw * 0.64, base = H - pad.b;
    let top = base;
    const seg = (v, color) => { const h = y(v); top -= h; return h > 0 ? `<rect x="${x}" y="${top}" width="${w}" height="${h}" fill="${color}"/>` : ""; };
    const parts = seg(s.boss, "var(--boss)") + seg(s.hunt, "var(--hunt)") + seg(s.etc, "var(--etc)");
    return `<g><title>${s.week} 주\n보스 ${fmt(s.boss)}\n사냥 ${fmt(s.hunt)}\n기타 ${fmt(s.etc)}</title>
      <clipPath id="c${i}"><rect x="${x}" y="${pad.t}" width="${w}" height="${base - pad.t}" rx="6"/></clipPath>
      <g clip-path="url(#c${i})">${parts}</g>
      <rect x="${x}" y="${pad.t}" width="${w}" height="${base - pad.t}" fill="transparent"/>
      <text x="${x + w / 2}" y="${H - 8}" text-anchor="middle" font-size="10" fill="var(--muted)">${s.week.slice(5)}</text></g>`;
  });
  return `<svg class="chart" viewBox="0 0 ${W} ${H}" preserveAspectRatio="none">
    <line x1="${pad.l}" x2="${W - pad.r}" y1="${H - pad.b}" y2="${H - pad.b}" stroke="var(--line)"/>
    <text x="${pad.l}" y="12" font-size="10" fill="var(--muted)">최대 ${fmt(max)}</text>${bars.join("")}</svg>`;
}

views.dash = dash;
