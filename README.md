# Projeto 01 - DevOps com Vagrant e Ansible

| | |
|---|---|
| **Integrantes** | Gabriel (matrícula 20251380035) e Caio (matrícula 20251380034) |
| **Disciplina** | Administração de Sistemas Abertos |
| **Instituição** | IFPB, campus João Pessoa |
| **Professor** | Leonidas Lima |
| **Período** | 2026.2 |
| **Domínio** | `gabriel.caio.devops` |

## Descrição

O **Vagrant** cria 4 VMs Debian 12 (`debian/bookworm64`) no VirtualBox e o **Ansible** configura todas elas.

| VM | IP | Função |
|----|----|--------|
| `arq` | `192.168.56.135` (fixo) | DHCP autoritativo, DNS (bind9, zonas direta/reversa), LVM (VG `dados`, LV `ifpb` 15 GB em `/dados`) e NFS (`/dados/nfs`) |
| `db`  | `192.168.56.134` (DHCP, reserva por MAC) | MariaDB + autofs |
| `app` | `192.168.56.154` (DHCP, reserva por MAC) | Apache2 (página com descrição e matrículas) + autofs |
| `cli` | `192.168.56.50` (DHCP, pool 50-100) | Firefox + X11 forwarding + autofs |

Em todas: chrony (`pool.ntp.br`), fuso `America/Recife`, grupo `ifpb`, usuários `gabriel` e `caio`, sudo para o grupo `ifpb`,
SSH só por chave, sem root, `AllowGroups vagrant ifpb`, banner de aviso e `nfs-common`.

O NFS do `arq` (`/dados/nfs`) usa `all_squash` para o usuário `nfs-ifpb` (sem shell), com `sync,no_wdelay`;
`db`, `app` e `cli` montam em `/var/nfs` via autofs.

> O enunciado só pede `arq`, `db` e `app` no DNS. Também há um registro `cli` (192.168.56.50) porque o script de
> verificação acessa `cli.<dominio>`. Para o IP ser sempre o mesmo, o `cli` tem MAC fixo no Vagrantfile.

## Estrutura

```
Vagrantfile                 # 4 VMs (portas SSH fixas 2201-2204)
Doc/                        # enunciado
scripts/
  configurar-host.sh        # /etc/hosts + ~/.ssh/config do hospedeiro
  rodar-ansible.sh          # checagens + ansible-playbook site.yml
  verifica-proj1.py         # script de verificação do professor
ansible/
  ansible.cfg  inventory.ini  requirements.yml
  site.yml                  # executa tudo, na ordem abaixo
  chaves.yml                # gera keys/<nome> no hospedeiro
  common.yml                # todas as VMs: updates, chrony, usuários, SSH, sudo
  arq.yml  db.yml  app.yml  cli.yml
  clientes.yml              # db/app/cli: eth1 por DHCP, autofs, DNS do arq (roda por último)
  group_vars/all.yml        # nomes, matrículas e finais de IP (único lugar a editar)
  templates/                # dhcpd, bind (opções, zonas), index.html
keys/                       # (gerada, NÃO versionada) chaves SSH dos integrantes
teste/                      # alternativa: rodar o Ansible de dentro da VM arq (hospedeiro sem Ansible)
```

## Pré-requisitos (hospedeiro Linux)

VirtualBox, Vagrant **>= 2.3** (suporte a `vm.disk`), Ansible (pacote `ansible`, não só `ansible-core`),
`openssh-client` e `python3`. Para o `-X` do Firefox: servidor X no hospedeiro.

```
sudo apt install ansible openssh-client python3
```

## Execução

```bash
git clone https://github.com/caiolucas12/projeto_ASA.git && cd projeto_ASA

vagrant up                          # cria as 4 VMs (arq primeiro)
VBoxManage list dhcpservers         # deve vir VAZIO (gatilho removeu o DHCP do VirtualBox)

bash scripts/rodar-ansible.sh       # gera keys/, configura as 4 VMs (leva vários minutos)
bash scripts/configurar-host.sh     # nomes no hospedeiro (pede sudo)

python3 scripts/verifica-proj1.py gabriel.caio    # verificação do professor (rodar na raiz do projeto)
```

Para refazer do zero: `vagrant destroy -f && vagrant up` e rode o Ansible de novo.

## Como validar manualmente

- **Nomes:** `ping arq.gabriel.caio.devops`; em db/app/cli: `getent hosts app.gabriel.caio.devops`.
- **SSH:** `ssh -i keys/gabriel gabriel@arq.gabriel.caio.devops` (senha e root devem ser recusados).
- **DHCP/DNS (arq):** `sudo systemctl status isc-dhcp-server bind9`; `dig @192.168.56.135 -x 192.168.56.154`.
- **LVM (arq):** `sudo vgs; sudo lvs dados/ifpb; findmnt /dados`.
- **NFS:** em db/app/cli `ls /var/nfs`; crie um arquivo e veja o dono `nfs-ifpb` no `arq`.
- **Apache:** `http://app.gabriel.caio.devops` (ou `curl`).
- **X11:** `ssh -X -i keys/caio caio@cli.gabriel.caio.devops firefox-esr`.

## Problemas comuns

| Sintoma | Causa / solução |
|---|---|
| `couldn't resolve module/action 'lvg'` | Só o `ansible-core` está instalado: `ansible-galaxy collection install -r ansible/requirements.yml` |
| Ansible ignora o `ansible.cfg` ("world writable directory") | Projeto em `/mnt/c` (WSL). Use `scripts/rodar-ansible.sh` ou mova o projeto para `~` |
| `UNREACHABLE` / `Connection refused` na 2201-2204 | VM desligada ou porta ocupada: `vagrant status`; `vagrant ssh-config` |
| `Permissions ... too open` na chave | `chmod 600 ~/.vagrant.d/insecure_private_key` |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | VMs recriadas: rode `scripts/configurar-host.sh` (desativa known_hosts para o domínio) |
| `VBoxManage list dhcpservers` não vazio | Rede com outro nome: ajuste `REDE` no Vagrantfile (`VBoxManage list hostonlyifs`) |

## Windows (sem Ansible no hospedeiro)

O script de verificação precisa de um hospedeiro Linux. No Windows é possível apenas configurar as VMs rodando o
Ansible de dentro da `arq` (ver `teste/README.md`); nesse modo as chaves de `keys/` são geradas dentro da VM.
Para acessar por nome no Windows, adicione os 4 nomes ao `C:\Windows\System32\drivers\etc\hosts`.
