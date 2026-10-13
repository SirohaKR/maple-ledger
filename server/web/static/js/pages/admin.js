// 관리자 화면
// 서버 요청은 js/api/admin.js 에 있어요.

async function admin(el) {
  if (!isAdmin()) { el.innerHTML = `<div class="card empty">관리자만 볼 수 있어요</div>`; return; }
  const a = await AdminApi.overview();
  el.innerHTML = `
    <h2>관리</h2>
    <div class="card"><h3>🎟 초대 코드</h3>
      <p class="small muted">길드원에게 이 코드를 알려 주면 가입할 수 있어요. 바꾸면 예전 코드로는 더 이상 가입할 수 없어요(이미 가입한 사람은 그대로).</p>
      <div class="row"><code class="invite">${esc(a.invite_code || "(없음)")}</code>
        <button id="ad-copy">복사</button><button id="ad-new">새로 만들기</button></div></div>
    <div class="card"><h3>👥 사용자 (${a.users.length}명)</h3><div class="table-wrap"><table>
      <thead><tr><th>아이디</th><th>가입일</th><th class="num">캐릭터</th><th>API 키</th><th>권한</th><th></th></tr></thead>
      <tbody>${a.users.map((u) => `<tr><td><b>${esc(u.username)}</b>${u.id === state.me.id ? ' <span class="pill">나</span>' : ""}</td>
        <td class="small muted">${(u.created_at || "").slice(0, 10)}</td><td class="num">${u.chars}</td>
        <td>${u.has_key ? '<span class="pill api">등록</span>' : '<span class="pill pending">없음</span>'}</td>
        <td>${u.is_admin ? '<span class="pill">관리자</span>' : "길드원"}</td>
        <td style="white-space:nowrap">${u.id === state.me.id ? "" : `
          <button class="link" data-pw="${u.id}">비밀번호 초기화</button>
          <button class="link" data-adm="${u.id}" data-v="${u.is_admin ? 0 : 1}">${u.is_admin ? "관리자 해제" : "관리자로"}</button>
          <button class="link danger" data-del="${u.id}" data-name="${esc(u.username)}">삭제</button>`}</td></tr>`).join("")}
      </tbody></table></div></div>
    <div class="card"><div class="row spread"><h3>📝 업데이트 내역 관리</h3><button id="cl-new">+ 새 버전 직접 쓰기</button></div>
      <p class="small muted">초안(CHANGELOG.md)을 불러와서 문구를 고친 다음 <b>게시</b>한 버전만 길드원에게 보여요. 올리기 싫은 버전은 그냥 두거나, 이미 올린 건 <b>숨기기</b>.
        한 줄에 하나씩 <code>- 내용</code>, 소제목은 <code>### 제목</code>, 굵게는 <code>**글자**</code>.</p>
      <div id="cl-list" class="cl-admin"><div class="empty small">불러오는 중…</div></div></div>`;
  const STATUS = { draft: ["초안", "pending"], saved: ["저장만 함", "daily"], published: ["게시 중", "api"], hidden: ["숨김", "over"] };
  const drawCl = (items) => {
    $("#cl-list").innerHTML = items.map((it) => {
      const cur = it.post || it.draft || {};
      const [label, cls] = STATUS[it.status];
      return `<div class="cl-item" data-v="${esc(it.version)}">
        <div class="row spread"><div class="row"><b class="cl-title" style="font-size:16px">${esc(it.version)}</b><span class="pill ${cls}">${label}</span>
          ${it.post && it.draft && it.post.body !== it.draft.body ? '<span class="small muted">초안과 문구 다름</span>' : ""}</div>
          <input type="date" data-k="date" value="${esc((cur.date || "").slice(0, 10))}"></div>
        <textarea data-k="body" rows="${Math.min(10, (cur.body || "").split("\n").length + 1)}">${esc(cur.body || "")}</textarea>
        <div class="row" style="justify-content:flex-end;margin-top:6px">
          ${it.draft ? `<button data-act="load">초안 다시 불러오기</button>` : ""}
          <button data-act="preview">미리보기</button>
          <button data-act="save">저장 (게시 안 함)</button>
          ${it.status === "published" ? `<button data-act="hide">숨기기</button>` : `<button class="primary" data-act="publish">${it.status === "hidden" ? "다시 보이기" : "게시"}</button>`}
          ${it.post ? `<button class="danger" data-act="del">게시 취소·문구 삭제</button>` : ""}</div>
        <div class="cl-preview" hidden></div></div>`;
    }).join("") || `<div class="empty small">초안이 없어요</div>`;
    $("#cl-list").onclick = (e) => {
      const b = e.target.closest("button[data-act]");
      if (!b) return;
      const box = b.closest(".cl-item"), v = box.dataset.v, it = items.find((x) => x.version === v);
      const body = $("[data-k=body]", box).value, date = $("[data-k=date]", box).value;
      const put = (extra, msg) => guard(async () => { drawCl(await AdminApi.saveChangelog(v, { body, date, ...extra })); toast(msg); markNewVersion(); });
      if (b.dataset.act === "load") { $("[data-k=body]", box).value = it.draft.body; $("[data-k=date]", box).value = (it.draft.date || "").slice(0, 10); toast("초안을 불러왔어요 (아직 저장 안 됨)"); }
      if (b.dataset.act === "preview") { const pv = $(".cl-preview", box); pv.hidden = !pv.hidden; pv.innerHTML = mdToHtml(postMd({ version: v, date, body })); }
      if (b.dataset.act === "save") put({}, "저장했어요");
      if (b.dataset.act === "publish") put({ published: 1, hidden: 0 }, `${v} 게시했어요`);
      if (b.dataset.act === "hide") put({ hidden: 1 }, `${v} 숨겼어요`);
      if (b.dataset.act === "del" && confirm(`${v}의 게시와 고친 문구를 지울까요? (초안은 남아요)`))
        guard(async () => { drawCl(await AdminApi.removeChangelog(v)); markNewVersion(); });
    };
  };
  guard(async () => drawCl(await AdminApi.changelog()));
  el.onclick = (e) => {
    const t = e.target.closest("button");
    if (!t) return;
    if (t.id === "cl-new") {
      const v = (prompt("새 버전 이름 (예: v1.3)") || "").trim();
      if (v) guard(async () => { await AdminApi.saveChangelog(v, { body: "- ", date: todayStr() }); admin(el); });
    }
    if (t.id === "ad-copy") navigator.clipboard?.writeText(a.invite_code).then(() => toast("복사했어요"));
    if (t.id === "ad-new" && confirm("초대 코드를 새로 만들까요?")) guard(async () => { await AdminApi.newInvite(); admin(el); });
    if (t.dataset.pw) {
      const pw = prompt("새 비밀번호 (6자 이상) — 그 길드원에게 알려 주세요");
      if (pw) guard(async () => { await AdminApi.editUser(t.dataset.pw, { password: pw }); toast("바꿨어요"); });
    }
    if (t.dataset.adm) guard(async () => { await AdminApi.editUser(t.dataset.adm, { is_admin: !!+t.dataset.v }); admin(el); });
    if (t.dataset.del && confirm(`${t.dataset.name}님과 그 사람의 모든 기록을 지울까요? 되돌릴 수 없어요.`))
      guard(async () => { await AdminApi.removeUser(t.dataset.del); admin(el); });
  };
}

views.admin = admin;
