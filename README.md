# Site Web cu Chat și IA peste Kubernetes

## Descriere

Acest proiect implementează un site web complet ce integrează un CMS Drupal, un sistem de chat în timp real bazat pe WebSocket și o aplicație de procesare a imaginilor folosind Azure OCR. Întreaga infrastructură este gestionată de Kubernetes cu Ingress pentru routing inteligent și respectă toate cerințele specificate în `Tema.md`.

## Tehnologii utilizate

- **CMS**: Drupal 10.0 cu MariaDB 10.6
- **Chat backend**: Node.js 18 + Nginx cu Express, WebSocket, Mongoose
- **Chat frontend**: Vue.js 3
- **Bază de date pentru chat**: MongoDB 6.0
- **AI backend**: Node.js 18 cu Express, Azure SDK
- **AI frontend**: Vue.js 3 cu integrare Azure Storage și Azure OCR
- **Cloud Services**: Azure Blob Storage, Azure Computer Vision OCR, Azure SQL Database
- **Containerizare**: Docker cu multi-stage builds
- **Orchestrare**: Kubernetes (MicroK8s) cu Ingress Controller
- **Networking**: Ingress + LoadBalancer pentru expunerea serviciilor

## Cerințe de instalare

### Dependențe

- MicroK8s instalat și configurat
- Docker
- kubectl
- Node.js 18.x (pentru dezvoltare locală)
- Cont Azure cu serviciile: Storage Account, Computer Vision, SQL Database

### Addon-uri MicroK8s necesare

```bash
microk8s enable registry dns storage ingress
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
kubectl get ingress
```

## Puncte de acces ale aplicației

### Conform cerințelor temei:

1. **Drupal CMS** - port 80
   - Acces: `http://<CLUSTER_IP>:80` sau `http://<CLUSTER_IP>/`
   - Tip: Ingress routing

2. **Chat Backend WebSocket** - port 88
   - Acces: `ws://<CLUSTER_IP>:88`
   - Tip: LoadBalancer direct

3. **Chat Frontend** - port 90 + routing alternativ
   - **Acces direct**: `http://<CLUSTER_IP>:90` (LoadBalancer)
   - **Acces prin Ingress**: `http://<CLUSTER_IP>/chat` (routing inteligent)
   - **Ambele opțiuni sunt funcționale**

### Puncte de acces adiționale prin Ingress:

4. **AI Frontend**: `http://<CLUSTER_IP>/ai`
5. **AI Backend API**: `http://<CLUSTER_IP>/api`

## Componente

### 1. Drupal CMS

- **Replici**: 6 (conform cerințelor)
- **Port**: 80 (expus prin Ingress)
- **Bază de date**: MariaDB
- **Persistență**: Volume persistent pentru site și baza de date
- **Init Container**: Configurează automat fișierele necesare

### 2. Sistemul de Chat

#### Backend
- **Replici**: 5 (conform cerințelor)
- **Port**: 88 (LoadBalancer direct pentru WebSocket)
- **Tehnologie**: Node.js + Nginx (conform cerințelor)
- **Funcționalități**: WebSocket pentru comunicare în timp real, salvare mesaje în MongoDB
- **API**: REST endpoints pentru istoricul mesajelor

#### Frontend
- **Replici**: 1
- **Port**: 90 (LoadBalancer) + routing `/chat` (Ingress)
- **Tehnologie**: Vue.js 3
- **Funcționalități**: Interfață pentru chat, conectare WebSocket automată, afișare mesaje în timp real
- **Acces dual**: Direct pe port 90 sau prin Ingress la `/chat`

#### Baza de date
- **Replici**: 1
- **Port**: 27017 (ClusterIP)
- **Tehnologie**: MongoDB 6.0
- **Persistență**: Volume persistent pentru mesaje

### 3. Aplicația de IA

#### Backend
- **Replici**: 2
- **Port**: 3001 (expus prin Ingress la `/api`)
- **Tehnologie**: Node.js 18 cu Azure SDK
- **Funcționalități**: 
  - Upload imagini la Azure Blob Storage
  - Procesare OCR cu Azure Computer Vision
  - Salvare rezultate în Azure SQL Database
  - API pentru istoric și rezultate

#### Frontend
- **Replici**: 1
- **Port**: 80 (expus prin Ingress la `/ai`)
- **Tehnologie**: Vue.js 3
- **Funcționalități**: Upload fișiere, afișare rezultate OCR, istoric procesări

## Configurarea CMS-ului

După implementarea sistemului, Drupal trebuie configurat manual:

1. **Accesează și instalează Drupal**: `http://<CLUSTER_IP>:80`
   - Folosește credențialele bazei de date MariaDB din deployment

