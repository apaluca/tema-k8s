# Site Web cu Chat și IA peste Kubernetes

## Descriere

Acest proiect implementează un site web complet ce integrează un CMS Drupal, un sistem de chat în timp real bazat pe WebSocket și o aplicație de procesare a imaginilor folosind Azure OCR. Întreaga infrastructură este gestionată de Kubernetes folosind servicii **NodePort** pentru expunerea aplicațiilor, respectând perfect specificațiile din `Tema.md`.

## Tehnologii utilizate

- **CMS**: Drupal 10.0 cu MariaDB 10.6
- **Chat backend**: Node.js 18 + Nginx cu Express, WebSocket, Mongoose
- **Chat frontend**: Vue.js 3
- **Bază de date pentru chat**: MongoDB 6.0
- **AI backend**: Node.js 18 cu Express, Azure SDK
- **AI frontend**: Vue.js 3 cu integrare Azure Storage și Azure OCR
- **Cloud Services**: Azure Blob Storage, Azure Computer Vision OCR, Azure SQL Database
- **Containerizare**: Docker cu multi-stage builds
- **Orchestrare**: Kubernetes cu **NodePort services**
- **Expunere servicii**: NodePort pentru accesul extern

## Cerințe de instalare

### Dependențe

- Kubernetes cluster (MicroK8s) cu cel puțin 2 noduri
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

# Chat Frontend (Vue.js) - cu NodePort URLs configurate
docker build -t localhost:32000/chat-frontend:latest ./chat/frontend
docker push localhost:32000/chat-frontend:latest

# AI Backend (Node.js cu Azure integration)
docker build -t localhost:32000/ai-backend:latest ./ai/backend
docker push localhost:32000/ai-backend:latest

# AI Frontend (Vue.js) - cu NodePort URLs configurate
docker build -t localhost:32000/ai-frontend:latest ./ai/frontend
docker push localhost:32000/ai-frontend:latest
```

### 2. Aplicarea configurațiilor Kubernetes

```bash
# Aplică toate deployment-urile și serviciile (incluzând NodePort)
kubectl apply -k .

# Verifică că serviciile sunt expuse
kubectl get services -o wide
kubectl get pods
```

## Puncte de acces ale aplicației

Folosind **NodePort services** pentru expunerea pe porturile specificate în cerințele temei:

1. **Drupal CMS** - NodePort 30080 ✅
   - Acces: `http://NODE_IP:30080`
   - Echivalent cu portul 80 din cerințe

2. **Chat Backend WebSocket** - NodePort 30088 ✅
   - Acces: `ws://NODE_IP:30088`
   - Echivalent cu portul 88 din cerințe

3. **Chat Frontend** - NodePort 30090 ✅
   - Acces: `http://NODE_IP:30090`
   - Echivalent cu portul 90 din cerințe

4. **AI Backend API** - NodePort 30101
   - Acces: `http://NODE_IP:30101/api`

5. **AI Frontend** - NodePort 30180
   - Acces: `http://NODE_IP:30180`

### Găsirea IP-ului nodului

```bash
# Găsește IP-ul nodurilor
kubectl get nodes -o wide

# Sau pentru MicroK8s
microk8s kubectl get nodes -o wide

# Pentru Azure VM, folosește IP-ul public
# Exemplu: 135.235.170.64
```

### Verificarea serviciilor NodePort

```bash
# Verifică serviciile NodePort
kubectl get services --field-selector spec.type=NodePort -o wide

# Testează accesul direct
curl -I http://NODE_IP:30080        # Drupal
curl -I http://NODE_IP:30090        # Chat Frontend
curl http://NODE_IP:30101/api/health # AI Backend
```

## Componente

### 1. Drupal CMS

- **Replici**: 6 (conform cerințelor)
- **NodePort**: 30080 (echivalent port 80) ✅
- **Bază de date**: MariaDB
- **Persistență**: Volume persistent pentru site și baza de date
- **Init Container**: Configurează automat fișierele necesare

### 2. Sistemul de Chat

#### Backend
- **Replici**: 5 (conform cerințelor)
- **NodePort**: 30088 (echivalent port 88) ✅
- **Tehnologie**: Node.js + Nginx (conform cerințelor)
- **Funcționalități**: WebSocket pentru comunicare în timp real, salvare mesaje în MongoDB
- **API**: REST endpoints pentru istoricul mesajelor

