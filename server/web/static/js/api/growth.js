// 성장 화면이 서버에 하는 요청 모음
// 서버 주소(/api/...)가 바뀌면 여기만 고치면 돼요.
const GrowthApi = {
  info: (cid, refresh) => api("GET", `/api/growth/${cid}${refresh ? "?refresh=1" : ""}`),
  history: (cid, days = 60) => api("GET", `/api/growth/${cid}/history?days=${days}`),
  backfill: (cid, days = 30) => api("POST", `/api/growth/${cid}/backfill`, { days }),
};
