// 관리자 화면이 서버에 하는 요청 모음
// 서버 주소(/api/...)가 바뀌면 여기만 고치면 돼요.
const AdminApi = {
  overview: () => api("GET", "/api/admin"),                          // 사용자 목록 + 초대 코드
  newInvite: () => api("POST", "/api/admin/invite", {}),
  editUser: (id, body) => api("PUT", `/api/admin/users/${id}`, body),
  removeUser: (id) => api("DELETE", `/api/admin/users/${id}`),
  changelog: () => api("GET", "/api/admin/changelog"),
  saveChangelog: (version, body) => api("PUT", `/api/admin/changelog/${encodeURIComponent(version)}`, body),
  removeChangelog: (version) => api("DELETE", `/api/admin/changelog/${encodeURIComponent(version)}`),
};
