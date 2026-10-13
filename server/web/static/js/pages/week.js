// 보스 기록 (주간 + 월간) 화면
// 서버 요청은 js/api/week.js 에 있어요.

async function week(el) {
  const w = await WeekApi.week(state.week);
  state.week = w.week;
  const month = w.week.slice(0, 7);
  const m = await WeekApi.month(month);
  const sel = (b) => b.cycle === "daily" || b.cycle === "weekly";

  const cards = state.chars.map((c) => {
    const data = w.chars[c.id] || { clears: [], income: 0, sold: 0 };
    const clearMap = Object.fromEntries(data.clears.map((x) => [x.boss_id, x]));
    const presetMap = Object.fromEntries(c.preset.map((p) => [p.boss_id, p]));
    const ids = [...new Set([...c.preset.map((p) => p.boss_id), ...data.clears.map((x) => x.boss_id)])]
      .filter((id) => bossById(id) && sel(bossById(id)))
      .sort((a, b) => bossById(a).sort - bossById(b).sort);
    const rows = ids.map((id) => {
      const b = bossById(id), cl = clearMap[id], p = presetMap[id];
      const party = cl?.party_size || p?.party_size || 1;
      const price = w.prices[id] || 0;
      const share = Math.floor(price / party);
      const ctrl = b.cycle === "daily"
        ? `<input type="number" min="0" max="7" value="${cl?.count || 0}" data-act="count" title="이번 주 잡은 횟수">`
        : `<input type="checkbox" ${cl ? "checked" : ""} data-act="check">`;
      const over = cl && cl.sold < cl.count ? `<span class="pill over" title="판매 한도 밖">${cl.count - cl.sold}개 초과</span>` : "";
      return `<tr data-boss="${id}" data-char="${c.id}" class="${cl ? "" : "dim"}">
        <td>${ctrl}</td>
        <td>${bossImg(b)}${esc(bossLabel(b))} ${b.cycle === "daily" ? '<span class="pill daily">일간</span>' : ""} ${cl?.source === "api" ? '<span class="pill api" title="넥슨 API로 자동 체크됨">자동</span>' : ""} ${over}</td>
        <td><select data-act="party">${partyOptions(b.max_party, party)}</select></td>
        <td class="num">${fmt(share)}</td>
        <td class="num">${cl ? fmt(cl.income) : "-"}</td></tr>`;
    });
    // 주간 보스는 같은 주에 한 난이도만 — 이미 있는 보스의 다른 난이도는 목록에서 뺀다
    const taken = new Set(ids.map((id) => bossById(id)).filter((b) => b.cycle === "weekly").map((b) => b.name));
    const extra = state.bosses.filter((b) => sel(b) && !b.hidden && !ids.includes(b.id) && !(b.cycle === "weekly" && taken.has(b.name)));
    const addOpts = ["weekly", "daily"].map((cy) => `<optgroup label="${CYCLE[cy]}">${extra.filter((b) => b.cycle === cy)
      .map((b) => `<option value="${b.id}">${esc(bossLabel(b))}</option>`).join("")}</optgroup>`).join("");
    return `<div class="card">
      <div class="row spread"><div class="char-head">${avatar(c)}${charInfo(c)}</div>
        <div class="num"><div><b>${fmt(data.income)}</b></div><div class="small muted">결정석 ${data.sold}${w.limit ? `/${w.limit}` : "개"}</div></div></div>
      <table><thead><tr><th></th><th>보스</th><th>파티</th><th class="num">1개당</th><th class="num">수익</th></tr></thead>
      <tbody>${rows.join("") || `<tr><td colspan="5" class="muted">캐릭터 탭에서 보스 프리셋을 정해 두면 여기에 바로 떠요</td></tr>`}</tbody></table>
      <div class="row" style="margin-top:8px">
        <select data-add="${c.id}"><option value="">+ 보스 추가</option>${addOpts}</select>
        <button data-fill="${c.id}">프리셋대로 체크</button></div>
    </div>`;
  });

  const monthlyBosses = state.bosses.filter((b) => b.cycle === "monthly" && !b.hidden);
  const mClear = (cid, bid) => m.clears.find((x) => x.character_id === cid && x.boss_id === bid);
  const monthRows = state.chars.flatMap((c) => monthlyBosses.map((b) => {
    const cl = mClear(c.id, b.id);
    const party = cl?.party_size || 1;
    return `<tr data-boss="${b.id}" data-char="${c.id}" data-month="1" class="${cl ? "" : "dim"}">
      <td><input type="checkbox" ${cl ? "checked" : ""} data-act="check"></td><td>${esc(c.name)}</td><td>${esc(bossLabel(b))}</td>
      <td><select data-act="party">${partyOptions(b.max_party, party)}</select></td>
      <td class="num">${fmt(Math.floor((m.prices[b.id] || 0) / party))}</td><td class="num">${cl ? fmt(cl.income) : "-"}</td></tr>`;
  }));

  el.innerHTML = `
    <div class="row spread"><h2>보스 기록</h2>
      <div class="row"><button data-nav="${w.prev}">◀</button>
        <b>${w.week} ~ ${w.end}</b> ${w.is_current ? '<span class="pill">이번 주</span>' : ""}
        <button data-nav="${w.next}">▶</button>
        ${w.is_current ? "" : `<button data-nav="">이번 주로</button>`}
        <button data-fill="">전체 프리셋대로 체크</button>
        ${state.settings.nexon_key_set ? `<button class="primary" id="w-sync">🤖 API로 보스 체크</button>` : ""}</div></div>
    ${state.settings.nexon_key_set ? `<div class="sync-bar" style="margin:-4px 0 12px">${syncSummary(state.settings)}</div>` : ""}
    <div class="card tile hero"><div class="label">이번 주 결정석 합계</div><div class="value">${fmt(w.total)}</div>
      <div class="small" style="opacity:.9">판매 한도: 캐릭터당 ${w.limit ? `${w.limit}개` : "제한 없음"} · 월드당 ${w.world_limit ? `${w.world_limit}개` : "제한 없음"}.
        한도 안에서 비싼 결정석부터 판다고 계산해요. 가격·규칙은 ${w.week} 기준.</div>
      ${Object.keys(w.worlds).length ? `<div class="row small" style="margin-top:6px">${Object.entries(w.worlds).map(([wd, n]) =>
        `<span class="pill ${w.world_limit && n >= w.world_limit ? "over" : ""}">${esc(wd)} ${n}${w.world_limit ? `/${w.world_limit}` : "개"}</span>`).join("")}</div>` : ""}</div>
    ${state.chars.length ? `<div class="grid wide">${cards.join("")}</div>` : `<div class="card">먼저 <a href="#chars">캐릭터</a>를 추가해 주세요.</div>`}
    <div class="card"><div class="row spread"><h3>월간 보스 — ${month}</h3><b>${fmt(m.total)}</b></div>
      <div class="table-wrap"><table><thead><tr><th></th><th>캐릭터</th><th>보스</th><th>파티</th><th class="num">1개당</th><th class="num">수익</th></tr></thead>
      <tbody>${monthRows.join("") || `<tr><td colspan="6" class="muted">캐릭터나 월간 보스가 없어요</td></tr>`}</tbody></table></div></div>`;

  const save = (tr, count) => {
    const party = +$("select[data-act=party]", tr).value;
    const period = tr.dataset.month ? month : w.week;
    return guard(async () => {
      await WeekApi.setClear({ character_id: +tr.dataset.char, boss_id: +tr.dataset.boss, period, count, party_size: party });
      week(el);
    });
  };
  el.onchange = (e) => {
    const t = e.target, tr = t.closest("tr");
    if (t.dataset.add) {
      const cid = +t.dataset.add, b = bossById(+t.value);
      if (!b) return;
      guard(async () => {
        await WeekApi.setClear({ character_id: cid, boss_id: b.id, period: w.week, count: 1, party_size: 1 });
        week(el);
      });
      return;
    }
    if (!tr) return;
    if (t.dataset.act === "check") save(tr, t.checked ? 1 : 0);
    else if (t.dataset.act === "count") save(tr, Math.max(0, Math.min(7, +t.value || 0)));
    else if (t.dataset.act === "party") {
      const chk = $("[data-act=check]", tr), cnt = $("[data-act=count]", tr);
      const count = chk ? (chk.checked ? 1 : 0) : +cnt.value || 0;
      if (count) save(tr, count); else week(el);
    }
  };
  el.onclick = (e) => {
    const t = e.target;
    if (t.id === "w-sync") return runSync(t).then(() => week(el));
    if (t.dataset.nav !== undefined) { state.week = t.dataset.nav || null; week(el); }
    if (t.dataset.fill !== undefined) {
      guard(async () => {
        await WeekApi.fillPreset({ week: w.week, character_id: t.dataset.fill ? +t.dataset.fill : null });
        toast("프리셋대로 체크했어요");
        week(el);
      });
    }
  };
}

views.week = week;
