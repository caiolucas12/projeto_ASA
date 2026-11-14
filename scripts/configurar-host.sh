#!/usr/bin/env bash
# Prepara o HOSPEDEIRO (Linux) para acessar as VMs pelo nome:
#   1) /etc/hosts com arq/db/app/cli (IPs lidos de ansible/group_vars/all.yml)
#   2) ~/.ssh/config sem checagem de known_hosts para o domínio (VMs recriadas mudam a chave de host)
# Uso (na raiz do projeto): bash scripts/configurar-host.sh
set -euo pipefail
cd "$(dirname "$0")/.."
V=ansible/group_vars/all.yml
dominio=$(awk '/^dominio:/ {print $2}' "$V")
final() { grep -E "^$1:" "$V" | sed -E 's/^[^"]*"([^"]*)".*/\1/'; }
IP_ARQ="192.168.56.1$(final final_arq)"
IP_DB="192.168.56.1$(final final_db)"
IP_APP="192.168.56.1$(final final_app)"
IP_CLI="192.168.56.$(final final_cli)"

sudo sed -i '/# BEGIN projeto-asa/,/# END projeto-asa/d' /etc/hosts
sudo tee -a /etc/hosts >/dev/null <<EOT
# BEGIN projeto-asa
$IP_ARQ arq.$dominio arq
$IP_DB  db.$dominio  db
$IP_APP app.$dominio app
$IP_CLI cli.$dominio cli
# END projeto-asa
EOT

mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/config && chmod 600 ~/.ssh/config
sed -i '/# BEGIN projeto-asa/,/# END projeto-asa/d' ~/.ssh/config
# o bloco vai no INÍCIO do arquivo (o ssh usa o primeiro valor encontrado)
{ cat <<EOT
# BEGIN projeto-asa
Host *.$dominio
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
# END projeto-asa

EOT
  cat ~/.ssh/config; } > ~/.ssh/config.new && mv ~/.ssh/config.new ~/.ssh/config && chmod 600 ~/.ssh/config

echo "Pronto. Teste: ping -c1 arq.$dominio"
