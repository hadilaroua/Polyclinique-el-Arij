import React, { useState, useEffect } from 'react';
import { Plus, UserPlus, Search, Shield, Stethoscope, HeartPulse, Baby, Microscope, X } from 'lucide-react';
import { api } from '../api';

export const StaffView: React.FC = () => {
  const [users, setUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterRole, setFilterRole] = useState<string>('ALL');
  const [searchTerm, setSearchTerm] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);

  // Formulaire d'ajout de personnel
  const [formData, setFormData] = useState({
    firstName: '',
    lastName: '',
    email: '',
    password: '',
    cin: '',
    phone: '',
    role: 'DOCTOR',
    service: 'Consultations Externes',
    specialty: 'Médecine Générale',
    shift: 'Matin (07h-15h)',
    licenseNumber: '',
    avatarUrl: '',
  });
  const [formError, setFormError] = useState<string | null>(null);
  const [formSubmitting, setFormSubmitting] = useState(false);

  const fetchStaff = async () => {
    try {
      setLoading(true);
      const res = await api.get('/users');
      // Filtrer pour ne garder que le personnel
      setUsers(res.data.filter((u: any) => u.role !== 'PATIENT'));
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStaff();
  }, []);

  const handleCreateStaff = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);
    setFormSubmitting(true);

    try {
      await api.post('/auth/create-staff-account', formData);
      setIsModalOpen(false);
      // Reset form
      setFormData({
        firstName: '',
        lastName: '',
        email: '',
        password: '',
        cin: '',
        phone: '',
        role: 'DOCTOR',
        service: 'Consultations Externes',
        specialty: 'Médecine Générale',
        shift: 'Matin (07h-15h)',
        licenseNumber: '',
        avatarUrl: '',
      });
      fetchStaff();
    } catch (err: any) {
      setFormError(
        err.response?.data?.message || 'Erreur lors de la création du compte personnel',
      );
    } finally {
      setFormSubmitting(false);
    }
  };

  const filteredUsers = users.filter((u) => {
    const matchesRole = filterRole === 'ALL' || u.role === filterRole;
    const matchesSearch =
      `${u.firstName} ${u.lastName}`.toLowerCase().includes(searchTerm.toLowerCase()) ||
      u.cin?.includes(searchTerm) ||
      u.email?.toLowerCase().includes(searchTerm.toLowerCase());
    return matchesRole && matchesSearch;
  });

  const getRoleBadge = (role: string) => {
    switch (role) {
      case 'ADMIN':
        return <span className="badge badge-rose">Directeur / Admin</span>;
      case 'DOCTOR':
        return <span className="badge badge-blue">Médecin</span>;
      case 'NURSE':
        return <span className="badge badge-emerald">Infirmier</span>;
      case 'MIDWIFE':
        return <span className="badge badge-purple">Sage-femme</span>;
      case 'TECHNICIAN':
        return <span className="badge badge-amber">Technicien</span>;
      default:
        return <span className="badge">{role}</span>;
    }
  };

  return (
    <div>
      <div className="table-card">
        <div className="table-header-bar">
          <div className="table-title-group">
            <h3>Personnel de la Polyclinique Arij</h3>
            <p>{filteredUsers.length} membres répertoriés</p>
          </div>

          <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center' }}>
            <div style={{ position: 'relative' }}>
              <Search
                size={16}
                style={{ position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }}
              />
              <input
                type="text"
                placeholder="Rechercher nom, CIN, email..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="form-control"
                style={{ paddingLeft: '32px', width: '240px' }}
              />
            </div>

            <button
              className="btn btn-primary"
              onClick={() => setIsModalOpen(true)}
              style={{ background: 'linear-gradient(135deg, #0284c7, #0ea5e9)' }}
            >
              <UserPlus size={16} />
              <span>Inscrire un Soignant</span>
            </button>
          </div>
        </div>

        {/* Filtres par Rôles */}
        <div style={{ padding: '0.75rem 1.5rem', background: '#f8fafc', borderBottom: '1px solid #e2e8f0', display: 'flex', gap: '0.5rem', overflowX: 'auto' }}>
          {[
            { id: 'ALL', label: 'Tous les membres' },
            { id: 'DOCTOR', label: 'Médecins' },
            { id: 'NURSE', label: 'Infirmiers' },
            { id: 'MIDWIFE', label: 'Sages-femmes' },
            { id: 'TECHNICIAN', label: 'Techniciens' },
            { id: 'ADMIN', label: 'Administration' },
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setFilterRole(tab.id)}
              className="btn"
              style={{
                padding: '0.4rem 0.85rem',
                fontSize: '0.8rem',
                background: filterRole === tab.id ? '#0284c7' : 'white',
                color: filterRole === tab.id ? 'white' : '#475569',
                border: '1px solid #cbd5e1',
                boxShadow: filterRole === tab.id ? '0 2px 6px rgba(2,132,199,0.3)' : 'none',
              }}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {loading ? (
          <div style={{ padding: '3rem', textAlign: 'center', color: '#64748b' }}>Chargement de l'équipe...</div>
        ) : (
          <table className="custom-table">
            <thead>
              <tr>
                <th>Membre du personnel</th>
                <th>Rôle</th>
                <th>CIN</th>
                <th>Contact</th>
                <th>Statut</th>
              </tr>
            </thead>
            <tbody>
              {filteredUsers.length === 0 ? (
                <tr>
                  <td colSpan={5} style={{ textAlign: 'center', padding: '2rem', color: '#64748b' }}>
                    Aucun membre trouvé pour ce critère.
                  </td>
                </tr>
              ) : (
                filteredUsers.map((u) => (
                  <tr key={u._id}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                        <div
                          style={{
                            width: 42,
                            height: 42,
                            borderRadius: '50%',
                            background: '#e0f2fe',
                            color: '#0284c7',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            fontWeight: 700,
                            overflow: 'hidden',
                            border: '2px solid #bae6fd',
                            flexShrink: 0,
                            boxShadow: '0 2px 5px rgba(0,0,0,0.06)',
                          }}
                        >
                          {u.avatarUrl ? (
                            <img
                              src={u.avatarUrl}
                              alt={`${u.firstName} ${u.lastName}`}
                              style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                              onError={(e) => {
                                (e.target as HTMLElement).style.display = 'none';
                              }}
                            />
                          ) : (
                            <span>
                              {u.firstName?.[0] || '?'}{u.lastName?.[0] || ''}
                            </span>
                          )}
                        </div>
                        <div>
                          <p style={{ fontWeight: 600, color: '#0f172a' }}>
                            {u.firstName} {u.lastName}
                          </p>
                          <span style={{ fontSize: '0.75rem', color: '#64748b' }}>{u.email}</span>
                        </div>
                      </div>
                    </td>
                    <td>{getRoleBadge(u.role)}</td>
                    <td>
                      <code style={{ background: '#f1f5f9', padding: '0.2rem 0.4rem', borderRadius: '4px', fontSize: '0.85rem' }}>
                        {u.cin}
                      </code>
                    </td>
                    <td>{u.phone || '—'}</td>
                    <td>
                      <span
                        className="badge"
                        style={{
                          background: u.isActive !== false ? '#d1fae5' : '#fee2e2',
                          color: u.isActive !== false ? '#065f46' : '#991b1b',
                        }}
                      >
                        {u.isActive !== false ? 'Actif' : 'Désactivé'}
                      </span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        )}
      </div>

      {/* Modal Inscription Personnel */}
      {isModalOpen && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <h3 style={{ fontSize: '1.15rem', fontWeight: 700, display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <UserPlus size={20} color="#0284c7" />
                <span>Inscrire un Membre du Personnel</span>
              </h3>
              <button onClick={() => setIsModalOpen(false)} style={{ color: '#64748b' }}>
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleCreateStaff}>
              <div className="modal-body">
                {formError && (
                  <div style={{ background: '#fee2e2', color: '#991b1b', padding: '0.75rem', borderRadius: '8px', fontSize: '0.85rem' }}>
                    {formError}
                  </div>
                )}

                <div className="form-group">
                  <label className="form-label">Rôle Professionnel *</label>
                  <select
                    className="form-control"
                    value={formData.role}
                    onChange={(e) => setFormData({ ...formData, role: e.target.value })}
                  >
                    <option value="DOCTOR">🩺 Médecin Spécialiste</option>
                    <option value="NURSE">💉 Infirmier / Soignant</option>
                    <option value="MIDWIFE">🌸 Sage-femme (Maternité)</option>
                    <option value="TECHNICIAN">🔬 Technicien (Labo / Radiologie)</option>
                    <option value="ADMIN">🛡️ Administrateur</option>
                  </select>
                </div>

                {/* Photo de profil / Avatar */}
                <div className="form-group" style={{ background: '#f8fafc', padding: '0.85rem', borderRadius: '10px', border: '1px solid #e2e8f0' }}>
                  <label className="form-label" style={{ marginBottom: '0.5rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                    <span>Photo de Profil / Avatar</span>
                    <span style={{ fontSize: '0.75rem', color: '#64748b' }}>(visible sur mobile et admin)</span>
                  </label>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', marginBottom: '0.6rem' }}>
                    <div
                      style={{
                        width: 52,
                        height: 52,
                        borderRadius: '50%',
                        background: '#e0f2fe',
                        border: '2px solid #0284c7',
                        overflow: 'hidden',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        flexShrink: 0,
                      }}
                    >
                      {formData.avatarUrl ? (
                        <img src={formData.avatarUrl} alt="Aperçu" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                      ) : (
                        <span style={{ color: '#0284c7', fontWeight: 700, fontSize: '1.2rem' }}>
                          {formData.firstName?.[0] || '📸'}
                        </span>
                      )}
                    </div>
                    <div style={{ flex: 1 }}>
                      <input
                        type="url"
                        placeholder="https://... ou choisir ci-dessous"
                        className="form-control"
                        value={formData.avatarUrl}
                        onChange={(e) => setFormData({ ...formData, avatarUrl: e.target.value })}
                        style={{ fontSize: '0.85rem' }}
                      />
                    </div>
                  </div>

                  {/* Avatars prédéfinis rapides */}
                  <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', alignItems: 'center' }}>
                    <span style={{ fontSize: '0.75rem', color: '#64748b' }}>Suggestions rapides :</span>
                    {[
                      { label: 'Dr. Homme', url: 'https://images.unsplash.com/photo-1622253692010-333f2da6031d?w=150' },
                      { label: 'Dr. Femme', url: 'https://images.unsplash.com/photo-1594824813587-5788e0b1c099?w=150' },
                      { label: 'Infirmière', url: 'https://images.unsplash.com/photo-1579684385127-1ef15d508118?w=150' },
                      { label: 'Technicien', url: 'https://images.unsplash.com/photo-1537368910025-700350fe46c7?w=150' },
                    ].map((preset, idx) => (
                      <button
                        key={idx}
                        type="button"
                        onClick={() => setFormData({ ...formData, avatarUrl: preset.url })}
                        style={{
                          background: formData.avatarUrl === preset.url ? '#0284c7' : 'white',
                          color: formData.avatarUrl === preset.url ? 'white' : '#0369a1',
                          border: '1px solid #bae6fd',
                          borderRadius: '6px',
                          padding: '0.2rem 0.5rem',
                          fontSize: '0.75rem',
                          cursor: 'pointer',
                        }}
                      >
                        {preset.label}
                      </button>
                    ))}
                    {formData.avatarUrl && (
                      <button
                        type="button"
                        onClick={() => setFormData({ ...formData, avatarUrl: '' })}
                        style={{
                          background: '#fee2e2',
                          color: '#991b1b',
                          border: 'none',
                          borderRadius: '6px',
                          padding: '0.2rem 0.5rem',
                          fontSize: '0.75rem',
                          cursor: 'pointer',
                        }}
                      >
                        Effacer
                      </button>
                    )}
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                  <div className="form-group">
                    <label className="form-label">Prénom *</label>
                    <input
                      type="text"
                      required
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
                      className="form-control"
                      value={formData.lastName}
                      onChange={(e) => setFormData({ ...formData, lastName: e.target.value })}
                    />
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                  <div className="form-group">
                    <label className="form-label">Numéro CIN *</label>
                    <input
                      type="text"
                      required
                      placeholder="Ex: 08123456"
                      className="form-control"
                      value={formData.cin}
                      onChange={(e) => setFormData({ ...formData, cin: e.target.value })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Téléphone</label>
                    <input
                      type="tel"
                      placeholder="+216 20 123 456"
                      className="form-control"
                      value={formData.phone}
                      onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                    />
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                  <div className="form-group">
                    <label className="form-label">Email professionnel *</label>
                    <input
                      type="email"
                      required
                      placeholder="dr.nom@arij.tn"
                      className="form-control"
                      value={formData.email}
                      onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Mot de passe temporaire *</label>
                    <input
                      type="password"
                      required
                      placeholder="••••••••"
                      className="form-control"
                      value={formData.password}
                      onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                    />
                  </div>
                </div>

                {/* Spécifique Médecin */}
                {formData.role === 'DOCTOR' && (
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                    <div className="form-group">
                      <label className="form-label">Spécialité Médicale *</label>
                      <input
                        type="text"
                        placeholder="Ex: Cardiologie, Pédiatrie"
                        className="form-control"
                        value={formData.specialty}
                        onChange={(e) => setFormData({ ...formData, specialty: e.target.value })}
                      />
                    </div>
                    <div className="form-group">
                      <label className="form-label">N° Ordre des Médecins</label>
                      <input
                        type="text"
                        placeholder="TN-MED-12345"
                        className="form-control"
                        value={formData.licenseNumber}
                        onChange={(e) => setFormData({ ...formData, licenseNumber: e.target.value })}
                      />
                    </div>
                  </div>
                )}

                {/* Spécifique Technicien */}
                {formData.role === 'TECHNICIAN' && (
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                    <div className="form-group">
                      <label className="form-label">Département Technique</label>
                      <input
                        type="text"
                        placeholder="Radiologie, Scanner, Laboratoire"
                        className="form-control"
                        value={formData.service}
                        onChange={(e) => setFormData({ ...formData, service: e.target.value })}
                      />
                    </div>
                    <div className="form-group">
                      <label className="form-label">Spécialité Technique</label>
                      <input
                        type="text"
                        placeholder="Scanner & IRM, Biologie..."
                        className="form-control"
                        value={formData.specialty}
                        onChange={(e) => setFormData({ ...formData, specialty: e.target.value })}
                      />
                    </div>
                  </div>
                )}
              </div>

              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setIsModalOpen(false)}>
                  Annuler
                </button>
                <button type="submit" disabled={formSubmitting} className="btn btn-primary">
                  {formSubmitting ? 'Création...' : 'Créer le compte staff'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
