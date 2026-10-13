// 공지 화면이 서버에 하는 요청 모음
// 서버 주소(/api/...)가 바뀌면 여기만 고치면 돼요.
const NoticesApi = {
  list: () => api("GET", "/api/notices"),
  markSeen: () => api("POST", "/api/notices/seen"),
  checkNow: () => api("POST", "/api/notices/check"),
};
