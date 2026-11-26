#!/usr/bin/env bash
# Checagem prévia (só leitura) para computador compartilhado. Uso: bash scripts/preflight.sh
ok()    { echo "  [ OK ] $1"; }
falha() { echo "  [FALHA] $1"; }

lsmod | grep -q '^kvm' && falha "KVM carregado (conflita com o VirtualBox): sudo modprobe -r kvm_intel kvm_amd kvm" || ok "KVM descarregado"

VMS=$(VBoxManage list runningvms)
[ -n "$VMS" ] && { falha "VMs ligadas (de outro grupo?): o DHCP/DNS delas responde na mesma rede"; echo "$VMS"; } || ok "nenhuma VM ligada"

VBoxManage list dhcpservers | grep -q vboxnet0 && ok "servidor DHCP existe em vboxnet0" \
  || falha "sem servidor DHCP em vboxnet0 (o gatilho do Vagrantfile falharia): VBoxManage dhcpserver add --interface=vboxnet0 --server-ip=192.168.56.100 --netmask=255.255.255.0 --lower-ip=192.168.56.101 --upper-ip=192.168.56.254 --enable"

for p in 2201 2202 2203 2204; do ss -ltn | grep -q ":$p " && falha "porta $p em uso"; done
sudo -n true 2>/dev/null || echo "  [AVISO] sudo pede senha: rode 'sudo -v' antes do vagrant up"
