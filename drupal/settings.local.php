<?php

/**
 * Configurări locale pentru Drupal în Kubernetes
 */

// Configurări pentru baza de date
$databases['default']['default'] = [
  'database' => 'drupal',
  'username' => 'drupal',
  'password' => 'drupal_password',
  'prefix' => '',
  'host' => 'drupal-db',
  'port' => '3306',
  'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
  'driver' => 'mysql',
];

// Configurări pentru cache și performanță
$settings['cache']['bins']['render'] = 'cache.backend.null';
$settings['cache']['bins']['page'] = 'cache.backend.null';
$settings['cache']['bins']['dynamic_page_cache'] = 'cache.backend.null';

// Configurări pentru debugging (doar pentru development)
$config['system.logging']['error_level'] = 'verbose';

// Configurări pentru hash salt
$settings['hash_salt'] = 'kubernetes-drupal-demo-salt-key-2024';

// Configurări pentru directorul de configurație
$settings['config_sync_directory'] = '../config/sync';

// Configurări pentru trusted host patterns (permite toate pentru demo)
$settings['trusted_host_patterns'] = [
  '^.+$',
];

// Configurări pentru fișiere
$settings['file_public_path'] = 'sites/default/files';
$settings['file_private_path'] = 'sites/default/files/private';
$settings['file_temp_path'] = '/tmp';

// Configurări pentru instalare automată
$settings['install_profile'] = 'minimal';