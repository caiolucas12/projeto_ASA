#!/usr/bin/env bash
# Roda o site.yml do Ansible com verificações prévias. Uso: bash scripts/rodar-ansible.sh [opções do ansible-playbook]
set -euo pipefail
cd "$(dirname "$0")/../ansible"
# força o uso do ansible.cfg (o Ansible o ignora em diretórios gravaveis por todos, ex.: /mnt/c no WSL)
export ANSIBLE_CONFIG="$PWD/ansible.cfg"

command -v ansible-playbook >/dev/null || { echo "ERRO: ansible não instalado (sudo apt install ansible)"; exit 1; }
KEY="${HOME}/.vagrant.d/insecure_private_key"
[ -f "$KEY" ] || { echo "ERRO: $KEY não existe. Rode 'vagrant up' antes."; exit 1; }
chmod 600 "$KEY"
# módulos lvg/lvol/filesystem/mount/authorized_key vivem em coleções
ansible-doc -t module community.general.lvg >/dev/null 2>&1 && ansible-doc -t module ansible.posix.mount >/dev/null 2>&1 \
  || ansible-galaxy collection install -r requirements.yml
ansible all -m ping -o || { echo "ERRO: alguma VM não responde. Confira 'vagrant status' e as portas (2201-2204)."; exit 1; }
exec ansible-playbook site.yml "$@"
