import React, { useState, useEffect } from 'react';
import {
  Stethoscope,
  Search,
  User,
  Calendar,
  FileText,
  Pill,
  ChevronRight,
  X,
  Filter,
  Eye,
} from 'lucide-react';
import { api } from '../api';

export const ConsultationsView: React.FC = () => {
  const [consultations, setConsultations] = useState<any[]>([]);
  const [doctors, setDoctors] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedDoctorId, setSelectedDoctorId] = useState<string>('ALL');
  const [selectedConsultation, setSelectedConsultation] = useState<any | null>(null);

  const fetchData = async () => {
    try {
      setLoading(true);
      const [consultRes, doctorsRes] = await Promise.all([
        api.get('/consultations'),
        api.get('/users?role=DOCTOR'),
      ]);
      setConsultations(consultRes.data);
      setDoctors(doctorsRes.data);
    } catch (err) {
      console.error('Erreur chargement consultations:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  // Filtrage par médecin et recherche
  const filteredConsultations = consultations.filter((c) => {
    // Filtre médecin
    if (selectedDoctorId !== 'ALL') {
      const docId = c.doctorId?._id || c.doctorId?.id;
      if (docId !== selectedDoctorId) return false;
    }

    // Filtre recherche
    if (searchTerm.trim() !== '') {
      const term = searchTerm.toLowerCase();
      const patientName = `${c.patientId?.firstName || ''} ${c.patientId?.lastName || ''}`.toLowerCase();
      const patientCin = (c.patientId?.cin || '').toLowerCase();
      const doctorName = `${c.doctorId?.firstName || ''} ${c.doctorId?.lastName || ''}`.toLowerCase();
      const diagnostic = (c.diagnostic || '').toLowerCase();
      const motive = (c.motive || '').toLowerCase();

      return (
        patientName.includes(term) ||
        patientCin.includes(term) ||
        doctorName.includes(term) ||
        diagnostic.includes(term) ||
        motive.includes(term)
      );
    }

    return true;
  });

  return (
    <div>
      {/* En-tête KPI et filtres */}
      <div className="table-card" style={{ marginBottom: '1.5rem', padding: '1.5rem' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
          <div>
            <h3 style={{ fontSize: '1.25rem', fontWeight: 700, color: '#0f172a', display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
              <Stethoscope size={22} color="#0284c7" />
              <span>Consultations Médicales par Médecin</span>
            </h3>
            <p style={{ fontSize: '0.85rem', color: '#64748b', marginTop: '0.25rem' }}>
              Suivi en temps réel de tous les actes médicaux et prescriptions rédigés par les praticiens
            </p>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
            {/* Filtre par Médecin */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <Filter size={16} color="#64748b" />
              <select
                className="form-control"
                style={{ width: '220px', fontSize: '0.85rem' }}
                value={selectedDoctorId}
                onChange={(e) => setSelectedDoctorId(e.target.value)}
              >
                <option value="ALL">Tous les Médecins ({consultations.length})</option>
                {doctors.map((doc) => {
                  const docCount = consultations.filter(
                    (c) => (c.doctorId?._id || c.doctorId?.id) === doc._id,
                  ).length;
                  return (
                    <option key={doc._id} value={doc._id}>
                      Dr. {doc.firstName} {doc.lastName} ({docCount})
                    </option>
                  );
                })}
              </select>
            </div>

            {/* Barre de recherche */}
            <div style={{ position: 'relative' }}>
              <Search
                size={16}
                style={{ position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }}
              />
              <input
                type="text"
                placeholder="Rechercher patient, diagnostic..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="form-control"
                style={{ paddingLeft: '32px', width: '240px', fontSize: '0.85rem' }}
              />
            </div>
          </div>
        </div>

        {/* Badges de filtre rapide par Médecin */}
        <div style={{ display: 'flex', gap: '0.5rem', marginTop: '1.25rem', overflowX: 'auto', paddingBottom: '0.25rem' }}>
          <button
            onClick={() => setSelectedDoctorId('ALL')}
            className="btn"
            style={{
              padding: '0.35rem 0.85rem',
              fontSize: '0.8rem',
              background: selectedDoctorId === 'ALL' ? '#0284c7' : '#f1f5f9',
              color: selectedDoctorId === 'ALL' ? 'white' : '#475569',
              border: 'none',
              borderRadius: '20px',
              fontWeight: 600,
            }}
          >
            Tous les praticiens ({consultations.length})
          </button>
          {doctors.map((doc) => {
            const count = consultations.filter((c) => (c.doctorId?._id || c.doctorId?.id) === doc._id).length;
            const isSelected = selectedDoctorId === doc._id;
            return (
              <button
                key={doc._id}
                onClick={() => setSelectedDoctorId(doc._id)}
                className="btn"
                style={{
                  padding: '0.35rem 0.85rem',
                  fontSize: '0.8rem',
                  background: isSelected ? '#0284c7' : '#f8fafc',
                  color: isSelected ? 'white' : '#334155',
                  border: isSelected ? 'none' : '1px solid #e2e8f0',
                  borderRadius: '20px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.4rem',
                  fontWeight: isSelected ? 700 : 500,
                }}
              >
                {doc.avatarUrl ? (
                  <img
                    src={doc.avatarUrl}
                    alt=""
                    style={{ width: 18, height: 18, borderRadius: '50%', objectFit: 'cover' }}
                  />
                ) : (
                  <span>🩺</span>
                )}
                <span>Dr. {doc.firstName} {doc.lastName}</span>
                <span
                  style={{
                    background: isSelected ? 'rgba(255,255,255,0.25)' : '#e2e8f0',
                    color: isSelected ? 'white' : '#475569',
                    padding: '0.1rem 0.4rem',
                    borderRadius: '10px',
                    fontSize: '0.7rem',
                  }}
                >
                  {count}
                </span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Tableau des consultations */}
      <div className="table-card">
        {loading ? (
          <div style={{ padding: '3rem', textAlign: 'center', color: '#64748b' }}>
            Chargement des consultations...
          </div>
        ) : filteredConsultations.length === 0 ? (
          <div style={{ padding: '3rem', textAlign: 'center', color: '#64748b' }}>
            <Stethoscope size={40} style={{ opacity: 0.3, margin: '0 auto 1rem' }} />
            <p style={{ fontWeight: 600, color: '#334155' }}>Aucune consultation médicale trouvée</p>
            <p style={{ fontSize: '0.85rem', color: '#94a3b8' }}>
              Les consultations saisies par les médecins sur l'application mobile apparaîtront ici automatiquement.
            </p>
          </div>
        ) : (
          <table className="custom-table">
            <thead>
              <tr>
                <th>Médecin Praticien</th>
                <th>Patient</th>
                <th>Date & Motif</th>
                <th>Diagnostic Posé</th>
                <th>Prescription</th>
                <th style={{ textAlign: 'right' }}>Action</th>
              </tr>
            </thead>
            <tbody>
              {filteredConsultations.map((c) => {
                const doc = c.doctorId;
                const pat = c.patientId;
                const docName = doc ? `Dr. ${doc.firstName} ${doc.lastName}` : 'Médecin non spécifié';
                const patName = pat ? `${pat.firstName} ${pat.lastName}` : 'Patient non spécifié';

                return (
                  <tr key={c._id}>
                    {/* Médecin */}
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                        <div
                          style={{
                            width: 38,
                            height: 38,
                            borderRadius: '50%',
                            background: '#e0f2fe',
                            border: '2px solid #bae6fd',
                            overflow: 'hidden',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            flexShrink: 0,
                          }}
                        >
                          {doc?.avatarUrl ? (
                            <img
                              src={doc.avatarUrl}
                              alt={docName}
                              style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                            />
                          ) : (
                            <span style={{ color: '#0284c7', fontWeight: 700 }}>
                              {doc?.firstName?.[0] || 'D'}
                            </span>
                          )}
                        </div>
                        <div>
                          <p style={{ fontWeight: 600, color: '#0f172a' }}>{docName}</p>
                          <span style={{ fontSize: '0.75rem', color: '#0284c7', fontWeight: 500 }}>
                            {doc?.email || 'Médecine Spécialisée'}
                          </span>
                        </div>
                      </div>
                    </td>

                    {/* Patient */}
                    <td>
                      <div>
                        <p style={{ fontWeight: 600, color: '#0f172a' }}>{patName}</p>
                        <div style={{ display: 'flex', gap: '0.4rem', marginTop: '0.2rem' }}>
                          {pat?.dossierNumber && (
                            <span className="badge badge-blue" style={{ fontSize: '0.7rem' }}>
                              {pat.dossierNumber}
                            </span>
                          )}
                          {pat?.cin && (
                            <span style={{ fontSize: '0.75rem', color: '#64748b' }}>
                              CIN: {pat.cin}
                            </span>
                          )}
                        </div>
                      </div>
                    </td>

                    {/* Date & Motif */}
                    <td>
                      <div>
                        <p style={{ fontWeight: 600, fontSize: '0.85rem' }}>{c.date || '—'}</p>
                        <p style={{ fontSize: '0.8rem', color: '#475569', maxWidth: '240px', whiteSpace: 'nowrap', textOverflow: 'ellipsis', overflow: 'hidden' }} title={c.motive}>
                          {c.motive || '—'}
                        </p>
                      </div>
                    </td>

                    {/* Diagnostic */}
                    <td>
                      <span
                        className="badge"
                        style={{
                          background: '#f0fdf4',
                          color: '#166534',
                          border: '1px solid #bbf7d0',
                          padding: '0.35rem 0.65rem',
                          fontWeight: 600,
                        }}
                      >
                        {c.diagnostic || '—'}
                      </span>
                    </td>

                    {/* Prescription */}
                    <td>
                      {c.prescription ? (
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', color: '#0284c7', fontSize: '0.85rem' }}>
                          <Pill size={14} />
                          <span style={{ maxWidth: '180px', whiteSpace: 'nowrap', textOverflow: 'ellipsis', overflow: 'hidden' }} title={c.prescription}>
                            {c.prescription}
                          </span>
                        </div>
                      ) : (
                        <span style={{ color: '#94a3b8', fontSize: '0.85rem' }}>Aucune</span>
                      )}
                    </td>

                    {/* Action */}
                    <td style={{ textAlign: 'right' }}>
                      <button
                        className="btn btn-secondary"
                        style={{ padding: '0.35rem 0.75rem', fontSize: '0.8rem', gap: '0.3rem' }}
                        onClick={() => setSelectedConsultation(c)}
                      >
                        <Eye size={14} />
                        <span>Détails</span>
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      {/* Modal Détails Consultation */}
      {selectedConsultation && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '620px' }}>
            <div className="modal-header">
              <h3 style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', margin: 0, fontSize: '1.2rem' }}>
                <Stethoscope size={20} color="#0284c7" />
                <span>Dossier Consultation Médicale</span>
              </h3>
              <button onClick={() => setSelectedConsultation(null)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748b' }}>
                <X size={20} />
              </button>
            </div>

            <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
              {/* Entête Médecin & Patient */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', background: '#f8fafc', padding: '1rem', borderRadius: '12px', border: '1px solid #e2e8f0' }}>
                <div>
                  <p style={{ fontSize: '0.75rem', color: '#64748b', fontWeight: 600 }}>MÉDECIN PRATICIEN</p>
                  <p style={{ fontWeight: 700, color: '#0f172a', marginTop: '0.2rem' }}>
                    Dr. {selectedConsultation.doctorId?.firstName} {selectedConsultation.doctorId?.lastName}
                  </p>
                  <p style={{ fontSize: '0.8rem', color: '#0284c7' }}>
                    {selectedConsultation.doctorId?.email}
                  </p>
                </div>
                <div>
                  <p style={{ fontSize: '0.75rem', color: '#64748b', fontWeight: 600 }}>PATIENT EXAMINÉ</p>
                  <p style={{ fontWeight: 700, color: '#0f172a', marginTop: '0.2rem' }}>
                    {selectedConsultation.patientId?.firstName} {selectedConsultation.patientId?.lastName}
                  </p>
                  <p style={{ fontSize: '0.8rem', color: '#64748b' }}>
                    CIN: {selectedConsultation.patientId?.cin} | Dossier: {selectedConsultation.patientId?.dossierNumber}
                  </p>
                </div>
              </div>

              {/* Date & Motif */}
              <div>
                <p style={{ fontSize: '0.8rem', color: '#64748b', fontWeight: 600 }}>DATE & MOTIF DE CONSULTATION</p>
                <p style={{ fontSize: '0.9rem', fontWeight: 600, marginTop: '0.2rem' }}>
                  Le {selectedConsultation.date}
                </p>
                <div style={{ background: '#f1f5f9', padding: '0.75rem', borderRadius: '8px', marginTop: '0.4rem', fontSize: '0.9rem', color: '#1e293b' }}>
                  {selectedConsultation.motive || 'Non renseigné'}
                </div>
              </div>

              {/* Examen Clinique */}
              {selectedConsultation.clinicalExam && (
                <div>
                  <p style={{ fontSize: '0.8rem', color: '#64748b', fontWeight: 600 }}>EXAMEN CLINIQUE RÉALISÉ</p>
                  <div style={{ background: '#f8fafc', padding: '0.75rem', borderRadius: '8px', marginTop: '0.4rem', fontSize: '0.9rem', border: '1px solid #e2e8f0' }}>
                    {selectedConsultation.clinicalExam}
                  </div>
                </div>
              )}

              {/* Diagnostic */}
              <div>
                <p style={{ fontSize: '0.8rem', color: '#64748b', fontWeight: 600 }}>DIAGNOSTIC MÉDICAL POSÉ</p>
                <div style={{ background: '#ecfdf5', border: '1px solid #a7f3d0', color: '#065f46', padding: '0.85rem', borderRadius: '8px', marginTop: '0.4rem', fontWeight: 700, fontSize: '0.95rem' }}>
                  {selectedConsultation.diagnostic || 'Non renseigné'}
                </div>
              </div>

              {/* Ordonnance / Prescription */}
              <div>
                <p style={{ fontSize: '0.8rem', color: '#64748b', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
                  <Pill size={15} color="#0284c7" />
                  <span>ORDONNANCE & PRESCRIPTION MÉDICAMENTEUSE</span>
                </p>
                <div style={{ background: '#f0f9ff', border: '1px solid #bae6fd', color: '#0369a1', padding: '0.85rem', borderRadius: '8px', marginTop: '0.4rem', fontSize: '0.9rem', whiteSpace: 'pre-line' }}>
                  {selectedConsultation.prescription || 'Aucune prescription médicamenteuse délivrée.'}
                </div>
              </div>

              {/* Observations */}
              {selectedConsultation.observations && (
                <div>
                  <p style={{ fontSize: '0.8rem', color: '#64748b', fontWeight: 600 }}>OBSERVATIONS DU MÉDECIN</p>
                  <p style={{ fontSize: '0.85rem', color: '#475569', marginTop: '0.2rem', fontStyle: 'italic' }}>
                    {selectedConsultation.observations}
                  </p>
                </div>
              )}
            </div>

            <div className="modal-footer">
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => setSelectedConsultation(null)}
              >
                Fermer
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
