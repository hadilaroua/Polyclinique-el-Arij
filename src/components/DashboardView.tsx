import React, { useState, useEffect } from 'react';
import {
  Users,
  UserRound,
  BedDouble,
  FlaskConical,
  Stethoscope,
  HeartPulse,
  Baby,
  Microscope,
  CalendarCheck,
  TrendingUp,
  ArrowRight,
  Pill,
} from 'lucide-react';
import { api } from '../api';

interface DashboardViewProps {
  stats: any;
  onNavigate: (tab: string) => void;
}

export const DashboardView: React.FC<DashboardViewProps> = ({ stats, onNavigate }) => {
  const [recentConsultations, setRecentConsultations] = useState<any[]>([]);
  const [loadingConsultations, setLoadingConsultations] = useState(false);

  useEffect(() => {
    const fetchRecentConsultations = async () => {
      try {
        setLoadingConsultations(true);
        const res = await api.get('/consultations');
        setRecentConsultations(res.data.slice(0, 5));
      } catch (err) {
        console.error('Erreur chargement consultations dashboard:', err);
      } finally {
        setLoadingConsultations(false);
      }
    };

    fetchRecentConsultations();
  }, []);

  if (!stats) {
    return (
      <div style={{ padding: '3rem', textAlign: 'center', color: '#64748b' }}>
        Chargement des métriques de la clinique...
      </div>
    );
  }

  const { patients, staff, appointments, consultations, exams, hospitalization } = stats;

  return (
    <div>
      {/* KPI Cards Grid */}
      <div className="kpi-grid">
        {/* Patients */}
        <div
          className="kpi-card"
          onClick={() => onNavigate('patients')}
          style={{ cursor: 'pointer' }}
        >
          <div>
            <p className="kpi-label">Patients Enregistrés</p>
            <p className="kpi-value">{patients?.total ?? 0}</p>
            <p className="kpi-subtext">
              <span style={{ color: '#059669', fontWeight: 600 }}>
                {patients?.active ?? 0}
              </span>{' '}
              dossiers actifs
            </p>
          </div>
          <div className="kpi-icon" style={{ background: '#e0f2fe', color: '#0284c7' }}>
            <UserRound size={26} />
          </div>
        </div>

        {/* Consultations Médecins */}
        <div
          className="kpi-card"
          onClick={() => onNavigate('consultations')}
          style={{ cursor: 'pointer', border: '1px solid #bae6fd' }}
        >
          <div>
            <p className="kpi-label">Consultations Réalisées</p>
            <p className="kpi-value" style={{ color: '#0284c7' }}>
              {consultations?.total ?? recentConsultations.length}
            </p>
            <p className="kpi-subtext" style={{ color: '#0369a1', fontWeight: 600 }}>
              Voir la liste par médecin →
            </p>
          </div>
          <div className="kpi-icon" style={{ background: '#e0f2fe', color: '#0284c7' }}>
            <Stethoscope size={26} />
          </div>
        </div>

        {/* Staff Total */}
        <div
          className="kpi-card"
          onClick={() => onNavigate('staff')}
          style={{ cursor: 'pointer' }}
        >
          <div>
            <p className="kpi-label">Personnel Médical</p>
            <p className="kpi-value">{staff?.total ?? 0}</p>
            <p className="kpi-subtext">
              {staff?.doctors ?? 0} Méd. • {staff?.nurses ?? 0} Inf. • {staff?.midwives ?? 0} SF • {staff?.technicians ?? 0} Tech
            </p>
          </div>
          <div className="kpi-icon" style={{ background: '#ede9fe', color: '#7c3aed' }}>
            <Users size={26} />
          </div>
        </div>

        {/* Hospitalisation / Lits */}
        <div
          className="kpi-card"
          onClick={() => onNavigate('hospitalization')}
          style={{ cursor: 'pointer' }}
        >
          <div>
            <p className="kpi-label">Taux d'Occupation Lits</p>
            <p className="kpi-value">{hospitalization?.occupancyRate ?? 0}%</p>
            <p className="kpi-subtext">
              <span style={{ color: '#e11d48', fontWeight: 700 }}>
                {hospitalization?.occupiedBeds ?? 0}
              </span>{' '}
              occupés sur {hospitalization?.totalBeds ?? 0} lits
            </p>
          </div>
          <div className="kpi-icon" style={{ background: '#fef3c7', color: '#d97706' }}>
            <BedDouble size={26} />
          </div>
        </div>

        {/* Examens & Labo */}
        <div
          className="kpi-card"
          onClick={() => onNavigate('exams')}
          style={{ cursor: 'pointer' }}
        >
          <div>
            <p className="kpi-label">Examens en attente</p>
            <p className="kpi-value" style={{ color: exams?.pending ? '#e11d48' : 'inherit' }}>
              {exams?.pending ?? 0}
            </p>
            <p className="kpi-subtext">
              {exams?.inProgress ?? 0} en cours • {exams?.completed ?? 0} terminés
            </p>
          </div>
          <div className="kpi-icon" style={{ background: '#ffe4e6', color: '#e11d48' }}>
            <FlaskConical size={26} />
          </div>
        </div>
      </div>

      {/* TABLEAU DIRECT : LISTE DES DERNIÈRES CONSULTATIONS PAR MÉDECIN */}
      <div className="table-card" style={{ marginBottom: '2rem' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem', flexWrap: 'wrap', gap: '0.75rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <div style={{ padding: '0.6rem', background: '#e0f2fe', color: '#0284c7', borderRadius: '10px' }}>
              <Stethoscope size={22} />
            </div>
            <div>
              <h3 style={{ fontSize: '1.15rem', fontWeight: 700, margin: 0, color: '#0f172a' }}>
                Consultations Récentes Ajoutées par les Médecins
              </h3>
              <p style={{ fontSize: '0.8rem', color: '#64748b', margin: 0 }}>
                Derniers actes médicaux et ordonnances enregistrés par les praticiens
              </p>
            </div>
          </div>

          <button
            className="btn btn-primary"
            style={{ fontSize: '0.85rem', padding: '0.45rem 1rem', gap: '0.4rem', background: 'linear-gradient(135deg, #0284c7, #0ea5e9)' }}
            onClick={() => onNavigate('consultations')}
          >
            <span>Voir Toutes les Consultations</span>
            <ArrowRight size={15} />
          </button>
        </div>

        {loadingConsultations ? (
          <div style={{ padding: '2rem', textAlign: 'center', color: '#64748b' }}>
            Chargement des consultations...
          </div>
        ) : recentConsultations.length === 0 ? (
          <div style={{ padding: '2rem', textAlign: 'center', color: '#64748b' }}>
            Aucune consultation médicale enregistrée pour le moment.
          </div>
        ) : (
          <table className="custom-table">
            <thead>
              <tr>
                <th>Médecin Praticien</th>
                <th>Patient</th>
                <th>Date</th>
                <th>Diagnostic</th>
                <th>Ordonnance</th>
                <th style={{ textAlign: 'right' }}>Détails</th>
              </tr>
            </thead>
            <tbody>
              {recentConsultations.map((c) => {
                const doc = c.doctorId;
                const pat = c.patientId;
                const docName = doc ? `Dr. ${doc.firstName} ${doc.lastName}` : 'Médecin Arij';
                const patName = pat ? `${pat.firstName} ${pat.lastName}` : 'Patient';

                return (
                  <tr key={c._id}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
                        <div
                          style={{
                            width: 34,
                            height: 34,
                            borderRadius: '50%',
                            background: '#e0f2fe',
                            overflow: 'hidden',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            border: '1.5px solid #bae6fd',
                            fontWeight: 700,
                            color: '#0284c7',
                            fontSize: '0.8rem',
                            flexShrink: 0,
                          }}
                        >
                          {doc?.avatarUrl ? (
                            <img src={doc.avatarUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                          ) : (
                            <span>{doc?.firstName?.[0] || 'D'}</span>
                          )}
                        </div>
                        <div>
                          <p style={{ fontWeight: 600, fontSize: '0.9rem', color: '#0f172a' }}>{docName}</p>
                          <span style={{ fontSize: '0.75rem', color: '#0284c7' }}>{doc?.email || 'Médecin'}</span>
                        </div>
                      </div>
                    </td>
                    <td>
                      <div>
                        <p style={{ fontWeight: 600, fontSize: '0.85rem' }}>{patName}</p>
                        <span style={{ fontSize: '0.75rem', color: '#64748b' }}>
                          CIN: {pat?.cin || '—'} {pat?.dossierNumber ? `(${pat.dossierNumber})` : ''}
                        </span>
                      </div>
                    </td>
                    <td>
                      <span style={{ fontSize: '0.85rem', color: '#475569' }}>{c.date}</span>
                    </td>
                    <td>
                      <span
                        className="badge"
                        style={{
                          background: '#f0fdf4',
                          color: '#166534',
                          border: '1px solid #bbf7d0',
                          fontSize: '0.8rem',
                        }}
                      >
                        {c.diagnostic}
                      </span>
                    </td>
                    <td>
                      {c.prescription ? (
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', color: '#0284c7', fontSize: '0.85rem' }}>
                          <Pill size={14} />
                          <span style={{ maxWidth: '180px', whiteSpace: 'nowrap', textOverflow: 'ellipsis', overflow: 'hidden' }}>
                            {c.prescription}
                          </span>
                        </div>
                      ) : (
                        <span style={{ color: '#94a3b8', fontSize: '0.85rem' }}>—</span>
                      )}
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <button
                        className="btn btn-secondary"
                        style={{ padding: '0.3rem 0.65rem', fontSize: '0.75rem' }}
                        onClick={() => onNavigate('consultations')}
                      >
                        Consulter
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      {/* Staff Breakdown by Role & Activité */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '1.5rem', marginBottom: '2rem' }}>
        <div className="table-card" style={{ marginBottom: 0, padding: '1.5rem' }}>
          <h3 style={{ fontSize: '1.1rem', fontWeight: 700, marginBottom: '1rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <TrendingUp size={20} color="#0284c7" />
            <span>Répartition des Équipes Médicales</span>
          </h3>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            {/* Médecins */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0.75rem', background: '#f8fafc', borderRadius: '8px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <div style={{ padding: '0.5rem', background: '#e0f2fe', color: '#0284c7', borderRadius: '8px' }}>
                  <Stethoscope size={18} />
                </div>
                <div>
                  <p style={{ fontWeight: 600, fontSize: '0.9rem' }}>Médecins Spécialistes</p>
                  <p style={{ fontSize: '0.75rem', color: '#64748b' }}>Cardiologie, Pédiatrie, etc.</p>
                </div>
              </div>
              <span className="badge badge-blue" style={{ fontSize: '0.9rem' }}>{staff?.doctors ?? 0}</span>
            </div>

            {/* Infirmiers */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0.75rem', background: '#f8fafc', borderRadius: '8px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <div style={{ padding: '0.5rem', background: '#d1fae5', color: '#059669', borderRadius: '8px' }}>
                  <HeartPulse size={18} />
                </div>
                <div>
                  <p style={{ fontWeight: 600, fontSize: '0.9rem' }}>Infirmiers & Soignants</p>
                  <p style={{ fontSize: '0.75rem', color: '#64748b' }}>Urgences, Soins intensifs</p>
                </div>
              </div>
              <span className="badge badge-emerald" style={{ fontSize: '0.9rem' }}>{staff?.nurses ?? 0}</span>
            </div>

            {/* Sages-femmes */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0.75rem', background: '#f8fafc', borderRadius: '8px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <div style={{ padding: '0.5rem', background: '#ede9fe', color: '#7c3aed', borderRadius: '8px' }}>
                  <Baby size={18} />
                </div>
                <div>
                  <p style={{ fontWeight: 600, fontSize: '0.9rem' }}>Sages-femmes (Maternité)</p>
                  <p style={{ fontSize: '0.75rem', color: '#64748b' }}>Bloc obstétrical & suites de couches</p>
                </div>
              </div>
              <span className="badge badge-purple" style={{ fontSize: '0.9rem' }}>{staff?.midwives ?? 0}</span>
            </div>

            {/* Techniciens */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0.75rem', background: '#f8fafc', borderRadius: '8px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <div style={{ padding: '0.5rem', background: '#fef3c7', color: '#d97706', borderRadius: '8px' }}>
                  <Microscope size={18} />
                </div>
                <div>
                  <p style={{ fontWeight: 600, fontSize: '0.9rem' }}>Techniciens Plateaux Techniques</p>
                  <p style={{ fontSize: '0.75rem', color: '#64748b' }}>Radiologie, Scanner, Laboratoire</p>
                </div>
              </div>
              <span className="badge badge-amber" style={{ fontSize: '0.9rem' }}>{staff?.technicians ?? 0}</span>
            </div>
          </div>
        </div>

        {/* Consultations & Activité Hospitalière */}
        <div className="table-card" style={{ marginBottom: 0, padding: '1.5rem' }}>
          <h3 style={{ fontSize: '1.1rem', fontWeight: 700, marginBottom: '1rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <CalendarCheck size={20} color="#059669" />
            <span>Activité Clinique & Consultations</span>
          </h3>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
            <div
              style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid #f1f5f9', paddingBottom: '0.75rem', cursor: 'pointer' }}
              onClick={() => onNavigate('consultations')}
            >
              <span style={{ color: '#0284c7', fontSize: '0.9rem', fontWeight: 600 }}>Total Consultations Médicales →</span>
              <span style={{ fontWeight: 700, fontSize: '1.1rem', color: '#0284c7' }}>{consultations?.total ?? recentConsultations.length}</span>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid #f1f5f9', paddingBottom: '0.75rem' }}>
              <span style={{ color: '#64748b', fontSize: '0.9rem' }}>Rendez-vous du jour</span>
              <span style={{ fontWeight: 700, fontSize: '1.1rem', color: '#0284c7' }}>{appointments?.today ?? 0}</span>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid #f1f5f9', paddingBottom: '0.75rem' }}>
              <span style={{ color: '#64748b', fontSize: '0.9rem' }}>Rendez-vous en attente de validation</span>
              <span style={{ fontWeight: 700, fontSize: '1.1rem', color: '#d97706' }}>{appointments?.pending ?? 0}</span>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ color: '#64748b', fontSize: '0.9rem' }}>Lits disponibles immédiatement</span>
              <span style={{ fontWeight: 700, fontSize: '1.1rem', color: '#059669' }}>{hospitalization?.availableBeds ?? 0}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
