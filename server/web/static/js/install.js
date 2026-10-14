// 앱으로 설치 (PC·폰 바탕화면에 아이콘으로 깔기)
// 브라우저가 설치를 허락하면 버튼 한 번으로 설치하고, 아니면 기기별 방법을 안내해요.
let installPrompt = null;

const isStandalone = () => matchMedia("(display-mode: standalone)").matches || navigator.standalone === true;
const isIOS = () => /iphone|ipad|ipod/i.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
const isAndroid = () => /android/i.test(navigator.userAgent);

function paintInstallBtns() {
  for (const b of $$(".install-btn")) b.hidden = isStandalone(); // 이미 앱으로 열었으면 숨김
}

if ("serviceWorker" in navigator && window.isSecureContext) {
  navigator.serviceWorker.register("/sw.js").catch(() => {});
}

window.addEventListener("beforeinstallprompt", (e) => {
  e.preventDefault(); // 브라우저가 알아서 띄우는 배너 대신 우리 버튼으로
  installPrompt = e;
  paintInstallBtns();
});
window.addEventListener("appinstalled", () => {
  installPrompt = null;
  toast("앱으로 설치했어요. 바탕화면(홈 화면)에서 열 수 있어요");
  paintInstallBtns();
});

async function installApp() {
  setMenu(false);
  if (installPrompt) {
    installPrompt.prompt();
    await installPrompt.userChoice;
    installPrompt = null;
    return;
  }
  openModal(installGuideHtml());
  $("#install-close").onclick = closeModal;
}

function installGuideHtml() {
  const step = (t) => `<li>${t}</li>`;
  let body;
  if (isIOS()) {
    body = `<p>아이폰·아이패드는 <b>Safari</b>에서 설치해요.</p><ol>
      ${step("아래(아이패드는 위)의 <b>공유 버튼</b>(네모에 위 화살표)을 눌러요")}
      ${step("<b>홈 화면에 추가</b>를 눌러요")}
      ${step("오른쪽 위 <b>추가</b>를 누르면 홈 화면에 장부 아이콘이 생겨요")}</ol>`;
  } else if (!window.isSecureContext) {
    body = `<p>지금 주소(<code>${esc(location.host)}</code>)는 <b>https</b>가 아니라서 브라우저가 정식 설치를 막아요.
      관리자가 https 주소를 만들어 두면 이 버튼 한 번으로 설치돼요. 그 전에는 아래처럼 바로가기로 쓸 수 있어요.</p>
      ${isAndroid()
        ? `<ol>${step("크롬 오른쪽 위 <b>⋮</b> 메뉴를 눌러요")}${step("<b>홈 화면에 추가</b>를 눌러요")}</ol>`
        : `<ol>${step("크롬 오른쪽 위 <b>⋮</b> → <b>전송, 저장, 공유</b>(또는 <b>도구 더보기</b>) → <b>바로가기 만들기</b>")}
           ${step("<b>창으로 열기</b>에 체크하고 <b>만들기</b>를 누르면 바탕화면에 아이콘이 생기고, 앱처럼 따로 창이 떠요")}</ol>`}`;
  } else {
    body = `<p>브라우저 메뉴에서 바로 설치할 수 있어요.</p><ol>
      ${isAndroid()
        ? `${step("크롬 오른쪽 위 <b>⋮</b> 메뉴를 눌러요")}${step("<b>앱 설치</b>(또는 <b>홈 화면에 추가</b>)를 눌러요")}`
        : `${step("주소창 오른쪽의 <b>설치 아이콘</b>(모니터에 화살표)을 누르거나")}
           ${step("크롬 <b>⋮</b> → <b>전송, 저장, 공유</b> → <b>페이지를 앱으로 설치</b> / 엣지 <b>…</b> → <b>앱</b> → <b>이 사이트를 앱으로 설치</b>")}`}</ol>`;
  }
  return `<h3>📲 앱으로 설치하기</h3>${body}
    <p class="small muted">설치해도 기록은 서버에 그대로 있어요. 앱은 이 장부를 따로 창으로 여는 바로가기예요.</p>
    <div class="row" style="justify-content:flex-end"><button id="install-close">닫기</button></div>`;
}

for (const b of $$(".install-btn")) b.onclick = installApp;
paintInstallBtns();
