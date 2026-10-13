// 숙제 화면이 서버에 하는 요청 모음
// 서버 주소(/api/...)가 바뀌면 여기만 고치면 돼요.
const TodoApi = {
  list: () => api("GET", "/api/todo"),
};
