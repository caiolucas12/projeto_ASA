#!/usr/bin/env bash
# Ao terminar num computador compartilhado: desliga as VMs (--destroy apaga), limpa o hospedeiro
# e reabilita o DHCP do VirtualBox (último passo da prática 05). Uso: bash scripts/finalizar.sh [--destroy]
cd "$(dirname "$0")/.."
if [ "$1" = "--destroy" ]; then vagrant destroy -f; else vagrant halt; fi
bash scripts/configurar-host.sh --limpar
VBoxManage dhcpserver start --interface vboxnet0
