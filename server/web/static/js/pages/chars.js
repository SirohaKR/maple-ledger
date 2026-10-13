// 캐릭터 화면
// 서버 요청은 js/api/chars.js 에 있어요.

async function chars(el) {
  state.chars = await CharsApi.list();
  el.innerHTML = `
    <div class="row spread"><h2>캐릭터</h2>
      <div class="row"><button class="primary" id="c-import">넥슨 API에서 불러오기</button>
        <button id="c-name">이름으로 추가</button><button id="c-refresh">레벨·이미지 갱신</button></div></div>
    ${state.settings.nexon_key_set ? "" : `<div class="card">넥슨 API 키가 없어요. <a href="#settings">설정</a>에서 먼저 넣어 주세요.</div>`}
    <div class="grid">${state.chars.map((c) => {
      const est = estimate(c.preset);
      return `<div class="card">
        <div class="row spread"><div class="char-head">${avatar(c, true)}${charInfo(c)}</div>
          <div class="num"><div class="small muted">프리셋 예상 주급</div><b>${fmt(est.total)}</b></div></div>
        <div class="small muted" style="margin:8px 0">${c.preset.length ? c.preset.map((p) => {
          const b = bossById(p.boss_id); return b ? `${esc(bossLabel(b))}${p.party_size > 1 ? `(${p.party_size}인)` : ""}` : "";
        }).join(" · ") : "보스 프리셋 없음"}</div>
        <div class="row"><button data-preset="${c.id}">보스 프리셋 설정</button>
          <button data-up="${c.id}">▲</button><button data-down="${c.id}">▼</button>
          <button class="danger" data-remove="${c.id}">삭제</button></div></div>`;
    }).join("") || `<div class="card muted">추가된 캐릭터가 없어요</div>`}</div>`;

  el.onclick = (e) => {
    const t = e.target;
    if (t.id === "c-import") importModal();
    if (t.id === "c-name") {
      const name = prompt("캐릭터 이름");
      if (name) guard(async () => { await CharsApi.add({ name }); toast(`${name} 추가`); chars(el); });
    }
    if (t.id === "c-refresh") guard(async () => {
      t.disabled = true; t.textContent = "갱신 중…";
      const r = await CharsApi.refresh();
      toast(`${r.refreshed}명 갱신`); chars(el);
    }).finally(() => (t.disabled = false));
    if (t.dataset.preset) presetModal(charById(+t.dataset.preset));
    if (t.dataset.remove && confirm("캐릭터와 그 캐릭터의 보스 기록이 모두 지워져요. 계속할까요?"))
      guard(async () => { await CharsApi.remove(t.dataset.remove); chars(el); });
    if (t.dataset.up || t.dataset.down) {
      const id = +(t.dataset.up || t.dataset.down);
      const i = state.chars.findIndex((c) => c.id === id), j = t.dataset.up ? i - 1 : i + 1;
      if (j < 0 || j >= state.chars.length) return;
      const order = state.chars.map((c) => c.id);
      [order[i], order[j]] = [order[j], order[i]];
      guard(async () => {
        await Promise.all(order.map((cid, k) => CharsApi.edit(cid, { sort: k })));
        chars(el);
      });
    }
  };
}

// 프리셋 예상 주급: 현재 가격 기준, 캐릭터 판매 한도 반영
function currentRule() {
  const t = todayStr();
  return (state.settings.rules || []).find((r) => r.effective_from <= t) || { char_limit: 0, world_limit: 0, daily_in_limit: 1 };
}

function estimate(preset) {
  const rule = currentRule();
  const limit = rule.char_limit, dailyIn = !!rule.daily_in_limit;
  const limited = [], free = [];
  let monthly = 0;
  for (const p of preset) {
    const b = bossById(p.boss_id);
    if (!b || b.price == null) continue;
    const share = Math.floor(b.price / Math.max(1, p.party_size));
    if (b.cycle === "monthly") { monthly += share; continue; }
    const n = b.cycle === "daily" ? p.daily_count : 1;
    for (let i = 0; i < n; i++) (b.cycle === "weekly" || dailyIn ? limited : free).push(share);
  }
  limited.sort((a, b) => b - a);
  const sold = limit ? limited.slice(0, limit) : limited;
  const total = [...sold, ...free].reduce((a, v) => a + v, 0);
  return { total, sold: sold.length, over: limited.length - sold.length, monthly };
}

