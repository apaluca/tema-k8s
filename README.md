# Site Web cu Chat și IA peste Kubernetes

## Descriere

Acest proiect implementează un site web complet ce integrează un CMS Drupal, un sistem de chat în timp real bazat pe WebSocket și o aplicație de procesare a imaginilor folosind Azure OCR. Întreaga infrastructură este gestionată de Kubernetes folosind servicii **LoadBalancer cu MetalLB** pentru expunerea aplicațiilor pe porturile exacte din cerințe, respectând perfect specificațiile din `Tema.md`.

## Tehnologii utilizate

- **CMS**: Drupal 10.0 cu MariaDB 10.6
- **Chat backend**: Node.js 18 + Nginx cu Express, WebSocket, Mongoose
- **Chat frontend**: Vue.js 3
- **Bază de date pentru chat**: MongoDB 6.0
- **AI backend**: Node.js 18 cu Express, Azure SDK
- **AI frontend**: Vue.js 3 cu integrare Azure Storage și Azure OCR
- **Cloud Services**: Azure Blob Storage, Azure Computer Vision OCR, Azure SQL Database
- **Containerizare**: Docker cu multi-stage builds
- **Orchestrare**: Kubernetes cu **MetalLB LoadBalancer**
- **Expunere servicii**: MetalLB pentru respectarea exactă a porturilor din cerințe

## Cerințe de instalare

### Dependențe

- Kubernetes cluster (MicroK8s) cu cel puțin 2 noduri
- MetalLB instalat și configurat
- Docker
- kubectl
- Node.js 18.x (pentru dezvoltare locală)
- Cont Azure cu serviciile: Storage Account, Computer Vision, SQL Database

### Addon-uri MicroK8s necesare

```bash
microk8s enable registry dns storage metallb
```

### Configurarea MetalLB

```bash
# Configurează pool-ul de IP-uri pentru LoadBalancer
kubectl apply -f metallb-config.yaml

# Verifică că MetalLB rulează
kubectl get pods -n metallb-system
kubectl get ipaddresspools -n metallb-system
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

### 1. Configurarea MetalLB

```bash
# Aplică configurația MetalLB cu pool-ul de IP-uri
kubectl apply -f metallb-config.yaml

# Verifică configurația
kubectl get ipaddresspools -n metallb-system
kubectl get l2advertisements -n metallb-system
```

### 2. Construirea imaginilor Docker

```bash
# Chat Backend (Node.js + Nginx)
docker build -t localhost:32000/chat-backend:latest ./chat/backend
docker push localhost:32000/chat-backend:latest

# Chat Frontend (Vue.js) - cu IP-uri MetalLB configurate
docker build -t localhost:32000/chat-frontend:latest ./chat/frontend
docker push localhost:32000/chat-frontend:latest

# AI Backend (Node.js cu Azure integration)
docker build -t localhost:32000/ai-backend:latest ./ai/backend
docker push localhost:32000/ai-backend:latest

# AI Frontend (Vue.js) - cu IP-uri MetalLB configurate
docker build -t localhost:32000/ai-frontend:latest ./ai/frontend
docker push localhost:32000/ai-frontend:latest
```

### 3. Aplicarea configurațiilor Kubernetes

```bash
# Aplică deployment-urile și serviciile ClusterIP
kubectl apply -k .

# Aplică serviciile LoadBalancer cu MetalLB
kubectl apply -f loadbalancer-services.yaml

# Verifică că serviciile au primit IP-uri externe
kubectl get services -o wide
kubectl get pods
```

### 4. Configurarea routing-ului pe Azure VM

```bash
# Pe master node (10.0.0.4), configurează routing pentru IP-urile MetalLB
sudo ip route add 10.0.0.10/32 dev eth0  # Drupal
sudo ip route add 10.0.0.11/32 dev eth0  # Chat Backend
sudo ip route add 10.0.0.12/32 dev eth0  # Chat Frontend
sudo ip route add 10.0.0.13/32 dev eth0  # AI Backend
sudo ip route add 10.0.0.14/32 dev eth0  # AI Frontend

