#!/bin/bash
# Roda o site.yml de dentro da VM arq (pasta do projeto em /vagrant).
# Uso (no Windows): vagrant ssh arq -c "bash /vagrant/teste/rodar.sh"
set -e
command -v ansible-playbook >/dev/null || { sudo apt-get update -qq; sudo apt-get install -y -qq ansible; }
cd /vagrant/ansible
ansible-playbook -i /vagrant/teste/inventory.ini site.yml "$@"
