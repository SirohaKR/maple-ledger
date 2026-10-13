// 기타 수익 화면
// 서버 요청은 js/api/incomes.js 에 있어요.

const KIND = { drop: "보스 드랍", fragment: "조각 판매", side: "부수입", etc: "기타" };

function incomeShare(f) {
  const net = f.gross * (1 - f.fee_rate / 100), n = Math.max(1, f.party_size);
  if (n === 1) return Math.floor(net);
  if (f.split === "ratio") {
    const total = f.leader_ratio + f.member_ratio * (n - 1);
    return total > 0 ? Math.floor((net * (f.role === "leader" ? f.leader_ratio : f.member_ratio)) / total) : 0;
  }
  return Math.floor(net / n);
}

async function incomes(el) {
  const [list, prices] = await Promise.all([IncomesApi.list(), IncomesApi.prices()]);
  const kind = state.incomeKind || "drop";
  const bossOpts = state.bosses.filter((b) => !b.hidden && b.cycle !== "daily")
    .map((b) => `<option value="${b.id}">${esc(bossLabel(b))}</option>`).join("");
  const sumBy = (k) => list.filter((r) => r.sold && r.kind === k).reduce((a, r) => a + r.amount, 0);
  const pend = list.filter((r) => !r.sold);

  el.innerHTML = `
    <h2>기타 수익</h2>
    <div class="tiles">${Object.entries(KIND).map(([k, v]) => `<div class="card tile etc"><div class="label">${v} (전체)</div><div class="value">${fmt(sumBy(k))}</div></div>`).join("")}
      ${pend.length ? `<div class="card tile"><div class="label">미판매 ${pend.length}건 (합계 제외)</div><div class="value">${fmt(pend.reduce((a, r) => a + r.amount, 0))}</div></div>` : ""}</div>
    <div class="card"><h3 id="i-title">➕ 수익 기록</h3>
      <div class="tabs">${Object.entries(KIND).map(([k, v]) => `<button data-kind="${k}" class="${kind === k ? "on" : ""}">${v}</button>`).join("")}</div>
      <input type="hidden" id="i-id">
      <div class="form-grid">
        <label class="field">날짜<input type="date" id="i-date" value="${todayStr()}" max="${todayStr()}"></label>
        <label class="field">캐릭터<select id="i-char">${charOpts()}</select></label>
        ${kind === "drop" ? `<label class="field">보스<select id="i-boss"><option value="">-</option>${bossOpts}</select></label>` : ""}
        <label class="field">${kind === "drop" ? "아이템" : kind === "fragment" ? "항목" : "내용"}
          <input id="i-title-in" list="i-items" placeholder="${kind === "drop" ? "예: 미트라의 분노" : kind === "fragment" ? "솔 에르다 조각" : kind === "side" ? "예: 코어 젬스톤" : ""}" value="${kind === "fragment" ? "솔 에르다 조각" : ""}">
          <datalist id="i-items">${prices.map((p) => `<option value="${esc(p.title)}">`).join("")}</datalist></label>
        <label class="field">개수<input type="number" id="i-qty" min="1" value="1"></label>
        <label class="field i-unit-f">개당 가격 (단가)<input id="i-unit" placeholder="예: 584만" value="${kind === "fragment" ? esc(state.settings.fragment_price || "") : ""}"></label>
        <label class="field"><span id="i-gross-l">판매 총액</span><input id="i-gross" class="meso" placeholder="예: 12억"></label>
        <label class="field">수수료<select id="i-fee"><option value="0">없음</option><option value="3">3% (MVP)</option><option value="5" ${kind !== "side" ? "selected" : ""}>5%</option></select></label>
        <label class="field">파티 인원<select id="i-party">${partyOptions(6, 1)}</select></label>
        <label class="field">분배<select id="i-split"><option value="equal">정분배 (1/N)</option><option value="ratio">비율 분배</option></select></label>
        <label class="field i-ratio" hidden>내 역할<select id="i-role"><option value="leader">파티장</option><option value="member">파티원</option></select></label>
        <label class="field i-ratio" hidden>파티장 : 파티원<span class="row" style="flex-wrap:nowrap"><input type="number" id="i-lr" value="7" min="0"> : <input type="number" id="i-mr" value="3" min="0"></span></label>
        <label class="check"><input type="checkbox" id="i-sold" checked> 판매 완료</label>
        <label class="field span2">메모<input id="i-note"></label>
      </div>
      <div class="row spread" style="margin-top:14px">
        <div>내 실수령 <b id="i-amount" style="font-size:20px;color:var(--accent)">0</b> <span class="small muted" id="i-hint"></span></div>
        <div class="row"><button id="i-cancel" hidden>수정 취소</button><button class="primary" id="i-save">저장</button></div></div>
    </div>
    <div class="grid">
      <div class="card" style="grid-column: 1 / -1"><h3>기록</h3><div class="table-wrap"><table>
        <thead><tr><th>날짜</th><th>종류</th><th>캐릭터</th><th>내용</th><th class="num">판매 총액</th><th>분배</th><th class="num">내 몫</th><th></th></tr></thead>
        <tbody>${list.map((r) => `<tr class="${r.sold ? "" : "dim"}">
          <td>${r.date}</td><td><span class="pill ${r.kind === "drop" ? "" : "monthly"}">${KIND[r.kind]}</span> ${r.sold ? "" : '<span class="pill pending">미판매</span>'}</td>
          <td>${esc(r.character_name || "")}</td>
          <td>${r.boss_name ? `<span class="muted small">${esc(r.boss_difficulty + " " + r.boss_name)}</span> ` : ""}${esc(r.title || "")}${r.qty > 1 ? ` ×${r.qty}` : ""}${r.note ? ` <span class="small muted">· ${esc(r.note)}</span>` : ""}</td>
          <td class="num">${fmt(r.gross)}${r.fee_rate ? ` <span class="small muted">-${r.fee_rate}%</span>` : ""}</td>
          <td class="small">${r.party_size > 1 ? (r.split === "ratio" ? `${r.party_size}인 ${r.leader_ratio}:${r.member_ratio} (${r.role === "leader" ? "파티장" : "파티원"})` : `${r.party_size}인 정분배`) : "솔로"}</td>
          <td class="num"><b>${fmt(r.amount)}</b></td>
          <td style="white-space:nowrap">${r.sold ? "" : `<button class="link" data-sell="${r.id}">판매 완료</button>`}<button class="link" data-iedit="${r.id}">수정</button><button class="link danger" data-idel="${r.id}">삭제</button></td></tr>`).join("") || `<tr><td colspan="8" class="empty">아직 기록이 없어요</td></tr>`}
        </tbody></table></div></div>
      ${prices.length ? `<div class="card"><h3>📈 개인 시세 (팔린 드랍, 1개당·수수료 전)</h3><table>
        <thead><tr><th>아이템</th><th class="num">횟수</th><th class="num">평균</th><th class="num">최근</th></tr></thead>
        <tbody>${prices.map((p) => `<tr><td>${esc(p.title)}</td><td class="num">${p.n}</td><td class="num">${fmt(p.avg)}</td><td class="num">${fmt(p.last)}</td></tr>`).join("")}</tbody></table></div>` : ""}
    </div>`;

  const form = () => ({
    kind, date: $("#i-date").value, character_id: $("#i-char").value || null,
    boss_id: $("#i-boss")?.value || null, title: $("#i-title-in").value, qty: +$("#i-qty").value || 1,
    gross: parseMeso($("#i-gross").value) || 0, fee_rate: +$("#i-fee").value, party_size: +$("#i-party").value,
    split: $("#i-split").value, role: $("#i-role").value, leader_ratio: +$("#i-lr").value || 0, member_ratio: +$("#i-mr").value || 0,
    sold: $("#i-sold").checked, note: $("#i-note").value,
  });
  // 조각 판매·부수입은 개수 × 단가로 총액 자동 (단, 이름에 '장비'가 들어간 장비 판매는 총액 직접)
  const unitMode = () => (kind === "fragment" || kind === "side") && !/장비/.test($("#i-title-in").value);
  const syncGross = () => {
    const on = unitMode();
    $$(".i-unit-f", el).forEach((x) => (x.hidden = !on));
    $("#i-gross").readOnly = on;
    $("#i-gross-l").textContent = on ? "판매 총액 (개수 × 단가 자동)" : "판매 총액";
    if (on) {
      const unit = parseMeso($("#i-unit").value) || 0, qty = +$("#i-qty").value || 0;
      $("#i-gross").value = unit && qty ? unit * qty : "";
    }
  };
  const preview = () => {
    syncGross();
    const f = form();
    $$(".i-ratio", el).forEach((x) => (x.hidden = !(f.split === "ratio" && f.party_size > 1)));
    $("#i-amount").textContent = fmt(incomeShare(f));
    const p = prices.find((x) => x.title === f.title);
    $("#i-hint").textContent = p ? `개인 시세 평균 ${fmt(p.avg)} · 최근 ${fmt(p.last)}` : "";
  };
  preview();
  el.oninput = el.onchange = (e) => { if (e.target.closest(".card")?.querySelector("#i-save")) preview(); };

  const fill = (r) => {
    state.incomeKind = r.kind;
    incomes(el).then(() => {
      $("#i-id").value = r.id; $("#i-date").value = r.date; $("#i-char").value = r.character_id ?? "";
      if ($("#i-boss")) $("#i-boss").value = r.boss_id ?? "";
      $("#i-title-in").value = r.title || ""; $("#i-qty").value = r.qty; $("#i-gross").value = r.gross;
      $("#i-unit").value = r.qty ? Math.round(r.gross / r.qty) : "";
      $("#i-fee").value = String(r.fee_rate).replace(/\.0$/, ""); $("#i-party").value = r.party_size; $("#i-split").value = r.split;
      $("#i-role").value = r.role; $("#i-lr").value = r.leader_ratio; $("#i-mr").value = r.member_ratio;
      $("#i-sold").checked = !!r.sold; $("#i-note").value = r.note || "";
      $("#i-title").textContent = "✏️ 기록 수정"; $("#i-cancel").hidden = false;
      preview(); $("#i-title").scrollIntoView({ behavior: "smooth" });
    });
  };

  el.onclick = (e) => {
    const t = e.target;
    if (t.dataset.kind) { state.incomeKind = t.dataset.kind; incomes(el); }
    if (t.id === "i-cancel") incomes(el);
    if (t.id === "i-save") {
      const f = form(), id = $("#i-id").value;
      if (!f.gross) return toast("판매 총액을 넣어 주세요", true);
      guard(async () => { await (id ? IncomesApi.edit(id, f) : IncomesApi.add(f)); toast("저장했어요"); incomes(el); });
    }
    if (t.dataset.iedit) fill(list.find((r) => r.id === +t.dataset.iedit));
    if (t.dataset.sell) {
      const r = list.find((x) => x.id === +t.dataset.sell);
      const g = prompt("판매 총액 (수수료 전)", r.gross);
      if (g !== null) guard(async () => { await IncomesApi.edit(r.id, { ...r, gross: parseMeso(g) ?? r.gross, sold: true }); incomes(el); });
    }
    if (t.dataset.idel && confirm("이 기록을 지울까요?")) guard(async () => { await IncomesApi.remove(t.dataset.idel); incomes(el); });
  };
}

views.incomes = incomes;
