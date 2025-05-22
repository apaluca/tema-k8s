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
- **Orchestrare**: Kubernetes (MicroK8s) cu Ingress Controller + MetalLB
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
microk8s enable registry dns storage ingress metallb
```

**IMPORTANT**: MetalLB este esențial pentru funcționarea serviciilor LoadBalancer și a Ingress-ului!

## Configurarea infrastructurii Kubernetes

### 1. Configurarea MetalLB (OBLIGATORIU)

MetalLB este necesar pentru ca serviciile LoadBalancer să primească IP-uri externe și pentru ca Ingress-ul să funcționeze corect.

#### Pas 1: Verifică rețeaua ta
```bash
# Verifică IP-ul mașinii tale
hostname -I

# Verifică gateway-ul implicit
ip route | grep default

# Exemplu de output:
# default via 192.168.1.1 dev enp0s3 proto dhcp metric 100
```

#### Pas 2: Activează MetalLB
```bash
microk8s enable metallb
```

#### Pas 3: Configurează range-ul de IP-uri
Când MetalLB te întreabă de range, folosește un interval din aceeași rețea:

**Exemple de configurație:**
- Dacă IP-ul tău este `192.168.1.50` → folosește `192.168.1.100-192.168.1.110`
- Dacă IP-ul tău este `10.0.0.25` → folosește `10.0.0.100-10.0.0.110`
- Dacă IP-ul tău este `172.16.1.15` → folosește `172.16.1.100-172.16.1.110`

#### Pas 4: Verifică configurația MetalLB
```bash
# Verifică că MetalLB rulează
kubectl get pods -n metallb-system

# Verifică configurația
kubectl get configmap -n metallb-system
```

### 2. Verificarea Ingress Controller

```bash
# Verifică că Ingress Controller rulează
kubectl get pods -n ingress

# Ar trebui să vezi:
# nginx-ingress-microk8s-controller-xxxxx   1/1     Running
```

### 3. Restart Ingress dacă este necesar

Dacă Ingress nu funcționează corect:

```bash
microk8s disable ingress
microk8s enable ingress

# Verifică din nou
kubectl get pods -n ingress
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

### 1. Verificarea pre-implementare

```bash
# Verifică că toate addon-urile sunt active
microk8s status

# Ar trebui să vezi:
# - dns                  # (core) CoreDNS
# - ingress              # (core) Ingress controller for external access
# - metallb              # (core) Loadbalancer for your Kubernetes cluster
# - registry             # (core) Private image registry exposed on localhost:32000
# - storage              # (core) Alias to hostpath-storage add-on

# Verifică că MetalLB funcționează
kubectl get pods -n metallb-system
kubectl get configmap -n metallb-system

# Verifică că Ingress funcționează
kubectl get pods -n ingress
```

### 2. Construirea imaginilor Docker

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

### 3. Aplicarea configurațiilor Kubernetes

```bash
# Aplicare folosind kustomize (recomandat)
kubectl apply -k .

# Verificarea deployment-urilor
kubectl get pods
kubectl get services
kubectl get ingress
```

### 4. Verificarea funcționării MetalLB

După aplicarea configurațiilor, verifică că serviciile LoadBalancer primesc IP-uri externe:

```bash
kubectl get services

# OUTPUT AȘTEPTAT:
# NAME              TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)
# chat-backend      LoadBalancer   10.152.183.x     192.168.1.100    88:xxxxx/TCP
# chat-frontend     LoadBalancer   10.152.183.x     192.168.1.101    90:xxxxx/TCP
# drupal            ClusterIP      10.152.183.x     <none>           80/TCP
# ai-backend        ClusterIP      10.152.183.x     <none>           3001/TCP
# ai-frontend       ClusterIP      10.152.183.x     <none>           80/TCP
```

**NOTĂ**: Dacă serviciile LoadBalancer rămân în starea `<pending>` la EXTERNAL-IP, înseamnă că MetalLB nu este configurat corect!

## Puncte de acces ale aplicației

### Obținerea IP-ului de acces

```bash
# Găsește IP-ul pentru acces
kubectl get services chat-frontend -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Sau vezi toate IP-urile
kubectl get services
```

### Conform cerințelor temei:

1. **Drupal CMS** - port 80
   - Acces: `http://<EXTERNAL_IP>:80` sau `http://<EXTERNAL_IP>/`
   - Tip: Ingress routing

