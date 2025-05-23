# Site Web cu Chat și IA peste Kubernetes

## 🎯 Descriere

Proiect academic care implementează un site web complet cu:
- **🌐 CMS Drupal** cu MySQL și tema Mahi (6 replici)
- **💬 Sistem de chat** în timp real (WebSocket, Node.js + Nginx, Vue.js, MongoDB)
- **🤖 Aplicație AI OCR** (Azure Computer Vision, Azure Blob Storage, Azure SQL)

Infrastructura este gestionată complet prin **Kubernetes** cu imagini Docker custom și deployment automat.

## 🏗️ Arhitectura sistemului

### Stack software
- **Backend**: Node.js 18, Express, WebSocket, Nginx
- **Frontend**: Vue.js 3, Axios
- **CMS**: Drupal 10 cu tema Mahi și MySQL 8.0
- **Baze de date**: MySQL, MongoDB, Azure SQL
- **Cloud**: Azure Blob Storage, Computer Vision OCR
- **Containerizare**: Docker multi-stage builds
- **Orchestrare**: Kubernetes (MicroK8s)
- **Messaging / Pub-Sub**: Redis 7.2 (fan-out pentru WebSockets)

### 🗺️ Maparea serviciilor

| Componentă | Replici | Port intern | NodePort | URL extern |
|------------|---------|-------------|----------|------------|
| **Drupal CMS** | 6 | 80 | 30080 | `http://NODE_IP:30080` |
| **Drupal Database** | 1 | 3306 | - | Intern |
| **Chat Backend** | 5 | 80 | 30088 | `ws://NODE_IP:30088` |
| **Chat Frontend** | 1 | 80 | 30090 | `http://NODE_IP:30090` |
| **Chat Database** | 1 | 27017 | - | Intern |w
| **Redis (Chat bus)** | 1 | 6379 | - | Intern |
| **AI Backend** | 1 | 3001 | 30101 | `http://NODE_IP:30101` |
| **AI Frontend** | 1 | 80 | 30180 | `http://NODE_IP:30180` |

## 📋 Cerințe și dependențe

### Kubernetes (MicroK8s)
```bash
# Instalare MicroK8s (Ubuntu/Linux)
sudo snap install microk8s --classic

# Pornire și configurare addon-uri
sudo microk8s start
sudo microk8s enable registry dns hostpath-storage

# Alias pentru kubectl (opțional)
sudo microk8s config > ~/.kube/config
```

### Azure Services necesare
1. **📦 Storage Account** cu container "images" (Blob Storage)
2. **👁️ Computer Vision** pentru OCR  
3. **🗄️ SQL Database** cu SQL Authentication activat

### 🔑 Configurare variabile Azure
Editează `secrets/azure-secrets.yaml` cu credențialele tale (base64 encoded):

```bash
# Exemple de encoding pentru secrets
echo -n "DefaultEndpointsProtocol=https;AccountName=..." | base64
echo -n "your_ocr_api_key_here" | base64  
echo -n "Server=tcp:server.database.windows.net,1433;..." | base64
```

## 🚀 Instalare și deployment

### Metoda 1: Script automat (Recomandat)
```bash
# Face totul automat: build, push, deploy
chmod +x build-and-deploy.sh
./build-and-deploy.sh
```

### Metoda 2: Manuală pas cu pas

#### 1. 🔧 Configurare secrete Azure
```bash
# Editează secrets/azure-secrets.yaml cu credențialele tale
nano secrets/azure-secrets.yaml
```

#### 2. 🏗️ Build și push imagini
```bash
# Chat Backend
docker build -t localhost:32000/chat-backend:latest ./chat/backend
docker push localhost:32000/chat-backend:latest

# Chat Frontend
docker build -t localhost:32000/chat-frontend:latest ./chat/frontend  
docker push localhost:32000/chat-frontend:latest

# AI Backend
docker build -t localhost:32000/ai-backend:latest ./ai/backend
docker push localhost:32000/ai-backend:latest

# AI Frontend
docker build -t localhost:32000/ai-frontend:latest ./ai/frontend
docker push localhost:32000/ai-frontend:latest

# Drupal Custom (versiune nouă simplificată)
docker build -t localhost:32000/custom-drupal:latest ./drupal
docker push localhost:32000/custom-drupal:latest
```

#### 3. 🎯 Deploy complet (o singură comandă)
```bash
microk8s kubectl apply -k .
```

## ✅ Verificare și testare

