#!/bin/bash
set -e

echo "🧹 Starting complete cleanup and redeploy..."

# Culori pentru output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Șterge toate resursele Drupal
print_step "Cleaning up ALL Drupal resources..."
microk8s kubectl delete deployment drupal --ignore-not-found=true
microk8s kubectl delete deployment drupal-db --ignore-not-found=true

# Așteaptă ca pod-urile să se termine
print_step "Waiting for Drupal pods to terminate..."
microk8s kubectl wait --for=delete pod -l app=drupal --timeout=120s || true
microk8s kubectl wait --for=delete pod -l app=drupal-db --timeout=120s || true

# Șterge PVC-urile Drupal pentru a începe cu o stare curată
print_warning "Deleting Drupal PVCs for clean start..."
microk8s kubectl delete pvc drupal-sites-pvc --ignore-not-found=true
microk8s kubectl delete pvc drupal-themes-pvc --ignore-not-found=true
microk8s kubectl delete pvc drupal-modules-pvc --ignore-not-found=true
microk8s kubectl delete pvc drupal-profiles-pvc --ignore-not-found=true
microk8s kubectl delete pvc drupal-vendor-pvc --ignore-not-found=true
microk8s kubectl delete pvc drupal-db-pvc --ignore-not-found=true

print_success "Cleanup completed"

# Așteaptă puțin pentru ca resursele să fie complet șterse
print_step "Waiting for resources to be fully cleaned up..."
sleep 10

# Re-deploy doar resursele Drupal
print_step "Deploying Drupal resources..."
microk8s kubectl apply -f drupal/drupal-db-pvc.yaml
microk8s kubectl apply -f drupal/drupal-pvc.yaml
microk8s kubectl apply -f drupal/drupal-db-deployment.yaml
microk8s kubectl apply -f drupal/drupal-db-service.yaml

# Așteaptă ca drupal-db să fie ready
print_step "Waiting for drupal-db to be ready..."
microk8s kubectl wait --for=condition=ready pod -l app=drupal-db --timeout=180s

print_success "drupal-db is ready"

# Deploy Drupal deployment
print_step "Deploying Drupal application..."
microk8s kubectl apply -f drupal/drupal-deployment.yaml
microk8s kubectl apply -f drupal/drupal-service.yaml

# Așteaptă ca Drupal să fie ready
print_step "Waiting for Drupal pods to be ready..."
microk8s kubectl wait --for=condition=ready pod -l app=drupal --timeout=300s

print_success "Drupal deployment completed!"

# Verifică statusul
print_step "Checking final status..."
echo ""
echo "🔍 Pod Status:"
microk8s kubectl get pods -l app=drupal -o wide
microk8s kubectl get pods -l app=drupal-db -o wide

echo ""
echo "📊 Service Status:"
microk8s kubectl get services drupal drupal-db

# Obține IP-ul nodului
NODE_IP=$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo ""
echo "🌐 Drupal Access:"
echo "  URL: http://$NODE_IP:30080"
echo ""
print_success "Drupal cleanup and redeploy completed!"
print_warning "Visit http://$NODE_IP:30080 to complete Drupal installation"
print_warning "Database settings: host=drupal-db, name=drupal, user=drupal, pass=drupalpassword"