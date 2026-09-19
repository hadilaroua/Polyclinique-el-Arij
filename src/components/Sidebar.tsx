import React from 'react';
import {
  LayoutDashboard,
  Users,
  UserRound,
  Stethoscope,
  BedDouble,
  FlaskConical,
  Building2,
  FileCode2,
  LogOut,
  Activity,
  Sparkles,
  ShieldCheck,
} from 'lucide-react';

interface SidebarProps {
  currentTab: string;
  setCurrentTab: (tab: string) => void;
  adminUser: any;
  onLogout: () => void;
  stats?: any;
}

export const Sidebar: React.FC<SidebarProps> = ({
  currentTab,
  setCurrentTab,
  adminUser,
  onLogout,
  stats,
}) => {
  const menuItems = [
    { id: 'dashboard', label: 'Tableau de bord', icon: LayoutDashboard },
    {
      id: 'staff',
      label: 'Personnel Médical',
      icon: Users,
      badge: stats?.staff?.total ? `${stats.staff.total}` : undefined,
    },
    {
      id: 'consultations',
      label: 'Consultations Médecins',
      icon: Stethoscope,
      badge: stats?.consultations?.total ? `${stats.consultations.total}` : undefined,
    },
    {
      id: 'patients',
      label: 'Patients & Dossiers',
      icon: UserRound,
      badge: stats?.patients?.total ? `${stats.patients.total}` : undefined,
    },
    {
      id: 'hospitalization',
      label: 'Hospitalisation & Lits',
      icon: BedDouble,
      badge: stats?.hospitalization?.occupancyRate
        ? `${stats.hospitalization.occupancyRate}%`
        : undefined,
    },
    {
      id: 'exams',
      label: 'Examens & Labo',
      icon: FlaskConical,
      badge: stats?.exams?.pending ? `${stats.exams.pending}` : undefined,
    },
    { id: 'services', label: 'Services & Spécialités', icon: Building2 },
    { id: 'audit', label: 'Journal d\'Audit Clinique', icon: ShieldCheck },
  ];

  return (
    <aside className="sidebar">
      <div className="sidebar-brand">
        <div className="sidebar-logo-icon" style={{ background: '#ffffff', padding: '4px' }}>
          <img
            src="/logo-polyclinique-arij.png"
            alt="Polyclinique Arij"
            style={{ width: '100%', height: '100%', objectFit: 'contain' }}
            onError={(e) => {
              (e.currentTarget as HTMLElement).style.display = 'none';
            }}
          />
        </div>
        <div>
          <h1 className="sidebar-title">Polyclinique Arij</h1>
          <p className="sidebar-subtitle">Djerba – Midoun • Direction</p>
        </div>
      </div>

      <p className="nav-section-title">Menu Principal</p>
      <nav className="nav-links">
        {menuItems.map((item) => {
          const Icon = item.icon;
          const isActive = currentTab === item.id;
          return (
            <button
              key={item.id}
              className={`nav-item ${isActive ? 'active' : ''}`}
              onClick={() => setCurrentTab(item.id)}
            >
              <Icon size={18} />
              <span>{item.label}</span>
              {item.badge && <span className="nav-badge">{item.badge}</span>}
            </button>
          );
        })}

        <p className="nav-section-title" style={{ marginTop: '1rem' }}>
          Outils Développeur
        </p>
        <a
          href="http://localhost:3000/api/docs"
          target="_blank"
          rel="noreferrer"
          className="nav-item"
          style={{ textDecoration: 'none' }}
        >
          <FileCode2 size={18} color="#38bdf8" />
          <span>Swagger API Docs</span>
          <span className="nav-badge" style={{ background: '#0284c7' }}>
            API
          </span>
        </a>
      </nav>

      <div className="sidebar-footer">
        <div className="user-mini-card">
          <div className="user-avatar" style={{ overflow: 'hidden', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            {adminUser?.avatarUrl ? (
              <img
                src={adminUser.avatarUrl}
                alt=""
                style={{ width: '100%', height: '100%', objectFit: 'cover' }}
              />
            ) : (
              adminUser?.firstName?.[0] || 'A'
            )}
          </div>
          <div style={{ overflow: 'hidden' }}>
            <p
              style={{
                fontSize: '0.85rem',
                fontWeight: 600,
                color: 'white',
                whiteSpace: 'nowrap',
                textOverflow: 'ellipsis',
                overflow: 'hidden',
              }}
            >
              {adminUser?.firstName} {adminUser?.lastName}
            </p>
            <span
              style={{
                fontSize: '0.7rem',
                color: '#38bdf8',
                fontWeight: 700,
                letterSpacing: '0.04em',
              }}
            >
              ADMINISTRATEUR
            </span>
          </div>
        </div>

        <button
          onClick={onLogout}
          className="btn btn-secondary"
          style={{
            background: 'rgba(239, 68, 68, 0.15)',
            color: '#fca5a5',
            width: '100%',
          }}
        >
          <LogOut size={16} />
          <span>Déconnexion</span>
        </button>
      </div>
    </aside>
  );
};
