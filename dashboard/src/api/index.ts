const baseURL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080';

async function request(path: string, options: RequestInit = {}) {
  const res = await fetch(`${baseURL}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });
  const body = await res.json();
  if (body.code === 200) return body.data;
  throw new Error(body.message || '请求失败');
}

/** 登录获取Token */
export async function login(studentId: string, password: string) {
  const d = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ studentId, password }),
  });
  localStorage.setItem('token', d.accessToken);
  localStorage.setItem('realName', d.realName);
  return d;
}

/** 获取今日统计数据 */
export async function fetchStats(token: string) {
  return request('/manage/dashboard', {
    headers: { Authorization: `Bearer ${token}` },
  });
}

export async function fetchTrend(token: string, days = 7) {
  return request(`/manage/report/trend?days=${days}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
}

export async function fetchAlerts(token: string) {
  return request('/manage/alerts', {
    headers: { Authorization: `Bearer ${token}` },
  });
}
