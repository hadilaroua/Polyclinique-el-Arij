import React, { useState, useEffect } from 'react';
import { FlaskConical, Clock, CheckCircle2, AlertTriangle, Search, Filter } from 'lucide-react';
import { api } from '../api';

export const ExamsView: React.FC = () => {
  const [exams, setExams] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<string>('ALL');

  const fetchExams = async () => {
    try {
      setLoading(true);
      const url = statusFilter === 'ALL' ? '/exams' : `/exams?status=${statusFilter}`;
      const res = await api.get(url);
      setExams(res.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchExams();
  }, [statusFilter]);

  const getPriorityBadge = (priority: string) => {
    switch (priority) {
      case 'URGENT':
        return <span className="badge badge-rose" style={{ animation: 'pulse 2s infinite' }}>🚨 URGENT</span>;
      case 'HIGH':
        return <span className="badge badge-amber">Élevée</span>;
      case 'MEDIUM':
        return <span className="badge badge-blue">Normale</span>;
      case 'LOW':
        return <span className="badge">Basse</span>;
      default:
        return <span className="badge">{priority}</span>;
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'PENDING':
        return (
          <span className="badge badge-amber">
            <Clock size={12} />
            <span>En attente</span>
          </span>
        );
      case 'IN_PROGRESS':
        return (
          <span className="badge badge-blue">
            <FlaskConical size={12} />
            <span>En cours d'analyse</span>
          </span>
        );
      case 'COMPLETED':
        return (
          <span className="badge badge-emerald">
            <CheckCircle2 size={12} />
            <span>Résultat Validé</span>
          </span>
        );
      case 'CANCELLED':
        return <span className="badge badge-rose">Annulé</span>;
      default:
        return <span className="badge">{status}</span>;
    }
  };

  return (
    <div className="table-card">
      <div className="table-header-bar">
        <div className="table-title-group">
          <h3>Examens & Plateau Technique</h3>
          <p>Suivi en temps réel des analyses biologiques, radiologies et scanners</p>
        </div>

        {/* Filtres statuts */}
        <div style={{ display: 'flex', gap: '0.5rem' }}>
          {[
            { id: 'ALL', label: 'Tous les examens' },
            { id: 'PENDING', label: 'En attente' },
            { id: 'IN_PROGRESS', label: 'En cours' },
            { id: 'COMPLETED', label: 'Validés' },
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setStatusFilter(tab.id)}
              className="btn"
              style={{
                padding: '0.4rem 0.85rem',
                fontSize: '0.8rem',
                background: statusFilter === tab.id ? '#0284c7' : '#f1f5f9',
                color: statusFilter === tab.id ? 'white' : '#475569',
              }}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {loading ? (
        <div style={{ textAlign: 'center', padding: '3rem', color: '#64748b' }}>Chargement des examens...</div>
      ) : exams.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '3rem', color: '#64748b' }}>
          Aucun examen dans cette catégorie.
        </div>
      ) : (
        <table className="custom-table">
          <thead>
            <tr>
              <th>Type d'examen</th>
              <th>Patient</th>
              <th>Médecin prescripteur</th>
              <th>Priorité</th>
              <th>Statut</th>
              <th>Résultats / Notes</th>
            </tr>
          </thead>
          <tbody>
            {exams.map((ex) => (
              <tr key={ex._id}>
                <td>
                  <div>
                    <p style={{ fontWeight: 600 }}>{ex.examType}</p>
                    <span style={{ fontSize: '0.75rem', color: '#64748b' }}>{ex.service || 'Plateau technique'}</span>
                  </div>
                </td>
                <td>
                  <p style={{ fontWeight: 600 }}>
                    {ex.patientId?.firstName} {ex.patientId?.lastName}
                  </p>
                  <span style={{ fontSize: '0.75rem', color: '#0284c7' }}>CIN: {ex.patientId?.cin || '—'}</span>
                </td>
                <td>
                  <p style={{ fontSize: '0.85rem' }}>
                    Dr. {ex.requestingDoctorId?.userId?.firstName || ex.requestingDoctorId?.firstName || 'Médecin'}
                  </p>
                </td>
                <td>{getPriorityBadge(ex.priority)}</td>
                <td>{getStatusBadge(ex.status)}</td>
                <td>
                  <p style={{ fontSize: '0.85rem', maxWidth: '280px', textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }}>
                    {ex.result || ex.requestNotes || 'En attente d’analyse'}
                  </p>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
};
