import React, { useState, useEffect } from 'react';
import { UserPlus, Search, UserRound, Droplet, Phone, MapPin, X } from 'lucide-react';
import { api } from '../api';

export const PatientsView: React.FC = () => {
  const [patients, setPatients] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);

  // Formulaire d'ajout de patient
  const [formData, setFormData] = useState({
    firstName: '',
    lastName: '',
    cin: '',
    dateOfBirth: '1990-01-01',
    gender: 'Homme',
    bloodType: 'O+',
    phone: '',
    address: 'Midoun, Djerba',
  });
  const [formSubmitting, setFormSubmitting] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const fetchPatients = async () => {
    try {
      setLoading(true);
      const res = await api.get('/patients');
      setPatients(res.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPatients();
  }, []);

  const handleCreatePatient = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);
    setFormSubmitting(true);

    try {
      await api.post('/patients', formData);
      setIsModalOpen(false);
      setFormData({
        firstName: '',
        lastName: '',
        cin: '',
        dateOfBirth: '1990-01-01',
        gender: 'Homme',
        bloodType: 'O+',
        phone: '',
        address: 'Midoun, Djerba',
      });
      fetchPatients();
    } catch (err: any) {
      setFormError(err.response?.data?.message || 'Erreur lors de la création du dossier patient');
    } finally {
      setFormSubmitting(false);
    }
  };

  const filteredPatients = patients.filter((p) => {
    const term = searchTerm.toLowerCase();
    return (
      `${p.firstName} ${p.lastName}`.toLowerCase().includes(term) ||
      p.cin?.includes(term) ||
      p.phone?.includes(term) ||
      p.dossierNumber?.toLowerCase().includes(term)
    );
  });

  return (
    <div>
      <div className="table-card">
        <div className="table-header-bar">
          <div className="table-title-group">
            <h3>Fichier Patients & Dossiers Médicaux</h3>
            <p>{filteredPatients.length} patients enregistrés dans la clinique</p>
          </div>

          <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center' }}>
            <div style={{ position: 'relative' }}>
              <Search
                size={16}
                style={{ position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }}
              />
              <input
                type="text"
                placeholder="Rechercher nom, CIN, N° dossier..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="form-control"
                style={{ paddingLeft: '32px', width: '260px' }}
              />
            </div>

            <button
              className="btn btn-primary"
              onClick={() => setIsModalOpen(true)}
              style={{ background: 'linear-gradient(135deg, #059669, #10b981)' }}
            >
              <UserPlus size={16} />
              <span>Nouveau Patient</span>
            </button>
          </div>
        </div>

        {loading ? (
          <div style={{ padding: '3rem', textAlign: 'center', color: '#64748b' }}>Chargement des dossiers...</div>
        ) : (
          <table className="custom-table">
            <thead>
              <tr>
                <th>Patient</th>
                <th>CIN</th>
                <th>Groupe Sanguin</th>
                <th>Date de naissance / Sexe</th>
                <th>Contact & Ville</th>
                <th>Statut</th>
              </tr>
            </thead>
            <tbody>
              {filteredPatients.length === 0 ? (
                <tr>
                  <td colSpan={6} style={{ textAlign: 'center', padding: '2rem', color: '#64748b' }}>
                    Aucun dossier patient correspondant.
                  </td>
                </tr>
              ) : (
                filteredPatients.map((p) => (
                  <tr key={p._id}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                        <div
                          style={{
                            width: 38,
                            height: 38,
                            borderRadius: '50%',
                            background: '#d1fae5',
                            color: '#059669',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            fontWeight: 700,
                          }}
                        >
                          {p.firstName?.[0]}
                          {p.lastName?.[0]}
                        </div>
                        <div>
                          <p style={{ fontWeight: 600 }}>
                            {p.firstName} {p.lastName}
                          </p>
                          <span style={{ fontSize: '0.75rem', color: '#0284c7', fontFamily: 'monospace' }}>
                            {p.dossierNumber || 'DME-ARIJ'}
                          </span>
                        </div>
                      </div>
                    </td>
                    <td>
                      <code style={{ background: '#f1f5f9', padding: '0.2rem 0.4rem', borderRadius: '4px', fontSize: '0.85rem' }}>
                        {p.cin}
                      </code>
                    </td>
                    <td>
                      <span className="badge badge-rose">
                        <Droplet size={12} />
                        <span>{p.bloodType || 'Inconnu'}</span>
                      </span>
                    </td>
                    <td>
                      <p style={{ fontSize: '0.85rem' }}>{p.dateOfBirth}</p>
                      <span style={{ fontSize: '0.75rem', color: '#64748b' }}>{p.gender || 'Non spécifié'}</span>
                    </td>
                    <td>
                      <p style={{ fontSize: '0.85rem', display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                        <Phone size={13} color="#64748b" />
                        <span>{p.phone || '—'}</span>
                      </p>
                      <span style={{ fontSize: '0.75rem', color: '#64748b', display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                        <MapPin size={12} />
                        <span>{p.address || 'Djerba'}</span>
                      </span>
                    </td>
                    <td>
                      <span className="badge badge-emerald">Dossier Actif</span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        )}
      </div>

      {/* Modal Création Patient */}
      {isModalOpen && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <h3 style={{ fontSize: '1.15rem', fontWeight: 700, display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <UserPlus size={20} color="#059669" />
                <span>Créer un Dossier Patient</span>
              </h3>
              <button onClick={() => setIsModalOpen(false)} style={{ color: '#64748b' }}>
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleCreatePatient}>
              <div className="modal-body">
                {formError && (
                  <div style={{ background: '#fee2e2', color: '#991b1b', padding: '0.75rem', borderRadius: '8px', fontSize: '0.85rem' }}>
                    {formError}
                  </div>
                )}

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                  <div className="form-group">
                    <label className="form-label">Prénom *</label>
                    <input
                      type="text"
                      required
                      placeholder="Prénom"
                      className="form-control"
                      value={formData.firstName}
                      onChange={(e) => setFormData({ ...formData, firstName: e.target.value })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Nom de famille *</label>
                    <input
                      type="text"
                      required
                      placeholder="Nom"
                      className="form-control"
                      value={formData.lastName}
                      onChange={(e) => setFormData({ ...formData, lastName: e.target.value })}
                    />
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                  <div className="form-group">
                    <label className="form-label">Numéro CIN unique *</label>
                    <input
                      type="text"
                      required
                      placeholder="Ex: 08765432"
                      className="form-control"
                      value={formData.cin}
                      onChange={(e) => setFormData({ ...formData, cin: e.target.value })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Téléphone</label>
                    <input
                      type="tel"
                      placeholder="+216 98 123 456"
                      className="form-control"
                      value={formData.phone}
                      onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                    />
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '1rem' }}>
                  <div className="form-group">
                    <label className="form-label">Date de Naissance *</label>
                    <input
                      type="date"
                      required
                      className="form-control"
                      value={formData.dateOfBirth}
                      onChange={(e) => setFormData({ ...formData, dateOfBirth: e.target.value })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Sexe</label>
                    <select
                      className="form-control"
                      value={formData.gender}
                      onChange={(e) => setFormData({ ...formData, gender: e.target.value })}
                    >
                      <option value="Homme">Homme</option>
                      <option value="Femme">Femme</option>
                    </select>
                  </div>
                  <div className="form-group">
                    <label className="form-label">Groupe Sanguin</label>
                    <select
                      className="form-control"
                      value={formData.bloodType}
                      onChange={(e) => setFormData({ ...formData, bloodType: e.target.value })}
                    >
                      <option value="O+">O+</option>
                      <option value="O-">O-</option>
                      <option value="A+">A+</option>
                      <option value="A-">A-</option>
                      <option value="B+">B+</option>
                      <option value="B-">B-</option>
                      <option value="AB+">AB+</option>
                      <option value="AB-">AB-</option>
                    </select>
                  </div>
                </div>

                <div className="form-group">
                  <label className="form-label">Adresse / Localité</label>
                  <input
                    type="text"
                    placeholder="Midoun, Houmt Souk, Djerba..."
                    className="form-control"
                    value={formData.address}
                    onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                  />
                </div>
              </div>

              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setIsModalOpen(false)}>
                  Annuler
                </button>
                <button
                  type="submit"
                  disabled={formSubmitting}
                  className="btn btn-primary"
                  style={{ background: '#059669' }}
                >
                  {formSubmitting ? 'Enregistrement...' : 'Créer le dossier patient'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
