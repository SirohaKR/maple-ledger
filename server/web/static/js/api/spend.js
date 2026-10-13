// 강화 · 지출 화면이 서버에 하는 요청 모음
// 서버 주소(/api/...)가 바뀌면 여기만 고치면 돼요.
const SpendApi = {
  enhance: (from, character) =>
    api("GET", `/api/enhance?from=${from}${character ? `&character=${encodeURIComponent(character)}` : ""}`),
  syncEnhance: () => api("POST", "/api/enhance/sync", {}),          // 넥슨 강화 기록 불러오기
  setCost: (id, body) => api("PUT", `/api/enhance/${encodeURIComponent(id)}`, body),
  expenses: (from) => api("GET", `/api/expenses?from=${from}`),
  addExpense: (body) => api("POST", "/api/expenses", body),
  editExpense: (id, body) => api("PUT", `/api/expenses/${id}`, body),
  removeExpense: (id) => api("DELETE", `/api/expenses/${id}`),
};
