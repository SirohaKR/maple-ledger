// 보스 가격표 화면
// 서버 요청은 js/api/bosses.js 에 있어요.

async function bosses(el) {
  state.bosses = await BossesApi.list();
  const f = state.bossFilter, q = state.bossSearch.trim();
  const list = state.bosses.filter((b) =>
    (f === "all" || b.cycle === f) && (state.showHidden || !b.hidden) && (!q || b.name.includes(q) || b.difficulty.includes(q)));
  el.innerHTML = `
    <h2>보스 가격표</h2>
    <p class="small muted">결정석 가격은 패치로 바뀌어요. 바뀌면 <b>가격 변경</b>에서 적용일과 새 가격을 넣으면, 그 날짜 이후 기록부터 새 가격으로 계산돼요(예전 기록은 그대로).
      기본값은 2026-09-17 조정 기준 커뮤니티 정리표라 공식 패치노트와 한 번 대조해 주세요.</p>
    <div class="row spread">
      <div class="tabs">${["weekly", "daily", "monthly", "all"].map((k) => `<button data-f="${k}" class="${f === k ? "on" : ""}">${CYCLE[k] || "전체"}</button>`).join("")}</div>
      <div class="row"><input id="b-q" placeholder="보스 검색" value="${esc(q)}">
        <label class="small"><input type="checkbox" id="b-hidden" ${state.showHidden ? "checked" : ""}> 숨긴 보스 보기</label></div></div>
    <div class="card table-wrap"><table>
      <thead><tr><th>보스</th><th>난이도</th><th>주기</th>${[1, 2, 3, 4, 5, 6].map((n) => `<th class="num">${n}인</th>`).join("")}<th></th></tr></thead>
      <tbody>${list.map((b) => `
        <tr class="${b.hidden ? "dim" : ""}"><td>${bossImg(b)}${esc(b.name)}</td><td>${esc(b.difficulty)}</td><td><span class="pill ${b.cycle}">${CYCLE[b.cycle]}</span></td>
          ${[1, 2, 3, 4, 5, 6].map((n) => `<td class="num ${n === 1 ? "" : "muted"}">${n <= b.max_party && b.price != null ? (n === 1 ? `<b>${fmt(b.price)}</b>` : fmt(Math.floor(b.price / n))) : ""}</td>`).join("")}
          <td style="white-space:nowrap">${isAdmin() ? `<button class="link" data-price="${b.id}">가격 변경</button><button class="link" data-hide="${b.id}">${b.hidden ? "보이기" : "숨기기"}</button>` : ""}</td></tr>`).join("")}
      </tbody></table></div>
    ${isAdmin() ? "" : `<p class="small muted">가격표는 길드원 모두가 같이 써요. 바뀐 가격이 있으면 관리자에게 알려 주세요.</p>`}
    <div class="card" ${isAdmin() ? "" : "hidden"}><h3>보스 추가</h3><div class="row">
      <label class="field">이름<input id="n-name"></label><label class="field">난이도<input id="n-diff" placeholder="노멀"></label>
      <label class="field">주기<select id="n-cycle"><option value="weekly">주간</option><option value="daily">일간</option><option value="monthly">월간</option></select></label>
      <label class="field">가격<input id="n-price" class="meso" placeholder="예: 5억 3200만"></label>
      <label class="field">최대 인원<input type="number" id="n-max" value="6" min="1" max="6"></label>
      <button class="primary" id="n-add" style="align-self:flex-end">추가</button></div></div>`;

  $("#b-q").oninput = (e) => {
    state.bossSearch = e.target.value;
    clearTimeout(bosses._t);
    bosses._t = setTimeout(() => bosses(el).then(() => { const i = $("#b-q"); i.focus(); i.setSelectionRange(i.value.length, i.value.length); }), 250);
  };
  $("#b-hidden").onchange = (e) => { state.showHidden = e.target.checked; bosses(el); };
  el.onclick = (e) => {
    const t = e.target;
    if (t.dataset.f) { state.bossFilter = t.dataset.f; bosses(el); }
    if (t.dataset.hide) {
      const b = bossById(+t.dataset.hide);
      guard(async () => { await BossesApi.edit(b.id, { hidden: b.hidden ? 0 : 1 }); bosses(el); });
    }
    if (t.dataset.price) priceModal(bossById(+t.dataset.price), () => bosses(el));
    if (t.id === "n-add") guard(async () => {
      await BossesApi.add({
        name: $("#n-name").value, difficulty: $("#n-diff").value, cycle: $("#n-cycle").value,
        price: parseMeso($("#n-price").value), max_party: +$("#n-max").value, effective_from: todayStr(),
      });
      toast("보스 추가"); bosses(el);
    });
  };
}

