#!/bin/bash

# sauvegarde du dossier /var/www/html, de la base de données MySQL et de la configuration Apache
USER="root"
REMOTE_SERVER=""
BACKUP_DIR=("/var/www/html" "/var/lib/mysql" "/etc/apache2")
REMOTE_BACKUP_DIR="/home/backups"


