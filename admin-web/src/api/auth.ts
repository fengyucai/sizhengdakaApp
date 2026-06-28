import request from './request';

export interface LoginParams {
  studentId: string;
  password: string;
}

export interface LoginResult {
  accessToken: string;
  refreshToken: string;
  userId: string;
  realName: string;
  role: string;
}

export const authApi = {
  login: (params: LoginParams) =>
    request.post<any, LoginResult>('/auth/login', params),

  refresh: (refreshToken: string) =>
    request.post<any, { accessToken: string }>('/auth/refresh', { refreshToken }),
};
