import request from './request';

export interface CheckinRecord {
  id: number;
  userId: number;
  checkinType: string;
  checkinTime: string;
  status: string;
  locationPassed: boolean;
  facePassed: boolean;
}

export interface TodayStats {
  studentTotal: number;
  dormChecked: number;
  classChecked: number;
  internChecked: number;
  pendingAlerts: number;
  dormRate: number;
  classRate: number;
  internRate: number;
}

export const checkinApi = {
  getDashboard: () =>
    request.get<any, TodayStats>('/manage/dashboard'),

  // 查寝管理
  getDormToday: (classId: number) =>
    request.get<any, any[]>(`/manage/class/${classId}/dorm-today`),

  // 出勤统计
  getAttendance: (classId: number) =>
    request.get<any, any>(`/manage/class/${classId}/attendance`),

  getClassSessions: (classId?: number) =>
    request.get<any, any[]>('/manage/class/sessions', { params: classId ? { classId } : undefined }),

  getSessionAttendance: (sessionId: number) =>
    request.get<any, any>(`/manage/class/session/${sessionId}/attendance`),

  generateClassQr: (sessionId: number, expiresInSeconds = 30) =>
    request.post<any, any>('/checkin/class/qr', { sessionId, expiresInSeconds }),

  // 实习监控
  getInternMonitor: () =>
    request.get<any, any>('/manage/intern/monitor'),

  getInternLogs: () =>
    request.get<any, any[]>('/manage/intern/logs'),

  reviewInternLog: (id: number, comment: string) =>
    request.post(`/manage/intern/log/${id}/review`, { comment }),

  // 预警列表
  getAlerts: () =>
    request.get<any, any[]>('/manage/alerts'),

  handleAlert: (id: number) =>
    request.post(`/manage/alerts/${id}/handle`),

  getLeaves: () =>
    request.get<any, any[]>('/manage/leave/list'),

  approveLeave: (id: number, comment?: string) =>
    request.post(`/manage/leave/${id}/approve`, { comment }),

  rejectLeave: (id: number, comment?: string) =>
    request.post(`/manage/leave/${id}/reject`, { comment }),

  getAppeals: (status = 'PENDING') =>
    request.get<any, any[]>('/manage/appeals', { params: { status } }),

  getWeeklyReport: () =>
    request.get<any, any>('/manage/report/weekly'),

  getTrendReport: (days = 7) =>
    request.get<any, any[]>('/manage/report/trend', { params: { days } }),

  // 审批申诉
  reviewAppeal: (id: number, approved: boolean, comment?: string) =>
    request.post(`/manage/appeal/${id}/review`, { approved, comment }),
};
