// 보스 가격표 화면이 서버에 하는 요청 모음
// 서버 주소(/api/...)가 바뀌면 여기만 고치면 돼요.
const BossesApi = {
  list: () => api("GET", "/api/bosses"),
  add: (body) => api("POST", "/api/bosses", body),
  edit: (id, body) => api("PUT", `/api/bosses/${id}`, body),
  remove: (id) => api("DELETE", `/api/bosses/${id}`),
  addPrice: (id, body) => api("POST", `/api/bosses/${id}/prices`, body),
  removePrice: (priceId) => api("DELETE", `/api/prices/${priceId}`),
};