function priceModal(b, done) {
  const draw = () => openModal(`
    <h3>${esc(bossLabel(b))} <span class="pill ${b.cycle}">${CYCLE[b.cycle]}</span></h3>
    <div class="row">
      <label class="field">새 가격<input id="pp-price" class="meso" placeholder="예: 15억 6000만"></label>
      <label class="field">적용일 (패치일)<input type="date" id="pp-date" value="${todayStr()}"></label>
      <label class="field">최대 파티 인원<input type="number" id="pp-max" min="1" max="6" value="${b.max_party}"></label>
      <label class="field">API 이름 (자동 체크 매칭용)<input id="pp-api" value="${esc(b.api_name || "")}" placeholder="${esc(b.name)}"></label>
      <label class="field" style="flex:1;min-width:240px">이미지 주소 (같은 이름 보스 전체에 적용)<input id="pp-img" value="${esc(b.image_url || "")}" placeholder="https://..."></label>
      <button class="primary" id="pp-ok" style="align-self:flex-end">저장</button></div>
    <h3 style="margin-top:16px">가격 이력</h3>
    <table><thead><tr><th>적용일</th><th class="num">가격</th><th></th></tr></thead><tbody>
      ${b.history.map((h) => `<tr><td>${h.effective_from}</td><td class="num">${fmt(h.price)} <span class="small muted">(${h.price.toLocaleString()})</span></td>
        <td>${b.history.length > 1 ? `<button class="link danger" data-pdel="${h.id}">삭제</button>` : ""}</td></tr>`).join("")}
    </tbody></table>
    <div class="row" style="margin-top:12px;justify-content:space-between">
      <button class="danger" id="pp-delboss">보스 삭제</button><button id="pp-close">닫기</button></div>`);
  draw();
  const refresh = async () => {
    state.bosses = await BossesApi.list();
    b = bossById(b.id);
    draw();
  };
  $("#modal-box").onclick = (e) => {
    const t = e.target;
    if (t.id === "pp-close") { closeModal(); done(); }
    if (t.id === "pp-ok") guard(async () => {
      const price = parseMeso($("#pp-price").value);
      const max = +$("#pp-max").value;
      const apiName = $("#pp-api").value.trim(), img = $("#pp-img").value.trim();
      if (max !== b.max_party || apiName !== (b.api_name || "")) await BossesApi.edit(b.id, { max_party: max, api_name: apiName });
      if (img !== (b.image_url || ""))
        await Promise.all(state.bosses.filter((x) => x.name === b.name).map((x) => BossesApi.edit(x.id, { image_url: img })));
      if (price != null) await BossesApi.addPrice(b.id, { price, effective_from: $("#pp-date").value });
      toast("저장했어요"); await refresh();
    });
    if (t.dataset.pdel && confirm("이 가격을 지울까요?")) guard(async () => { await BossesApi.removePrice(t.dataset.pdel); await refresh(); });
    if (t.id === "pp-delboss" && confirm(`${bossLabel(b)}를 삭제할까요? (기록이 있으면 숨기기만 가능)`))
      guard(async () => { await BossesApi.remove(b.id); closeModal(); done(); });
  };
}

views.bosses = bosses;
