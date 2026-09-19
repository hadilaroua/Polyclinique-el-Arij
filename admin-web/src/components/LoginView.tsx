import React, { useState } from 'react';
import { Activity, Lock, Mail, ShieldAlert, CheckCircle2 } from 'lucide-react';
import { api } from '../api';

interface LoginViewProps {
  onLoginSuccess: (user: any, token: string) => void;
}

export const LoginView: React.FC<LoginViewProps> = ({ onLoginSuccess }) => {
  const [email, setEmail] = useState('admin@arij.tn');
  const [password, setPassword] = useState('Admin123!');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const res = await api.post('/auth/login', { email, password });
      const { user, accessToken } = res.data;

      if (user.role !== 'ADMIN') {
        setError('Accès refusé : Ce tableau de bord est exclusivement réservé à l’Administrateur.');
        return;
      }

      localStorage.setItem('arij_admin_token', accessToken);
      localStorage.setItem('arij_admin_user', JSON.stringify(user));
      onLoginSuccess(user, accessToken);
    } catch (err: any) {
      setError(
        err.response?.data?.message || 'Identifiants invalides. Vérifiez que le backend est démarré.',
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-container">
      <div className="login-card">
        <div style={{ textAlign: 'center', marginBottom: '2rem' }}>
          <div
            style={{
              width: 56,
              height: 56,
              background: '#ffffff',
              borderRadius: '16px',
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: '0 8px 24px rgba(2, 132, 199, 0.18)',
              border: '1px solid #e2e8f0',
              marginBottom: '1rem',
              padding: '6px',
            }}
          >
            <img
              src="/logo-polyclinique-arij.png"
              alt="Logo Polyclinique Arij"
              style={{ width: '48px', height: '48px', objectFit: 'contain' }}
              onError={(e) => {
                (e.currentTarget as HTMLElement).style.display = 'none';
              }}
            />
          </div>
          <h2 style={{ fontSize: '1.5rem', fontWeight: 800, color: '#0f172a', letterSpacing: '-0.02em' }}>
            Polyclinique Arij
          </h2>
          <p style={{ color: '#64748b', fontSize: '0.875rem', marginTop: '0.25rem' }}>
            Portail Direction & Administration Médicale
          </p>
        </div>

        {error && (
          <div
            style={{
              background: '#fee2e2',
              color: '#991b1b',
              padding: '0.85rem',
              borderRadius: '10px',
              fontSize: '0.85rem',
              marginBottom: '1.5rem',
              display: 'flex',
              alignItems: 'flex-start',
              gap: '0.5rem',
            }}
          >
            <ShieldAlert size={18} style={{ flexShrink: 0, marginTop: '2px' }} />
            <span>{error}</span>
          </div>
        )}

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
          <div className="form-group">
            <label className="form-label">Email Administrateur</label>
            <div style={{ position: 'relative' }}>
              <Mail
                size={18}
                style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }}
              />
              <input
                type="email"
                required
                className="form-control"
                style={{ paddingLeft: '38px' }}
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
          </div>

          <div className="form-group">
            <label className="form-label">Mot de passe</label>
            <div style={{ position: 'relative' }}>
              <Lock
                size={18}
                style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }}
              />
              <input
                type="password"
                required
                className="form-control"
                style={{ paddingLeft: '38px' }}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="btn btn-primary"
            style={{
              width: '100%',
              padding: '0.85rem',
              fontSize: '0.95rem',
              fontWeight: 700,
              background: 'linear-gradient(135deg, #0284c7, #0369a1)',
              marginTop: '0.5rem',
            }}
          >
            {loading ? 'Connexion en cours...' : 'Se connecter au Dashboard'}
          </button>

          <div
            style={{
              padding: '0.85rem',
              background: '#f8fafc',
              borderRadius: '8px',
              border: '1px dashed #cbd5e1',
              fontSize: '0.8rem',
              color: '#475569',
              textAlign: 'center',
            }}
          >
            <p style={{ fontWeight: 600, color: '#0f172a' }}>Identifiants Admin Démo :</p>
            <p style={{ marginTop: '0.2rem' }}>
              <code>admin@arij.tn</code> • <code>Admin123!</code>
            </p>
          </div>
        </form>
      </div>
    </div>
  );
};