async function importModal() {
  openModal(`<h3>넥슨 API에서 불러오기</h3><p class="muted">불러오는 중…</p>`);
  const list = await guard(() => CharsApi.fromNexon());
  if (!list) return closeModal();
  const worlds = [...new Set(list.map((c) => c.world))];
  openModal(`
    <div class="row spread"><h3>내 계정 캐릭터 (${list.length})</h3>
      <label class="small"><input type="checkbox" id="i-lv" checked> 200레벨 이상만</label></div>
    <div style="max-height:60vh;overflow:auto">${worlds.map((wd) => `
      <h3 style="margin-top:12px">${esc(wd)}</h3><table><tbody>${list.filter((c) => c.world === wd).map((c) => `
        <tr data-lv="${c.level}"><td><input type="checkbox" value="${esc(c.ocid)}" ${c.tracked || c.taken ? "checked disabled" : ""}></td>
        <td>${esc(c.name)}</td><td>Lv.${c.level}</td><td class="muted">${esc(c.job)}</td><td>${c.tracked ? '<span class="pill">추가됨</span>' : ""}</td></tr>`).join("")}
      </tbody></table>`).join("")}</div>
    <div class="row" style="margin-top:12px;justify-content:flex-end"><button id="i-cancel">닫기</button><button class="primary" id="i-ok">선택한 캐릭터 추가</button></div>`);
  const box = $("#modal-box");
  const filter = () => $$("tr[data-lv]", box).forEach((tr) => (tr.hidden = $("#i-lv").checked && +tr.dataset.lv < 200));
  filter();
  $("#i-lv").onchange = filter;
  $("#i-cancel").onclick = closeModal;
  $("#i-ok").onclick = () => guard(async () => {
    const ocids = $$("input[type=checkbox][value]:checked:not(:disabled)", box).map((i) => i.value);
    if (!ocids.length) return toast("선택한 캐릭터가 없어요", true);
    $("#i-ok").disabled = true; $("#i-ok").textContent = "추가 중…";
    const r = await CharsApi.add({ ocids });
    toast(`${r.added.length}명 추가했어요`);
    closeModal(); render();
  });
}

function presetModal(c) {
  // 보스 이름+주기별로 묶어서 난이도 하나만 고르게 (같은 주에 한 난이도만 클리어 가능)
  const groups = [];
  for (const b of state.bosses.filter((x) => !x.hidden)) {
    let g = groups.find((x) => x.name === b.name && x.cycle === b.cycle);
    if (!g) groups.push((g = { name: b.name, cycle: b.cycle, list: [] }));
    g.list.push(b);
  }
  const cur = Object.fromEntries(c.preset.map((p) => [p.boss_id, p]));
  const row = (g, i) => {
    const chosen = g.list.find((b) => cur[b.id]);
    const p = chosen ? cur[chosen.id] : { party_size: 1, daily_count: 7 };
    return `<tr data-g="${i}"><td><span class="pill ${g.cycle}">${CYCLE[g.cycle]}</span></td><td>${esc(g.name)}</td>
      <td><select data-k="boss"><option value="">-</option>${g.list.map((b) => `<option value="${b.id}" ${chosen?.id === b.id ? "selected" : ""}>${esc(b.difficulty)} (${fmt(b.price)})</option>`).join("")}</select></td>
      <td><select data-k="party">${partyOptions(6, p.party_size)}</select></td>
      <td>${g.cycle === "daily" ? `<input type="number" data-k="daily" min="1" max="7" value="${p.daily_count}" title="주에 몇 번">회` : ""}</td></tr>`;
  };
  const order = ["weekly", "monthly", "daily"];
  const sorted = groups.map((g, i) => [g, i]).sort((a, b) => order.indexOf(a[0].cycle) - order.indexOf(b[0].cycle));
  openModal(`
    <div class="row spread"><h3>${esc(c.name)} — 보스 프리셋</h3><div class="num"><span class="small muted">예상 주급</span> <b id="p-est"></b></div></div>
    <p class="small muted">매주 도는 보스와 파티 인원을 정해 두면 보스 기록 화면에서 한 번에 체크할 수 있어요.</p>
    <div style="max-height:60vh;overflow:auto"><table><thead><tr><th></th><th>보스</th><th>난이도</th><th>파티</th><th>일간 횟수</th></tr></thead>
    <tbody>${sorted.map(([g, i]) => row(g, i)).join("")}</tbody></table></div>
    <div class="row" style="margin-top:12px;justify-content:flex-end"><button id="p-cancel">취소</button><button class="primary" id="p-ok">저장</button></div>`);
  const box = $("#modal-box");
  const collect = () => $$("tr[data-g]", box).map((tr) => ({
    boss_id: +$("[data-k=boss]", tr).value,
    party_size: +$("[data-k=party]", tr).value,
    daily_count: +($("[data-k=daily]", tr)?.value || 7),
  })).filter((x) => x.boss_id);
  const upd = () => {
    const e = estimate(collect());
    $("#p-est").textContent = fmt(e.total) + (e.over ? ` (한도 초과 ${e.over}개)` : "") + (e.monthly ? ` + 월 ${fmt(e.monthly)}` : "");
  };
  upd();
  box.onchange = upd;
  $("#p-cancel").onclick = closeModal;
  $("#p-ok").onclick = () => guard(async () => {
    await CharsApi.savePreset(c.id, collect());
    toast("프리셋 저장");
    closeModal(); render();
  });
}

views.chars = chars;
