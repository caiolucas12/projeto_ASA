#!/usr/bin/env bash
# Pós-"vagrant up": chamado pelo Vagrantfile quando a última VM (cli) sobe. Também roda à mão.
#   1) configura o hospedeiro   2) configura as 4 VMs com Ansible   3) confere a resolução de nomes
set -e
cd "$(dirname "$0")/.."
DOM=$(awk '/^dominio:/ {print $2}' ansible/group_vars/all.yml)

bash scripts/configurar-host.sh || echo "AVISO: hospedeiro não configurado (rode: bash scripts/configurar-host.sh)"

cd ansible
# lvg, lvol, filesystem, mount e authorized_key vêm de coleções (o pacote "ansible" já as inclui)
ansible-doc -t module community.general.lvg >/dev/null 2>&1 || ansible-galaxy collection install -r requirements.yml
ansible-playbook site.yml

for h in arq db app cli; do getent hosts "$h.$DOM" || echo "FALHA: $h.$DOM não resolve"; done
