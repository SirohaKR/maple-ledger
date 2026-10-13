// 숙제 화면
// 서버 요청은 js/api/todo.js 에 있어요.

// 넥슨이 주는 값의 형식이 확실하지 않아서 넉넉하게 판정: true/Y/1/등록/완료 → 참, false/N/0/미등록/미완료 → 거짓
const flagOf = (v) => {
  const s = String(v ?? "").trim().toLowerCase();
  if (!s) return null;
  if (/^(false|n|no|0)$/.test(s) || /미|않|아님/.test(s)) return false;
  if (/^(true|y|yes|1)$/.test(s) || /등록|완료|클리어/.test(s)) return true;
  return null;
};
const isTrue = (v) => flagOf(v) === true;
// 몬스터파크(익스트림 제외): 무료 2회만 돌면 완료로 본다 (유료 포함 최대 7회)
const isMonsterPark = (x) => /몬스터\s*파크/.test(x.content_name || "") && !/익스트림/.test(x.content_name || "");
// 지역별 입장 레벨 — 캐릭터 레벨보다 높은 지역의 퀘스트는 숨긴다
const AREA_LEVEL = [["소멸의 여로", 200], ["츄츄", 210], ["레헬른", 220], ["아르카나", 225], ["모라스", 230], ["에스페라", 235],
  ["문브릿지", 245], ["문 브릿지", 245], ["고통의 미궁", 250], ["리멘", 255],
  ["세르니움", 260], ["아르크스", 265], ["오디움", 270], ["도원경", 275], ["아르테리아", 280], ["카르시온", 285],
  ["탈라하트", 290], ["기어드락", 295]];
const openAt = (x, lv) => {
  if (/잠김|미해금|해금 전|조건 미달|입장 불가/.test(x.quest_state || "")) return false;
  const hit = AREA_LEVEL.find(([n]) => (x.content_name || "").includes(n));
  return !hit || !lv || lv >= hit[1];
};
const doneOf = (x) => {
  if (isMonsterPark(x) && +x.now_count >= 2) return true;
  const f = flagOf(x.complete_flag);
  if (f !== null) return f;
  if (x.max_count) return x.now_count >= x.max_count;
  return flagOf(x.quest_state) === true;
};
const registered = (x) => flagOf(x.registration_flag) !== false; // 값이 애매하면 보여준다
const CYCLE_KO = (c) => (/일|day/i.test(c || "") ? "일간" : /월|month/i.test(c || "") ? "월간" : "주간");

function todoItem(x, label) {
  const done = doneOf(x);
  const prog = isMonsterPark(x) ? `${x.now_count}/2 (최대 ${x.max_count || 7})` : x.max_count ? `${x.now_count}/${x.max_count}` : "";
  const goal = isMonsterPark(x) ? 2 : x.max_count;
  const pct = goal ? Math.min(100, Math.round((x.now_count / goal) * 100)) : done ? 100 : 0;
  return `<div class="todo ${done ? "done" : "left"}">
    <span class="tick">${done ? "✓" : ""}</span>
    <div class="todo-main"><div class="row spread" style="flex-wrap:nowrap"><span class="ellipsis">${esc(label)}</span>
      <span class="small ${done ? "muted" : ""}" style="white-space:nowrap">${done ? "완료" : prog || "미완료"}</span></div>
      ${x.max_count > 1 ? `<div class="bar"><i style="width:${pct}%"></i></div>` : ""}</div></div>`;
}

// 같은 type끼리 묶기 (예: 심볼 퀘스트, 에픽 던전 …)
function groupBy(arr, keyFn) {
  const m = new Map();
  for (const x of arr) {
    const k = keyFn(x) || "기타";
    if (!m.has(k)) m.set(k, []);
    m.get(k).push(x);
  }
  return [...m.entries()];
}

