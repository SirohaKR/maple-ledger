// 보스 기록 화면이 서버에 하는 요청 모음
// 서버 주소(/api/...)가 바뀌면 여기만 고치면 돼요.
const WeekApi = {
  week: (week) => api("GET", "/api/week" + (week ? `?week=${week}` : "")),
  month: (month) => api("GET", `/api/month?month=${month}`),
  setClear: (body) => api("PUT", "/api/clears", body),            // count 0이면 삭제
  fillPreset: (body) => api("POST", "/api/week/fill", body),
};
