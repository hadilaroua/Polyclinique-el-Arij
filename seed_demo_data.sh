#!/bin/bash

TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"dr.karima@arij.tn","password":"Doctor123!"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('accessToken',''))")

DOC_ID="6ab98dd8524b89106a48fd28"

echo "Token obtained, creating consultations..."

# Patient IDs
PAT_IDS=(
  "6ac9a16e5fcae271d1a7ff03"
  "6ac9a17f5fcae271d1a7ff04"
  "6ac9a17f5fcae271d1a7ff05"
  "6ac9a17f5fcae271d1a7ff06"
  "6ac9a17f5fcae271d1a7ff07"
  "6ac9a17f5fcae271d1a7ff08"
)

declare -a MOTIVES
MOTIVES[0]="Douleurs thoraciques récurrentes"
MOTIVES[1]="Suivi grossesse - 3ème trimestre"
MOTIVES[2]="Insuffisance rénale - contrôle bilan"
MOTIVES[3]="Bilan préopératoire"
MOTIVES[4]="Hypertension - contrôle tensionnel"
MOTIVES[5]="Consultation de routine"

declare -a DIAGS
DIAGS[0]="ECG normal, pas d'anomalie significative. Surveillance cardio recommandée."
DIAGS[1]="Grossesse évolutive sans complication. Préparation accouchement en cours."
DIAGS[2]="Créatinémie stable. Dialyse non nécessaire pour l'instant."
DIAGS[3]="Bilan préopératoire favorable. Chirurgie autorisée sous surveillance."
DIAGS[4]="Tension équilibrée sous traitement. Amlodipine 5mg maintenu."
DIAGS[5]="Bonne santé générale. Pas de pathologie identifiée. RAS."

for i in 0 1 2 3 4 5; do
  PAT_ID="${PAT_IDS[$i]}"
  MOTIVE="${MOTIVES[$i]}"
  DIAG="${DIAGS[$i]}"
  
  RESULT=$(curl -s -X POST "http://localhost:3000/api/consultations" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"patientId\": \"$PAT_ID\", \"doctorId\": \"$DOC_ID\", \"date\": \"2026-10-10\", \"motive\": \"$MOTIVE\", \"diagnostic\": \"$DIAG\", \"clinicalExam\": \"Examen clinique normal. Patient coopérant.\", \"observations\": \"Surveillance continue recommandée.\"}")
  
  ID=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('_id','ERR'))" 2>/dev/null)
  echo "Consultation $i created: $ID"
done

echo "Creating exams..."

ADMIN_TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@arij.tn","password":"Admin123!"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('accessToken',''))")

# Get technician ID
TECH_ID=$(curl -s "http://localhost:3000/api/technicians" -H "Authorization: Bearer $TOKEN" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['userId']['_id'] if d and isinstance(d[0].get('userId'),dict) else d[0]['userId'] if d else '')" 2>/dev/null)
echo "Technician ID: $TECH_ID"

for PAT_ID in "${PAT_IDS[@]}"; do
  RESULT=$(curl -s -X POST "http://localhost:3000/api/exams" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"patientId\": \"$PAT_ID\", \"requestingDoctorId\": \"$DOC_ID\", \"examType\": \"Bilan sanguin complet\", \"priority\": \"MEDIUM\", \"service\": \"Laboratoire\", \"requestNotes\": \"NFS, ionogramme, bilan hépatique, bilan rénal\"}")
  
  ID=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('_id','ERR'))" 2>/dev/null)
  echo "Exam created: $ID"
done

echo "All done!"
