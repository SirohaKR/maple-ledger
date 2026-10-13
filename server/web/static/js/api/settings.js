// 설정 화면이 서버에 하는 요청 모음
// 서버 주소(/api/...)가 바뀌면 여기만 고치면 돼요.
const SettingsApi = {
  get: () => api("GET", "/api/settings"),
  save: (body) => api("PUT", "/api/settings", body),
  addRule: (body) => api("POST", "/api/rules", body),
  removeRule: (id) => api("DELETE", `/api/rules/${id}`),
  changePassword: (body) => api("PUT", "/api/account/password", body),
};
