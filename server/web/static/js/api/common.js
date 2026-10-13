// 공통 (로그인 · 기본 정보 · 버전) 화면이 서버에 하는 요청 모음
// 서버 주소(/api/...)가 바뀌면 여기만 고치면 돼요.
const CommonApi = {
  me: () => fetch("/api/auth/me"),
  login: (body) => api("POST", "/api/auth/login", body),
  signup: (body) => api("POST", "/api/auth/signup", body),
  logout: () => api("POST", "/api/auth/logout"),
  version: () => api("GET", "/api/auth/version"),
  settings: () => api("GET", "/api/settings"),
  bosses: () => api("GET", "/api/bosses"),
  characters: () => api("GET", "/api/characters"),
  syncBosses: () => api("POST", "/api/sync"),
};