### Status servicii
```bash
# Verifică pod-urile
microk8s kubectl get pods -o wide

# Verifică serviciile NodePort
microk8s kubectl get services --field-selector spec.type=NodePort

# IP nod Kubernetes
NODE_IP=$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Node IP: $NODE_IP"
```

### 🌐 Accesare aplicații
- **Drupal CMS**: `http://NODE_IP:30080` (instalare manuală necesară)
- **Chat Live**: `http://NODE_IP:30090`
- **AI OCR**: `http://NODE_IP:30180`

### 🧪 Testare endpoints
```bash
# Test conectivitate
curl -I http://$NODE_IP:30080              # Drupal
curl -I http://$NODE_IP:30090              # Chat Frontend  
curl http://$NODE_IP:30101/api/health      # AI Backend health

# Test WebSocket (necesită wscat: npm install -g wscat)
wscat -c ws://$NODE_IP:30088               # Chat Backend
```

## 🎨 Configurare Drupal

### Instalare manuală
După deployment, accesează `http://NODE_IP:30080` și urmează pașii:

1. **Selectează limba**: English
2. **Profil de instalare**: Standard
3. **Configurare bază de date**:
   - Database host: `drupal-db`
   - Database name: `drupal`
   - Database username: `drupal`
   - Database password: `drupalpassword`
4. **Configurare site**:
   - Site name: Kubernetes Demo Site
   - Admin username: `admin`
   - Admin password: `admin123`
   - Admin email: `admin@example.com`

### Activare temă Mahi
După instalare:
```bash
# Conectează-te la un pod Drupal
microk8s kubectl exec -it deployment/drupal -- bash

# Activează tema Mahi
cd /var/www/html
vendor/bin/drush theme:enable mahi
vendor/bin/drush config:set system.theme default mahi
```

### Adăugare conținut cu iframe-uri
Creează pagini noi în Drupal și adaugă conținut HTML:

**Pentru Chat:**
```html
<h2>Real-time Chat Application</h2>
<iframe src="http://NODE_IP:30090" width="100%" height="600px" frameborder="0"></iframe>
```

**Pentru AI OCR:**
```html
<h2>OCR Image Processing</h2>
<iframe src="http://NODE_IP:30180" width="100%" height="700px" frameborder="0"></iframe>
```

## 📁 Structura proiectului

```
├── 🚀 build-and-deploy.sh           # Script automat pentru deployment
├── 📋 kustomization.yaml            # Orchestrare Kubernetes
├── 🔑 secrets/azure-secrets.yaml    # Credențiale Azure
├── 🌐 drupal/                       # CMS Drupal
├── 💬 chat/                         # Sistem chat complet
│   ├── backend/                     # Node.js + Nginx + WebSocket
│   ├── frontend/                    # Vue.js client
│   └── db/                          # MongoDB (chat-db)
└── 🤖 ai/                           # Aplicație OCR
    ├── backend/                     # Node.js + Azure SDK
    └── frontend/                    # Vue.js upload interface
```

## 🧹 Cleanup complet
```bash
# Șterge toate resursele
microk8s kubectl delete -k .

# Verifică că totul a fost șters
microk8s kubectl get all
```

## 📊 Convenții de denumire

Proiectul urmează convenții consistente pentru toate componentele:

- **drupal-db**: Baza de date MySQL pentru Drupal
- **chat-db**: Baza de date MongoDB pentru chat  
- **Servicii**: `<component>-service.yaml`
- **Deployment-uri**: `<component>-deployment.yaml`
- **PVC-uri**: `<component>-pvc.yaml`

## ✅ Conformitate cerințe temă

- ✅ **Drupal CMS** - 6 replici, port 80 echivalent (NodePort 30080)  
- ✅ **Chat Backend** - Node.js + Nginx, 5 replici, port 88 echivalent (NodePort 30088)  
- ✅ **Chat Frontend** - Vue.js, 1 replică, port 90 echivalent (NodePort 30090)  
- ✅ **AI Application** - Upload imagini, Azure OCR, istoric rezultate  
- ✅ **Azure Integration** - Blob Storage, Computer Vision, SQL Database  
- ✅ **Kubernetes** - Deployment-uri, Services, PVC-uri, Secrets  
- ✅ **Registry privat** - MicroK8s registry localhost:32000  
- ✅ **Single apply** - Deployment complet cu `kubectl apply -k .`
- ✅ **Zero configurare manuală după deploy** - Doar instalarea Drupal prin web UI

---

> 💡 **Tip**: Pentru debugging rapid, folosește `microk8s kubectl get events --sort-by=.metadata.creationTimestamp` pentru a vedea ce se întâmplă în cluster.