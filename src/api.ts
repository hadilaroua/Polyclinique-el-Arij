import axios from 'axios';

export const API_BASE_URL = 'http://localhost:3000/api';

export const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Intercepteur pour injecter automatiquement le token JWT
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('arij_admin_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Intercepteur pour gérer l'expiration du token
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response && error.response.status === 401) {
      localStorage.removeItem('arij_admin_token');
      localStorage.removeItem('arij_admin_user');
      if (window.location.pathname !== '/login') {
        window.location.reload();
      }
    }
    return Promise.reject(error);
  },
);
