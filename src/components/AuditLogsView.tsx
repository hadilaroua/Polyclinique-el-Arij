import React, { useState, useEffect } from 'react';
import {
  ShieldCheck,
  Search,
  Filter,
  RefreshCw,
  Clock,
  User,
  Stethoscope,
  FlaskConical,
  Activity,
  AlertTriangle,
  FileCheck,
  Building,
} from 'lucide-react';
import { api } from '../api';

interface AuditLogItem {
  _id: string;
  action: string;
  category: string;
  actorId: string;
  actorName: string;
  actorRole: string;
  patientId?: string;
  patientName?: string;
  patientDossier?: string;
  entityId?: string;
  targetEntity?: string;
  details: string;
  metadata?: any;
  createdAt: string;
}

export const AuditLogsView: React.FC = () => {
  const [logs, setLogs] = useState<AuditLogItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('ALL');

  const fetchLogs = async () => {
    try {
      setLoading(true);
      const res = await api.get('/audit-logs');
      setLogs(res.data || []);
    } catch (err) {
      console.error('Erreur chargement logs audit:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLogs();
  }, []);

  const getActionBadge = (action: string, category: string) => {
    switch (action) {
      case 'CREATION_CONSULTATION':
        return { label: 'Consultation', color: '#0284c7', bg: '#e0f2fe', icon: Stethoscope };
      case 'DEMANDE_EXAMEN':
        return { label: 'Demande Examen', color: '#7c3aed', bg: '#ede9fe', icon: FlaskConical };
      case 'VALIDATION_EXAMEN':
        return { label: 'Validation Examen', color: '#059669', bg: '#d1fae5', icon: FileCheck };
      case 'PRISE_CONSTANTES':
        return { label: 'Constantes Vitales', color: '#d97706', bg: '#fef3c7', icon: Activity };
      case 'CREATION_ALERTE':
        return { label: 'Alerte Médicale', color: '#dc2626', bg: '#fee2e2', icon: AlertTriangle };
      case 'HOSPITALISATION':
        return { label: 'Hospitalisation', color: '#0891b2', bg: '#cffafe', icon: Building };
      default:
        return { label: action, color: '#475569', bg: '#f1f5f9', icon: Clock };
    }
  };

  const getRoleBadge = (role: string) => {
    switch (role) {
      case 'DOCTOR':
        return { label: 'Médecin', bg: '#e0f2fe', color: '#0369a1' };
      case 'NURSE':
        return { label: 'Infirmier(ère)', bg: '#ede9fe', color: '#6d28d9' };
      case 'MIDWIFE':
        return { label: 'Sage-femme', bg: '#fce7f3', color: '#be185d' };
      case 'TECHNICIAN':
        return { label: 'Technicien', bg: '#fef3c7', color: '#b45309' };
      case 'ADMIN':
        return { label: 'Admin', bg: '#f1f5f9', color: '#334155' };
      default:
        return { label: role, bg: '#f1f5f9', color: '#64748b' };
    }
  };

  const filteredLogs = logs.filter((log) => {
    const matchesSearch =
      (log.actorName && log.actorName.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (log.patientName && log.patientName.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (log.patientDossier && log.patientDossier.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (log.details && log.details.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (log.action && log.action.toLowerCase().includes(searchTerm.toLowerCase()));

    const matchesCategory =
      categoryFilter === 'ALL' ||
      log.category?.toUpperCase() === categoryFilter ||
      log.action?.includes(categoryFilter);

    return matchesSearch && matchesCategory;
  });

  const stats = {
    total: logs.length,
    consultations: logs.filter((l) => l.action === 'CREATION_CONSULTATION').length,
    exams: logs.filter((l) => l.action.includes('EXAMEN')).length,
    vitals: logs.filter((l) => l.action === 'PRISE_CONSTANTES').length,
    alerts: logs.filter((l) => l.action.includes('ALERTE')).length,
  };

  return (
    <div className="view-container">
      {/* Header */}
      <div className="page-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
        <div>
          <h1 style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '24px', fontWeight: '700', color: '#0f172a' }}>
            <ShieldCheck size={28} color="#059669" />
            Journal d'Audit Clinique & Traçabilité
          </h1>
          <p style={{ color: '#64748b', fontSize: '14px', marginTop: '4px' }}>
            Traçabilité médico-légale en temps réel des actes réalisés : qui a fait quoi, quand et sur quel dossier patient.
          </p>
        </div>
        <button
          onClick={fetchLogs}
          className="btn btn-secondary"
          style={{ display: 'flex', alignItems: 'center', gap: '8px' }}
        >
          <RefreshCw size={16} className={loading ? 'spin' : ''} />
          Actualiser
        </button>
      </div>

      {/* KPI Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px', marginBottom: '24px' }}>
        <div className="kpi-card" style={{ background: '#fff', padding: '16px 20px', borderRadius: '12px', border: '1px solid #e2e8f0' }}>
          <div style={{ fontSize: '13px', color: '#64748b', fontWeight: '500' }}>Actes Traçables Enregistrés</div>
          <div style={{ fontSize: '26px', fontWeight: '700', color: '#0f172a', marginTop: '4px' }}>{stats.total}</div>
        </div>
        <div className="kpi-card" style={{ background: '#fff', padding: '16px 20px', borderRadius: '12px', border: '1px solid #e2e8f0' }}>
          <div style={{ fontSize: '13px', color: '#0284c7', fontWeight: '500' }}>Consultations Médecins</div>
          <div style={{ fontSize: '26px', fontWeight: '700', color: '#0284c7', marginTop: '4px' }}>{stats.consultations}</div>
        </div>
        <div className="kpi-card" style={{ background: '#fff', padding: '16px 20px', borderRadius: '12px', border: '1px solid #e2e8f0' }}>
          <div style={{ fontSize: '13px', color: '#059669', fontWeight: '500' }}>Actes Examens & Labo</div>
          <div style={{ fontSize: '26px', fontWeight: '700', color: '#059669', marginTop: '4px' }}>{stats.exams}</div>
        </div>
        <div className="kpi-card" style={{ background: '#fff', padding: '16px 20px', borderRadius: '12px', border: '1px solid #e2e8f0' }}>
          <div style={{ fontSize: '13px', color: '#d97706', fontWeight: '500' }}>Constantes & Soins</div>
          <div style={{ fontSize: '26px', fontWeight: '700', color: '#d97706', marginTop: '4px' }}>{stats.vitals}</div>
        </div>
        <div className="kpi-card" style={{ background: '#fff', padding: '16px 20px', borderRadius: '12px', border: '1px solid #e2e8f0' }}>
          <div style={{ fontSize: '13px', color: '#dc2626', fontWeight: '500' }}>Alertes Médicales</div>
          <div style={{ fontSize: '26px', fontWeight: '700', color: '#dc2626', marginTop: '4px' }}>{stats.alerts}</div>
        </div>
      </div>

      {/* Filters & Search */}
      <div style={{ display: 'flex', gap: '16px', marginBottom: '20px', flexWrap: 'wrap', alignItems: 'center' }}>
        <div style={{ position: 'relative', flex: '1', minWidth: '260px' }}>
          <Search size={18} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
          <input
            type="text"
            placeholder="Rechercher par médecin, patient, n° dossier, action..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            style={{
              width: '100%',
              padding: '10px 14px 10px 38px',
              borderRadius: '8px',
              border: '1px solid #cbd5e1',
              fontSize: '14px',
              outline: 'none',
            }}
          />
        </div>

        <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
          {[
            { id: 'ALL', label: 'Tous' },
            { id: 'CONSULTATION', label: 'Consultations' },
            { id: 'EXAMEN', label: 'Examens' },
            { id: 'SOINS', label: 'Soins / Vitals' },
            { id: 'ALERTE', label: 'Alertes' },
          ].map((cat) => (
            <button
              key={cat.id}
              onClick={() => setCategoryFilter(cat.id)}
              style={{
                padding: '8px 16px',
                borderRadius: '8px',
                border: '1px solid',
                borderColor: categoryFilter === cat.id ? '#059669' : '#e2e8f0',
                background: categoryFilter === cat.id ? '#ecfdf5' : '#fff',
                color: categoryFilter === cat.id ? '#059669' : '#475569',
                fontWeight: categoryFilter === cat.id ? '600' : '400',
                fontSize: '13px',
                cursor: 'pointer',
              }}
            >
              {cat.label}
            </button>
          ))}
        </div>
      </div>

      {/* Table */}
      <div style={{ background: '#fff', borderRadius: '12px', border: '1px solid #e2e8f0', overflow: 'hidden' }}>
        {loading ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>
            <RefreshCw className="spin" size={24} style={{ margin: '0 auto 12px' }} />
            Chargement de la traçabilité clinique...
          </div>
        ) : filteredLogs.length === 0 ? (
          <div style={{ padding: '48px', textAlign: 'center', color: '#94a3b8' }}>
            <ShieldCheck size={40} style={{ margin: '0 auto 12px', color: '#cbd5e1' }} />
            <p style={{ fontWeight: '500', color: '#475569' }}>Aucun enregistrement d'audit trouvé</p>
            <p style={{ fontSize: '13px', marginTop: '4px' }}>Les actes médicaux enregistrés dans l'application mobile apparaîtront ici automatiquement.</p>
          </div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '14px' }}>
            <thead>
              <tr style={{ background: '#f8fafc', borderBottom: '1px solid #e2e8f0', color: '#475569', fontWeight: '600' }}>
                <th style={{ padding: '14px 20px' }}>Date & Heure</th>
                <th style={{ padding: '14px 20px' }}>Type d'Acte</th>
                <th style={{ padding: '14px 20px' }}>Professionnel (Acteur)</th>
                <th style={{ padding: '14px 20px' }}>Patient / Dossier</th>
                <th style={{ padding: '14px 20px' }}>Détails de l'Acte</th>
              </tr>
            </thead>
            <tbody>
              {filteredLogs.map((log) => {
                const badge = getActionBadge(log.action, log.category);
                const roleBadge = getRoleBadge(log.actorRole);
                const ActionIcon = badge.icon;
                const formattedDate = new Date(log.createdAt).toLocaleString('fr-FR', {
                  day: '2-digit',
                  month: '2-digit',
                  year: 'numeric',
                  hour: '2-digit',
                  minute: '2-digit',
                  second: '2-digit',
                });

                return (
                  <tr key={log._id} style={{ borderBottom: '1px solid #f1f5f9', transition: 'background 0.2s' }}>
                    <td style={{ padding: '14px 20px', whiteSpace: 'nowrap', color: '#64748b', fontSize: '13px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <Clock size={14} color="#94a3b8" />
                        {formattedDate}
                      </div>
                    </td>

                    <td style={{ padding: '14px 20px', whiteSpace: 'nowrap' }}>
                      <span
                        style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '6px',
                          padding: '4px 10px',
                          borderRadius: '6px',
                          fontSize: '12px',
                          fontWeight: '600',
                          background: badge.bg,
                          color: badge.color,
                        }}
                      >
                        <ActionIcon size={14} />
                        {badge.label}
                      </span>
                    </td>

                    <td style={{ padding: '14px 20px' }}>
                      <div style={{ fontWeight: '600', color: '#1e293b' }}>{log.actorName}</div>
                      <span
                        style={{
                          fontSize: '11px',
                          fontWeight: '500',
                          padding: '2px 6px',
                          borderRadius: '4px',
                          background: roleBadge.bg,
                          color: roleBadge.color,
                          display: 'inline-block',
                          marginTop: '2px',
                        }}
                      >
                        {roleBadge.label}
                      </span>
                    </td>

                    <td style={{ padding: '14px 20px' }}>
                      {log.patientName ? (
                        <div>
                          <div style={{ fontWeight: '500', color: '#1e293b' }}>{log.patientName}</div>
                          {log.patientDossier && (
                            <div style={{ fontSize: '12px', color: '#0284c7', fontFamily: 'monospace' }}>
                              {log.patientDossier}
                            </div>
                          )}
                        </div>
                      ) : (
                        <span style={{ color: '#94a3b8', fontStyle: 'italic' }}>Général / Système</span>
                      )}
                    </td>

                    <td style={{ padding: '14px 20px', color: '#334155' }}>
                      <div style={{ maxWidth: '420px', wordBreak: 'break-word', lineHeight: '1.4' }}>
                        {log.details || 'Acte clinique standard'}
                      </div>
                      {log.metadata && Object.keys(log.metadata).length > 0 && (
                        <div style={{ display: 'flex', gap: '6px', marginTop: '4px', flexWrap: 'wrap' }}>
                          {log.metadata.hasPrescriptionItems && (
                            <span style={{ fontSize: '11px', background: '#e0f2fe', color: '#0369a1', padding: '1px 6px', borderRadius: '4px' }}>
                              Ordonnance structurée
                            </span>
                          )}
                          {log.metadata.hasAttachments && (
                            <span style={{ fontSize: '11px', background: '#fef3c7', color: '#b45309', padding: '1px 6px', borderRadius: '4px' }}>
                              Pièce jointe / PDF
                            </span>
                          )}
                          {log.metadata.hasResultDocument && (
                            <span style={{ fontSize: '11px', background: '#d1fae5', color: '#065f46', padding: '1px 6px', borderRadius: '4px' }}>
                              Doc résultat joint
                            </span>
                          )}
                          {log.metadata.anomalies && log.metadata.anomalies.map((anom: string, i: number) => (
                            <span key={i} style={{ fontSize: '11px', background: '#fee2e2', color: '#b91c1c', padding: '1px 6px', borderRadius: '4px' }}>
                              {anom}
                            </span>
                          ))}
                        </div>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
};
