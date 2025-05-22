# Site Web cu Chat și IA peste Kubernetes

## Descriere

Acest proiect implementează un site web complet ce integrează un CMS Drupal, un sistem de chat în timp real bazat pe WebSocket și o aplicație de procesare a imaginilor folosind Azure OCR. Întreaga infrastructură este gestionată de Kubernetes folosind servicii NodePort pentru expunerea aplicațiilor, respectând exact cerințele specificate în `Tema.md`.

## Tehnologii utilizate

- **CMS**: Drupal 10.0 cu MariaDB 10.6
- **Chat backend**: Node.js 18 + Nginx cu Express, WebSocket, Mongoose
- **Chat frontend**: Vue.js 3
- **Bază de date pentru chat**: MongoDB 6.0
- **AI backend**: Node.js 18 cu Express, Azure SDK
- **AI frontend**: Vue.js 3 cu integrare Azure Storage și Azure OCR
- **Cloud Services**: Azure Blob Storage, Azure Computer Vision OCR, Azure SQL Database
- **Containerizare**: Docker cu multi-stage builds
- **Orchestrare**: Kubernetes (MicroK8s) cu servicii NodePort

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
# Aplicare folosind kustomize
kubectl apply -k .

# Verificarea deployment-urilor
kubectl get pods
kubectl get services
kubectl get nodes -o wide  # Pentru a vedea IP-ul nodului
```

## Puncte de acces ale aplicației

Conform cerințelor temei, folosind NodePort:

1. **Drupal CMS** - port 80
   - Acces: `http://<NODE_IP>:30080`
   - NodePort: 30080

2. **Chat Backend WebSocket** - port 88
   - Acces: `ws://<NODE_IP>:30088`
   - NodePort: 30088

3. **Chat Frontend** - port 90
   - Acces: `http://<NODE_IP>:30090`
   - NodePort: 30090

4. **AI Frontend**
   - Acces: `http://<NODE_IP>:30302`
   - NodePort: 30302

5. **AI Backend API**
   - Acces: `http://<NODE_IP>:30301/api`
   - NodePort: 30301

### Găsirea IP-ului nodului

```bash
# Obține IP-ul nodului
kubectl get nodes -o wide

# Sau pentru MicroK8s
ip route show | grep default | awk '{print $3}'
```

## Componente

### 1. Drupal CMS

- **Replici**: 6 (conform cerințelor)
- **Port**: 80 → NodePort 30080
- **Bază de date**: MariaDB
- **Persistență**: Volume persistent pentru site și baza de date
- **Init Container**: Configurează automat fișierele necesare

### 2. Sistemul de Chat

#### Backend
- **Replici**: 5 (conform cerințelor)
- **Port**: 88 → NodePort 30088
- **Tehnologie**: Node.js + Nginx (conform cerințelor)
- **Funcționalități**: WebSocket pentru comunicare în timp real, salvare mesaje în MongoDB
- **API**: REST endpoints pentru istoricul mesajelor

#### Frontend
- **Replici**: 1
- **Port**: 90 → NodePort 30090
- **Tehnologie**: Vue.js 3
- **Funcționalități**: Interfață pentru chat, conectare WebSocket automată, afișare mesaje în timp real

#### Baza de date
- **Replici**: 1
- **Port**: 27017 (ClusterIP)
- **Tehnologie**: MongoDB 6.0
- **Persistență**: Volume persistent pentru mesaje

### 3. Aplicația de IA

#### Backend
- **Replici**: 1
- **Port**: 3001 → NodePort 30301
- **Tehnologie**: Node.js 18 cu Azure SDK
- **Funcționalități**: 
  - Upload imagini la Azure Blob Storage
  - Procesare OCR cu Azure Computer Vision
  - Salvare rezultate în Azure SQL Database
  - API pentru istoric și rezultate

#### Frontend
- **Replici**: 1
- **Port**: 80 → NodePort 30302
- **Tehnologie**: Vue.js 3
- **Funcționalități**: Upload fișiere, afișare rezultate OCR, istoric procesări

## Configurarea CMS-ului

După implementarea sistemului, Drupal trebuie configurat manual:

1. **Accesează și instalează Drupal**: `http://<NODE_IP>:30080`
   - Folosește credențialele bazei de date MariaDB din deployment

2. **Creează bloc Full HTML pentru chat**:
   ```html
   <iframe src="http://<NODE_IP>:30090" width="100%" height="600px" frameborder="0" style="border: 1px solid #ccc; border-radius: 5px;"></iframe>
   ```

