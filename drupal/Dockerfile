# Build stage - Drupal cu configurare automată
FROM drupal:10.0-apache AS build

# Instalează utilitățile necesare
RUN apt-get update && apt-get install -y \
    netcat-traditional \
    default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

# Copiază script-ul de instalare și configurare
COPY install-and-configure.sh /install-and-configure.sh
COPY settings.local.php /opt/drupal/web/sites/default/
COPY custom-theme/ /opt/drupal/web/themes/custom/kubernetes_theme/

# Configurează permisiunile
RUN chmod +x /install-and-configure.sh \
    && chown -R www-data:www-data /opt/drupal/web/sites/default/ \
    && chown -R www-data:www-data /opt/drupal/web/themes/custom/

# Production stage
FROM drupal:10.0-apache

# Copiază tot din build stage
COPY --from=build /install-and-configure.sh /install-and-configure.sh
COPY --from=build /opt/drupal/web/sites/default/settings.local.php /opt/drupal/web/sites/default/
COPY --from=build /opt/drupal/web/themes/custom/ /opt/drupal/web/themes/custom/

# Instalează dependențele pentru netcat și mysql client
RUN apt-get update && apt-get install -y \
    netcat-traditional \
    default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

# Configurează permisiunile finale
RUN chown -R www-data:www-data /opt/drupal/web/sites/default/ \
    && chown -R www-data:www-data /opt/drupal/web/themes/custom/ \
    && chmod +x /install-and-configure.sh

# Schimbă directorul de lucru
WORKDIR /opt/drupal/web

# Script de pornire
CMD ["/install-and-configure.sh"]