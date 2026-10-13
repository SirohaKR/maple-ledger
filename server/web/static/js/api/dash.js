// 대시보드 화면이 서버에 하는 요청 모음
// 서버 주소(/api/...)가 바뀌면 여기만 고치면 돼요.
const DashApi = {
  stats: (weeks = 12) => api("GET", `/api/stats?weeks=${weeks}`),
};
