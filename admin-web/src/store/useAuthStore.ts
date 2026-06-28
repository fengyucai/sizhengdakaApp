import { create } from 'zustand';

interface AuthState {
  token: string | null;
  userId: string | null;
  realName: string | null;
  role: string | null;
  login: (token: string, userId: string, realName: string, role: string) => void;
  logout: () => void;
  isLoggedIn: () => boolean;
}

export const useAuthStore = create<AuthState>((set, get) => ({
  token: localStorage.getItem('accessToken'),
  userId: localStorage.getItem('userId'),
  realName: localStorage.getItem('realName'),
  role: localStorage.getItem('role'),

  login: (token, userId, realName, role) => {
    localStorage.setItem('accessToken', token);
    localStorage.setItem('userId', userId);
    localStorage.setItem('realName', realName);
    localStorage.setItem('role', role);
    set({ token, userId, realName, role });
  },

  logout: () => {
    localStorage.clear();
    set({ token: null, userId: null, realName: null, role: null });
  },

  isLoggedIn: () => !!get().token,
}));
