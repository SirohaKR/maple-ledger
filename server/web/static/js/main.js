// 시작: 로그인 상태를 확인하고 첫 화면을 띄운다 (모든 화면 파일을 불러온 다음 실행)
(async () => {
  const res = await CommonApi.me();
  const d = await res.json().catch(() => ({}));
  if (res.ok && d.user) await afterLogin(d.user);
  else showLogin(!!d.first_user);
})().catch((e) => toast(e.message, true));