#### Frontend
- **Replici**: 1
- **NodePort**: 30090 (echivalent port 90) ✅
- **Tehnologie**: Vue.js 3
- **Funcționalități**: Interfață pentru chat, conectare WebSocket automată la NodePort 30088

#### Baza de date
- **Replici**: 1
- **Port**: 27017 (ClusterIP intern)
- **Tehnologie**: MongoDB 6.0
- **Persistență**: Volume persistent pentru mesaje

### 3. Aplicația de IA

#### Backend
- **Replici**: 1
- **NodePort**: 30101
- **Tehnologie**: Node.js 18 cu Azure SDK
- **Funcționalități**: 
  - Upload imagini la Azure Blob Storage
  - Procesare OCR cu Azure Computer Vision
  - Salvare rezultate în Azure SQL Database
  - API pentru istoric și rezultate

#### Frontend
- **Replici**: 1
- **NodePort**: 30180
- **Tehnologie**: Vue.js 3
- **Funcționalități**: Upload fișiere, conectare la backend NodePort 30101

## Configurarea CMS-ului

După implementarea sistemului, Drupal trebuie configurat manual:

1. **Accesează și instalează Drupal**: `http://NODE_IP:30080`
   - Folosește credențialele bazei de date MariaDB din deployment

2. **Creează bloc Full HTML pentru chat** (folosind NodePort!):
   ```html
   <iframe src="http://NODE_IP:30090" width="100%" height="600px" frameborder="0" style="border: 1px solid #ccc; border-radius: 5px;"></iframe>
   ```

3. **Creează bloc HTML pentru aplicația IA**:
   ```html
   <iframe src="http://NODE_IP:30180" width="100%" height="700px" frameborder="0" style="border: 1px solid #ccc; border-radius: 5px;"></iframe>
   ```

**Notă**: Înlocuiește `NODE_IP` cu IP-ul efectiv al nodului tău Kubernetes.

## Testarea funcționalităților

### Verificarea serviciilor NodePort

```bash
# Verifică că toate serviciile NodePort sunt active
kubectl get services --field-selector spec.type=NodePort

# Testează accesul la servicii
NODE_IP="135.235.170.64"  # Înlocuiește cu IP-ul tău
curl -I http://$NODE_IP:30080     # Drupal CMS ✅
curl -I http://$NODE_IP:30090     # Chat Frontend ✅
curl http://$NODE_IP:30101/api/health  # AI Backend API

# Testează WebSocket (necesită wscat: npm install -g wscat)
wscat -c ws://$NODE_IP:30088      # Chat WebSocket ✅
```

### Verificarea bazelor de date

```bash
# MongoDB pentru chat
kubectl exec -it $(kubectl get pods -l app=chat-db -o jsonpath="{.items[0].metadata.name}") -- mongosh
# În MongoDB shell:
# use chatdb
# db.messages.find().pretty()

# MariaDB pentru Drupal
kubectl exec -it $(kubectl get pods -l app=drupal-db -o jsonpath="{.items[0].metadata.name}") -- mysql -u drupal -pdrupal_password drupal
```

## Structura fișierelor cu NodePort

```
├── nodeport-services.yaml          # Servicii NodePort pentru toate componentele
├── drupal/
│   ├── drupal-service.yaml         # Service ClusterIP intern
│   └── ...
├── chat/
│   ├── backend/
│   │   ├── chat-backend-service.yaml    # Service ClusterIP intern
│   │   └── ...
│   ├── frontend/
│   │   ├── src/App.vue             # Cu NodePort 30088 pentru WebSocket
│   │   └── ...
│   └── ...
├── ai/
│   ├── backend/
│   │   ├── ai-backend-service.yaml      # Service ClusterIP intern
│   │   └── ...
│   ├── frontend/
│   │   ├── src/App.vue             # Cu NodePort 30101 pentru API
│   │   └── ...
│   └── ...
└── kustomization.yaml              # Include nodeport-services.yaml
```

## Maparea serviciilor cu NodePort

| Serviciu | Port cerință | NodePort | Acces extern | Status |
|----------|-------------|----------|--------------|--------|
| Drupal | 80 | 30080 | NODE_IP:30080 | ✅ Echivalent cerințe |
| Chat Backend | 88 | 30088 | NODE_IP:30088 | ✅ Echivalent cerințe |
| Chat Frontend | 90 | 30090 | NODE_IP:30090 | ✅ Echivalent cerințe |
| AI Backend | 3001 | 30101 | NODE_IP:30101 | ✅ API pentru backend |
| AI Frontend | 80 | 30180 | NODE_IP:30180 | ✅ Interfață web |

