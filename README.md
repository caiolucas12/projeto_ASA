# Projeto ASA
Projeto 01 - DevOps com Vagrant e Ansible.

- **Integrantes:** Gabriel (matrícula 20251380035) e Caio (matrícula 20251380034)
- **Disciplina:** Administração de Sistemas Abertos
- **Instituição:** IFPB, campus João Pessoa
- **Professor:** Leonidas Lima
- **Período:** 2026.2

## Descrição
O `Vagrantfile` cria 4 VMs Debian (`debian/bookworm64`) no VirtualBox e o Ansible configura cada uma:

| VM  | Função |
|-----|--------|
| arq | Servidor de arquivos: DHCP, DNS, NFS (3 discos extras de 10 GB) |
| db  | Servidor de banco de dados (IP por DHCP, reserva por MAC) |
| app | Servidor de aplicação com Apache (IP por DHCP, reserva por MAC) |
| cli | Host cliente com Firefox e X11 |

Domínio: `gabriel.caio.devops` (ex.: `arq.gabriel.caio.devops`).

## Estrutura de arquivos
```
Vagrantfile              # define as 4 VMs (detecta Windows automaticamente)
hosts-windows.txt        # linhas para o arquivo hosts do Windows
Doc/                     # enunciado do projeto (PDF)
ansible/
  ansible.cfg
  inventory.ini          # hosts e portas SSH (uso com Ansible no WSL/Linux)
  site.yml               # playbook principal (executa todos na ordem)
  common.yml             # usuários, SSH, chrony, timezone
  arq.yml  db.yml  app.yml  cli.yml
  clientes.yml           # roda por último: eth1 via DHCP, autofs/NFS e DNS do arq em db, app e cli
  group_vars/all.yml     # variáveis (nomes, matrículas, IPs)
  templates/             # dhcpd, named (DNS), zonas, index.html
teste/
  inventory.ini          # inventário para rodar de dentro da VM arq
  rodar.sh               # executa o site.yml dentro da arq
  verificar.sh           # checagens do enunciado (rodar em cada VM)
  README.md  RESULTADO.md
```

## Matrículas e IPs
IPs: arq `.135` (XX=35), db `.134` (YY=34) e app `.154`.

**Ponto em aberto - "1XY" do app:** adotamos XY = último dígito de cada matrícula (5 e 4), logo `.154`.
Se o professor definir outra interpretação, basta mudar **em um único lugar**: `ansible/group_vars/all.yml`
(`matricula_gabriel`, `matricula_caio`, `final_arq`, `final_db`, `final_app`) e atualizar `hosts-windows.txt`.
A variável `XX` do `Vagrantfile` deve ser igual a `final_arq` (IP do arq `192.168.56.1XX`).

## Pré-requisitos (Windows)
- VirtualBox
- Vagrant

Não é preciso instalar o Ansible no Windows: ele é instalado e executado de dentro da VM `arq`
(a pasta do projeto fica em `/vagrant`). Com WSL/Linux também é possível rodar `ansible/` direto do hospedeiro.

## Passo a passo (PowerShell, na pasta do projeto)
1. Suba as VMs (o `arq` é o servidor DHCP/DNS das outras; o Vagrant sobe na ordem do `Vagrantfile`):
   ```
   vagrant up
   vagrant status
   ```
2. Confira as portas SSH e, se diferirem de `teste/inventory.ini`, ajuste o arquivo (db, app e cli usam `10.0.2.2` com portas diferentes):
   ```
   vagrant ssh-config
   ```
3. Copie a chave insecure do Vagrant para a `arq` (só na primeira vez; o inventário de teste usa `~/.ssh/insecure_key`):
   ```
   vagrant upload "$env:USERPROFILE\.vagrant.d\insecure_private_key" /home/vagrant/.ssh/insecure_key arq
   vagrant ssh arq -c "chmod 600 ~/.ssh/insecure_key"
   ```
4. (Opcional) Valide a sintaxe dos playbooks:
   ```
   vagrant ssh arq -c "cd /vagrant/ansible && ansible-playbook -i ../teste/inventory.ini --syntax-check site.yml"
   ```
5. Execute o Ansible de dentro da `arq` (instala o Ansible se faltar):
   ```
   vagrant ssh arq -c "bash /vagrant/teste/rodar.sh"
   ```
   Alternativa com WSL/Linux: `cd ansible; ansible-playbook -i inventory.ini site.yml`
   (a chave `~/.vagrant.d/insecure_private_key` precisa existir no home do WSL com `chmod 600`).

## Rede host-only no Windows
O `Vagrantfile` já detecta o Windows e usa `REDE = "VirtualBox Host-Only Ethernet Adapter"` (no Linux/macOS, `vboxnet0`).
Os gatilhos `trigger` removem o servidor DHCP do VirtualBox nessa rede, antes e depois do `vagrant up`, para que
quem atenda DHCP seja o `arq`. Se o nome do seu adaptador for outro, ajuste `REDE`. Para ver os nomes:
```
VBoxManage list dhcpservers
VBoxManage list hostonlyifs
```

## Resolução de nomes no hospedeiro
O Windows não usa o DNS do arq. Há duas opções (o projeto não altera o Windows sozinho):

**Opção 1 - arquivo hosts.** Abra o Bloco de Notas como Administrador, abra
`C:\Windows\System32\drivers\etc\hosts` e cole as linhas de `hosts-windows.txt` (IPs de `ansible/group_vars/all.yml`;
o `cli` recebe 192.168.56.50 por DHCP). Teste: `ping arq.gabriel.caio.devops`.

**Opção 2 - DNS no adaptador host-only.** Em Configurações de rede > adaptador "VirtualBox Host-Only Ethernet Adapter" >
IPv4 > DNS preferencial `192.168.56.135`.

Dentro de cli, db e app a resolução já funciona pelo DNS do arq: `getent hosts db.gabriel.caio.devops`.

## Chave SSH dos usu?rios gabriel e caio
Em `ansible/common.yml` s?o criados o grupo `ifpb` e os usu?rios `gabriel` e `caio`. Cada usu?rio recebe seu **pr?prio par de chaves**
(`generate_ssh_key`) e a chave p?blica dele ? colocada no pr?prio `authorized_keys` (m?dulo `authorized_key`).
O usu?rio `vagrant` continua com a chave insecure do Vagrant, usada pelo Ansible. O SSH aceita apenas chave (sem senha, sem root),
somente para os grupos `vagrant` e `ifpb`, e mostra o banner de aviso.
O login por chave de gabriel e caio, e a recusa de senha e de root, est?o registrados em `teste/RESULTADO.md`.
## Como validar
Rápido: em cada VM rode `vagrant ssh <vm> -c "bash /vagrant/teste/verificar.sh"`. Resultados anteriores estão em `teste/RESULTADO.md`.

Manualmente:
- **Nomes (DNS):** em db/app/cli, `nslookup arq.gabriel.caio.devops` e `nslookup app.gabriel.caio.devops`; também `hostname -f`.
- **NFS:** no arq, `exportfs -v`; em db/app/cli, `ls /var/nfs` (monta via autofs) e crie um arquivo para ver se aparece nas outras VMs.
- **Apache:** no app, `systemctl status apache2`; acesse `http://192.168.56.154` no navegador (página com as matrículas).
- **X11:** conecte ao cli com `ssh -X` e rode `firefox-esr`; a janela deve abrir no host.