2. **Chat Backend WebSocket** - port 88
   - Acces: `ws://<EXTERNAL_IP>:88`
   - Tip: LoadBalancer direct

3. **Chat Frontend** - port 90 + routing alternativ
   - **Acces direct**: `http://<EXTERNAL_IP>:90` (LoadBalancer)
   - **Acces prin Ingress**: `http://<EXTERNAL_IP>/chat` (routing inteligent)
   - **Ambele opțiuni sunt funcționale**

### Puncte de acces adiționale prin Ingress:

4. **AI Frontend**: `http://<EXTERNAL_IP>/ai`
5. **AI Backend API**: `http://<EXTERNAL_IP>/api`

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

1. **Accesează și instalează Drupal**: `http://<EXTERNAL_IP>:80`
   - Folosește credențialele bazei de date MariaDB din deployment

2. **Creează bloc Full HTML pentru chat** (ai două opțiuni):
   
   **Opțiunea 1 - Acces direct pe port (conform cerințelor):**
   ```html
   <iframe src="http://<EXTERNAL_IP>:90" width="100%" height="600px" frameborder="0" style="border: 1px solid #ccc; border-radius: 5px;"></iframe>
   ```
   
   **Opțiunea 2 - Acces prin Ingress (routing elegant):**
   ```html
   <iframe src="http://<EXTERNAL_IP>/chat" width="100%" height="600px" frameborder="0" style="border: 1px solid #ccc; border-radius: 5px;"></iframe>
   ```

3. **Creează bloc HTML pentru aplicația IA**:
   ```html
   <iframe src="http://<EXTERNAL_IP>/ai" width="100%" height="700px" frameborder="0" style="border: 1px solid #ccc; border-radius: 5px;"></iframe>
   ```

## Testarea funcționalităților

### Verificarea punctelor de acces

```bash
# Obține IP-ul extern
EXTERNAL_IP=$(kubectl get services chat-frontend -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "External IP: $EXTERNAL_IP"

# Testează toate punctele de acces
curl -I http://$EXTERNAL_IP:80          # Drupal CMS
curl -I http://$EXTERNAL_IP:90          # Chat Frontend (direct)
curl -I http://$EXTERNAL_IP/chat        # Chat Frontend (Ingress)
curl -I http://$EXTERNAL_IP/ai          # AI Frontend
curl http://$EXTERNAL_IP/api/health     # AI Backend API
```

### Verificarea MetalLB și Load Balancers

```bash
# Verifică starea MetalLB
kubectl get pods -n metallb-system
kubectl logs -n metallb-system -l app=metallb

# Verifică serviciile LoadBalancer
kubectl get services
kubectl describe service chat-backend
kubectl describe service chat-frontend

# Verifică că IP-urile externe sunt asignate
kubectl get services -o wide | grep LoadBalancer
```

### Verificarea Ingress

```bash
# Verifică configurația Ingress
kubectl get ingress
kubectl describe ingress main-ingress
kubectl describe ingress api-ingress

# Verifică log-urile Ingress Controller
kubectl logs -n ingress -l app.kubernetes.io/name=nginx-ingress-microk8s
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
# Obține IP-ul extern
EXTERNAL_IP=$(kubectl get services chat-backend -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Verifică log-urile pentru WebSocket
kubectl logs -l app=chat-backend -f

# Testează WebSocket cu wscat (dacă ai npm)
npm install -g wscat
wscat -c ws://$EXTERNAL_IP:88
```

### Testarea aplicației AI

```bash
# Obține IP-ul extern
EXTERNAL_IP=$(kubectl get services chat-frontend -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Verifică health check
curl http://$EXTERNAL_IP/api/health

# Verifică istoricul procesărilor
curl http://$EXTERNAL_IP/api/history
```

### Verificarea persistenței datelor

```bash
# Testează persistența prin repornirea pod-urilor
kubectl delete pod $(kubectl get pods -l app=chat-db -o jsonpath="{.items[0].metadata.name}")
kubectl delete pod $(kubectl get pods -l app=drupal-db -o jsonpath="{.items[0].metadata.name}")

# Verifică că datele persistă după recreare
```

## Troubleshooting

### Probleme comune cu MetalLB

#### Serviciile LoadBalancer rămân în starea `<pending>`