2. **Creează bloc Full HTML pentru chat** (ai două opțiuni):
   
   **Opțiunea 1 - Acces direct pe port (conform cerințelor):**
   ```html
   <iframe src="http://<CLUSTER_IP>:90" width="100%" height="600px" frameborder="0" style="border: 1px solid #ccc; border-radius: 5px;"></iframe>
   ```
   
   **Opțiunea 2 - Acces prin Ingress (routing elegant):**
   ```html
   <iframe src="http://<CLUSTER_IP>/chat" width="100%" height="600px" frameborder="0" style="border: 1px solid #ccc; border-radius: 5px;"></iframe>
   ```

3. **Creează bloc HTML pentru aplicația IA**:
   ```html
   <iframe src="http://<CLUSTER_IP>/ai" width="100%" height="700px" frameborder="0" style="border: 1px solid #ccc; border-radius: 5px;"></iframe>
   ```

## Testarea funcționalităților

### Verificarea punctelor de acces

```bash
# Testează toate punctele de acces
curl -I http://<CLUSTER_IP>:80          # Drupal CMS
curl -I http://<CLUSTER_IP>:90          # Chat Frontend (direct)
curl -I http://<CLUSTER_IP>/chat        # Chat Frontend (Ingress)
curl -I http://<CLUSTER_IP>/ai          # AI Frontend
curl http://<CLUSTER_IP>/api/health     # AI Backend API
```

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

# Testează WebSocket cu wscat
npm install -g wscat
wscat -c ws://<CLUSTER_IP>:88
```

### Testarea aplicației AI

```bash
# Verifică health check
curl http://<CLUSTER_IP>/api/health

# Verifică istoricul procesărilor
curl http://<CLUSTER_IP>/api/history
```

### Verificarea Ingress

```bash
# Verifică configurația Ingress
kubectl get ingress
kubectl describe ingress main-ingress
kubectl describe ingress api-ingress

# Verifică log-urile Ingress Controller
kubectl logs -n ingress -l app.kubernetes.io/name=ingress-nginx
```

### Verificarea persistenței datelor

```bash
# Testează persistența prin repornirea pod-urilor
kubectl delete pod $(kubectl get pods -l app=chat-db -o jsonpath="{.items[0].metadata.name}")
kubectl delete pod $(kubectl get pods -l app=drupal-db -o jsonpath="{.items[0].metadata.name}")

# Verifică că datele persistă după recreare
```

## Note de utilizare

- **Acces dual pentru chat**: Frontend-ul poate fi accesat atât direct pe port 90, cât și prin Ingress la `/chat`
- **Aplicațiile independente**: Chat și IA sunt complet independente de CMS, integrate prin iframe
- **Expunere servicii**: WebSocket pentru chat expus direct, API și frontend-uri prin Ingress
- **Securitate**: Bazele de date folosesc ClusterIP pentru securitate internă
- **Scalabilitate**: Frontend-urile sunt stateless și pot fi scalate
- **Persistența**: Toate datele sunt stocate în volume persistente și servicii Azure
- **Flexibilitate routing**: Ingress oferă routing inteligent și management centralizat

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

echo "=== Ingress ==="
kubectl logs -n ingress -l app.kubernetes.io/name=ingress-nginx --tail=5
```

### Verificarea conectivității

```bash
# Testează conectivitatea internă
kubectl run test-pod --image=busybox --rm -it -- sh
# În pod: wget -qO- http://drupal
# În pod: wget -qO- http://chat-frontend
# În pod: wget -qO- http://ai-backend:3001/api/health
```

### Diagnosticarea problemelor de routing

```bash
# Verifică serviciile
kubectl get services
kubectl describe service chat-frontend
kubectl describe service ai-backend

# Verifică endpoint-urile
kubectl get endpoints
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
✅ **Chat Backend** - Node.js + Nginx, 5 replici, WebSocket pe port 88, MongoDB  
✅ **Chat Frontend** - Vue.js, 1 replică, port 90 + `/chat`, iframe integration  
✅ **AI Application** - Vue.js frontend + Node.js backend prin Ingress  
✅ **Azure Integration** - Blob Storage, Computer Vision OCR, SQL Database  
✅ **Kubernetes** - Deployment-uri, Services, PVC-uri, Secrets, Ingress  
✅ **Registry privat** - MicroK8s registry local  
✅ **Single apply** - Funcționează cu `kubectl apply -k .`  
✅ **Expunere porturi** - 80 (Drupal), 88 (Chat WS), 90 (Chat Frontend)  
✅ **Routing flexibil** - Ingress pentru accesibilitate îmbunătățită  

## Licență

Acest proiect este dezvoltat ca temă de facultate și este disponibil pentru referință educațională.