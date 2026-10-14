// 메이플 수익 장부 — 공통 코드 (모든 화면이 같이 쓰는 것)
const $ = (s, el = document) => el.querySelector(s);
const $$ = (s, el = document) => [...el.querySelectorAll(s)];
const esc = (v) => String(v ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const CYCLE = { daily: "일간", weekly: "주간", monthly: "월간" };

const state = { me: null, settings: {}, bosses: [], chars: [], week: null, bossFilter: "weekly", bossSearch: "", showHidden: false };
const isAdmin = () => !!state.me?.is_admin;

// ───────── 공통 ─────────
async function api(method, url, body) {
  const res = await fetch(url, {
    method,
    headers: body ? { "Content-Type": "application/json" } : {},
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (res.status === 401 && !url.startsWith("/api/auth/")) {
    showLogin();
    throw new Error("로그인이 필요해요");
  }
  if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
  return data;
}

function toast(msg, err = false) {
  const t = $("#toast");
  t.textContent = msg;
  t.className = "toast" + (err ? " err" : "");
  t.hidden = false;
  clearTimeout(toast._t);
  toast._t = setTimeout(() => (t.hidden = true), err ? 4000 : 2000);
}

async function guard(fn) {
  try { return await fn(); } catch (e) { toast(e.message, true); }
}

// 1560000000 → "15억 6,000만"
function fmt(n) {
  if (n == null || n === "") return "-";
  n = Number(n);
  const neg = n < 0;
  n = Math.abs(n);
  const eok = Math.floor(n / 1e8), man = Math.floor((n % 1e8) / 1e4), rest = n % 1e4;
  const parts = [];
  if (eok) parts.push(`${eok.toLocaleString()}억`);
  if (man) parts.push(`${man.toLocaleString()}만`);
  if (!eok && !man) parts.push(rest.toLocaleString());
  return (neg ? "-" : "") + parts.join(" ");
}

// "15억 6000만", "1,560,000,000", "3.5억" 모두 허용
function parseMeso(s) {
  if (s == null) return null;
  s = String(s).replace(/[,\s]/g, "");
  if (!s) return null;
  if (/[억만]/.test(s)) {
    let total = 0;
    const eok = s.match(/([\d.]+)억/);
    const man = s.match(/([\d.]+)만/);
    if (eok) total += parseFloat(eok[1]) * 1e8;
    if (man) total += parseFloat(man[1]) * 1e4;
    const tail = s.replace(/[\d.]+억/, "").replace(/[\d.]+만/, "");
    if (/^\d+$/.test(tail)) total += parseInt(tail, 10);
    return Math.round(total);
  }
  const v = parseInt(s, 10);
  return Number.isNaN(v) ? null : v;
}

const todayStr = () => new Date(Date.now() + 9 * 3600e3).toISOString().slice(0, 10);
const bossById = (id) => state.bosses.find((b) => b.id === id);
const bossLabel = (b) => `${b.difficulty} ${b.name}`;
const bossImg = (b) => (b?.image_url ? `<img class="boss-img" src="${esc(b.image_url)}" alt="" loading="lazy">` : "");
const charById = (id) => state.chars.find((c) => c.id === id);
const avatar = (c, lg) => `<div class="avatar${lg ? " lg" : ""}">${c.image ? `<img src="${esc(c.image)}" alt="" loading="lazy">` : ""}</div>`;
const charInfo = (c) => `<div><div class="char-name">${esc(c.name)}</div>
  <div class="small muted">Lv.${c.level ?? "?"} ${esc(c.job || "")}</div><div class="small muted">${esc(c.world || "")}</div></div>`;
const partyOptions = (max, sel) =>
  Array.from({ length: max }, (_, i) => `<option value="${i + 1}" ${i + 1 === sel ? "selected" : ""}>${i + 1}인</option>`).join("");

// ───────── 장비 툴팁 ─────────
const STAT_LABEL = {
  str: "STR", dex: "DEX", int: "INT", luk: "LUK", max_hp: "최대 HP", max_mp: "최대 MP",
  attack_power: "공격력", magic_power: "마력", armor: "방어력", speed: "이동속도", jump: "점프력",
  boss_damage: "보스 몬스터 공격 시 데미지", ignore_monster_armor: "몬스터 방어율 무시", all_stat: "올스탯",
  damage: "데미지", max_hp_rate: "최대 HP", max_mp_rate: "최대 MP", equipment_level_decrease: "착용 레벨 감소",
};
const PCT_STATS = new Set(["boss_damage", "ignore_monster_armor", "all_stat", "damage", "max_hp_rate", "max_mp_rate"]);
const GRADE_CLS = { 레어: "g-rare-t", 에픽: "g-epic-t", 유니크: "g-unique-t", 레전드리: "g-legend-t" };
state.tips = {};
let tipSeq = 0;
// 툴팁 데이터를 맡겨 두고 data-tip 속성으로 연결
const tipAttr = (detail) => {
  if (!detail || !Object.keys(detail).length) return "";
  const k = "t" + ++tipSeq;
  state.tips[k] = detail;
  return ` data-tip="${k}"`;
};
const num = (v) => Number(v || 0);

function itemTipHtml(d) {
  const tot = d.item_total_option || {}, base = d.item_base_option || {}, add = d.item_add_option || {};
  const etc = d.item_etc_option || {}, sf = d.item_starforce_option || {}, ex = d.item_exceptional_option || {};
  const stars = num(d.starforce);
  const lines = Object.keys(STAT_LABEL).filter((k) => num(tot[k])).map((k) => {
    const u = PCT_STATS.has(k) ? "%" : "";
    const parts = [[base[k], "b"], [add[k], "add"], [etc[k], "etc"], [sf[k], "sf"], [ex[k], "ex"]]
      .filter(([v], i) => i === 0 || num(v)).map(([v, c]) => `<span class="tp-${c}">${c === "b" ? "" : "+"}${num(v)}${u}</span>`);
    const hasExtra = parts.length > 1;
    return `<div class="tp-stat ${hasExtra ? "tp-up" : ""}">${STAT_LABEL[k]} : +${num(tot[k])}${u}${hasExtra ? ` <span class="tp-br">(${parts.join(" ")})</span>` : ""}</div>`;
  });
  const potBlock = (title, grade, opts) => {
    const o = opts.filter(Boolean);
    if (!grade && !o.length) return "";
    return `<div class="tp-sec"><div class="${GRADE_CLS[grade] || ""}">◈ ${title}${grade ? ` · ${esc(grade)}` : ""}</div>${o.map((x) => `<div>${esc(x)}</div>`).join("")}</div>`;
  };
  const meta = [];
  if (d.scroll_upgrade != null) meta.push(`주문서 강화 <b>${num(d.scroll_upgrade)}</b>회`);
  if (num(d.scroll_upgradable_count)) meta.push(`업그레이드 가능 ${num(d.scroll_upgradable_count)}회`);
  if (num(d.scroll_resilience_count)) meta.push(`복구 가능 ${num(d.scroll_resilience_count)}회`);
  if (d.golden_hammer_flag === "1" || d.golden_hammer_flag === 1) meta.push("황금망치 적용");
  if (d.cuttable_count && d.cuttable_count !== "255") meta.push(`가위 ${esc(d.cuttable_count)}회`);
  return `<div class="tp-head">
      ${stars ? `<div class="tp-stars">${"★".repeat(Math.min(stars, 30))} <b>${stars}성</b></div>` : ""}
      <div class="tp-name">${esc(d.item_name || "")}</div>
      <div class="tp-sub">${esc([d.item_equipment_slot, d.item_equipment_part].filter(Boolean).join(" · "))}</div></div>
    ${lines.length ? `<div class="tp-sec">${lines.join("")}</div>` : ""}
    ${meta.length ? `<div class="tp-sec tp-meta">${meta.join(" · ")}</div>` : ""}
    ${potBlock("잠재능력", d.potential_option_grade, [d.potential_option_1, d.potential_option_2, d.potential_option_3])}
    ${potBlock("에디셔널 잠재능력", d.additional_potential_option_grade, [d.additional_potential_option_1, d.additional_potential_option_2, d.additional_potential_option_3])}
    ${d.soul_name ? `<div class="tp-sec"><div class="tp-soul">${esc(d.soul_name)}</div><div>${esc(d.soul_option || "")}</div></div>` : ""}
    <div class="tp-legend"><span class="tp-b">기본</span> <span class="tp-add">추옵</span> <span class="tp-etc">주문서</span> <span class="tp-sf">스타포스</span></div>`;
}

const tipBox = document.createElement("div");
tipBox.id = "tip";
tipBox.className = "tip";
tipBox.hidden = true;
document.body.appendChild(tipBox);
function placeTip(x, y) {
  const r = tipBox.getBoundingClientRect();
  let left = x + 16, top = y + 16;
  if (left + r.width > innerWidth - 8) left = Math.max(8, x - r.width - 16);
  if (top + r.height > innerHeight - 8) top = Math.max(8, innerHeight - r.height - 8);
  tipBox.style.left = left + "px";
  tipBox.style.top = top + "px";
}
function showTip(elx, x, y) {
  const d = state.tips[elx.dataset.tip];
  if (!d) return;
  tipBox.innerHTML = itemTipHtml(d);
  tipBox.hidden = false;
  placeTip(x, y);
}
document.addEventListener("mouseover", (e) => {
  const t = e.target.closest?.("[data-tip]");
  if (t) showTip(t, e.clientX, e.clientY);
});
document.addEventListener("mousemove", (e) => { if (!tipBox.hidden) placeTip(e.clientX, e.clientY); });
document.addEventListener("mouseout", (e) => {
  const t = e.target.closest?.("[data-tip]");
  if (t && !t.contains(e.relatedTarget)) tipBox.hidden = true;
});
// 휴대폰: 누르면 보이고, 다른 곳을 누르면 닫힘
document.addEventListener("touchstart", (e) => {
  const t = e.target.closest?.("[data-tip]");
  if (t) { const p = e.touches[0]; showTip(t, p.clientX, p.clientY); } else tipBox.hidden = true;
}, { passive: true });

function openModal(html) {
  $("#modal-box").innerHTML = html;
  $("#modal").hidden = false;
}
function closeModal() { $("#modal").hidden = true; }
$("#modal").addEventListener("click", (e) => { if (e.target.id === "modal") closeModal(); });

async function loadBase() {
  [state.settings, state.bosses, state.chars] = await Promise.all([
    CommonApi.settings(),
    CommonApi.bosses(),
    CommonApi.characters(),
  ]);
}

// ───────── 라우터 ─────────
// 화면 목록 — 각 화면 파일(pages/*.js) 맨 아래에서 views.이름 = 함수 로 등록한다
const views = {};

async function render() {
  if (!state.me) return;
  const name = location.hash.slice(1) || "dash";
  state.tips = {};
  tipBox.hidden = true;
  state.spendDays = null; // 강화·지출은 들어올 때마다 기본 7일
  $$("#nav a").forEach((a) => a.classList.toggle("on", a.getAttribute("href") === "#" + name));
  clearInterval(render._timer);
  await guard(() => (views[name] || dash)($("#view")));
}
window.addEventListener("hashchange", render);

// ── 작은 화면: ☰ 버튼을 누르면 오른쪽에서 메뉴 서랍이 나온다 (왼쪽은 어둡게, 누르면 닫힘)
function setMenu(open) {
  document.body.classList.toggle("menu-open", open);
  $("#menu-btn").setAttribute("aria-expanded", open ? "true" : "false");
}
$("#menu-btn").onclick = () => setMenu(!document.body.classList.contains("menu-open"));
$("#menu-close").onclick = () => setMenu(false);
$("#menu-overlay").onclick = () => setMenu(false);
$("#nav").addEventListener("click", (e) => { if (e.target.closest("a")) setMenu(false); });
$("#nav-logout").onclick = () => { setMenu(false); logout(); };
window.addEventListener("hashchange", () => setMenu(false));
document.addEventListener("keydown", (e) => { if (e.key === "Escape") setMenu(false); });

// ── 앱(좁은 화면)에서는 표를 줄마다 카드로: 각 칸에 머리글 이름을 붙여 둔다 (CSS가 '항목: 값'으로 보여줌)
function labelTables(root = document) {
  root.querySelectorAll("table").forEach((t) => {
    const heads = [...t.querySelectorAll("thead th")].map((th) => th.textContent.trim());
    if (!heads.length) return;
    t.classList.add("cardable");
    t.querySelectorAll("tbody tr").forEach((tr) => {
      let i = 0;
      for (const td of tr.children) {
        if (!td.hasAttribute("data-label")) td.dataset.label = td.colSpan > 1 ? "" : heads[i] || "";
        i += td.colSpan || 1;
      }
    });
  });
}
new MutationObserver(() => labelTables()).observe(document.getElementById("view"), { childList: true, subtree: true });
new MutationObserver(() => labelTables($("#modal-box"))).observe(document.getElementById("modal-box"), { childList: true, subtree: true });

// ───────── 여러 화면이 같이 쓰는 것 ─────────
const charOpts = (sel) => `<option value="">(캐릭터 없음)</option>` +
  state.chars.map((c) => `<option value="${c.id}" ${c.id === sel ? "selected" : ""}>${esc(c.name)}</option>`).join("");

const gradeClass = (g) => ({ 레어: "g-rare", 에픽: "g-epic", 유니크: "g-unique", 레전드리: "g-legend" }[g] || "");
const resultClass = (r) => (/파괴/.test(r || "") ? "over" : /성공|상승/.test(r || "") ? "api" : "pending");
const itemIcon = (icon, cls = "", tip = "") => `<span class="item-icon ${cls}"${tip}>${icon ? `<img src="${esc(icon)}" alt="" loading="lazy">` : ""}</span>`;

function syncSummary(s) {
  const r = s.sync_result;
  const iv = +s.sync_interval || 0;
  const status = iv ? `<span class="dot"></span> ${iv}분마다 자동 체크` : `<span class="dot off"></span> 자동 체크 꺼짐`;
  const last = r ? `마지막 ${r.at.slice(5, 16).replace("T", " ")} · 새로 체크 ${r.added.length}개${r.errors.length ? ` · 오류 ${r.errors.length}` : ""}` : "아직 동기화 안 함";
  return `${status} · ${last}`;
}

async function runSync(btn) {
  const label = btn.textContent;
  btn.disabled = true; btn.textContent = "체크 중…";
  await guard(async () => {
    const r = await CommonApi.syncBosses();
    toast(r.errors.length ? `오류: ${r.errors[0]}` : `${r.chars}명 확인 · 새로 체크 ${r.added.length}개`, !!r.errors.length);
    state.settings = await CommonApi.settings();
  });
  btn.disabled = false; btn.textContent = label;
}

const postMd = (p) => `## ${p.version} — ${p.date || ""}\n${p.body || ""}`;

// ───────── 테마 ─────────
function effectiveTheme() {
  return document.documentElement.dataset.theme || (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
}
function paintThemeBtn() {
  const label = effectiveTheme() === "dark" ? "🌙 다크" : "☀️ 라이트";
  $("#theme-btn").innerHTML = label;
  $("#theme-btn2").innerHTML = `${label} 모드`;
}
$("#theme-btn2").onclick = () => $("#theme-btn").click();
$("#theme-btn").onclick = () => {
  const next = effectiveTheme() === "dark" ? "light" : "dark";
  document.documentElement.dataset.theme = next;
  try { localStorage.setItem("theme", next); } catch (e) {}
  paintThemeBtn();
};
paintThemeBtn();

// ───────── 로그인 ─────────
function showLogin(first = false, mode = first ? "signup" : "login") {
  state.me = null;
  document.body.classList.add("logged-out");
  $("#user-box").innerHTML = "";
  $("#drawer-user").textContent = "";
  const signup = mode === "signup";
  $("#view").innerHTML = `
    <div class="login card">
      <div class="brand" style="justify-content:center;margin-bottom:6px"><img class="brand-logo" src="/static/icons/logo.svg" alt=""><b>메이플 수익 장부</b></div>
      <p class="small muted" style="text-align:center">${first ? "첫 가입자가 <b>관리자</b>가 돼요. 기존 기록은 이 계정으로 옮겨져요." : signup ? "관리자에게 받은 <b>초대 코드</b>가 있어야 가입할 수 있어요." : "길드원 전용이에요."}</p>
      <form id="auth-form" class="form-grid" style="grid-template-columns:1fr">
        <label class="field">아이디<input id="au-name" autocomplete="username" required></label>
        <label class="field">비밀번호${signup ? " (6자 이상)" : ""}<input id="au-pw" type="password" autocomplete="${signup ? "new-password" : "current-password"}" required></label>
        ${signup && !first ? `<label class="field">초대 코드<input id="au-inv" required></label>` : ""}
        <button class="primary" type="submit">${signup ? "가입하기" : "로그인"}</button>
      </form>
      ${first ? "" : `<p class="small" style="text-align:center;margin-top:12px"><a href="#" id="au-switch">${signup ? "이미 계정이 있어요 → 로그인" : "처음이에요 → 가입하기"}</a></p>`}
    </div>`;
  $("#au-switch")?.addEventListener("click", (e) => { e.preventDefault(); showLogin(false, signup ? "login" : "signup"); });
  $("#auth-form").onsubmit = (e) => {
    e.preventDefault();
    guard(async () => {
      const body = { username: $("#au-name").value, password: $("#au-pw").value, invite: $("#au-inv")?.value };
      const r = await (signup ? CommonApi.signup(body) : CommonApi.login(body));
      await afterLogin(r.user);
    });
  };
}

async function afterLogin(user) {
  state.me = user;
  document.body.classList.remove("logged-out");
  $("#user-box").innerHTML = `<span class="user-name">${esc(user.username)}</span>${user.is_admin ? '<span class="user-role">관리자</span>' : ""}`;
  $("#drawer-user").innerHTML = `<b>${esc(user.username)}</b>님${user.is_admin ? ' <span class="pill">관리자</span>' : ""}`;
  $$("#nav .admin-only").forEach((a) => (a.hidden = !user.is_admin));
  markNewVersion();
  await loadBase();
  render();
}

async function logout() {
  await CommonApi.logout();
  location.hash = "";
  showLogin();
}

// ───────── 업데이트 내역 ─────────
// 버전 표시에 빨간 점: 마지막으로 본 버전과 지금 버전이 다르면
async function markNewVersion() {
  const r = await CommonApi.version().catch(() => ({ version: "" }));
  state.version = r.version;
  $("#ver-chip").hidden = !r.version;
  $("#ver-text").textContent = r.version;
  $("#drawer-ver-text").textContent = r.version;
  let seen = null;
  try { seen = localStorage.getItem("seen_version"); } catch (e) {}
  $$(".new-dot").forEach((d) => (d.hidden = !r.version || seen === r.version));
}

// CHANGELOG.md를 간단히 화면용으로 (## 버전, ### 소제목, - 목록, **굵게**, `코드`)
function mdToHtml(md) {
  const inline = (t) => esc(t).replace(/\*\*(.+?)\*\*/g, "<b>$1</b>").replace(/`(.+?)`/g, "<code>$1</code>");
  let html = "", inList = false, open = false;
  const closeList = () => { if (inList) { html += "</ul>"; inList = false; } };
  for (const raw of md.replace(/<!--[\s\S]*?-->/g, "").split(/\r?\n/)) {
    const line = raw.trimEnd();
    if (line.startsWith("# ")) continue;
    if (line.startsWith("## ")) {
      closeList();
      if (open) html += "</section>";
      const [ver, ...rest] = line.slice(3).split(" — ");
      html += `<section class="card cl-ver"><div class="row spread"><h3 class="cl-title">${inline(ver)}</h3><span class="small muted">${inline(rest.join(" — "))}</span></div>`;
      open = true;
    } else if (line.startsWith("### ")) {
      closeList();
      html += `<h4 class="cl-sub">${inline(line.slice(4))}</h4>`;
    } else if (line.startsWith("- ")) {
      if (!inList) { html += "<ul class=\"cl-list\">"; inList = true; }
      html += `<li>${inline(line.slice(2))}</li>`;
    } else if (line.trim()) {
      closeList();
      html += `<p>${inline(line)}</p>`;
    }
  }
  closeList();
  if (open) html += "</section>";
  return html;
}
