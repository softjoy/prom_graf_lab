#!/bin/bash

set -e

# Update packages
sudo apt update
sudo apt upgrade -y

# Creating a group and user for Prometheus
sudo groupadd --system prometheus
sudo useradd -s /sbin/nologin --system -g prometheus prometheus
sudo mkdir -p /etc/prometheus /var/lib/prometheus

# Download and configure Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.43.0/prometheus-2.43.0.linux-amd64.tar.gz
tar xvf prometheus-2.43.0.linux-amd64.tar.gz
cd prometheus-2.43.0.linux-amd64
sudo mv prometheus promtool /usr/local/bin/
sudo chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool
sudo mv consoles console_libraries /etc/prometheus/
sudo mv prometheus.yml /etc/prometheus/
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
cd ..
rm -rf prometheus-2.43.0.linux-amd64.tar.gz prometheus-2.43.0.linux-amd64

# Creating Prometheus service file
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOT
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOT

# Creating Prometheus config file
sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOT
global:
  scrape_interval: 15s
  external_labels:
    monitor: 'prometheus'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'nginx-node-exporter'
    static_configs:
      - targets: ['${nginx_webserver_ip}:9100']
EOT

# Reload systemd, enable and start Prometheus service
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus

# Creating user and installing Node Exporter
sudo useradd --no-create-home --shell /bin/false node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvf node_exporter-1.6.1.linux-amd64.tar.gz
sudo mv node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
rm -rf node_exporter-1.6.1.linux-amd64.tar.gz node_exporter-1.6.1.linux-amd64

# Creating Node Exporter service file
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOT
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOT

# Reload systemd, enable and start Node Exporter service
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter

# Install Grafana
sudo apt install -y gnupg curl software-properties-common
curl -fsSL https://packages.grafana.com/gpg.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/grafana.gpg
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
sudo apt update
sudo apt install -y grafana
sudo systemctl enable --now grafana-server

# Optional: Setting hostname
sudo hostnamectl set-hostname prom