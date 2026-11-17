#!/usr/bin/env bash
# Deixa o computador como foi encontrado (use ao terminar a apresentação num computador compartilhado):
#   1) desliga as VMs (ou as apaga, com --destroy)
#   2) desfaz /etc/hosts, resolvedor e ~/.ssh/config deste projeto
#   3) reabilita o DHCP do VirtualBox (último passo da prática 05)
# Uso, na raiz do projeto: bash scripts/finalizar.sh [--destroy]
cd "$(dirname "$0")/.."
if [ "${1:-}" = "--destroy" ]; then vagrant destroy -f; else vagrant halt; fi
bash scripts/configurar-host.sh --limpar || echo "AVISO: rode depois: bash scripts/configurar-host.sh --limpar"
VBoxManage dhcpserver start --interface vboxnet0 2>/dev/null || echo "AVISO: não consegui reabilitar o DHCP do VirtualBox (confira: VBoxManage list dhcpservers)"
echo "Pronto."