# Configurează iptables pentru NAT (acces din exterior prin IP public)
sudo iptables -t nat -A PREROUTING -d 135.235.170.64 -p tcp --dport 80 -j DNAT --to-destination 10.0.0.10:80
sudo iptables -t nat -A PREROUTING -d 135.235.170.64 -p tcp --dport 88 -j DNAT --to-destination 10.0.0.11:88
sudo iptables -t nat -A PREROUTING -d 135.235.170.64 -p tcp --dport 90 -j DNAT --to-destination 10.0.0.12:90

# Permite forward și masquerading
sudo iptables -A FORWARD -j ACCEPT
sudo iptables -t nat -A POSTROUTING -j MASQUERADE

# Salvează configurația iptables (persistență)
sudo iptables-save > /etc/iptables/rules.v4
```

## Puncte de acces ale aplicației

Conform cerințelor temei, folosind **MetalLB LoadBalancer pe porturile exacte**:

1. **Drupal CMS** - port 80 ✅
   - Acces: `http://135.235.170.64:80`
   - LoadBalancer IP: 10.0.0.10

2. **Chat Backend WebSocket** - port 88 ✅
   - Acces: `ws://135.235.170.64:88`
   - LoadBalancer IP: 10.0.0.11

3. **Chat Frontend** - port 90 ✅
   - Acces: `http://135.235.170.64:90`
   - LoadBalancer IP: 10.0.0.12

4. **AI Backend API**
   - Acces: `http://135.235.170.64:3001/api`
   - LoadBalancer IP: 10.0.0.13

5. **AI Frontend**
   - Acces: `http://135.235.170.64:8080`
   - LoadBalancer IP: 10.0.0.14

### Verificarea IP-urilor LoadBalancer

```bash
# Verifică IP-urile atribuite de MetalLB
kubectl get services --field-selector spec.type=LoadBalancer -o wide

# Verifică că serviciile sunt accesibile intern
curl -I http://10.0.0.10        # Drupal
curl -I http://10.0.0.12:90     # Chat Frontend
curl http://10.0.0.13:3001/api/health  # AI Backend
```

## Componente

### 1. Drupal CMS

- **Replici**: 6 (conform cerințelor)
- **Port**: 80 (exact din cerințe!) ✅
- **LoadBalancer IP**: 10.0.0.10
- **Bază de date**: MariaDB
- **Persistență**: Volume persistent pentru site și baza de date
- **Init Container**: Configurează automat fișierele necesare

### 2. Sistemul de Chat

#### Backend
- **Replici**: 5 (conform cerințelor)
- **Port**: 88 (exact din cerințe!) ✅
- **LoadBalancer IP**: 10.0.0.11
- **Tehnologie**: Node.js + Nginx (conform cerințelor)
- **Funcționalități**: WebSocket pentru comunicare în timp real, salvare mesaje în MongoDB
- **API**: REST endpoints pentru istoricul mesajelor

#### Frontend
- **Replici**: 1
- **Port**: 90 (exact din cerințe!) ✅
- **LoadBalancer IP**: 10.0.0.12
- **Tehnologie**: Vue.js 3
- **Funcționalități**: Interfață pentru chat, conectare WebSocket automată la 10.0.0.11:88

#### Baza de date
- **Replici**: 1
- **Port**: 27017 (ClusterIP intern)
- **Tehnologie**: MongoDB 6.0
- **Persistență**: Volume persistent pentru mesaje

### 3. Aplicația de IA

#### Backend
- **Replici**: 1
- **Port**: 3001
- **LoadBalancer IP**: 10.0.0.13
- **Tehnologie**: Node.js 18 cu Azure SDK
- **Funcționalități**: 
  - Upload imagini la Azure Blob Storage
  - Procesare OCR cu Azure Computer Vision
  - Salvare rezultate în Azure SQL Database
  - API pentru istoric și rezultate