function todoSection(title, items, labelFn) {
  if (!items.length) return "";
  const left = items.filter((x) => !doneOf(x)).length;
  return `<div class="todo-sec"><div class="row spread"><h3 style="margin:0">${esc(title)}</h3>
    <span class="pill ${left ? "over" : "api"}">${left ? `${left}개 남음` : "완료"}</span></div>
    ${items.sort((a, b) => doneOf(a) - doneOf(b)).map((x) => todoItem(x, labelFn(x))).join("")}</div>`;
}

async function todo(el) {
  const list = await TodoApi.list();
  const onlyReg = state.todoOnlyReg ?? true;
  const filt = (arr, lv) => (onlyReg ? arr.filter(registered) : arr).filter((x) => openAt(x, lv));
  el.innerHTML = `
    <div class="row spread"><h2>숙제</h2>
      <div class="row"><label class="small"><input type="checkbox" id="td-reg" ${onlyReg ? "checked" : ""}> 스케줄러에 등록한 것만</label>
        ${state.settings.nexon_key_set ? `<button class="primary" id="td-sync">🤖 지금 불러오기</button>` : ""}</div></div>
    <p class="small muted">게임 안 <b>스케줄러에 등록해 둔 항목</b>과 완료 여부를 넥슨 API로 불러와요. 안 한 건 주황색, 한 건 초록 체크로 보여요. 보스 자동 체크 주기마다 같이 갱신돼요.</p>
    ${list.map((c) => {
      const lv = c.character.level;
      const bosses = filt(c.bosses), daily = filt(c.daily, lv), weekly = filt(c.weekly, lv);
      const all = [...bosses, ...daily, ...weekly];
      const left = all.filter((x) => !doneOf(x)).length;
      const bossSecs = groupBy(bosses, (x) => `${CYCLE_KO(x.cycle)} 보스`)
        .map(([t, xs]) => todoSection(t, xs, (x) => `${x.difficulty ? x.difficulty + " " : ""}${x.content_name}`));
      const dailySecs = groupBy(daily, (x) => x.type).map(([t, xs]) => todoSection(`일일 · ${t}`, xs, (x) => x.content_name));
      const weeklySecs = groupBy(weekly, (x) => x.type).map(([t, xs]) => todoSection(`주간 · ${t}`, xs, (x) => x.content_name));
      return `<div class="card">
        <div class="row spread"><div class="char-head">${avatar(c.character)}${charInfo(c.character)}</div>
          <div class="num">${c.fetched_at ? `<div><b style="font-size:24px;color:${left ? "var(--accent)" : "var(--ok)"}">${left}</b> <span class="small muted">개 남음</span></div>
            ${c.boss_limit ? `<div class="small muted">주간 보스 ${c.boss_count ?? 0}/${c.boss_limit}</div>` : ""}
            <div class="small muted">${c.fetched_at.slice(5, 16).replace("T", " ")} 기준</div>` : `<span class="small muted">아직 안 불러옴</span>`}</div></div>
        ${c.fetched_at ? (all.length ? `<div class="todo-grid">${[...bossSecs, ...dailySecs, ...weeklySecs].join("")}</div>`
          : `<div class="empty small">표시할 항목이 없어요.${onlyReg ? " 위의 \"스케줄러에 등록한 것만\"을 꺼 보세요." : ""}</div>`) : ""}
        ${c.fetched_at ? `<details class="small muted" style="margin-top:10px"><summary>원본 데이터 보기 (안 맞으면 이걸 보내 주세요)</summary>
          <pre class="raw">${esc(JSON.stringify({ bosses: c.bosses, daily: c.daily, weekly: c.weekly }, null, 1).slice(0, 6000))}</pre></details>` : ""}
      </div>`;
    }).join("") || `<div class="card empty">캐릭터가 없어요</div>`}`;
  $("#td-reg").onchange = (e) => { state.todoOnlyReg = e.target.checked; todo(el); };
  el.onclick = (e) => { if (e.target.id === "td-sync") runSync(e.target).then(() => todo(el)); };
}

views.todo = todo;
