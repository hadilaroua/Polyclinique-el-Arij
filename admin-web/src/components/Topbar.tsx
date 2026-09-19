import React, { useState } from 'react';
import { Sparkles, RefreshCw, CheckCircle2, AlertCircle } from 'lucide-react';
import { api } from '../api';

interface TopbarProps {
  title: string;
  onRefresh: () => void;
}

export const Topbar: React.FC<TopbarProps> = ({ title, onRefresh }) => {
  const [seeding, setSeeding] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  const handleSeed = async () => {
    try {
      setSeeding(true);
      setMessage(null);
      const res = await api.post('/database/seed');
      setMessage('Données de démo initialisées avec succès !');
      onRefresh();
      setTimeout(() => setMessage(null), 4000);
    } catch (err: any) {
      setMessage('Erreur lors de l\'initialisation des données');
      setTimeout(() => setMessage(null), 4000);
    } finally {
      setSeeding(false);
    }
  };

  return (
    <header className="topbar">
      <div className="topbar-left">
        <h2 className="page-title">{title}</h2>
      </div>

      <div className="topbar-right">
        {message && (
          <div className="badge badge-emerald" style={{ padding: '0.4rem 0.85rem' }}>
            <CheckCircle2 size={15} />
            <span>{message}</span>
          </div>
        )}

        <button
          onClick={handleSeed}
          disabled={seeding}
          className="btn btn-primary"
          style={{
            background: 'linear-gradient(135deg, #0284c7, #0369a1)',
            gap: '0.4rem',
            padding: '0.5rem 1rem',
          }}
          title="Initialise ou met à jour les comptes de test (Médecins, Infirmiers, Sages-femmes, Techniciens, etc.)"
        >
          <Sparkles size={16} />
          <span>{seeding ? 'Initialisation...' : 'Générer Démo Seed'}</span>
        </button>

        <button
          onClick={onRefresh}
          className="btn btn-secondary"
          style={{ padding: '0.5rem 0.75rem' }}
          title="Actualiser les données"
        >
          <RefreshCw size={16} />
        </button>

        <div
          className="badge badge-emerald"
          style={{
            background: '#ecfdf5',
            color: '#065f46',
            border: '1px solid #a7f3d0',
            padding: '0.4rem 0.75rem',
          }}
        >
          <span
            style={{
              width: 8,
              height: 8,
              borderRadius: '50%',
              backgroundColor: '#10b981',
              display: 'inline-block',
            }}
          />
          <span>API 3000 En ligne</span>
        </div>
      </div>
    </header>
  );
};
