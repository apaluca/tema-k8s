# Site Web cu Chat și IA peste Kubernetes

## Descriere

Proiect academic care implementează un site web complet cu:
- **CMS Drupal** (6 replici, MariaDB)
- **Sistem de chat** în timp real (WebSocket, Node.js + Nginx, Vue.js, MongoDB)
- **Aplicație AI OCR** (Azure Computer Vision, Azure Blob Storage, Azure SQL)

Infrastructura este gestionată complet prin **Kubernetes** cu expunere prin **NodePort services**.

## Arhitectura sistemului

### Stack tehnologic
- **Backend**: Node.js 18, Express, WebSocket, Nginx
- **Frontend**: Vue.js 3, Axios
- **Baze de date**: MariaDB, MongoDB, Azure SQL
- **Cloud**: Azure Blob Storage, Computer Vision OCR
- **Containerizare**: Docker multi-stage builds
- **Orchestrare**: Kubernetes (MicroK8s)

### Maparea serviciilor

| Componentă | Replici | Port intern | NodePort | URL extern |
|------------|---------|-------------|----------|------------|
| Drupal CMS | 6 | 80 | 30080 | `http://NODE_IP:30080` |
| Chat Backend | 5 | 80 | 30088 | `ws://NODE_IP:30088` |
| Chat Frontend | 1 | 80 | 30090 | `http://NODE_IP:30090` |
| AI Backend | 1 | 3001 | 30101 | `http://NODE_IP:30101` |
| AI Frontend | 1 | 80 | 30180 | `http://NODE_IP:30180` |

## Cerințe și dependențe

### Kubernetes
```bash
# Addon-uri MicroK8s necesare
microk8s enable registry dns hostpath-storage
```

### Azure Services
1. **Storage Account** cu container "images"
2. **Computer Vision** pentru OCR  
3. **SQL Database** cu SQL Authentication

### Variabile de mediu (Azure)
```bash
# În secrets/azure-secrets.yaml (base64 encoded)
AZURE_STORAGE_CONNECTION_STRING
AZURE_OCR_API_KEY  
AZURE_SQL_CONNECTION_STRING
```

## Instalare și deployment

### 1. Configurare secrete Azure
```bash
echo -n "your_storage_connection_string" | base64
echo -n "your_ocr_api_key" | base64  
echo -n "your_sql_connection_string" | base64
# Actualizează secrets/azure-secrets.yaml
```

### 2. Build și push imagini
```bash
docker build -t localhost:32000/chat-backend:latest ./chat/backend
docker push localhost:32000/chat-backend:latest

docker build -t localhost:32000/chat-frontend:latest ./chat/frontend  
docker push localhost:32000/chat-frontend:latest

docker build -t localhost:32000/ai-backend:latest ./ai/backend
docker push localhost:32000/ai-backend:latest

docker build -t localhost:32000/ai-frontend:latest ./ai/frontend
docker push localhost:32000/ai-frontend:latest
```

### 3. Deploy complet (o singură comandă)
```bash
kubectl apply -k .
```

### 4. Verificare
```bash
# Status servicii NodePort
kubectl get services --field-selector spec.type=NodePort -o wide

# Status pods
kubectl get pods

# IP nod Kubernetes
kubectl get nodes -o wide
```

## Configurare post-deployment

### Drupal CMS setup
1. Accesează `http://NODE_IP:30080`
2. Instalează Drupal cu credențialele MariaDB din deployment
3. Adaugă blocuri HTML pentru integrarea iframe:

**Chat integration:**
```html
<iframe src="http://NODE_IP:30090" width="100%" height="600px" 
        frameborder="0" style="border: 1px solid #ccc; border-radius: 5px;">
</iframe>
```

**AI integration:**
```html
<iframe src="http://NODE_IP:30180" width="100%" height="700px" 
        frameborder="0" style="border: 1px solid #ccc; border-radius: 5px;">
</iframe>
```