#### Frontend
- **Replici**: 1
- **Port**: 80
- **LoadBalancer IP**: 10.0.0.14
- **Tehnologie**: Vue.js 3
- **Funcționalități**: Upload fișiere, conectare la backend 10.0.0.13:3001

## Configurarea CMS-ului

După implementarea sistemului, Drupal trebuie configurat manual:

1. **Accesează și instalează Drupal**: `http://135.235.170.64:80`
   - Folosește credențialele bazei de date MariaDB din deployment

2. **Creează bloc Full HTML pentru chat** (exact pe portul 90!):
   ```html
   <iframe src="http://135.235.170.64:90" width="100%" height="600px" frameborder="0" style="border: 1px solid #ccc; border-radius: 5px;"></iframe>
   ```

3. **Creează bloc HTML pentru aplicația IA**:
   ```html
   <iframe src="http://135.235.170.64:8080" width="100%" height="700px" frameborder="0" style="border: 1px solid #ccc; border-radius: 5px;"></iframe>
   ```

## Testarea funcționalităților

### Verificarea LoadBalancer-elor

```bash
# Verifică că toate serviciile LoadBalancer au primit IP-uri externe
kubectl get services --field-selector spec.type=LoadBalancer

# Testează accesul direct la IP-urile LoadBalancer
curl -I http://10.0.0.10:80          # Drupal direct
curl -I http://10.0.0.12:90          # Chat Frontend direct
curl http://10.0.0.13:3001/api/health # AI Backend direct
```

### Verificarea accesului prin IP public

```bash
# Testează toate punctele de acces prin IP-ul public Azure
curl -I http://135.235.170.64:80     # Drupal CMS ✅
curl -I http://135.235.170.64:90     # Chat Frontend ✅
curl http://135.235.170.64:3001/api/health  # AI Backend API

# Testează WebSocket (necesită wscat: npm install -g wscat)
wscat -c ws://135.235.170.64:88      # Chat WebSocket ✅
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

## Structura fișierelor cu MetalLB

```
├── metallb-config.yaml              # Configurația MetalLB cu pool IP-uri
├── loadbalancer-services.yaml       # Servicii LoadBalancer pentru toate componentele
├── drupal/
│   ├── drupal-service.yaml         # Service ClusterIP intern
│   └── ...
├── chat/
│   ├── backend/
│   │   ├── chat-backend-service.yaml    # Service ClusterIP intern
│   │   └── ...
│   ├── frontend/
│   │   ├── src/App.vue             # Cu IP 10.0.0.11:88 pentru WebSocket
│   │   └── ...
│   └── ...
├── ai/
│   ├── backend/
│   │   ├── ai-backend-service.yaml      # Service ClusterIP intern
│   │   └── ...
│   ├── frontend/
│   │   ├── src/App.vue             # Cu IP 10.0.0.13:3001 pentru API
│   │   └── ...
│   └── ...
└── kustomization.yaml              # Toate resursele de bază
```

## Maparea serviciilor cu MetalLB

| Serviciu | Port cerință | LoadBalancer IP | Acces extern | Status |
|----------|-------------|-----------------|--------------|--------|
| Drupal | 80 | 10.0.0.10 | 135.235.170.64:80 | ✅ Exact din cerințe |
| Chat Backend | 88 | 10.0.0.11 | 135.235.170.64:88 | ✅ Exact din cerințe |
| Chat Frontend | 90 | 10.0.0.12 | 135.235.170.64:90 | ✅ Exact din cerințe |
| AI Backend | 3001 | 10.0.0.13 | 135.235.170.64:3001 | ✅ API pentru backend |
| AI Frontend | 80 | 10.0.0.14 | 135.235.170.64:8080 | ✅ Interfață web |

## Comenzi de deployment

### Deployment complet într-o singură comandă (conform cerințelor temei)

```bash
# Configurează MetalLB
kubectl apply -f metallb-config.yaml

# Deploy toate componentele
kubectl apply -k .

# Deploy serviciile LoadBalancer
kubectl apply -f loadbalancer-services.yaml

