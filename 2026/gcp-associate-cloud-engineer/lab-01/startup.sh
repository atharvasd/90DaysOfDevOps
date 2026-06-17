#!/bin/bash
apt-get-update
apt-get install -y apache2
echo "Hello from GCE web server -$(hostname)" > /var/www/html/index.html
systemctl start apache2
