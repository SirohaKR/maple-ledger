// 사냥 화면이 서버에 하는 요청 모음
// 서버 주소(/api/...)가 바뀌면 여기만 고치면 돼요.
const HuntsApi = {
  list: () => api("GET", "/api/hunts"),
  add: (body) => api("POST", "/api/hunts", body),
  edit: (id, body) => api("PUT", `/api/hunts/${id}`, body),
  remove: (id) => api("DELETE", `/api/hunts/${id}`),
  start: (body) => api("POST", "/api/hunts/start", body),          // 타이머 시작
  end: (id) => api("POST", `/api/hunts/${id}/end`),                 // 사냥 종료 (시간 확정)
  resume: (id) => api("POST", `/api/hunts/${id}/resume`),           // 다시 이어서
  save: (id, body) => api("POST", `/api/hunts/${id}/stop`, body),   // 메소·조각 적고 저장
};
