#!/usr/bin/env bash
# Prepara o hospedeiro Linux para acessar as VMs pelo nome (pede a senha do sudo).
#   sem argumentos  só o cli vai para o /etc/hosts; arq, db e app resolvem pelo DNS do arq
#   --limpar        desfaz tudo (use ao sair de um computador compartilhado)
cd "$(dirname "$0")/.."
V=ansible/group_vars/all.yml
DOM=$(awk '/^dominio:/ {print $2}' $V)
val() { sed -n "s/^$1: *\"\([^\"]*\)\".*/\1/p" $V; }
IP_ARQ=192.168.56.1$(val final_arq)
IP_CLI=192.168.56.$(val final_cli)
IFACE=$(ip -4 -o addr | awk '$4 ~ /^192\.168\.56\.1\// {print $2; exit}')   # host-only (vboxnet0)

limpar() {
  sudo sed -i '/# projeto-asa/d' /etc/hosts
  grep -q 'projeto-asa' /etc/resolv.conf && sudo sed -i --follow-symlinks '/# projeto-asa/,+1d' /etc/resolv.conf
  [ -n "$IFACE" ] && sudo resolvectl revert "$IFACE" 2>/dev/null
  [ -f ~/.ssh/config ] && sed -i '/# BEGIN projeto-asa/,/# END projeto-asa/d' ~/.ssh/config
  return 0
}

limpar
[ "$1" = "--limpar" ] && { echo "Hospedeiro limpo."; exit 0; }

# 1) só o cli em /etc/hosts (o IP dele vem do DHCP, não está na zona do enunciado)
echo "$IP_CLI cli.$DOM cli # projeto-asa" | sudo tee -a /etc/hosts >/dev/null

# 2) o hospedeiro consulta o DNS do arq para o domínio do projeto
if systemctl is-active -q systemd-resolved && readlink -f /etc/resolv.conf | grep -q systemd/resolve; then
  [ -n "$IFACE" ] || { echo "ERRO: interface 192.168.56.1 não existe (suba as VMs antes)"; exit 1; }
  sudo resolvectl dns "$IFACE" "$IP_ARQ"
  sudo resolvectl domain "$IFACE" "~$DOM"
else   # sem systemd-resolved: nameserver no topo do /etc/resolv.conf
  tmp=$(mktemp); { printf '# projeto-asa\nnameserver %s\n' "$IP_ARQ"; cat /etc/resolv.conf; } > "$tmp"
  sudo cp "$tmp" /etc/resolv.conf; rm -f "$tmp"
fi

# 3) ssh sem checagem de known_hosts no domínio (VMs recriadas mudam a chave de host)
mkdir -p ~/.ssh; touch ~/.ssh/config; chmod 600 ~/.ssh/config
printf '# BEGIN projeto-asa\nHost *.%s\n    StrictHostKeyChecking no\n    UserKnownHostsFile /dev/null\n    LogLevel ERROR\n# END projeto-asa\n' "$DOM" \
  | cat - ~/.ssh/config > ~/.ssh/config.new && mv ~/.ssh/config.new ~/.ssh/config
echo "Hospedeiro pronto: cli em /etc/hosts, DNS $IP_ARQ para $DOM."
