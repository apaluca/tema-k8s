# Site Web cu Chat și IA peste Kubernetes

## Descriere

Acest proiect implementează un site web complet ce integrează un CMS Drupal, un sistem de chat în timp real bazat pe WebSocket și o aplicație de procesare a imaginilor folosind Azure OCR. Întreaga infrastructură este gestionată de Kubernetes și respectă toate cerințele specificate în `Tema.md`.

## Tehnologii utilizate

- **CMS**: Drupal 10.0 cu MariaDB 10.6
- **Chat backend**: Node.js 18 + Nginx cu Express, WebSocket, Mongoose
- **Chat frontend**: Vue.js 3
- **Bază de date pentru chat**: MongoDB 6.0
- **AI backend**: Node.js 18 cu Express, Azure SDK
- **AI frontend**: Vue.js 3 cu integrare Azure Storage și Azure OCR
- **Cloud Services**: Azure Blob Storage, Azure Computer Vision OCR, Azure SQL Database
- **Containerizare**: Docker cu multi-stage builds
- **Orchestrare**: Kubernetes (MicroK8s)

## Cerințe de instalare

### Dependențe

- MicroK8s instalat și configurat
- Docker
- kubectl
- Node.js 18.x (pentru dezvoltare locală)
- Cont Azure cu serviciile: Storage Account, Computer Vision, SQL Database

### Addon-uri MicroK8s necesare

```bash
microk8s enable registry dns storage
```

## Configurarea serviciilor Azure

### 1. Azure Storage Account
- Creează un Storage Account
- Creează un container numit "images"
- Obține connection string-ul

### 2. Azure Computer Vision
- Creează o resursă Computer Vision
- Obține endpoint-ul și API key-ul

### 3. Azure SQL Database
- Creează un SQL Server și o bază de date
- Configurează SQL Authentication
- Obține connection string-ul

### 4. Configurarea secretelor

Actualizează `secrets/azure-secrets.yaml` cu valorile reale codificate în base64:

```bash
# Codifică valorile în base64
echo -n "your_storage_connection_string" | base64
echo -n "your_ocr_api_key" | base64
echo -n "your_sql_connection_string" | base64
```

## Implementare

### 1. Construirea imaginilor Docker

```bash
# Chat Backend (Node.js + Nginx)
docker build -t localhost:32000/chat-backend:latest ./chat/backend
docker push localhost:32000/chat-backend:latest

# Chat Frontend (Vue.js)
docker build -t localhost:32000/chat-frontend:latest ./chat/frontend
docker push localhost:32000/chat-frontend:latest

# AI Backend (Node.js cu Azure integration)
docker build -t localhost:32000/ai-backend:latest ./ai/backend
docker push localhost:32000/ai-backend:latest

# AI Frontend (Vue.js)
docker build -t localhost:32000/ai-frontend:latest ./ai/frontend
docker push localhost:32000/ai-frontend:latest
```

### 2. Aplicarea configurațiilor Kubernetes

```bash
# Aplicare folosind kustomize (recomandat)
kubectl apply -k .

# Verificarea deployment-urilor
kubectl get pods
kubectl get services
```

## Componente

### 1. Drupal CMS

- **Replici**: 6 (conform cerințelor)
- **Port**: 80 (NodePort: 30080)
- **Bază de date**: MariaDB
- **Persistență**: Volume persistent pentru site și baza de date
- **Init Container**: Configurează automat fișierele necesare

### 2. Sistemul de Chat

#### Backend
- **Replici**: 5 (conform cerințelor)
- **Port**: 88 (NodePort: 30088)
- **Tehnologie**: Node.js + Nginx (conform cerințelor)
- **Funcționalități**: WebSocket pentru comunicare în timp real, salvare mesaje în MongoDB
- **API**: REST endpoints pentru istoricul mesajelor

#### Frontend
- **Replici**: 1
- **Port**: 90 (NodePort: 30090)
- **Tehnologie**: Vue.js 3
- **Funcționalități**: Interfață pentru chat, conectare WebSocket automată, afișare mesaje în timp real

#### Baza de date
- **Replici**: 1
- **Port**: 27017 (ClusterIP)
- **Tehnologie**: MongoDB 6.0
- **Persistență**: Volume persistent pentru mesaje

### 3. Aplicația de IA

#### Backend
- **Replici**: 2
- **Port**: 3001 (NodePort: 30092)
- **Tehnologie**: Node.js 18 cu Azure SDK
- **Funcționalități**: 
  - Upload imagini la Azure Blob Storage
  - Procesare OCR cu Azure Computer Vision
  - Salvare rezultate în Azure SQL Database
  - API pentru istoric și rezultate

#### Frontend
- **Replici**: 1
- **Port**: 80 (NodePort: 30091)
- **Tehnologie**: Vue.js 3
- **Funcționalități**: Upload fișiere, afișare rezultate OCR, istoric procesări