```bash
# Verifică că MetalLB rulează
kubectl get pods -n metallb-system

# Verifică configurația MetalLB
kubectl get configmap -n metallb-system metallb-config -o yaml

# Verifică log-urile MetalLB
kubectl logs -n metallb-system -l app=metallb

# Re-activează MetalLB dacă este necesar
microk8s disable metallb
microk8s enable metallb
```

#### Range-ul de IP-uri nu este corect

```bash
# Verifică rețeaua ta din nou
ip route | grep default
hostname -I

# Re-configurează MetalLB cu range-ul corect
microk8s disable metallb
microk8s enable metallb
# Folosește range-ul corect pentru rețeaua ta
```

### Probleme cu Ingress

#### Ingress nu rutează corect

```bash
# Verifică că Ingress Controller rulează
kubectl get pods -n ingress

# Verifică configurația Ingress
kubectl get ingress
kubectl describe ingress main-ingress

# Verifică log-urile Ingress
kubectl logs -n ingress -l app.kubernetes.io/name=nginx-ingress-microk8s

# Re-activează Ingress dacă este necesar
microk8s disable ingress
microk8s enable ingress
```

#### Probleme de conectivitate

```bash
# Testează conectivitatea internă
kubectl run test-pod --image=busybox --rm -it -- sh
# În pod: wget -qO- http://drupal
# În pod: wget -qO- http://chat-frontend
# În pod: wget -qO- http://ai-backend:3001/api/health
```

### Verificarea log-urilor complete

```bash
# Script pentru verificarea tuturor componentelor
echo "=== MetalLB Status ==="
kubectl get pods -n metallb-system
kubectl logs -n metallb-system -l app=metallb --tail=5

echo "=== Ingress Status ==="
kubectl get pods -n ingress
kubectl logs -n ingress -l app.kubernetes.io/name=nginx-ingress-microk8s --tail=5

echo "=== Services Status ==="
kubectl get services

echo "=== AI Backend ==="
kubectl logs $(kubectl get pods -l app=ai-backend -o jsonpath="{.items[0].metadata.name}") --tail=5

echo "=== Chat Backend ==="
kubectl logs $(kubectl get pods -l app=chat-backend -o jsonpath="{.items[0].metadata.name}") --tail=5

echo "=== Drupal ==="
kubectl logs $(kubectl get pods -l app=drupal -o jsonpath="{.items[0].metadata.name}") --tail=5
```

### Diagnosticarea problemelor de routing

```bash
# Verifică serviciile
kubectl get services
kubectl describe service chat-frontend
kubectl describe service ai-backend

# Verifică endpoint-urile
kubectl get endpoints

# Verifică configurația DNS
kubectl run test-dns --image=busybox --rm -it -- nslookup chat-frontend
```

## Reinstalarea completă în caz de probleme

Dacă întâmpini probleme majore:

```bash
# Șterge toate resursele
kubectl delete -k . --ignore-not-found

# Re-activează addon-urile în ordine
microk8s disable ingress metallb
microk8s enable metallb
# Configurează din nou range-ul de IP-uri
microk8s enable ingress

# Verifică că totul funcționează
kubectl get pods -n metallb-system
kubectl get pods -n ingress

# Re-aplică configurația
kubectl apply -k .
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
✅ **MetalLB** - LoadBalancer pentru servicii externe  
✅ **Routing flexibil** - Ingress pentru accesibilitate îmbunătățită  

## Note importante

- **MetalLB este OBLIGATORIU** pentru ca serviciile LoadBalancer să funcționeze
- **Range-ul de IP-uri** trebuie să fie din aceeași rețea cu mașina ta
- **Ingress Controller** trebuie să ruleze pentru ca rutarea să funcționeze
- **Toate addon-urile** (dns, storage, registry, ingress, metallb) trebuie să fie active
- **Aplicațiile independente**: Chat și IA sunt complet independente de CMS, integrate prin iframe
- **Expunere servicii**: WebSocket pentru chat expus direct, API și frontend-uri prin Ingress
- **Securitate**: Bazele de date folosesc ClusterIP pentru securitate internă
- **Scalabilitate**: Frontend-urile sunt stateless și pot fi scalate
- **Persistența**: Toate datele sunt stocate în volume persistente și servicii Azure

## Licență

Acest proiect este dezvoltat ca temă de facultate și este disponibil pentru referință educațională.