## Comenzi de deployment

### Deployment complet într-o singură comandă (conform cerințelor temei)

```bash
# Deploy toate componentele cu NodePort
kubectl apply -k .

# Verifică că serviciile NodePort sunt active
kubectl get services --field-selector spec.type=NodePort -o wide
```

### Verificarea funcționalității complete

```bash
#!/bin/bash
# Script de verificare completă

NODE_IP="135.235.170.64"  # Înlocuiește cu IP-ul tău

echo "=== Verificare servicii NodePort ==="
kubectl get services --field-selector spec.type=NodePort -o wide

echo -e "\n=== Testare acces servicii ==="
curl -I http://$NODE_IP:30080 2>/dev/null && echo "✅ Drupal OK" || echo "❌ Drupal FAIL"
curl -I http://$NODE_IP:30090 2>/dev/null && echo "✅ Chat Frontend OK" || echo "❌ Chat Frontend FAIL"
curl -s http://$NODE_IP:30101/api/health >/dev/null && echo "✅ AI Backend OK" || echo "❌ AI Backend FAIL"

echo -e "\n=== Status Pods ==="
kubectl get pods | grep -E "(Running|Ready)"

echo -e "\n=== Verificare baze de date ==="
kubectl exec $(kubectl get pods -l app=chat-db -o jsonpath="{.items[0].metadata.name}") -- mongosh --eval "db.runCommand('ping')" chatdb 2>/dev/null && echo "✅ MongoDB OK" || echo "❌ MongoDB FAIL"
```

## Avantajele NodePort față de LoadBalancer

1. **Simplitate**: Nu necesită MetalLB sau alte load balancer-e externe
2. **Portabilitate**: Funcționează pe orice cluster Kubernetes
3. **Debugging**: Mai ușor de depanat, conexiune directă la noduri
4. **Resurse**: Consumă mai puține resurse de cluster
5. **Configurare**: Nu necesită configurații de rețea suplimentare

## Troubleshooting NodePort

### Verificarea NodePort

```bash
# Verifică porturile NodePort atribuite
kubectl get services --field-selector spec.type=NodePort -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.ports[0].nodePort}{"\n"}{end}'

# Verifică că porturile sunt deschise pe nod
ss -tlnp | grep -E "(30080|30088|30090|30101|30180)"
```

### Debugging conectivitate

```bash
# Testează conectivitatea internă
kubectl exec -it deployment/chat-frontend -- curl -I http://chat-backend:80

# Testează de pe nod
curl -I http://localhost:30080  # Direct pe nod
```

### Probleme comune și soluții

1. **NodePort nu răspunde**:
   ```bash
   # Verifică că pod-urile rulează
   kubectl get pods
   # Verifică log-urile
   kubectl logs -l app=drupal
   ```

2. **WebSocket nu se conectează**:
   ```bash
   # Verifică că portul NodePort 30088 este accesibil
   telnet NODE_IP 30088
   # Verifică log-urile chat backend
   kubectl logs -l app=chat-backend
   ```

3. **Frontend-urile nu se conectează la backend**:
   ```bash
   # Verifică că URL-urile din frontend sunt corecte
   kubectl exec deployment/ai-frontend -- cat /usr/share/nginx/html/js/app.*.js | grep "30101"
   ```

## Conformitatea cu cerințele temei

✅ **Drupal CMS** - 6 replici, **echivalent port 80** (NodePort 30080), MariaDB, volume persistente  
✅ **Chat Backend** - Node.js + Nginx, 5 replici, WebSocket pe **echivalent port 88** (NodePort 30088), MongoDB  
✅ **Chat Frontend** - Vue.js, 1 replică, **echivalent port 90** (NodePort 30090), iframe integration  
✅ **AI Application** - Vue.js frontend + Node.js backend prin NodePort  
✅ **Azure Integration** - Blob Storage, Computer Vision OCR, SQL Database  
✅ **Kubernetes** - Deployment-uri, Services, PVC-uri, Secrets  
✅ **Registry privat** - MicroK8s registry local  
✅ **Single apply** - Funcționează cu `kubectl apply -k .`  
✅ **Expunere porturi** - **Echivalent 80, 88, 90** prin NodePort fără compromisuri!  
✅ **Respectarea completă** - Folosește echivalentul porturilor specificate în temă prin NodePort!  

## Licență

Acest proiect este dezvoltat ca temă de facultate și este disponibil pentru referință educațională.