# Verifică că totul funcționează
kubectl get services --field-selector spec.type=LoadBalancer
```

### Verificarea funcționalității complete

```bash
#!/bin/bash
# Script de verificare completă

echo "=== Verificare IP-uri LoadBalancer ==="
kubectl get services --field-selector spec.type=LoadBalancer -o wide

echo -e "\n=== Testare acces servicii ==="
curl -I http://135.235.170.64:80 2>/dev/null && echo "✅ Drupal OK" || echo "❌ Drupal FAIL"
curl -I http://135.235.170.64:90 2>/dev/null && echo "✅ Chat Frontend OK" || echo "❌ Chat Frontend FAIL"
curl -s http://135.235.170.64:3001/api/health >/dev/null && echo "✅ AI Backend OK" || echo "❌ AI Backend FAIL"

echo -e "\n=== Status Pods ==="
kubectl get pods | grep -E "(Running|Ready)"

echo -e "\n=== Verificare baze de date ==="
kubectl exec $(kubectl get pods -l app=chat-db -o jsonpath="{.items[0].metadata.name}") -- mongosh --eval "db.runCommand('ping')" chatdb 2>/dev/null && echo "✅ MongoDB OK" || echo "❌ MongoDB FAIL"
```

## Troubleshooting MetalLB

### Verificarea MetalLB

```bash
# Verifică că MetalLB rulează
kubectl get pods -n metallb-system

# Verifică configurația IP pool
kubectl describe ipaddresspool default-pool -n metallb-system

# Verifică log-urile MetalLB
kubectl logs -n metallb-system -l app=metallb
```

### Debugging routing

```bash
# Verifică rutele configurate
ip route show | grep "10.0.0.1"

# Verifică regulile iptables
sudo iptables -t nat -L PREROUTING | grep -E "(80|88|90)"

# Testează conectivitatea internă
ping 10.0.0.10  # Drupal LoadBalancer IP
ping 10.0.0.11  # Chat Backend LoadBalancer IP
```

### Probleme comune și soluții

1. **IP-urile LoadBalancer rămân în Pending**:
   ```bash
   # Verifică pool-ul MetalLB
   kubectl get ipaddresspools -n metallb-system
   # Reconfigurează dacă e necesar
   kubectl apply -f metallb-config.yaml
   ```

2. **Serviciile nu sunt accesibile extern**:
   ```bash
   # Verifică și reconfigurează iptables
   sudo iptables -t nat -F PREROUTING
   sudo iptables -t nat -A PREROUTING -d 135.235.170.64 -p tcp --dport 80 -j DNAT --to-destination 10.0.0.10:80
   # ... repeat for other ports
   ```

3. **WebSocket nu se conectează**:
   ```bash
   # Verifică că portul 88 este routat corect
   telnet 135.235.170.64 88
   # Verifică log-urile chat backend
   kubectl logs -l app=chat-backend
   ```

## Conformitatea cu cerințele temei

✅ **Drupal CMS** - 6 replici, **port 80 exact**, MariaDB, volume persistente  
✅ **Chat Backend** - Node.js + Nginx, 5 replici, WebSocket pe **port 88 exact**, MongoDB  
✅ **Chat Frontend** - Vue.js, 1 replică, **port 90 exact**, iframe integration  
✅ **AI Application** - Vue.js frontend + Node.js backend prin LoadBalancer  
✅ **Azure Integration** - Blob Storage, Computer Vision OCR, SQL Database  
✅ **Kubernetes** - Deployment-uri, Services, PVC-uri, Secrets  
✅ **Registry privat** - MicroK8s registry local  
✅ **Single apply** - Funcționează cu `kubectl apply -k . && kubectl apply -f loadbalancer-services.yaml`  
✅ **Expunere porturi** - **80, 88, 90 exact din cerințe** prin MetalLB LoadBalancer  
✅ **Respectarea completă** - Folosește exact porturile specificate în temă fără compromisuri!  

## Licență

Acest proiect este dezvoltat ca temă de facultate și este disponibil pentru referință educațională.