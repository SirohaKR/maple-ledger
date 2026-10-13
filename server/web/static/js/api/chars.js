// 캐릭터 화면이 서버에 하는 요청 모음
// 서버 주소(/api/...)가 바뀌면 여기만 고치면 돼요.
const CharsApi = {
  list: () => api("GET", "/api/characters"),
  fromNexon: () => api("GET", "/api/nexon/characters"),            // 내 계정 캐릭터 목록
  add: (body) => api("POST", "/api/characters", body),               // { ocids } 또는 { name }
  refresh: () => api("POST", "/api/characters/refresh"),
  edit: (id, body) => api("PUT", `/api/characters/${id}`, body),
  remove: (id) => api("DELETE", `/api/characters/${id}`),
  savePreset: (id, items) => api("PUT", `/api/characters/${id}/preset`, { items }),
};
