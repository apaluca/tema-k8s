#!/bin/bash
set -e

echo "Starting Drupal installation and configuration..."

# Funcție pentru a aștepta ca baza de date să fie disponibilă
wait_for_db() {
    echo "Waiting for database to be ready..."
    while ! nc -z drupal-db 3306; do
        echo "Database not ready, waiting..."
        sleep 5
    done
    echo "Database is ready!"
}

# Funcție pentru a verifica dacă Drupal este deja instalat
is_drupal_installed() {
    if [ -f "/opt/drupal/web/sites/default/settings.php" ]; then
        if grep -q "config_sync_directory" /opt/drupal/web/sites/default/settings.php; then
            return 0
        fi
    fi
    return 1
}

# Schimbă la directorul web
cd /opt/drupal/web

# Așteaptă baza de date
wait_for_db

# Verifică dacă Drupal este deja instalat
if is_drupal_installed; then
    echo "Drupal is already installed, starting Apache..."
else
    echo "Installing Drupal..."
    
    # Instalează Drupal folosind Drush
    vendor/bin/drush site:install minimal \
        --db-url=mysql://drupal:drupal_password@drupal-db:3306/drupal \
        --site-name="Kubernetes Demo Site" \
        --account-name=admin \
        --account-pass=admin123 \
        --yes

    # Activează modulele necesare
    echo "Enabling required modules..."
    vendor/bin/drush en block system user node text filter editor ckeditor5 -y

    # Creează conținutul cu iframe-urile
    echo "Creating content with chat and AI integrations..."
    
    # Obține IP-ul nodului (folosim numele serviciului din Kubernetes pentru acces intern)
    NODE_IP=\$(hostname -I | awk '{print \$1}')
    
    # Creează pagina pentru Chat
    vendor/bin/drush php:eval "
    \$node = \\Drupal\\node\\Entity\\Node::create([
        'type' => 'page',
        'title' => 'Live Chat',
        'body' => [
            'value' => '<h2>Real-time Chat Application</h2>
                       <p>Connect and chat with other users in real-time:</p>
                       <iframe src=\"http://\$NODE_IP:30090\" width=\"100%\" height=\"600px\" 
                               frameborder=\"0\" style=\"border: 2px solid #0073aa; border-radius: 8px; margin: 10px 0;\">
                       </iframe>
                       <p><em>Powered by WebSocket technology with Node.js backend and Vue.js frontend.</em></p>',
            'format' => 'full_html'
        ],
        'status' => 1,
        'uid' => 1
    ]);
    \$node->save();
    echo 'Chat page created with ID: ' . \$node->id() . \"\\n\";
    "

    # Creează pagina pentru AI OCR
    vendor/bin/drush php:eval "
    \$node = \\Drupal\\node\\Entity\\Node::create([
        'type' => 'page',
        'title' => 'AI Image Recognition',
        'body' => [
            'value' => '<h2>OCR Image Processing with Azure AI</h2>
                       <p>Upload images to extract text using Azure Computer Vision OCR:</p>
                       <iframe src=\"http://\$NODE_IP:30180\" width=\"100%\" height=\"700px\" 
                               frameborder=\"0\" style=\"border: 2px solid #0073aa; border-radius: 8px; margin: 10px 0;\">
                       </iframe>
                       <p><em>Powered by Azure Computer Vision, Blob Storage, and SQL Database.</em></p>',
            'format' => 'full_html'
        ],
        'status' => 1,
        'uid' => 1
    ]);
    \$node->save();
    echo 'AI OCR page created with ID: ' . \$node->id() . \"\\n\";
    "

    # Creează pagina principală cu linkuri către ambele aplicații
    vendor/bin/drush php:eval "
    \$node = \\Drupal\\node\\Entity\\Node::create([
        'type' => 'page',
        'title' => 'Welcome to Kubernetes Demo',
        'body' => [
            'value' => '<h1>Welcome to our Kubernetes-powered Website!</h1>
                       <div style=\"display: flex; gap: 20px; margin: 20px 0;\">
                           <div style=\"flex: 1; padding: 20px; border: 2px solid #0073aa; border-radius: 8px;\">
                               <h3>💬 Live Chat</h3>
                               <p>Connect with other users in real-time using our WebSocket-powered chat system.</p>
                               <a href=\"/node/1\" style=\"background: #0073aa; color: white; padding: 10px 20px; text-decoration: none; border-radius: 4px;\">Open Chat</a>
                           </div>
                           <div style=\"flex: 1; padding: 20px; border: 2px solid #0073aa; border-radius: 8px;\">
                               <h3>🤖 AI Image Recognition</h3>
                               <p>Upload images and extract text using Azure Computer Vision OCR technology.</p>
                               <a href=\"/node/2\" style=\"background: #0073aa; color: white; padding: 10px 20px; text-decoration: none; border-radius: 4px;\">Try OCR</a>
                           </div>
                       </div>
                       <h2>Architecture Overview</h2>
                       <ul>
                           <li><strong>CMS:</strong> Drupal 10 with MariaDB (6 replicas)</li>
                           <li><strong>Chat:</strong> Node.js + WebSocket backend (5 replicas) + Vue.js frontend</li>
                           <li><strong>AI:</strong> Azure Computer Vision OCR + Blob Storage + SQL Database</li>
                           <li><strong>Infrastructure:</strong> Kubernetes with persistent storage</li>
                       </ul>',
            'format' => 'full_html'
        ],
        'status' => 1,
        'uid' => 1
    ]);
    \$node->save();
    echo 'Welcome page created with ID: ' . \$node->id() . \"\\n\";
    "

    # Setează pagina principală ca homepage
    vendor/bin/drush config:set system.site page.front /node/3 -y

    # Activează tema personalizată
    echo "Activating custom theme..."
    vendor/bin/drush theme:enable kubernetes_theme -y
    vendor/bin/drush config:set system.theme default kubernetes_theme -y

    # Configurează permisiunile finale
    chown -R www-data:www-data sites/default/files
    chmod 755 sites/default
    
    echo "Drupal installation and configuration completed!"
fi

# Pornește Apache în foreground
echo "Starting Apache web server..."
apache2-foreground