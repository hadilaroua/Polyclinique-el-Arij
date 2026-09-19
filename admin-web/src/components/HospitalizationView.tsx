import React, { useState, useEffect } from 'react';
import { BedDouble, Plus, CheckCircle2, AlertCircle, Wrench, X } from 'lucide-react';
import { api } from '../api';

export const HospitalizationView: React.FC = () => {
  const [rooms, setRooms] = useState<any[]>([]);
  const [beds, setBeds] = useState<any[]>([]);
  const [occupancy, setOccupancy] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  // Modals
  const [isRoomModalOpen, setIsRoomModalOpen] = useState(false);
  const [isBedModalOpen, setIsBedModalOpen] = useState(false);

  // Form states
  const [roomForm, setRoomForm] = useState({
    number: '',
    service: 'Médecine Interne',
    floor: 1,
    capacity: 2,
    roomType: 'STANDARD',
  });
  const [bedForm, setBedForm] = useState({
    number: '',
    roomId: '',
  });

  const fetchData = async () => {
    try {
      setLoading(true);
      const [roomsRes, bedsRes, occRes] = await Promise.all([
        api.get('/hospitalization/rooms'),
        api.get('/hospitalization/beds'),
        api.get('/hospitalization/stats/occupancy'),
      ]);
      setRooms(roomsRes.data);
      setBeds(bedsRes.data);
      setOccupancy(occRes.data);
      if (roomsRes.data.length > 0 && !bedForm.roomId) {
        setBedForm((prev) => ({ ...prev, roomId: roomsRes.data[0]._id }));
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const handleCreateRoom = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await api.post('/hospitalization/rooms', roomForm);
      setIsRoomModalOpen(false);
      setRoomForm({ number: '', service: 'Médecine Interne', floor: 1, capacity: 2, roomType: 'STANDARD' });
      fetchData();
    } catch (err: any) {
      alert(err.response?.data?.message || 'Erreur création chambre');
    }
  };

  const handleCreateBed = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await api.post('/hospitalization/beds', bedForm);
      setIsBedModalOpen(false);
      setBedForm({ number: '', roomId: rooms[0]?._id || '' });
      fetchData();
    } catch (err: any) {
      alert(err.response?.data?.message || 'Erreur création lit');
    }
  };

  const getBedStatusBadge = (status: string) => {
    switch (status) {
      case 'AVAILABLE':
        return (
          <span className="badge badge-emerald">
            <CheckCircle2 size={12} />
            <span>Disponible</span>
          </span>
        );
      case 'OCCUPIED':
        return (
          <span className="badge badge-rose">
            <AlertCircle size={12} />
            <span>Occupé</span>
          </span>
        );
      case 'MAINTENANCE':
        return (
          <span className="badge badge-amber">
            <Wrench size={12} />
            <span>Maintenance</span>
          </span>
        );
      default:
        return <span className="badge">{status}</span>;
    }
  };

  return (
    <div>
      {/* Top summary KPIs */}
      <div className="kpi-grid">
        <div className="kpi-card">
          <div>
            <p className="kpi-label">Capacité Totale</p>
            <p className="kpi-value">{occupancy?.totalBeds ?? beds.length}</p>
            <p className="kpi-subtext">{rooms.length} chambres enregistrées</p>
          </div>
          <div className="kpi-icon" style={{ background: '#e0f2fe', color: '#0284c7' }}>
            <BedDouble size={26} />
          </div>
        </div>

        <div className="kpi-card">
          <div>
            <p className="kpi-label">Lits Disponibles</p>
            <p className="kpi-value" style={{ color: '#059669' }}>
              {occupancy?.availableBeds ?? 0}
            </p>
            <p className="kpi-subtext">Prêts pour nouvelles admissions</p>
          </div>
          <div className="kpi-icon" style={{ background: '#d1fae5', color: '#059669' }}>
            <CheckCircle2 size={26} />
          </div>
        </div>

        <div className="kpi-card">
          <div>
            <p className="kpi-label">Lits Occupés</p>
            <p className="kpi-value" style={{ color: '#e11d48' }}>
              {occupancy?.occupiedBeds ?? 0}
            </p>
            <p className="kpi-subtext">Patients sous observation</p>
          </div>
          <div className="kpi-icon" style={{ background: '#ffe4e6', color: '#e11d48' }}>
            <AlertCircle size={26} />
          </div>
        </div>

        <div className="kpi-card">
          <div>
            <p className="kpi-label">Taux d'Occupation</p>
            <p className="kpi-value" style={{ color: '#d97706' }}>
              {occupancy?.occupancyRate ?? 0}%
            </p>
            <p className="kpi-subtext">Charge hospitalière globale</p>
          </div>
          <div className="kpi-icon" style={{ background: '#fef3c7', color: '#d97706' }}>
            <BedDouble size={26} />
          </div>
        </div>
      </div>

      {/* Action Bar */}
      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem', marginBottom: '1.5rem' }}>
        <button
          className="btn btn-outline"
          onClick={() => setIsRoomModalOpen(true)}
        >
          <Plus size={16} />
          <span>Ajouter une Chambre</span>
        </button>

        <button
          className="btn btn-primary"
          onClick={() => setIsBedModalOpen(true)}
        >
          <Plus size={16} />
          <span>Ajouter un Lit</span>
        </button>
      </div>

      {/* Grid des Chambres et Lits */}
      <div className="table-card" style={{ padding: '1.5rem' }}>
        <h3 style={{ fontSize: '1.1rem', fontWeight: 700, marginBottom: '1.25rem' }}>
          Plan d'Hospitalisation des Chambres & Lits
        </h3>

        {loading ? (
          <div style={{ textAlign: 'center', padding: '2rem', color: '#64748b' }}>Chargement...</div>
        ) : rooms.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '2rem', color: '#64748b' }}>
            Aucune chambre créée. Cliquez sur "Ajouter une Chambre".
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '1.25rem' }}>
            {rooms.map((room) => {
              const roomBeds = beds.filter((b) => (b.roomId?._id || b.roomId) === room._id);
              return (
                <div
                  key={room._id}
                  style={{
                    border: '1px solid #e2e8f0',
                    borderRadius: '12px',
                    padding: '1.25rem',
                    background: '#f8fafc',
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
                    <div>
                      <h4 style={{ fontSize: '1.1rem', fontWeight: 700 }}>Chambre {room.number}</h4>
                      <p style={{ fontSize: '0.75rem', color: '#64748b' }}>
                        {room.service} • Étage {room.floor}
                      </p>
                    </div>
                    <span className="badge badge-blue">{room.roomType || 'STANDARD'}</span>
                  </div>

                  {/* Lits de la chambre */}
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem', marginTop: '0.75rem' }}>
                    {roomBeds.length === 0 ? (
                      <p style={{ fontSize: '0.8rem', color: '#94a3b8', fontStyle: 'italic' }}>
                        Aucun lit dans cette chambre
                      </p>
                    ) : (
                      roomBeds.map((bed) => (
                        <div
                          key={bed._id}
                          style={{
                            display: 'flex',
                            justifyContent: 'space-between',
                            alignItems: 'center',
                            background: 'white',
                            padding: '0.6rem 0.85rem',
                            borderRadius: '8px',
                            border: '1px solid #e2e8f0',
                          }}
                        >
                          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                            <BedDouble size={16} color="#64748b" />
                            <span style={{ fontWeight: 600, fontSize: '0.85rem' }}>Lit {bed.number}</span>
                          </div>
                          {getBedStatusBadge(bed.status)}
                        </div>
                      ))
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Modal Ajout Chambre */}
      {isRoomModalOpen && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <h3 style={{ fontSize: '1.1rem', fontWeight: 700 }}>Ajouter une Chambre</h3>
              <button onClick={() => setIsRoomModalOpen(false)}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleCreateRoom}>
              <div className="modal-body">
                <div className="form-group">
                  <label className="form-label">Numéro de chambre *</label>
                  <input
                    type="text"
                    required
                    placeholder="Ex: 101, 102, 201..."
                    className="form-control"
                    value={roomForm.number}
                    onChange={(e) => setRoomForm({ ...roomForm, number: e.target.value })}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Service d'affectation *</label>
                  <input
                    type="text"
                    required
                    placeholder="Maternité, Chirurgie, Soins Intensifs..."
                    className="form-control"
                    value={roomForm.service}
                    onChange={(e) => setRoomForm({ ...roomForm, service: e.target.value })}
                  />
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                  <div className="form-group">
                    <label className="form-label">Étage</label>
                    <input
                      type="number"
                      className="form-control"
                      value={roomForm.floor}
                      onChange={(e) => setRoomForm({ ...roomForm, floor: Number(e.target.value) })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Capacité (Lits)</label>
                    <input
                      type="number"
                      className="form-control"
                      value={roomForm.capacity}
                      onChange={(e) => setRoomForm({ ...roomForm, capacity: Number(e.target.value) })}
                    />
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setIsRoomModalOpen(false)}>
                  Annuler
                </button>
                <button type="submit" className="btn btn-primary">
                  Créer la chambre
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Ajout Lit */}
      {isBedModalOpen && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <h3 style={{ fontSize: '1.1rem', fontWeight: 700 }}>Ajouter un Lit</h3>
              <button onClick={() => setIsBedModalOpen(false)}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleCreateBed}>
              <div className="modal-body">
                <div className="form-group">
                  <label className="form-label">Chambre de rattachement *</label>
                  <select
                    className="form-control"
                    value={bedForm.roomId}
                    onChange={(e) => setBedForm({ ...bedForm, roomId: e.target.value })}
                  >
                    {rooms.map((r) => (
                      <option key={r._id} value={r._id}>
                        Chambre {r.number} ({r.service})
                      </option>
                    ))}
                  </select>
                </div>
                <div className="form-group">
                  <label className="form-label">Identifiant du Lit *</label>
                  <input
                    type="text"
                    required
                    placeholder="Ex: A, B, 101-A, 101-B..."
                    className="form-control"
                    value={bedForm.number}
                    onChange={(e) => setBedForm({ ...bedForm, number: e.target.value })}
                  />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setIsBedModalOpen(false)}>
                  Annuler
                </button>
                <button type="submit" className="btn btn-primary">
                  Créer le lit
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
