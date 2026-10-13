// 기타 수익 화면이 서버에 하는 요청 모음
// 서버 주소(/api/...)가 바뀌면 여기만 고치면 돼요.
const IncomesApi = {
  list: () => api("GET", "/api/incomes"),
  prices: () => api("GET", "/api/incomes/prices"),                  // 개인 시세
  add: (body) => api("POST", "/api/incomes", body),
  edit: (id, body) => api("PUT", `/api/incomes/${id}`, body),
  remove: (id) => api("DELETE", `/api/incomes/${id}`),
};
