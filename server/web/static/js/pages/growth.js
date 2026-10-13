// 성장 화면
// 서버 요청은 js/api/growth.js 에 있어요.

function lineChart(points, { color = "var(--accent)", fmtY = (v) => v, bars = false, height = 200 } = {}) {
  const W = 760, H = height, pad = { l: 8, r: 8, t: 16, b: 22 };
  const vals = points.map((p) => p.v).filter((v) => v != null);
  if (vals.length < 1) return `<div class="empty small">데이터가 아직 없어요</div>`;
  let lo = Math.min(...vals), hi = Math.max(...vals);
  if (bars) lo = Math.min(0, lo);
  if (hi === lo) { hi += 1; lo -= bars ? 0 : 1; }
  const n = points.length, bw = (W - pad.l - pad.r) / n;
  const x = (i) => pad.l + i * bw + bw / 2;
  const y = (v) => pad.t + (H - pad.t - pad.b) * (1 - (v - lo) / (hi - lo));
  const labels = points.map((p, i) => (i % Math.ceil(n / 10) === 0 ? `<text x="${x(i)}" y="${H - 6}" text-anchor="middle" font-size="10" fill="var(--muted)">${p.label}</text>` : "")).join("");
  const tips = points.map((p, i) => `<rect x="${x(i) - bw / 2}" y="${pad.t}" width="${bw}" height="${H - pad.t - pad.b}" fill="transparent"><title>${p.label}\n${p.v == null ? "-" : fmtY(p.v)}${p.extra ? "\n" + p.extra : ""}</title></rect>`).join("");
  let body;
  if (bars) {
    body = points.map((p, i) => p.v == null ? "" : `<rect x="${x(i) - bw * 0.32}" y="${Math.min(y(p.v), y(0))}" width="${bw * 0.64}" height="${Math.abs(y(p.v) - y(0))}" rx="3" fill="${color}"/>`).join("");
  } else {
    const pts = points.map((p, i) => (p.v == null ? null : `${x(i)},${y(p.v)}`)).filter(Boolean);
    body = `<polyline points="${pts.join(" ")}" fill="none" stroke="${color}" stroke-width="2.5" stroke-linejoin="round"/>` +
      points.map((p, i) => (p.v == null ? "" : `<circle cx="${x(i)}" cy="${y(p.v)}" r="2.5" fill="${color}"/>`)).join("");
  }
  return `<svg class="chart" style="height:${H}px" viewBox="0 0 ${W} ${H}" preserveAspectRatio="none">
    <text x="${pad.l}" y="11" font-size="10" fill="var(--muted)">최고 ${fmtY(Math.max(...vals))}</text>${body}${labels}${tips}</svg>`;
}

// 만렙: 아케인 20, 어센틱·그랜드 어센틱 11 (요구 성장치가 없어도 만렙)
const symbolMax = (s) => !s.require || +s.level >= (/아케인/.test(s.name || "") ? 20 : 11);
const symbolPct = (s) => (symbolMax(s) ? 100 : Math.min(100, Math.round((s.growth / s.require) * 100)));