3. **Creează bloc HTML pentru aplicația IA**:
   ```html
   <iframe src="http://<NODE_IP>:30302" width="100%" height="700px" frameborder="0" style="border: 1px solid #ccc; border-radius: 5px;"></iframe>
   ```

## Testarea funcționalităților

### Verificarea punctelor de acces

```bash
# Obține IP-ul nodului
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Testează toate punctele de acces
curl -I http://$NODE_IP:30080          # Drupal CMS
curl -I http://$NODE_IP:30090          # Chat Frontend
curl -I http://$NODE_IP:30302          # AI Frontend
curl http://$NODE_IP:30301/api/health  # AI Backend API
```

### Verificarea serviciilor NodePort

```bash
# Verifică serviciile NodePort
kubectl get services --field-selector spec.type=NodePort
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

# Testează WebSocket cu wscat (instalează wscat dacă nu există)
npm install -g wscat
wscat -c ws://$NODE_IP:30088
```

### Testarea aplicației AI

```bash
# Verifică health check
curl http://$NODE_IP:30301/api/health

# Verifică istoricul procesărilor
curl http://$NODE_IP:30301/api/history
```

## Structura fișierelor pentru NodePort

```
├── drupal/
│   ├── drupal-service-nodeport.yaml     # Port 80 → NodePort 30080
│   └── ...
├── chat/
│   ├── backend/
│   │   ├── chat-backend-service-nodeport.yaml  # Port 88 → NodePort 30088
│   │   └── ...
│   ├── frontend/
│   │   ├── chat-frontend-service-nodeport.yaml # Port 90 → NodePort 30090
│   │   └── ...
│   └── ...
├── ai/
│   ├── backend/
│   │   ├── ai-backend-service-nodeport.yaml    # Port 3001 → NodePort 30301
│   │   └── ...
│   ├── frontend/
│   │   ├── ai-frontend-service-nodeport.yaml   # Port 80 → NodePort 30302
│   │   └── ...
│   └── ...
└── kustomization-nodeport.yaml
```

## Maparea porturilor NodePort

| Serviciu | Port intern | NodePort | Descriere |
|----------|------------|----------|-----------|
| Drupal | 80 | 30080 | CMS principal |
| Chat Backend | 88 | 30088 | WebSocket server |
| Chat Frontend | 90 | 30090 | Interfața chat |
| AI Backend | 3001 | 30301 | API pentru AI |
| AI Frontend | 80 | 30302 | Interfața AI |

## Note de utilizare

- **Acces simplu**: Toate serviciile sunt accesibile direct prin NodePort
- **Porturile cerințelor**: Respectă exact porturile 80, 88, 90 din cerințe
- **Aplicații independente**: Chat și IA sunt complet independente de CMS
- **Expunere directă**: Nu necesită configurația complexă de Ingress
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

### Verificarea conectivității

```bash
# Testează conectivitatea internă
kubectl run test-pod --image=busybox --rm -it -- sh
# În pod: wget -qO- http://drupal
# În pod: wget -qO- http://chat-frontend
# În pod: wget -qO- http://ai-backend:3001/api/health
```

### Verificarea NodePort

```bash
# Verifică că toate serviciile NodePort sunt active
kubectl get services -o wide | grep NodePort

# Verifică endpoint-urile
kubectl get endpoints
```

## Conformitatea cu cerințele temei

✅ **Drupal CMS** - 6 replici, port 80 (NodePort 30080), MariaDB, volume persistente  
✅ **Chat Backend** - Node.js + Nginx, 5 replici, WebSocket pe port 88 (NodePort 30088), MongoDB  
✅ **Chat Frontend** - Vue.js, 1 replică, port 90 (NodePort 30090), iframe integration  
✅ **AI Application** - Vue.js frontend + Node.js backend prin NodePort  
✅ **Azure Integration** - Blob Storage, Computer Vision OCR, SQL Database  
✅ **Kubernetes** - Deployment-uri, Services, PVC-uri, Secrets  
✅ **Registry privat** - MicroK8s registry local  
✅ **Single apply** - Funcționează cu `kubectl apply -k .`  
✅ **Expunere porturi** - 80, 88, 90 prin NodePort (mai simplu decât Ingress)  
✅ **Respectarea cerințelor** - Folosește exact porturile specificate în temă  

## Avantajele NodePort vs Ingress

- **Simplicitate**: Nu necesită configurarea unui Ingress Controller
- **Conformitate strictă**: Respectă exact porturile din cerințele temei
- **Debugging mai ușor**: Acces direct la servicii fără routing complex
- **Funcționare garantată**: NodePort funcționează out-of-the-box în MicroK8s

## Licență

Acest proiect este dezvoltat ca temă de facultate și este disponibil pentru referință educațională.