import React, { useState, useEffect } from 'react';
import { api } from './api';
import { Sidebar } from './components/Sidebar';
import { Topbar } from './components/Topbar';
import { DashboardView } from './components/DashboardView';
import { ConsultationsView } from './components/ConsultationsView';
import { StaffView } from './components/StaffView';
import { PatientsView } from './components/PatientsView';
import { HospitalizationView } from './components/HospitalizationView';
import { ExamsView } from './components/ExamsView';
import { ServicesView } from './components/ServicesView';
import { AuditLogsView } from './components/AuditLogsView';
import { LoginView } from './components/LoginView';

export function App() {
  const [adminUser, setAdminUser] = useState<any>(null);
  const [currentTab, setCurrentTab] = useState<string>('dashboard');
  const [stats, setStats] = useState<any>(null);
  const [loadingStats, setLoadingStats] = useState<boolean>(false);

  // Vérifier si une session admin existe déjà
  useEffect(() => {
    const token = localStorage.getItem('arij_admin_token');
    const userStr = localStorage.getItem('arij_admin_user');
    if (token && userStr) {
      try {
        const user = JSON.parse(userStr);
        if (user.role === 'ADMIN') {
          setAdminUser(user);
        } else {
          handleLogout();
        }
      } catch {
        handleLogout();
      }
    }
  }, []);

  const fetchStats = async () => {
    if (!adminUser) return;
    try {
      setLoadingStats(true);
      const res = await api.get('/dashboard/stats');
      setStats(res.data);
    } catch (err) {
      console.error('Erreur chargement stats dashboard:', err);
    } finally {
      setLoadingStats(false);
    }
  };

  useEffect(() => {
    if (adminUser) {
      fetchStats();
    }
  }, [adminUser]);

  const handleLoginSuccess = (user: any, token: string) => {
    setAdminUser(user);
  };

  const handleLogout = () => {
    localStorage.removeItem('arij_admin_token');
    localStorage.removeItem('arij_admin_user');
    setAdminUser(null);
  };

  if (!adminUser) {
    return <LoginView onLoginSuccess={handleLoginSuccess} />;
  }

  const getPageTitle = () => {
    switch (currentTab) {
      case 'dashboard':
        return 'Tableau de Bord & Indicateurs Clés';
      case 'staff':
        return 'Gestion du Personnel Médical & Soignant';
      case 'consultations':
        return 'Consultations Médicales & Diagnostics par Médecin';
      case 'patients':
        return 'Fichier Patients & Admissions';
      case 'hospitalization':
        return 'Gestion des Chambres, Lits & Hospitalisations';
      case 'exams':
        return 'Plateau Technique, Radiologie & Biologie';
      case 'services':
        return 'Départements & Spécialités Médicales';
      case 'audit':
        return 'Journal d\'Audit Clinique & Traçabilité Médico-Légale';
      default:
        return 'Administration Polyclinique Arij';
    }
  };

  return (
    <div className="app-layout">
      {/* Barre latérale */}
      <Sidebar
        currentTab={currentTab}
        setCurrentTab={setCurrentTab}
        adminUser={adminUser}
        onLogout={handleLogout}
        stats={stats}
      />

      {/* Zone de contenu principale */}
      <div className="main-wrapper">
        <Topbar title={getPageTitle()} onRefresh={fetchStats} />

        <main className="content-body">
          {currentTab === 'dashboard' && (
            <DashboardView stats={stats} onNavigate={(tab) => setCurrentTab(tab)} />
          )}
          {currentTab === 'staff' && <StaffView />}
          {currentTab === 'consultations' && <ConsultationsView />}
          {currentTab === 'patients' && <PatientsView />}
          {currentTab === 'hospitalization' && <HospitalizationView />}
          {currentTab === 'exams' && <ExamsView />}
          {currentTab === 'services' && <ServicesView />}
          {currentTab === 'audit' && <AuditLogsView />}
        </main>
      </div>
    </div>
  );
}

export default App;
