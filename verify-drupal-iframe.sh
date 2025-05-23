#!/bin/bash

# Verification script for Drupal iframe integration
set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Get node IP
NODE_IP=$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "🌐 Node IP: $NODE_IP"

# Test 1: Check if Drupal pages contain correct IP
echo "🔍 Checking Drupal pages for correct iframe URLs..."

# Get Chat page content
CHAT_CONTENT=$(microk8s kubectl exec $(microk8s kubectl get pods -l app=drupal -o name | head -1) -- drush ev "
\$node = \Drupal::entityTypeManager()->getStorage('node')->load(1);
if (\$node) {
    echo \$node->body->value;
}
" 2>/dev/null)

if echo "$CHAT_CONTENT" | grep -q "$NODE_IP:30090"; then
    print_success "Chat page contains correct iframe URL ($NODE_IP:30090)"
else
    print_error "Chat page does not contain correct iframe URL"
    echo "Expected: $NODE_IP:30090"
    echo "Found: $(echo "$CHAT_CONTENT" | grep -o 'http://[^"]*:30090' || echo 'No iframe found')"
fi

# Get AI page content
AI_CONTENT=$(microk8s kubectl exec $(microk8s kubectl get pods -l app=drupal -o name | head -1) -- drush ev "
\$node = \Drupal::entityTypeManager()->getStorage('node')->load(2);
if (\$node) {
    echo \$node->body->value;
}
" 2>/dev/null)

if echo "$AI_CONTENT" | grep -q "$NODE_IP:30180"; then
    print_success "AI page contains correct iframe URL ($NODE_IP:30180)"
else
    print_error "AI page does not contain correct iframe URL"
    echo "Expected: $NODE_IP:30180"
    echo "Found: $(echo "$AI_CONTENT" | grep -o 'http://[^"]*:30180' || echo 'No iframe found')"
fi

# Test 2: Check if iframe content is accessible
echo "🌐 Testing iframe content accessibility..."

if curl -s -I "http://$NODE_IP:30090" | grep -q "200"; then
    print_success "Chat frontend is accessible for iframe"
else
    print_error "Chat frontend is not accessible"
fi

if curl -s -I "http://$NODE_IP:30180" | grep -q "200"; then
    print_success "AI frontend is accessible for iframe"
else
    print_error "AI frontend is not accessible"
fi

# Test 3: Check Drupal pages are accessible
echo "🗂️  Testing Drupal page accessibility..."

if curl -s "http://$NODE_IP:30080/node/1" | grep -q "iframe"; then
    print_success "Chat page in Drupal loads and contains iframe"
else
    print_error "Chat page in Drupal does not load or contain iframe"
fi

if curl -s "http://$NODE_IP:30080/node/2" | grep -q "iframe"; then
    print_success "AI page in Drupal loads and contains iframe"
else
    print_error "AI page in Drupal does not load or contain iframe"
fi

echo ""
echo "🔗 Manual Test URLs:"
echo "   Drupal Chat page:  http://$NODE_IP:30080/node/1"
echo "   Drupal AI page:    http://$NODE_IP:30080/node/2" 
echo "   Standalone Chat:   http://$NODE_IP:30090"
echo "   Standalone AI:     http://$NODE_IP:30180"

echo ""
echo "🎯 What to check manually:"
echo "   1. Open the Drupal Chat page in browser"
echo "   2. Verify the chat interface loads inside the iframe"
echo "   3. Test sending a message in the iframe"
echo "   4. Verify it works the same as the standalone version"