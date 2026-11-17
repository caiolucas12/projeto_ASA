#!/usr/bin/env bash
# Prepara o HOSPEDEIRO (Linux) para acessar as VMs pelo nome.
#
# PADRÃO (sem argumentos):
#   - /etc/hosts recebe SÓ o cli (o IP dele vem do DHCP, não está no enunciado do DNS)
#   - arq, db e app são resolvidos pelo DNS do arq (192.168.56.135), que o hospedeiro passa a usar:
#       a) com systemd-resolved: só para o domínio do projeto (resolvectl), sem mexer no resto;
#       b) sem systemd-resolved: acrescenta "nameserver <ip do arq>" no topo do /etc/resolv.conf
#          (o arq encaminha o resto da internet para 1.1.1.1 e 8.8.8.8).
#   - ~/.ssh/config sem checagem de known_hosts para o domínio (VMs recriadas mudam a chave de host)
#
# OUTRAS OPÇÕES:
#   --verificar   confere se arq, db, app e cli resolvem (rodar DEPOIS do Ansible)
#   --hosts       alternativa: grava os 4 nomes no /etc/hosts (não usa o DNS)
#   --limpar      desfaz tudo (/etc/hosts, resolvedor e ~/.ssh/config) - use ao sair de um computador compartilhado
#
# Os IPs são lidos de ansible/group_vars/all.yml.
set -euo pipefail
cd "$(dirname "$0")/.."

ACAO=dns
case "${1:-}" in
  ""|--dns) ACAO=dns ;;
  --hosts) ACAO=hosts ;;
  --limpar) ACAO=limpar ;;
  --verificar) ACAO=verificar ;;
  *) echo "Uso: $0 [--dns|--hosts|--verificar|--limpar]"; exit 2 ;;
esac

V=ansible/group_vars/all.yml
dominio=$(awk '/^dominio:/ {print $2}' "$V")
final() { grep -E "^$1:" "$V" | sed -E 's/^[^"]*"([^"]*)".*/\1/'; }
IP_ARQ="192.168.56.1$(final final_arq)"
IP_DB="192.168.56.1$(final final_db)"
IP_APP="192.168.56.1$(final final_app)"
IP_CLI="192.168.56.$(final final_cli)"
MARCA_I="# BEGIN projeto-asa"
MARCA_F="# END projeto-asa"

# interface host-only do hospedeiro (a que tem 192.168.56.1)
IFACE=$(ip -4 -o addr show 2>/dev/null | awk '$4 ~ /^192\.168\.56\.1\// {print $2; exit}' || true)

tem_resolved() {
  command -v resolvectl >/dev/null 2>&1 \
    && systemctl is-active --quiet systemd-resolved 2>/dev/null \
    && readlink -f /etc/resolv.conf | grep -q 'systemd/resolve'
}
tira_bloco() {   # remove o nosso bloco, preservando links simbólicos
  [ -e "$1" ] && grep -q "$MARCA_I" "$1" && sudo sed -i --follow-symlinks "/$MARCA_I/,/$MARCA_F/d" "$1" || true
}
config_ssh() {
  mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/config && chmod 600 ~/.ssh/config
  sed -i "/$MARCA_I/,/$MARCA_F/d" ~/.ssh/config
  { cat <<EOT
$MARCA_I
Host *.$dominio
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
$MARCA_F

EOT
    cat ~/.ssh/config; } > ~/.ssh/config.new && mv ~/.ssh/config.new ~/.ssh/config && chmod 600 ~/.ssh/config
}

case "$ACAO" in
limpar)
  tira_bloco /etc/hosts
  tira_bloco /etc/resolv.conf
  if [ -n "${IFACE:-}" ] && command -v resolvectl >/dev/null 2>&1; then sudo resolvectl revert "$IFACE" 2>/dev/null || true; fi
  [ -f ~/.ssh/config ] && sed -i "/$MARCA_I/,/$MARCA_F/d" ~/.ssh/config
  echo "Hospedeiro limpo (/etc/hosts, resolvedor e ~/.ssh/config)."
  ;;

verificar)
  falhas=0
  for h in arq db app cli; do
    if r=$(getent hosts "$h.$dominio"); then echo "  [ OK ] $r"; else echo "  [FALHA] $h.$dominio não resolve"; [ "$h" != cli ] && falhas=$((falhas+1)); fi
  done
  if [ "$falhas" -gt 0 ]; then
    echo "arq/db/app não resolvem pelo DNS. O bind do arq está no ar? Teste: dig @$IP_ARQ app.$dominio +short"
    echo "Alternativa: bash scripts/configurar-host.sh --hosts"
    exit 1
  fi
  echo "Resolução de nomes OK."
  ;;

hosts)
  tira_bloco /etc/hosts
  sudo tee -a /etc/hosts >/dev/null <<EOT
$MARCA_I
$IP_ARQ arq.$dominio arq
$IP_DB  db.$dominio  db
$IP_APP app.$dominio app
$IP_CLI cli.$dominio cli
$MARCA_F
EOT
  tira_bloco /etc/resolv.conf
  if [ -n "${IFACE:-}" ] && command -v resolvectl >/dev/null 2>&1; then sudo resolvectl revert "$IFACE" 2>/dev/null || true; fi
  config_ssh
  echo "Modo hosts: os 4 nomes estão no /etc/hosts."
  ;;

dns)
  # 1) só o cli no /etc/hosts
  tira_bloco /etc/hosts
  sudo tee -a /etc/hosts >/dev/null <<EOT
$MARCA_I
$IP_CLI cli.$dominio cli
$MARCA_F
EOT
  # 2) o hospedeiro passa a consultar o DNS do arq para o domínio do projeto
  if tem_resolved; then
    if [ -z "${IFACE:-}" ]; then
      echo "ERRO: não achei a interface host-only (192.168.56.1). Suba as VMs (vagrant up) e rode de novo."; exit 1
    fi
    sudo resolvectl dns "$IFACE" "$IP_ARQ"
    sudo resolvectl domain "$IFACE" "~$dominio"
    echo "DNS: *.$dominio é resolvido por $IP_ARQ (systemd-resolved, interface $IFACE; some ao reiniciar)."
  else
    tira_bloco /etc/resolv.conf
    tmp=$(mktemp)
    { echo "$MARCA_I"; echo "nameserver $IP_ARQ"; echo "$MARCA_F"; cat /etc/resolv.conf; } > "$tmp"
    sudo cp "$tmp" /etc/resolv.conf && rm -f "$tmp"
    echo "DNS: nameserver $IP_ARQ no topo do /etc/resolv.conf (o NetworkManager pode sobrescrevê-lo; rode de novo se isso ocorrer)."
  fi
  config_ssh
  echo "Só o cli está no /etc/hosts. arq, db e app dependem do DNS do arq (disponível depois do Ansible)."
  echo "Confira depois com: bash scripts/configurar-host.sh --verificar"
  ;;
esac
