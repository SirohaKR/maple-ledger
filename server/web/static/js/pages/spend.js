// 강화 · 지출 화면
// 서버 요청은 js/api/spend.js 에 있어요.

const KIND_LABEL = { starforce: "스타포스", potential: "잠재능력 재설정", cube: "큐브" };
const EXPENSE_CATS = ["장비 구매", "솔 에르다 조각 구매", "강화 (직접)", "펫", "코디", "도핑", "메이플포인트", "기타"];
async function spend(el) {
  const days = state.spendDays || 7;
  const from = new Date(Date.now() + 9 * 3600e3 - (days - 1) * 86400e3).toISOString().slice(0, 10);
  const names = state.chars.map((c) => c.name);
  const who = state.spendChar && names.includes(state.spendChar) ? state.spendChar : names[0];
  state.spendChar = who;
  const [en, exAll] = await Promise.all([
    SpendApi.enhance(from, who),
    SpendApi.expenses(from),
  ]);
  const rows = en.rows;
  const whoId = state.chars.find((c) => c.name === who)?.id;
  const ex = exAll.filter((x) => x.character_id === whoId);
  const counts = Object.fromEntries(en.characters.map((c) => [c.name, c]));
  const sumCost = (f) => rows.filter(f).reduce((a, r) => a + (r.cost || 0), 0);
  const sf = sumCost((r) => r.kind === "starforce"), pot = sumCost((r) => r.kind === "potential");
  const manual = ex.reduce((a, r) => a + r.amount, 0);
  const unpriced = rows.filter((r) => r.cost == null && r.kind !== "cube").length;

  // 장비별 요약
  const byItem = {};
  for (const r of rows) {
    const k = r.target_item || "(알 수 없음)";
    const g = (byItem[k] ||= { name: k, icon: r.icon, n: 0, ok: 0, boom: 0, cost: 0, kinds: new Set(), maxStar: null, grade: null });
    g.n++; g.cost += r.cost || 0; g.kinds.add(r.kind);
    if (/성공|상승/.test(r.result || "")) g.ok++;
    if (/파괴/.test(r.result || "")) g.boom++;
    if (r.kind === "starforce" && r.after_star != null) g.maxStar = Math.max(g.maxStar ?? 0, r.after_star);
    if (r.grade && !g.grade) g.grade = r.grade;
  }
  const items = Object.values(byItem).sort((a, b) => b.cost - a.cost || b.n - a.n);

  el.innerHTML = `
    <div class="row spread"><h2>강화 · 지출</h2>
      <div class="row">
        <div class="tabs" style="margin:0">${[7, 30, 90].map((d) => `<button data-days="${d}" class="${days === d ? "on" : ""}">${d}일</button>`).join("")}</div>
        ${state.settings.nexon_key_set ? `<button class="primary" id="en-sync">🔄 강화 기록 불러오기</button>` : ""}</div></div>
    <div class="char-tabs">${state.chars.map((x) => `<button data-sc="${esc(x.name)}" class="${x.name === who ? "on" : ""}">${avatar(x)}<span>${esc(x.name)}</span>
      ${counts[x.name] ? `<span class="small muted">${counts[x.name].n}회</span>` : ""}</button>`).join("")}</div>
    <p class="small muted">넥슨 API의 스타포스·잠재능력 재설정·큐브 기록을 가져와요(계정 전체를 한 번에 불러오고, 여기서는 고른 캐릭터 것만 보여요). 비용은 공식으로 <b>추정</b>한 값이라 비용을 눌러 직접 고칠 수 있어요.
      ${en.last_sync ? `마지막으로 불러온 시각: ${en.last_sync.slice(5, 16).replace("T", " ")}` : "아직 안 불러왔어요."}</p>
    <div class="tiles">
      <div class="card tile hero"><div class="label">${esc(who || "")} · 최근 ${days}일 총지출</div><div class="value">${fmt(sf + pot + manual)}</div>
        <div class="small" style="opacity:.9">강화 ${rows.length.toLocaleString()}회${unpriced ? ` · 비용 미계산 ${unpriced}회` : ""}</div></div>
      <div class="card tile boss"><div class="label">스타포스</div><div class="value">${fmt(sf)}</div>
        <div class="small muted">${rows.filter((r) => r.kind === "starforce").length}회 · 파괴 ${rows.filter((r) => /파괴/.test(r.result || "")).length}회</div></div>
      <div class="card tile hunt"><div class="label">잠재능력 재설정</div><div class="value">${fmt(pot)}</div>
        <div class="small muted">${rows.filter((r) => r.kind === "potential").length}회 · 큐브 ${rows.filter((r) => r.kind === "cube").length}개</div></div>
      <div class="card tile etc"><div class="label">직접 넣은 지출</div><div class="value">${fmt(manual)}</div><div class="small muted">${ex.length}건</div></div>
    </div>
    ${items.length ? `<div class="card"><h3>장비별</h3><div class="item-grid">${items.slice(0, 24).map((g) => `
      <div class="item-card">${itemIcon(g.icon, gradeClass(g.grade), tipAttr(en.items[g.name]))}
        <div style="min-width:0"><div class="ellipsis"><b>${esc(g.name)}</b></div>
          <div class="small muted">${[...g.kinds].map((k) => KIND_LABEL[k]).join("·")} ${g.n}회${g.boom ? ` · <span style="color:var(--warn)">파괴 ${g.boom}</span>` : ""}${g.maxStar != null ? ` · 최고 ${g.maxStar}성` : ""}</div>
          <div><b>${fmt(g.cost)}</b></div></div></div>`).join("")}</div></div>` : ""}
    <div class="grid split">
      <div class="card"><h3 id="x-title">✍️ 지출 직접 기록</h3>
        <input type="hidden" id="x-id">
        <div class="form-grid">
          <label class="field">날짜<input type="date" id="x-date" value="${todayStr()}" max="${todayStr()}"></label>
          <label class="field">캐릭터<select id="x-char">${charOpts(whoId)}</select></label>
          <label class="field">분류<select id="x-cat">${EXPENSE_CATS.map((c) => `<option>${c}</option>`).join("")}</select></label>
          <label class="field">금액<input id="x-amount" placeholder="예: 30억"></label>
          <label class="field span2">메모<input id="x-note"></label>
          <button id="x-cancel" hidden>수정 취소</button>
          <button class="primary" id="x-save">저장</button></div>
        <div class="table-wrap" style="margin-top:14px"><table><tbody>${ex.map((x) => `<tr>
          <td>${x.date}</td><td><span class="pill">${esc(x.category)}</span></td><td>${esc(x.character_name || "")}</td>
          <td class="small muted">${esc(x.note || "")}</td><td class="num"><b>${fmt(x.amount)}</b></td>
          <td style="white-space:nowrap"><button class="link" data-xedit="${x.id}">수정</button><button class="link danger" data-xdel="${x.id}">삭제</button></td></tr>`).join("") || `<tr><td class="empty">직접 넣은 지출이 없어요</td></tr>`}</tbody></table></div></div>
      <div class="card"><h3>강화 기록</h3><div class="table-wrap" style="max-height:640px;overflow-y:auto"><table>
        <thead><tr><th>일시</th><th>장비</th><th>내용</th><th>결과</th><th class="num">비용</th></tr></thead>
        <tbody>${rows.slice(0, 500).map((r) => `<tr>
          <td class="small">${(r.at || r.date).slice(5, 16)}<div class="muted">${esc(r.character_name || "")}</div></td>
          <td><div class="row" style="flex-wrap:nowrap">${itemIcon(r.icon, gradeClass(r.grade), tipAttr(en.items[r.target_item]))}<span class="small">${esc(r.target_item || "")}${r.level ? `<div class="muted">Lv.${r.level}</div>` : ""}</span></div></td>
          <td class="small"><span class="pill ${r.kind === "starforce" ? "" : "daily"}">${KIND_LABEL[r.kind]}</span>
            ${r.kind === "starforce" ? ` ${r.before_star}→${r.after_star}성${r.destroy_defence ? " 🛡" : ""}` : ` ${esc(r.sub || "")} ${r.grade ? `<span class="${gradeClass(r.grade)}-t">${esc(r.grade)}</span>` : ""}`}
            ${r.kind === "starforce" && r.sub ? `<div class="muted">${esc(r.sub)}</div>` : ""}</td>
          <td><span class="pill ${resultClass(r.result)}">${esc(r.result || "-")}</span></td>
          <td class="num"><button class="link" data-cost="${esc(r.id)}" title="눌러서 직접 고치기">${r.cost == null ? '<span class="pill pending">미계산</span>' : fmt(r.cost)}${r.cost_manual ? " ✎" : ""}</button></td></tr>`).join("") || `<tr><td colspan="5" class="empty">기록이 없어요. 위의 "강화 기록 불러오기"를 눌러 주세요.</td></tr>`}
        </tbody></table></div>${rows.length > 500 ? `<div class="small muted">최근 500개만 보여요</div>` : ""}</div>
    </div>`;

  const resetX = () => spend(el);
  el.onclick = (e) => {
    const t = e.target.closest("button") || e.target;
    if (t.dataset.days) { state.spendDays = +t.dataset.days; spend(el); }
    if (t.dataset.sc) { state.spendChar = t.dataset.sc; spend(el); }
    if (t.id === "en-sync") {
      t.disabled = true; t.textContent = "불러오는 중… (처음엔 오래 걸려요)";
      guard(async () => {
        const r = await SpendApi.syncEnhance();
        toast(`새 기록 ${r.added}개${r.errors.length ? ` · 오류 ${r.errors.length}` : ""}`, !!r.errors.length);
        if (r.errors.length) console.warn(r.errors);
      }).finally(() => spend(el));
    }
    if (t.dataset.cost) {
      const r = rows.find((x) => x.id === t.dataset.cost);
      const v = prompt("실제 비용 (비우면 추정값으로 되돌려요)", r.cost ?? "");
      if (v === null) return;
      guard(async () => {
        await SpendApi.setCost(r.id, v.trim() ? { cost: parseMeso(v) } : { reset: true });
        spend(el);
      });
    }
    if (t.id === "x-save") {
      const body = { date: $("#x-date").value, character_id: $("#x-char").value || null, category: $("#x-cat").value,
        amount: parseMeso($("#x-amount").value), note: $("#x-note").value };
      if (!body.amount) return toast("금액을 넣어 주세요", true);
      const id = $("#x-id").value;
      guard(async () => { await (id ? SpendApi.editExpense(id, body) : SpendApi.addExpense(body)); toast("저장했어요"); spend(el); });
    }
    if (t.id === "x-cancel") resetX();
    if (t.dataset.xedit) {
      const x = ex.find((v) => v.id === +t.dataset.xedit);
      $("#x-id").value = x.id; $("#x-date").value = x.date; $("#x-char").value = x.character_id ?? "";
      $("#x-cat").value = x.category; $("#x-amount").value = x.amount; $("#x-note").value = x.note || "";
      $("#x-title").textContent = "✏️ 지출 수정"; $("#x-cancel").hidden = false;
    }
    if (t.dataset.xdel && confirm("이 지출을 지울까요?")) guard(async () => { await SpendApi.removeExpense(t.dataset.xdel); spend(el); });
  };
}

views.spend = spend;