## Configurarea CMS-ului

După implementarea sistemului, Drupal trebuie configurat manual:

1. **Accesează și instalează Drupal**: `http://<IP_HOST>:30080`
   - Folosește credențialele bazei de date MariaDB din deployment

2. **Creează bloc Full HTML pentru chat**:
   ```html
   <iframe src="http://<IP_HOST>:30090" width="100%" height="600px" frameborder="0" style="border: 1px solid #ccc; border-radius: 5px;"></iframe>
   ```

3. **Creează bloc HTML pentru aplicația IA**:
   ```html
   <iframe src="http://<IP_HOST>:30091" width="100%" height="700px" frameborder="0" style="border: 1px solid #ccc; border-radius: 5px;"></iframe>
   ```

## Testarea funcționalităților

### Verificarea mesajelor stocate în MongoDB

```bash
# Accesează shell-ul MongoDB
kubectl exec -it $(kubectl get pods -l app=chat-db -o jsonpath="{.items[0].metadata.name}") -- mongosh

# În shell-ul MongoDB
use chatdb
db.messages.find().pretty()
db.messages.count()
```

### Testarea aplicației de chat

```bash
# Verifică log-urile pentru WebSocket
kubectl logs -l app=chat-backend -f

# Testează cu wscat
npm install -g wscat
wscat -c ws://<IP_HOST>:30088
```

### Testarea aplicației AI

```bash
# Verifică health check
curl http://<IP_HOST>:30092/api/health

# Verifică istoricul procesărilor
curl http://<IP_HOST>:30092/api/history
```

### Verificarea persistenței datelor

```bash
# Testează persistența prin repornirea pod-urilor
kubectl delete pod $(kubectl get pods -l app=chat-db -o jsonpath="{.items[0].metadata.name}")
kubectl delete pod $(kubectl get pods -l app=drupal-db -o jsonpath="{.items[0].metadata.name}")

# Verifică că datele persistă după recreare
```

## Note de utilizare

- **Aplicațiile independente**: Chat și IA sunt complet independente de CMS, integrate prin iframe
- **Expunere servicii**: WebSocket pentru chat și API pentru IA sunt expuse prin NodePort
- **Securitate**: Bazele de date folosesc ClusterIP pentru securitate internă
- **Scalabilitate**: Frontend-urile sunt stateless și pot fi scalate
- **Persistența**: Toate datele sunt stocate în volume persistente și servicii Azure

## Troubleshooting

### Verificarea log-urilor

```bash
# Script pentru verificarea tuturor componentelor
echo "=== AI Backend ==="
kubectl logs $(kubectl get pods -l app=ai-backend -o jsonpath="{.items[0].metadata.name}") --tail=5

echo "=== Chat Backend ==="
kubectl logs $(kubectl get pods -l app=chat-backend -o jsonpath="{.items[0].metadata.name}") --tail=5

echo "=== Drupal ==="
kubectl logs $(kubectl get pods -l app=drupal -o jsonpath="{.items[0].metadata.name}") --tail=5
```

### Testarea endpoint-urilor

```bash
# Testează toate serviciile
curl -I http://<IP_HOST>:30080          # Drupal
curl -I http://<IP_HOST>:30090          # Chat Frontend
curl -I http://<IP_HOST>:30091          # AI Frontend
curl http://<IP_HOST>:30092/api/health  # AI Backend
```

## Backup și restaurare

### Backup MongoDB
```bash
kubectl exec -it $(kubectl get pods -l app=chat-db -o jsonpath="{.items[0].metadata.name}") -- mongodump --out=/tmp/backup
kubectl cp $(kubectl get pods -l app=chat-db -o jsonpath="{.items[0].metadata.name}"):/tmp/backup ./mongodb-backup
```

### Backup MariaDB
```bash
kubectl exec -it $(kubectl get pods -l app=drupal-db -o jsonpath="{.items[0].metadata.name}") -- mysqldump -u drupal -p drupal > drupal-backup.sql
```

## Conformitatea cu cerințele temei

✅ **Drupal CMS** - 6 replici, port 80, MariaDB, volume persistente  
✅ **Chat Backend** - Node.js + Nginx, 5 replici, WebSocket, MongoDB  
✅ **Chat Frontend** - Vue.js, 1 replică, iframe integration  
✅ **AI Application** - Vue.js frontend + Node.js backend  
✅ **Azure Integration** - Blob Storage, Computer Vision OCR, SQL Database  
✅ **Kubernetes** - Deployment-uri, Services, PVC-uri, Secrets  
✅ **Registry privat** - MicroK8s registry local  
✅ **Single apply** - Funcționează cu `kubectl apply -k .`  

## Licență

Acest proiect este dezvoltat ca temă de facultate și este disponibil pentru referință educațională.