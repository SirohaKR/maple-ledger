// 설정 화면
// 서버 요청은 js/api/settings.js 에 있어요.

async function settings(el) {
  const s = (state.settings = await SettingsApi.get());
  const r = s.sync_result;
  el.innerHTML = `
    <h2>설정</h2>
    <div class="card"><h3>🔑 넥슨 오픈 API 키 <span class="small muted">— 나만 쓰는 키예요 (다른 길드원과 공유되지 않아요)</span></h3>
      <p class="small muted"><a href="https://openapi.nexon.com/" target="_blank" rel="noopener">openapi.nexon.com</a> 로그인 → 마이 페이지 → 애플리케이션 등록(게임: 메이플스토리) → API Key 복사.
        <b>본인 계정으로 발급한 키</b>여야 내 캐릭터 목록과 보스 완료 여부를 불러올 수 있어요. 키는 이 서버(NAS)의 DB에만 저장돼요.</p>
      <div class="row">
        <input id="s-key" type="password" placeholder="${s.nexon_key_set ? `저장됨 (${esc(s.nexon_key_hint)}) — 바꾸려면 새 키 입력` : "API 키 붙여넣기"}" style="flex:1;min-width:260px">
        <button class="primary" id="s-key-save">키 저장</button>
        ${s.nexon_key_set ? `<button class="danger" id="s-key-del">키 삭제</button>` : ""}</div></div>

    <div class="card"><h3>🤖 보스 자동 체크</h3>
      <p class="small muted">넥슨 스케줄러 API로 등록된 캐릭터의 보스 완료 여부를 주기적으로 읽어서 보스 기록에 자동 체크해요(파티 인원은 프리셋 값).
        직접 체크한 기록은 건드리지 않아요. 캐릭터 1명당 1회 호출이라, 캐릭터가 많으면 넥슨 API 하루 호출 한도를 생각해서 주기를 넉넉히 잡아 주세요.</p>
      <div class="row">
        <label class="field">체크 주기(분, 0 = 끔)<input type="number" id="s-iv" min="0" value="${esc(s.sync_interval)}"></label>
        <button id="s-iv-save" style="align-self:flex-end">저장</button>
        <button class="primary" id="s-sync" style="align-self:flex-end" ${s.nexon_key_set ? "" : "disabled"}>지금 체크</button></div>
      <div class="sync-bar" style="margin-top:10px">${syncSummary(s)}</div>
      ${r && r.errors.length ? `<div class="small" style="color:var(--warn);margin-top:6px">${r.errors.map(esc).join("<br>")}</div>` : ""}
      ${r && r.unmatched.length ? `<div class="small" style="margin-top:8px"><b>매칭 안 된 보스</b> <span class="muted">— 보스 가격표의 "가격 변경"에서 <b>API 이름</b>을 아래 이름으로 넣어 주세요</span>
        <div class="row" style="margin-top:4px">${r.unmatched.map((u) => `<span class="pill pending">${esc(u)}</span>`).join("")}</div></div>` : ""}
    </div>

    <div class="card"><h3>💎 솔 에르다 조각</h3>
      <p class="small muted">사냥 기록에서 "조각 판매 반영"을 체크하면 저장 시점의 시세와 수수료로 수익이 계산돼요. 나중에 시세를 바꿔도 지난 기록은 그대로예요.</p>
      <div class="row">
        <label class="field">조각 1개 시세<input id="s-fp" class="meso" value="${esc(s.fragment_price)}"></label>
        <label class="field">판매 수수료(%)<input type="number" id="s-ff" min="0" max="100" step="0.5" value="${esc(s.fragment_fee)}"></label>
        <button class="primary" id="s-frag-save" style="align-self:flex-end">저장</button>
        <span class="small muted" style="align-self:flex-end">현재 ${fmt(+s.fragment_price)}</span></div></div>

    <div class="card"><h3>🔨 강화 · 공지</h3>
      <p class="small muted">스타포스 비용 추정에 MVP·PC방 할인을 반영해요(17성 미만). 공지 감시는 1시간마다 업데이트·일반·이벤트 공지를 확인해서 단어가 나오면 대시보드에 알려줘요.</p>
      <div class="form-grid">
        <label class="field">MVP·PC방 스타포스 할인(%)<input type="number" id="s-sfd" min="0" max="30" step="1" value="${esc(s.starforce_discount)}"></label>
        <label class="field">강화 기록 처음 불러올 일수<input type="number" id="s-bf" min="1" max="365" value="${esc(s.enhance_backfill_days)}"></label>
        <label class="field">장부 시작일 (이 날 이전 지출은 대시보드에서 빼요 · ${esc(s.spend_count_from || "")} 이전은 안 돼요)<input type="date" id="s-ls" min="${esc(s.spend_count_from || "")}" value="${esc(s.ledger_start || "")}"></label>
        <label class="field span2">공지 감시 단어 (쉼표로 구분${isAdmin() ? "" : " · 관리자만 변경"})<input id="s-kw" value="${esc(s.notice_keywords || "")}" placeholder="결정석, 스타포스" ${isAdmin() ? "" : "disabled"}></label>
        <button class="primary" id="s-misc-save">저장</button></div></div>

    <div class="card"><h3>📜 결정석 판매 규칙</h3>
      <p class="small muted">패치로 규칙이 바뀌면 적용일과 함께 새 규칙을 추가해 주세요. 각 주는 그 주 시작일(목) 기준 규칙으로 계산되고, 한도 안에서 1개당 가격이 비싼 결정석부터 팔았다고 가정해요. 0 = 제한 없음.</p>
      <table><thead><tr><th>적용일</th><th class="num">캐릭터당</th><th class="num">월드당</th><th>일간 결정석 포함</th><th></th></tr></thead><tbody>
        ${s.rules.map((r) => `<tr><td>${r.effective_from}</td><td class="num">${r.char_limit || "제한 없음"}</td><td class="num">${r.world_limit || "제한 없음"}</td>
          <td>${r.daily_in_limit ? "포함" : "제외"}</td><td>${isAdmin() && s.rules.length > 1 ? `<button class="link danger" data-rdel="${r.id}">삭제</button>` : ""}</td></tr>`).join("")}
      </tbody></table>
      <div class="row" style="margin-top:10px" ${isAdmin() ? "" : "hidden"}>
        <label class="field">적용일<input type="date" id="s-eff" value="${todayStr()}"></label>
        <label class="field">캐릭터당 주간 한도<input type="number" id="s-limit" min="0" value="0"></label>
        <label class="field">월드당 주간 한도<input type="number" id="s-world" min="0" value="90"></label>
        <label class="small" style="align-self:flex-end"><input type="checkbox" id="s-daily" checked> 일간 결정석도 한도에 포함</label>
        <button class="primary" id="s-rule-save" style="align-self:flex-end">규칙 추가</button></div></div>

    <div class="card"><h3>🔒 내 계정 (${esc(state.me.username)})</h3>
      <div class="form-grid">
        <label class="field">지금 비밀번호<input type="password" id="pw-old" autocomplete="current-password"></label>
        <label class="field">새 비밀번호 (6자 이상)<input type="password" id="pw-new" autocomplete="new-password"></label>
        <button class="primary" id="pw-save">비밀번호 바꾸기</button>
        <button id="logout">로그아웃</button></div></div>`;
  el.onclick = (e) => {
    const t = e.target;
    if (t.id === "pw-save") guard(async () => {
      await SettingsApi.changePassword({ old: $("#pw-old").value, new: $("#pw-new").value });
      toast("비밀번호를 바꿨어요"); $("#pw-old").value = $("#pw-new").value = "";
    });
    if (t.id === "logout") logout();
    if (t.id === "s-key-save") {
      const key = $("#s-key").value.trim();
      if (!key) return toast("키를 입력해 주세요", true);
      guard(async () => { state.settings = await SettingsApi.save({ nexon_api_key: key }); toast("API 키 저장"); settings(el); });
    }
    if (t.id === "s-key-del" && confirm("API 키를 지울까요?"))
      guard(async () => { await SettingsApi.save({ clear_nexon_api_key: true }); settings(el); });
    if (t.id === "s-iv-save")
      guard(async () => { state.settings = await SettingsApi.save({ sync_interval: +$("#s-iv").value || 0 }); toast("저장했어요"); settings(el); });
    if (t.id === "s-sync") runSync(t).then(() => settings(el));
    if (t.id === "s-misc-save") guard(async () => {
      state.settings = await SettingsApi.save({ starforce_discount: $("#s-sfd").value, enhance_backfill_days: $("#s-bf").value, notice_keywords: $("#s-kw").value, ledger_start: $("#s-ls").value });
      toast("저장했어요"); settings(el);
    });
    if (t.id === "s-frag-save") guard(async () => {
      state.settings = await SettingsApi.save({ fragment_price: parseMeso($("#s-fp").value), fragment_fee: $("#s-ff").value });
      toast("저장했어요"); settings(el);
    });
    if (t.id === "s-rule-save") guard(async () => {
      state.settings = await SettingsApi.addRule({
        effective_from: $("#s-eff").value, char_limit: +$("#s-limit").value || 0,
        world_limit: +$("#s-world").value || 0, daily_in_limit: $("#s-daily").checked,
      });
      toast("규칙 추가"); settings(el);
    });
    if (t.dataset.rdel && confirm("이 규칙을 지울까요?"))
      guard(async () => { state.settings = await SettingsApi.removeRule(t.dataset.rdel); settings(el); });
  };
}

views.settings = settings;
