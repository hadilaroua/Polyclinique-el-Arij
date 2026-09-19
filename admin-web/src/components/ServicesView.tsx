import React, { useState, useEffect } from 'react';
import { Building2, Stethoscope, Plus, CheckCircle2, X } from 'lucide-react';
import { api } from '../api';

export const ServicesView: React.FC = () => {
  const [services, setServices] = useState<any[]>([]);
  const [specialties, setSpecialties] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  // Modal Service
  const [isServiceModalOpen, setIsServiceModalOpen] = useState(false);
  const [serviceName, setServiceName] = useState('');
  const [serviceDescription, setServiceDescription] = useState('');

  const fetchData = async () => {
    try {
      setLoading(true);
      const [srvRes, spcRes] = await Promise.all([
        api.get('/services'),
        api.get('/specialties'),
      ]);
      setServices(srvRes.data);
      setSpecialties(spcRes.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const handleCreateService = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await api.post('/services', { name: serviceName, description: serviceDescription });
      setIsServiceModalOpen(false);
      setServiceName('');
      setServiceDescription('');
      fetchData();
    } catch (err: any) {
      alert(err.response?.data?.message || 'Erreur création service');
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
      {/* Services de la clinique */}
      <div className="table-card">
        <div className="table-header-bar">
          <div className="table-title-group">
            <h3>Départements & Services de la Clinique</h3>
            <p>Organisation des pôles d'activité (Urgences, Maternité, Bloc, Imagerie, etc.)</p>
          </div>

          <button
            className="btn btn-primary"
            onClick={() => setIsServiceModalOpen(true)}
          >
            <Plus size={16} />
            <span>Nouveau Service</span>
          </button>
        </div>

        {loading ? (
          <div style={{ padding: '2rem', textAlign: 'center', color: '#64748b' }}>Chargement...</div>
        ) : (
          <div style={{ padding: '1.5rem', display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: '1rem' }}>
            {services.map((s) => (
              <div
                key={s._id}
                style={{
                  border: '1px solid #e2e8f0',
                  borderRadius: '10px',
                  padding: '1.25rem',
                  background: '#f8fafc',
                  display: 'flex',
                  alignItems: 'flex-start',
                  gap: '0.75rem',
                }}
              >
                <div style={{ padding: '0.5rem', background: '#e0f2fe', color: '#0284c7', borderRadius: '8px' }}>
                  <Building2 size={20} />
                </div>
                <div>
                  <h4 style={{ fontSize: '1rem', fontWeight: 700 }}>{s.name}</h4>
                  <p style={{ fontSize: '0.8rem', color: '#64748b', marginTop: '0.25rem' }}>
                    {s.description || 'Service opérationnel à la Polyclinique Arij'}
                  </p>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Spécialités Médicales */}
      <div className="table-card">
        <div className="table-header-bar">
          <div className="table-title-group">
            <h3>Spécialités Médicales & Chirurgicales</h3>
            <p>{specialties.length} spécialités accréditées</p>
          </div>
        </div>

        <div style={{ padding: '1.5rem', display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
          {specialties.map((sp) => (
            <span
              key={sp._id}
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.35rem',
                padding: '0.4rem 0.85rem',
                background: '#f1f5f9',
                borderRadius: '8px',
                fontSize: '0.85rem',
                fontWeight: 600,
                color: '#334155',
                border: '1px solid #cbd5e1',
              }}
            >
              <Stethoscope size={14} color="#0284c7" />
              <span>{sp.name}</span>
            </span>
          ))}
        </div>
      </div>

      {/* Modal Ajout Service */}
      {isServiceModalOpen && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <h3 style={{ fontSize: '1.1rem', fontWeight: 700 }}>Ajouter un Département / Service</h3>
              <button onClick={() => setIsServiceModalOpen(false)}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleCreateService}>
              <div className="modal-body">
                <div className="form-group">
                  <label className="form-label">Nom du Service *</label>
                  <input
                    type="text"
                    required
                    placeholder="Ex: Soins Intensifs, Cardiologie..."
                    className="form-control"
                    value={serviceName}
                    onChange={(e) => setServiceName(e.target.value)}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Description / Rôle</label>
                  <input
                    type="text"
                    placeholder="Courte description de l'activité"
                    className="form-control"
                    value={serviceDescription}
                    onChange={(e) => setServiceDescription(e.target.value)}
                  />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setIsServiceModalOpen(false)}>
                  Annuler
                </button>
                <button type="submit" className="btn btn-primary">
                  Créer le service
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
