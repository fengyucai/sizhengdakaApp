import axios from 'axios';
import { message } from 'antd';
import { API_BASE_URL } from './runtime';

const request = axios.create({
  baseURL: API_BASE_URL,
  timeout: 15000,
});

// 请求拦截器 — 注入Token
request.interceptors.request.use((config) => {
  const token = localStorage.getItem('accessToken');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// 响应拦截器 — 统一错误处理
request.interceptors.response.use(
  (res) => {
    const { code, message: msg, data } = res.data;
    if (code === 200) return data;
    if (code === 401) {
      localStorage.clear();
      window.location.href = '/login';
      return Promise.reject(new Error(msg));
    }
    message.error(msg || '请求失败');
    return Promise.reject(new Error(msg));
  },
  (err) => {
    message.error('网络错误，请检查后端是否启动');
    return Promise.reject(err);
  },
);

export default request;
