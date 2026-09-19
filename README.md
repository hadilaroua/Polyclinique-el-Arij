# 🏥 Polyclinique El Arij - Plateforme de Gestion Médicale

Bienvenue sur le dépôt principal de la plateforme **Polyclinique El Arij**. Ce projet regroupe les différentes composantes technologiques de l'application médicale.

---

## 📐 Architecture du Projet

Le dépôt est structuré selon les sous-dossiers et branches suivantes :

| Composante | Dossier | Branche Git | Description | Technos |
| :--- | :--- | :--- | :--- | :--- |
| **Main (Monorepo)** | `/` | `main` | Code source complet de l'application | Multi |
| **Backend API** | `/backend` | `backend` | API REST & services de la clinique | NestJS, TypeORM, TypeScript |
| **Application Mobile** | `/frontend` | `frontend` | Application mobile pour les patients & staff | Flutter, Dart |
| **Dashboard Admin** | `/admin-web` | `dashbord` | Interface web d'administration de la clinique | React, Vite, TypeScript, Tailwind |

---

## 🚀 Démarrage Rapide

### 1. Backend API (`/backend`)
```bash
cd backend
npm install
npm run start:dev
```

### 2. Application Mobile Frontend (`/frontend`)
```bash
cd frontend
flutter pub get
flutter run
```

### 3. Dashboard Web Admin (`/admin-web`)
```bash
cd admin-web
npm install
npm run dev
```

---

## 🌟 Fonctionnalités Réalisées

- 🔐 **Authentification & Gestion des Rôles**
- 📋 **Gestion des Dossiers Médicaux & QR Code Patient**
- 📅 **Prise et suivi des Rendez-vous**
- 🏥 **Gestion des Services Médicaux de la clinique**
- 🤖 **Assistant Virtuel Arij (IA / Chatbot)**
- 📊 **Tableau de Bord Administratif complet**
