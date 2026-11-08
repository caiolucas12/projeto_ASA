# Teste dos playbooks (Windows)

Sem Ansible no Windows, roda-se de dentro da VM arq (pasta do projeto em /vagrant):

    vagrant up
    vagrant ssh arq -c "bash /vagrant/teste/rodar.sh"

O inventario de teste (inventory.ini) usa 10.0.2.2 (host visto pela VM) com as portas SSH do Vagrant (confira com `vagrant ssh-config`).
Antes da 1a execucao, copie a chave insecure do Vagrant para ~/.ssh/insecure_key na arq (chmod 600).
