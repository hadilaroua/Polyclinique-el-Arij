# 🏥 El ArijFlow — Smart Healthcare Management Platform

**Empowering Healthcare Through Mobile Technology, Artificial Intelligence, and Intelligent Digital Solutions.**

El ArijFlow is a smart healthcare management platform developed during a **two-month summer internship at Polyclinique El Arij, Djerba, Tunisia**.

The project aims to streamline clinical workflows, improve medical information management, and empower healthcare professionals through an integrated digital ecosystem combining a mobile application, a web administration dashboard, and AI-powered capabilities.

---

## 📸 Project Overview

El ArijFlow brings together three interconnected components:

- 📱 **Mobile Application:** A dedicated workspace for healthcare professionals to access and manage medical information.
- 💻 **Admin Web Dashboard:** A centralized interface for managing users, roles, and administrative operations.
- ⚙️ **Backend API:** A RESTful backend responsible for business logic, authentication, data management, and communication between the applications.

---

## 🏗️ System Architecture

The repository is organized into the following components:

| Component | Directory | Git Branch | Technologies |
|---|---|---|---|
| Main Repository | `/` | `main` | Multi-stack |
| Backend API | `/backend` | `backend` | NestJS, TypeScript, MongoDB, Mongoose |
| Mobile Application | `/frontend` | `frontend` | Flutter, Dart |
| Admin Dashboard | `/admin-web` | `dashbord` | React, Vite, TypeScript, Tailwind CSS |

---

## ✨ Key Features

### 📱 1. Intelligent Mobile Application

Designed to support healthcare professionals in their daily clinical activities.

- **Dossier 360°:** Centralized access to structured patient medical records.
- **Voice AI Assistant:** Voice-based interaction and intelligent assistance to make information access more intuitive.
- **Smart Monitoring:** Interactive visualization of patient temperature and SpO₂ measurements.
- **Role-Based Access Control (RBAC):** Dedicated access and permissions for different healthcare professionals.
- **Medical Information Management:** Structured access to relevant patient information.

### 🤖 2. AI-Powered Capabilities

Artificial intelligence is integrated to explore smarter healthcare workflows.

- **Gemini AI Integration:** AI-powered assistance and intelligent interactions.
- **Voice AI Assistant:** Conversational interaction designed to simplify access to information.
- **Intelligent Medical Assistance:** Support for working with structured medical information.

### 💻 3. Web Administration Dashboard

A centralized administrative interface providing:

- User management and administration.
- Role and permission management.
- Secure access governance.
- Activity tracking and audit capabilities.
- Centralized administration of the platform.

### 🔐 4. Security & Backend Infrastructure

- JWT-based authentication.
- Role-Based Access Control (RBAC).
- Protected API endpoints.
- RESTful API architecture.
- Data persistence using MongoDB and Mongoose.
- API documentation with Swagger.
- Activity logging and audit capabilities.

---

## 🛠️ Technology Stack

| Category | Technologies |
|---|---|
| Mobile Development | Flutter, Dart |
| Frontend Web | React, Vite, TypeScript |
| Backend Development | NestJS, TypeScript |
| Database | MongoDB, Mongoose |
| Authentication | JWT |
| API Architecture | REST API |
| API Documentation | Swagger |
| Artificial Intelligence | Google Gemini AI |
| Styling | Tailwind CSS |
| Version Control | Git, GitHub |

---

## 🚀 Getting Started

### Prerequisites

Make sure you have the following installed:

- Node.js and npm
- Flutter SDK
- Dart SDK
- MongoDB
- Git

### 1. Clone the Repository

```bash
git clone <YOUR_REPOSITORY_URL>
cd <YOUR_PROJECT_DIRECTORY>
```

### 2. Backend API

```bash
cd backend
npm install
npm run start:dev
```

Configure the required environment variables in your backend `.env` file, including database connection and authentication settings.

### 3. Mobile Application

```bash
cd frontend
flutter pub get
flutter run
```

### 4. Admin Web Dashboard

```bash
cd admin-web
npm install
npm run dev
```

---

## 👥 User Roles

The platform implements role-based access for different healthcare professionals:

- 👨‍⚕️ Doctor
- 👩‍⚕️ Nurse
- 🤱 Midwife
- 🧑‍🔬 Technician
- 🛡️ Administrator

Each role benefits from access permissions adapted to its responsibilities.

---

## 🎯 Project Objectives

El ArijFlow explores how modern software engineering and AI technologies can contribute to:

- Digitalizing healthcare workflows.
- Centralizing patient information.
- Improving access to medical data.
- Supporting healthcare professionals through intelligent assistance.
- Strengthening security and access governance.
- Providing a connected mobile and web ecosystem.

---

## 👩‍💻 Development Experience

Developed as part of a **two-month summer internship at Polyclinique El Arij, Djerba, Tunisia**.

This project provided hands-on experience in:

- Mobile application development.
- Full-Stack software engineering.
- REST API design and integration.
- Database modeling and management.
- Authentication and authorization.
- Artificial Intelligence integration.
- Healthcare-oriented software solutions.

---

## ⚠️ Disclaimer

El ArijFlow is an academic and internship development project. Its monitoring visualizations are intended for informational purposes and are not a substitute for professional medical judgment or clinical diagnosis.

No real patient medical data should be exposed through this repository.

---

**El ArijFlow — Building a Smarter, More Connected Healthcare Experience.** 💙

