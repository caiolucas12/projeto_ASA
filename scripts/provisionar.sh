#!/usr/bin/env bash
# Chamado automaticamente pelo Vagrantfile quando a última VM (cli) termina de subir.
# Também pode ser rodado à mão para refazer tudo: bash scripts/provisionar.sh
#   1) hospedeiro: só o cli no /etc/hosts + DNS do arq para o domínio + SSH   -> pede a senha do sudo
#   2) remove o DHCP do VirtualBox (o Vagrant o recria ao subir o cli e ele concorreria com o do arq)
#   3) roda o Ansible (site.yml) nas 4 VMs
#   4) confere se arq, db, app e cli resolvem pelo nome
cd "$(dirname "$0")/.."
REDE_VBOX="${REDE_VBOX:-vboxnet0}"

echo "=== [1/4] Nomes e SSH no hospedeiro (pode pedir a senha do sudo) ==="
bash scripts/configurar-host.sh || echo "AVISO: não foi possível configurar o hospedeiro. Depois rode: bash scripts/configurar-host.sh"

echo "=== [2/4] Desabilitando o DHCP do VirtualBox ==="
if command -v VBoxManage >/dev/null 2>&1; then
  VBoxManage dhcpserver remove --network="HostInterfaceNetworking-${REDE_VBOX}" 2>/dev/null || true
  if VBoxManage list dhcpservers 2>/dev/null | grep -q "HostInterfaceNetworking-${REDE_VBOX}"; then
    echo "AVISO: DHCP do VirtualBox continua ativo em ${REDE_VBOX}; confira o nome com: VBoxManage list dhcpservers"
  fi
fi

echo "=== [3/4] Configurando as VMs com Ansible ==="
bash scripts/rodar-ansible.sh || { echo "ERRO no Ansible. Corrija e rode de novo: bash scripts/rodar-ansible.sh"; exit 1; }

echo "=== [4/4] Conferindo a resolução de nomes no hospedeiro ==="
bash scripts/configurar-host.sh --verificar || echo "AVISO: veja a mensagem acima antes de rodar o verificador do professor."

echo
echo "=== Tudo pronto. Verificação: python3 scripts/verifica-proj1.py $(awk '/^dominio:/ {print $2}' ansible/group_vars/all.yml | sed 's/\.devops$//') ==="