async function growth(el) {
  if (!state.chars.length) { el.innerHTML = `<h2>성장</h2><div class="card empty">캐릭터를 먼저 추가해 주세요</div>`; return; }
  const cid = state.growthChar && charById(state.growthChar) ? state.growthChar : state.chars[0].id;
  state.growthChar = cid;
  el.innerHTML = `<h2>성장</h2><div class="card empty">불러오는 중…</div>`;
  const [g, hist] = await Promise.all([
    GrowthApi.info(cid, state.growthRefresh).catch((e) => ({ error: e.message })),
    GrowthApi.history(cid, 60),
  ]);
  state.growthRefresh = false;
  const c = charById(cid);
  const last = hist[hist.length - 1];
  const gains = hist.filter((h) => h.gain != null);
  const avgGain = gains.length ? gains.slice(-7).reduce((a, h) => a + h.gain, 0) / Math.min(7, gains.length) : null;
  const cpNow = last?.combat_power, cpPrev = hist.find((h) => h.combat_power)?.combat_power;
  const hx = g.hexa;

  el.innerHTML = `
    <div class="row spread"><h2>성장</h2>
      <div class="row"><button id="gr-refresh">🔄 최신 정보</button><button class="primary" id="gr-backfill">📅 지난 30일 채우기</button></div></div>
    <div class="char-tabs">${state.chars.map((x) => `<button data-gc="${x.id}" class="${x.id === cid ? "on" : ""}">${avatar(x)}<span>${esc(x.name)}</span></button>`).join("")}</div>
    ${g.error ? `<div class="card" style="color:var(--warn)">${esc(g.error)}</div>` : ""}
    <div class="tiles">
      <div class="card tile hero"><div class="label">레벨</div><div class="value">Lv.${last?.level ?? c.level ?? "?"} <span style="font-size:16px">${last?.exp_rate != null ? last.exp_rate.toFixed(3) + "%" : ""}</span></div>
        <div class="small" style="opacity:.9">최근 7일 평균 하루 +${avgGain != null ? avgGain.toFixed(2) : "-"}%</div></div>
      <div class="card tile boss"><div class="label">전투력</div><div class="value">${cpNow ? fmt(cpNow) : "-"}</div>
        <div class="small muted">${cpNow && cpPrev ? `60일 전보다 ${cpNow >= cpPrev ? "+" : ""}${fmt(cpNow - cpPrev)}` : "지난 기록을 채우면 비교돼요"}</div></div>
      ${hx ? `<div class="card tile hunt"><div class="label">HEXA 만렙까지</div><div class="value">${hx.remaining_fragments.toLocaleString()}<span style="font-size:14px"> 조각</span></div>
        <div class="small muted">솔 에르다 ${hx.remaining_erda}개 · 조각 시세로 ${fmt(hx.remaining_meso)}</div></div>` : ""}
      ${g.symbols ? `<div class="card tile etc"><div class="label">심볼</div><div class="value">${g.symbols.filter(symbolMax).length}/${g.symbols.length} <span style="font-size:14px">MAX</span></div>
        <div class="small muted">포스 합계 ${g.symbols.reduce((a, s) => a + (+s.force || 0), 0).toLocaleString()}</div></div>` : ""}
    </div>
    <div class="grid">
      <div class="card"><h3>하루 경험치 (%)</h3>${lineChart(hist.map((h) => ({ label: h.date.slice(5), v: h.gain,
        extra: h.hunt_minutes ? `사냥 ${h.hunt_minutes}분 · 시간당 ${(h.gain / h.hunt_minutes * 60).toFixed(2)}%` : "" })), { bars: true, color: "var(--hunt)", fmtY: (v) => `${v.toFixed(2)}%` })}</div>
      <div class="card"><h3>전투력</h3>${lineChart(hist.map((h) => ({ label: h.date.slice(5), v: h.combat_power })), { color: "var(--boss)", fmtY: fmt })}</div>
    </div>
    ${hx ? `<div class="card"><div class="row spread"><h3>HEXA 코어</h3><span class="small muted">조각 시세 ${fmt(hx.fragment_price)} 기준 · 남은 비용은 30레벨까지</span></div>
      <div class="core-grid">${hx.cores.sort((a, b) => (a.type || "").localeCompare(b.type || "") || b.level - a.level).map((k) => `
        <div class="core">${itemIcon(k.icon)}
          <div style="min-width:0;flex:1"><div class="ellipsis"><b>${esc(k.name)}</b></div>
            <div class="small muted">${esc(k.type || "")} · Lv.${k.level}/30</div>
            <div class="bar"><i style="width:${(k.level / 30) * 100}%"></i></div>
            <div class="small muted">${k.remaining ? (k.remaining.next ? `다음 ${k.remaining.next[0]}에르다·${k.remaining.next[1]}조각 · 남은 ${k.remaining.fragments.toLocaleString()}조각` : "만렙") : ""}</div></div></div>`).join("") || `<div class="empty small">HEXA 코어가 없어요</div>`}</div></div>` : ""}
    ${g.symbols?.length ? `<div class="card"><h3>심볼</h3><div class="core-grid">${g.symbols.map((s) => `
      <div class="core">${itemIcon(s.icon)}
        <div style="min-width:0;flex:1"><div class="ellipsis"><b>${esc(s.name)}</b></div>
          <div class="small muted">Lv.${s.level} · 포스 ${s.force} ${symbolMax(s) ? '<span class="pill max">MAX</span>' : ""}</div>
          <div class="bar"><i style="width:${symbolPct(s)}%;background:var(--etc)"></i></div>
          <div class="small muted">${symbolMax(s) ? "MAX" : `${s.growth}/${s.require}`}</div></div></div>`).join("")}</div></div>` : ""}
    ${g.equipment?.length ? `<div class="card"><h3>장착 장비</h3><div class="equip-grid">${g.equipment.map((x) => `
      <div class="equip"${tipAttr(x.detail || { item_name: x.name, item_equipment_slot: x.slot, starforce: x.star })}>
        ${itemIcon(x.icon, gradeClass(x.grade))}
        ${x.star && x.star !== "0" ? `<span class="star">★${esc(x.star)}</span>` : ""}
        <div class="small ellipsis">${esc(x.slot || "")}</div></div>`).join("")}</div></div>` : ""}`;

  el.onclick = (e) => {
    const t = e.target.closest("button");
    if (!t) return;
    if (t.dataset.gc) { state.growthChar = +t.dataset.gc; growth(el); }
    if (t.id === "gr-refresh") { state.growthRefresh = true; growth(el); }
    if (t.id === "gr-backfill") {
      t.disabled = true; t.textContent = "불러오는 중… (1분쯤)";
      guard(async () => { const r = await GrowthApi.backfill(cid, 30); toast(`${r.added}일치 채웠어요`); })
        .finally(() => growth(el));
    }
  };
}

views.growth = growth;
