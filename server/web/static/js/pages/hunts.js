// 사냥 화면
// 서버 요청은 js/api/hunts.js 에 있어요.

async function hunts(el) {
  const list = await HuntsApi.list();
  const running = list.filter((h) => h.status === "running");
  const done = list.filter((h) => h.status === "done");
  const perHour = (h) => (h.minutes && h.meso != null ? fmt(Math.round((h.meso / h.minutes) * 60)) : "-");
  const fragPrice = +state.settings.fragment_price || 0, fragFee = +state.settings.fragment_fee || 0;

  el.innerHTML = `
    <h2>사냥</h2>
    ${running.map((h) => h.ended_at ? `
      <div class="card running ended" data-run="${h.id}">
        <div class="row spread"><div><b>${esc(h.character_name || "")}</b> ${esc(h.place || "")} <span class="pill">사냥 끝 · 기록 작성</span>
          <div class="small muted">${h.started_at.slice(11, 16)} ~ ${h.ended_at.slice(11, 16)} · 시작 메소 ${fmt(h.meso_start)}</div></div>
          <div class="timer" data-start="${h.started_at}" data-end="${h.ended_at}">00:00:00</div></div>
        <p class="small muted" style="margin:10px 0 0">시간은 멈췄어요. 지금 인벤토리 메소와 얻은 것들을 적고 저장해 주세요.</p>
        <div class="form-grid" style="margin-top:10px">
          <label class="field">종료 메소<input data-f="meso_end" placeholder="예: 152억 3000만"></label>
          <label class="field">추가 부수입<input data-f="extra" placeholder="코어 젬스톤 등"></label>
          <label class="field">솔 에르다 조각<input type="number" data-f="fragments" min="0"></label>
          <label class="check"><input type="checkbox" data-f="fragments_sold"> 조각 판매 반영</label>
          <label class="field">메모<input data-f="note"></label>
          <button data-resume="${h.id}">다시 이어서 사냥</button>
          <button class="primary" data-stop="${h.id}">저장</button></div>
      </div>` : `
      <div class="card running" data-run="${h.id}">
        <div class="row spread"><div><b>${esc(h.character_name || "")}</b> ${esc(h.place || "")}
          <div class="small muted">시작 ${h.started_at.slice(11, 16)} · 시작 메소 ${fmt(h.meso_start)}</div></div>
          <div class="timer" data-start="${h.started_at}">00:00:00</div></div>
        <div class="row" style="margin-top:12px;justify-content:flex-end">
          <button class="danger" data-del="${h.id}">취소 (기록 안 함)</button>
          <button class="primary big-btn" data-end="${h.id}">⏹ 사냥 종료</button></div>
      </div>`).join("")}
    <div class="grid split">
      <div class="card"><h3>⏱ 타이머로 기록</h3>
        <p class="small muted">시작할 때 인벤토리 메소를 넣고, 끝날 때 종료 메소를 넣으면 시간·획득량·시급이 자동 계산돼요. 다른 기기에서 열어도 이어져요.</p>
        <div class="form-grid">
          <label class="field">캐릭터<select id="t-char">${charOpts()}</select></label>
          <label class="field">사냥터<input id="t-place" placeholder="예: 오디움 1"></label>
          <label class="field">시작 메소<input id="t-start" placeholder="예: 150억"></label>
          <button class="primary" id="t-go">시작</button></div></div>
      <div class="card"><h3 id="m-title">✍️ 직접 기록</h3>
        <input type="hidden" id="m-id">
        <div class="form-grid">
          <label class="field">날짜<input type="date" id="m-date" value="${todayStr()}" max="${todayStr()}"></label>
          <label class="field">캐릭터<select id="m-char">${charOpts()}</select></label>
          <label class="field">사냥터<input id="m-place"></label>
          <label class="field">시간(분)<input type="number" id="m-min" min="0"></label>
          <label class="field">획득 메소<input id="m-meso" placeholder="예: 3억 2000만"></label>
          <label class="field">추가 부수입<input id="m-extra" placeholder="코어 젬스톤, 장비 판매 등"></label>
          <label class="field">솔 에르다 조각<input type="number" id="m-frag" min="0"></label>
          <label class="check"><input type="checkbox" id="m-fsold"> 조각 판매 반영</label>
          <label class="field span2">메모<input id="m-note"></label>
          <button id="m-cancel" hidden>수정 취소</button>
          <button class="primary" id="m-save">저장</button></div>
        <p class="small muted" style="margin:12px 0 0">조각 판매 반영 시 저장 시점 시세 <b>${fmt(fragPrice)}</b> · 수수료 ${fragFee}%로 고정돼요 (<a href="#settings">설정</a>에서 변경).</p></div>
    </div>
    <div class="card"><h3>기록</h3><div class="table-wrap"><table>
      <thead><tr><th>날짜</th><th>캐릭터</th><th>사냥터</th><th class="num">시간</th><th class="num">메소</th><th class="num">시급</th>
        <th class="num">부수입</th><th class="num">조각</th><th class="num">합계</th><th>메모</th><th></th></tr></thead>
      <tbody>${done.map((h) => `<tr>
        <td>${h.date}</td><td>${esc(h.character_name || "")}</td><td>${esc(h.place || "")}</td>
        <td class="num">${h.minutes != null ? `${Math.floor(h.minutes / 60)}:${String(h.minutes % 60).padStart(2, "0")}` : "-"}</td>
        <td class="num">${fmt(h.meso)}</td><td class="num muted">${perHour(h)}</td><td class="num">${h.extra ? fmt(h.extra) : ""}</td>
        <td class="num">${h.fragments ?? ""}${h.fragments_sold && h.fragments ? ` <span class="pill monthly" title="판매 반영 (개당 ${fmt(h.fragment_price)}, 수수료 ${h.fragment_fee}%)">+${fmt(h.fragment_income)}</span>` : ""}</td>
        <td class="num"><b>${fmt(h.total)}</b></td>
        <td>${esc(h.note || "")}</td>
        <td style="white-space:nowrap"><button class="link" data-edit="${h.id}">수정</button><button class="link danger" data-del="${h.id}">삭제</button></td></tr>`).join("") || `<tr><td colspan="11" class="empty">아직 기록이 없어요</td></tr>`}
      </tbody></table></div></div>`;

  const tick = () => $$(".timer", el).forEach((t) => {
    const end = t.dataset.end ? new Date(t.dataset.end) : Date.now();
    const sec = Math.max(0, Math.floor((end - new Date(t.dataset.start)) / 1000));
    t.textContent = [sec / 3600, (sec % 3600) / 60, sec % 60].map((v) => String(Math.floor(v)).padStart(2, "0")).join(":");
  });
  tick();
  render._timer = setInterval(tick, 1000);

  const resetForm = () => {
    $("#m-id").value = ""; $("#m-title").textContent = "✍️ 직접 기록";
    $("#m-cancel").hidden = true; $("#m-fsold").checked = false;
    ["#m-place", "#m-min", "#m-meso", "#m-extra", "#m-frag", "#m-note"].forEach((s) => ($(s).value = ""));
  };

  el.onclick = (e) => {
    const t = e.target;
    if (t.id === "t-go") guard(async () => {
      await HuntsApi.start({ character_id: $("#t-char").value || null, place: $("#t-place").value, meso_start: parseMeso($("#t-start").value) });
      hunts(el);
    });
    if (t.dataset.end) guard(async () => { await HuntsApi.end(t.dataset.end); hunts(el); });
    if (t.dataset.resume) guard(async () => { await HuntsApi.resume(t.dataset.resume); hunts(el); });
    if (t.dataset.stop) {
      const box = t.closest("[data-run]");
      const f = Object.fromEntries($$("[data-f]", box).map((i) => [i.dataset.f, i.type === "checkbox" ? i.checked : i.value]));
      guard(async () => {
        await HuntsApi.save(t.dataset.stop, { ...f, meso_end: parseMeso(f.meso_end), extra: parseMeso(f.extra) });
        toast("사냥 기록 완료!");
        hunts(el);
      });
    }
    if (t.dataset.del && confirm("이 기록을 지울까요?")) guard(async () => { await HuntsApi.remove(t.dataset.del); hunts(el); });
    if (t.dataset.edit) {
      const h = done.find((x) => x.id === +t.dataset.edit);
      $("#m-id").value = h.id; $("#m-date").value = h.date; $("#m-char").value = h.character_id ?? "";
      $("#m-place").value = h.place || ""; $("#m-min").value = h.minutes ?? ""; $("#m-meso").value = h.meso ?? "";
      $("#m-extra").value = h.extra ?? ""; $("#m-frag").value = h.fragments ?? ""; $("#m-fsold").checked = !!h.fragments_sold;
      $("#m-note").value = h.note || "";
      $("#m-title").textContent = "✏️ 기록 수정"; $("#m-cancel").hidden = false;
      $("#m-title").scrollIntoView({ behavior: "smooth" });
    }
    if (t.id === "m-cancel") resetForm();
    if (t.id === "m-save") {
      const body = {
        date: $("#m-date").value, character_id: $("#m-char").value || null, place: $("#m-place").value,
        minutes: $("#m-min").value, meso: parseMeso($("#m-meso").value), extra: parseMeso($("#m-extra").value),
        fragments: $("#m-frag").value, fragments_sold: $("#m-fsold").checked, note: $("#m-note").value,
      };
      const id = $("#m-id").value;
      guard(async () => {
        await (id ? HuntsApi.edit(id, body) : HuntsApi.add(body));
        toast("저장했어요");
        hunts(el);
      });
    }
  };
}

views.hunts = hunts;
