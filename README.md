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
| `arq` | `192.168.56.135` (fixo) | DHCP autoritativo, DNS (bind9, zonas direta e reversa), LVM (VG `dados`, LV `ifpb` de 15 GB em `/dados`) e NFS (`/dados/nfs`) |
| `db`  | `192.168.56.134` (DHCP, reserva por MAC) | MariaDB e autofs |
| `app` | `192.168.56.154` (DHCP, reserva por MAC) | Apache2 (página do projeto) e autofs |
| `cli` | `192.168.56.50` (DHCP, pool 50-100) | Firefox, X11 forwarding e autofs |

Em todas: chrony (`pool.ntp.br`), fuso `America/Recife`, grupo `ifpb`, usuários `gabriel` e `caio`, sudo para o
grupo `ifpb`, SSH só por chave, sem root, `AllowGroups vagrant ifpb`, banner de aviso e `nfs-common`.
O NFS usa `all_squash` para o usuário `nfs-ifpb` (sem shell), com `sync,no_wdelay`; `db`, `app` e `cli` montam
`/dados/nfs` em `/var/nfs` via autofs. O `cli` também está no DNS (o script de verificação usa `cli.<dominio>`).

## Estrutura

```
Vagrantfile              4 VMs, portas SSH fixas (2201-2204), gatilhos (DHCP do VirtualBox e pós-up)
scripts/
  provisionar.sh         pós-up: configura o hospedeiro, roda o Ansible e confere os nomes
  configurar-host.sh     hospedeiro: só o cli no /etc/hosts + DNS do arq + ssh (--limpar desfaz)
  preflight.sh           checagem prévia, somente leitura
  finalizar.sh           desliga as VMs, limpa o hospedeiro, reabilita o DHCP do VirtualBox
  verifica-proj1.py      script de verificação do professor
ansible/
  ansible.cfg  inventory.ini  requirements.yml  group_vars/all.yml (nomes, matrículas, IPs)
  site.yml               executa na ordem: chaves, common, arq, db, app, cli, clientes
  chaves.yml  common.yml  arq.yml  db.yml  app.yml  cli.yml  clientes.yml
  templates/             dhcpd, bind (opções, zonas) e index.html (Jinja2)
keys/                    chaves SSH dos integrantes (geradas, não versionadas)
```

## Execução (hospedeiro Linux)

Requisitos: VirtualBox, Vagrant 2.4.9 ou mais novo, Ansible (pacote `ansible`) e `openssh-client`.
O módulo KVM não pode estar carregado (`sudo modprobe -r kvm_intel kvm_amd kvm`).

```bash
git clone https://github.com/caiolucas12/projeto_ASA.git && cd projeto_ASA
bash scripts/preflight.sh                         # opcional: checa o que atrapalha
sudo -v                                           # senha do sudo em cache (o hospedeiro é configurado no fim)
vagrant up --provider=virtualbox                  # 30 a 40 minutos
python3 scripts/verifica-proj1.py gabriel.caio    # verificação do professor
```

O que acontece no `vagrant up`:

1. **Gatilho do DHCP**: a cada VM iniciada roda `vboxmanage dhcpserver stop --interface vboxnet0`, para só o DHCP
   do `arq` responder. O servidor DHCP do VirtualBox precisa existir em `vboxnet0`.
2. **Pós-up** (gatilho do `cli`, a última VM): `scripts/provisionar.sh` configura o hospedeiro, roda o
   `ansible/site.yml` nas 4 VMs e confere se os nomes resolvem.

Refazer só a configuração: `bash scripts/provisionar.sh`. Subir sem provisionar: `SEM_ANSIBLE=1 vagrant up`.
Refazer do zero: `vagrant destroy -f && vagrant up`. Ao terminar em computador compartilhado: `bash scripts/finalizar.sh`.

### Nomes no hospedeiro

Só o `cli` fica em `/etc/hosts` (o IP vem do DHCP). `arq`, `db` e `app` resolvem pelo DNS do `arq`, configurado
com `resolvectl dns vboxnet0 192.168.56.135` (ou `nameserver` no `/etc/resolv.conf` se não houver `systemd-resolved`).
A regra do `resolvectl` some ao reiniciar o computador: rode `bash scripts/configurar-host.sh` de novo.

## Como validar

- Nomes: `getent hosts app.gabriel.caio.devops`; `dig @192.168.56.135 -x 192.168.56.154 +short`
- SSH: `ssh -i keys/gabriel gabriel@arq.gabriel.caio.devops` (root e senha são recusados)
- DHCP: `vagrant ssh db -c "ip -4 a show eth1"` (`.134`); `vagrant ssh arq -c "sudo tail /var/lib/dhcp/dhcpd.leases"`
- LVM: `vagrant ssh arq -c "sudo pvs; sudo lvs; findmnt /dados"`
- NFS: `vagrant ssh arq -c "sudo exportfs -v"`; em db/app/cli `ls /var/nfs`
- Apache: `curl http://app.gabriel.caio.devops`
- X11: `ssh -X -i keys/caio caio@cli.gabriel.caio.devops firefox-esr`

## Problemas comuns

| Sintoma | Solução |
|---|---|
| `vagrant up` falha no `arq`: `Failed to find DHCP server ... 'vboxnet0'` | Recriar: `VBoxManage dhcpserver add --interface=vboxnet0 --server-ip=192.168.56.100 --netmask=255.255.255.0 --lower-ip=192.168.56.101 --upper-ip=192.168.56.254 --enable` |
| `VERR_VMX_IN_VMX_ROOT_MODE` | Descarregar o KVM (ver Execução) |
| `couldn't resolve module/action 'lvg'` | `ansible-galaxy collection install -r ansible/requirements.yml` |
| Porta 2201-2204 em uso | VMs de outro projeto ligadas: desligá-las |
| Nomes não resolvem | `bash scripts/configurar-host.sh`; sem DNS, acrescentar os 4 nomes ao `/etc/hosts` |