## Testare și verificare

### Conectivitate servicii
```bash
NODE_IP="your_node_ip"  # Înlocuiește cu IP-ul real

# Test endpoints
curl -I http://$NODE_IP:30080              # Drupal
curl -I http://$NODE_IP:30090              # Chat Frontend  
curl http://$NODE_IP:30101/api/health      # AI Backend

# Test WebSocket
wscat -c ws://$NODE_IP:30088               # Chat Backend
```

### Verificare baze de date
```bash
# MongoDB (chat)
kubectl exec -it $(kubectl get pods -l app=chat-db -o jsonpath="{.items[0].metadata.name}") -- mongosh
# use chatdb; db.messages.find()

# MariaDB (Drupal)  
kubectl exec -it $(kubectl get pods -l app=drupal-db -o jsonpath="{.items[0].metadata.name}") -- mysql -u drupal -pdrupal_password drupal
```

## Structura proiectului

```
├── kustomization.yaml              # Orchestrare Kubernetes
├── secrets/azure-secrets.yaml     # Credențiale Azure
├── drupal/                        # CMS cu MariaDB
│   ├── drupal-deployment.yaml
│   ├── drupal-service.yaml
│   ├── drupal-pvc.yaml
│   └── drupal-db-*
├── chat/                          # Sistem chat complet
│   ├── backend/                   # Node.js + Nginx + WebSocket
│   ├── frontend/                  # Vue.js client
│   └── db/                        # MongoDB
└── ai/                           # Aplicație OCR
    ├── backend/                   # Node.js + Azure SDK
    └── frontend/                  # Vue.js upload interface
```

## Componente detaliate

### Chat System
- **Backend**: Express server cu WebSocket pentru comunicare în timp real
- **Database**: MongoDB pentru persistența mesajelor  
- **Frontend**: Vue.js cu conectare automată la WebSocket
- **Features**: Istoric mesaje, utilizatori multipli, reconnectare automată

### AI Application  
- **Upload**: Interfață Vue.js pentru încărcare imagini
- **Processing**: Azure Computer Vision OCR
- **Storage**: Azure Blob Storage pentru imagini
- **History**: Azure SQL Database pentru rezultate
- **API**: REST endpoints pentru management

### Drupal Integration
- **CMS**: Drupal 10.0 cu MariaDB backend
- **Integration**: Iframe embedding pentru chat și AI
- **Persistence**: Volume persistente pentru conținut și baza de date

## Troubleshooting

### Servicii NodePort nu răspund
```bash
kubectl get pods                    # Verifică status pods
kubectl logs -l app=drupal         # Log-uri aplicație
ss -tlnp | grep 30080              # Port deschis pe nod
```

### WebSocket connection failed  
```bash
kubectl logs -l app=chat-backend   # Log-uri chat backend
telnet NODE_IP 30088               # Test conectivitate port
```

### Azure services errors
```bash
kubectl logs -l app=ai-backend     # Log-uri AI backend
kubectl get secrets azure-secrets -o yaml  # Verifică secrete
```

## Conformitate cerințe temă

✅ **Drupal CMS** - 6 replici, echivalent port 80 (NodePort 30080)  
✅ **Chat Backend** - Node.js + Nginx, 5 replici, echivalent port 88 (NodePort 30088)  
✅ **Chat Frontend** - Vue.js, 1 replică, echivalent port 90 (NodePort 30090)  
✅ **AI Application** - Upload imagini, Azure OCR, istoric rezultate  
✅ **Azure Integration** - Blob Storage, Computer Vision, SQL Database  
✅ **Kubernetes** - Deployment-uri, Services, PVC-uri, Secrets  
✅ **Registry privat** - MicroK8s registry localhost:32000  
✅ **Single apply** - Deployment complet cu `kubectl apply -k .`

## Licență

Acest proiect este dezvoltat ca temă de facultate și este disponibil pentru referință educațională.