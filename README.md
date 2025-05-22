# Site Web cu Chat și IA peste Kubernetes

## 🎯 Descriere

Proiect academic care implementează un site web complet cu:
- **🌐 CMS Drupal** cu configurare automată și integrări iframe (6 replici, MariaDB)
- **💬 Sistem de chat** în timp real (WebSocket, Node.js + Nginx, Vue.js, MongoDB)
- **🤖 Aplicație AI OCR** (Azure Computer Vision, Azure Blob Storage, Azure SQL)

Infrastructura este gestionată complet prin **Kubernetes** cu imagini Docker custom și deployment automat.

## 🏗️ Arhitectura sistemului

### Stack software
- **Backend**: Node.js 18, Express, WebSocket, Nginx
- **Frontend**: Vue.js 3, Axios
- **CMS**: Drupal 10 cu temă personalizată
- **Baze de date**: MariaDB, MongoDB, Azure SQL
- **Cloud**: Azure Blob Storage, Computer Vision OCR
- **Containerizare**: Docker multi-stage builds
- **Orchestrare**: Kubernetes (MicroK8s)

### 🗺️ Maparea serviciilor

| Componentă | Replici | Port intern | NodePort | URL extern |
|------------|---------|-------------|----------|------------|
| **Drupal CMS** | 6 | 80 | 30080 | `http://NODE_IP:30080` |
| **Chat Backend** | 5 | 80 | 30088 | `ws://NODE_IP:30088` |
| **Chat Frontend** | 1 | 80 | 30090 | `http://NODE_IP:30090` |
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

# Drupal Custom
docker build -t localhost:32000/drupal-custom:latest ./drupal
docker push localhost:32000/drupal-custom:latest
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
- **Drupal CMS**: `http://NODE_IP:30080` (admin/admin123)
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

## 🎨 Caracteristici Drupal custom

### Configurare automată
- **Instalare automată** la primul boot (fără intervenție manuală)
- **Temă personalizată** cu design modern și responsiv
- **Integrări iframe** pre-configurate pentru chat și AI
- **Conținut demo** cu linkuri către aplicații
- **Credențiale admin**: `admin` / `admin123`

### Pagini create automat
1. **🏠 Homepage** - Pagina principală cu linkuri către chat și AI
2. **💬 Live Chat** - Iframe cu aplicația de chat
3. **🤖 AI OCR** - Iframe cu aplicația AI pentru procesare imagini

## 📁 Structura proiectului

```
├── 🚀 build-and-deploy.sh           # Script automat pentru deployment
├── 📋 kustomization.yaml            # Orchestrare Kubernetes
├── 🔑 secrets/azure-secrets.yaml    # Credențiale Azure
├── 🌐 drupal/                       # CMS Drupal
├── 💬 chat/                         # Sistem chat complet
│   ├── backend/                     # Node.js + Nginx + WebSocket
│   ├── frontend/                    # Vue.js client
│   └── db/                          # MongoDB
└── 🤖 ai/                           # Aplicație OCR
    ├── backend/                     # Node.js + Azure SDK
    └── frontend/                    # Vue.js upload interface
```

## 🔧 Troubleshooting

### Probleme comune

#### Pod-urile nu pornesc
```bash
# Verifică log-urile
microk8s kubectl logs -l app=drupal
microk8s kubectl logs -l app=chat-backend
microk8s kubectl logs -l app=ai-backend

# Verifică resursele
microk8s kubectl describe pod <pod-name>
```

#### Servicii NodePort nu răspund
```bash
# Verifică dacă porturile sunt deschise
ss -tlnp | grep 30080
ss -tlnp | grep 30088

# Restart servicii
microk8s kubectl rollout restart deployment/drupal
```

#### WebSocket connection failed
```bash
# Test port WebSocket
telnet $NODE_IP 30088

# Verifică log-uri chat backend
microk8s kubectl logs -l app=chat-backend -f
```

#### Azure services errors
```bash
# Verifică secretele
microk8s kubectl get secrets azure-secrets -o yaml

# Test AI backend
curl http://$NODE_IP:30101/api/debug
```

### 🧹 Cleanup complet
```bash
# Șterge toate resursele
microk8s kubectl delete -k .

# Verifică că totul a fost șters
microk8s kubectl get all
```

## 📊 Monitorizare

### Log-uri în timp real
```bash
# Toate pod-urile
microk8s kubectl logs -l app=drupal -f --all-containers=true

# Specific pe aplicație
microk8s kubectl logs -l app=chat-backend -f
microk8s kubectl logs -l app=ai-backend -f
```

### Statistici resurse
```bash
# CPU și memorie
microk8s kubectl top nodes
microk8s kubectl top pods
```

## ✅ Conformitate cerințe temă

- ✅ **Drupal CMS** - 6 replici, port 80 echivalent (NodePort 30080)  
- ✅ **Chat Backend** - Node.js + Nginx, 5 replici, port 88 echivalent (NodePort 30088)  
- ✅ **Chat Frontend** - Vue.js, 1 replică, port 90 echivalent (NodePort 30090)  
- ✅ **AI Application** - Upload imagini, Azure OCR, istoric rezultate  
- ✅ **Azure Integration** - Blob Storage, Computer Vision, SQL Database  
- ✅ **Kubernetes** - Deployment-uri, Services, PVC-uri, Secrets  
- ✅ **Registry privat** - MicroK8s registry localhost:32000  
- ✅ **Single apply** - Deployment complet cu `kubectl apply -k .`
- ✅ **Zero configurare manuală** - Totul funcționează după apply

---

> 💡 **Tip**: Pentru debugging rapid, folosește `microk8s kubectl get events --sort-by=.metadata.creationTimestamp` pentru a vedea ce se întâmplă în cluster.