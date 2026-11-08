# Resultado dos testes (4 VMs reais no VirtualBox)

Comandos usados (host, PowerShell):

```powershell
$env:Path += ";C:\Program Files\Vagrant\bin"
vagrant ssh <arq|db|app|cli> -c "bash /vagrant/teste/verificar.sh"   # todas as verificacoes
vagrant ssh arq -c "cd /vagrant/ansible && ansible-playbook -i /vagrant/teste/inventory.ini clientes.yml"
```

A saida completa de cada VM esta em `teste/saida.txt` (gerada pelo `verificar.sh`).

## Reteste final do zero (vagrant destroy -f + vagrant up)
Passos: `vagrant destroy -f`, `vagrant up` (4 VMs `running`), chave insecure copiada para a arq (README), `apt-get install ansible` na arq (ansible core 2.14.18), depois duas vezes:
`vagrant ssh arq -c "cd /vagrant/ansible && ansible-playbook -i /vagrant/teste/inventory.ini site.yml"`

1a execucao:
```text
app : ok=29 changed=25 unreachable=0 failed=0 skipped=0
arq : ok=32 changed=30 unreachable=0 failed=0 skipped=0
cli : ok=30 changed=26 unreachable=0 failed=0 skipped=0
db  : ok=28 changed=24 unreachable=0 failed=0 skipped=0
```
2a execucao (idempotencia):
```text
app : ok=25 changed=0 unreachable=0 failed=0 skipped=1
arq : ok=27 changed=0 unreachable=0 failed=0 skipped=0
cli : ok=25 changed=0 unreachable=0 failed=0 skipped=1
db  : ok=24 changed=0 unreachable=0 failed=0 skipped=1
```
Depois `bash /vagrant/teste/verificar.sh` nas 4 VMs: todos os itens da tabela abaixo conferidos de novo (IPs .135/.134/.154/.50, DNS direto/reverso, LVM 15.00g em /dados, NFS all_squash anonuid=1003, autofs nfs4 em db/app/cli com arquivos de root e gabriel gravados como 1003:1004, sshd, usuarios/ifpb/sudo, chrony America/Recife, mariadb/apache2/firefox-esr/xauth). Ao fim, `vagrant destroy -f`.

Falhas achadas no reteste do zero e corrigidas:
- arq: a ordem dos discos muda a cada boot (o disco do sistema apareceu como `sdd`), entao `pvs: /dev/sdb,/dev/sdc,/dev/sdd` pegaria o disco do sistema. Agora o VG usa os discos de 10 GB pelos facts (`ansible_devices`).
- arq: o `dist-upgrade` falhava no `grub-pc` (grub-install no disco errado). Agora o debconf do grub-pc e pre-configurado para nao rodar grub-install (o grub ja esta instalado na box).
- db/app/cli: o `resolv.conf` era reescrito pelo dhclient a cada renovacao do lease (lease de 180 s), quebrando a idempotencia. Agora um hook `make_resolv_conf() { :; }` impede a reescrita.

## Itens

| Item | Resultado | Evidencia |
|---|---|---|
| IP/hostname arq (192.168.56.135, arq.gabriel.caio.devops) | passou | `eth1 192.168.56.135/24`; `hostname -f` ok |
| db = .134 e app = .154 por DHCP/MAC | passou | db `eth1 192.168.56.134/24`, app `192.168.56.154/24`; reservas `08:00:27:00:00:02` e `...03` no dhcpd.conf |
| DHCP entrega IP ao cli | passou | cli `eth1 192.168.56.50/24` (faixa 50-100); lease com `client-hostname "cli"` |
| DHCP: autoritativo, lease 180/3600, dominio, DNS, gateway .1 | passou | `dhcpd.conf` na saida |
| DNS direto/reverso | passou | `dig` em arq/db/cli: 192.168.56.135/.134/.154 e `db.`/`app.gabriel.caio.devops.` |
| Resolucao de nomes em cli/db/app | passou | `getent hosts` dos 3 nomes |
| LVM (VG dados, LV ifpb 15G, ext4, /dados) | passou | `vgs` 3 PV, `lvs` ifpb 15.00g, `findmnt /dados` ext4 |
| NFS exportado para 192.168.56.0/24 | passou | `exportfs -v`: `all_squash,anonuid=1003,sync,no_wdelay` |
| nfs-ifpb sem shell | passou | `/usr/sbin/nologin` |
| autofs monta /var/nfs em db/app/cli | passou | `findmnt`: `arq.gabriel.caio.devops:/dados/nfs nfs4` |
| Escrita NFS so como nfs-ifpb | passou | root e gabriel criam arquivos que ficam com dono 1003:1004 (nfs-ifpb); `/dados/nfs` pertence a nfs-ifpb com modo 755 |
| sshd: sem senha, sem root, AllowGroups vagrant ifpb, banner | passou | `passwordauthentication no`, `permitrootlogin no`, `allowgroups vagrant ifpb`, banner "Acesso apenas para pessoas com autorizacao expressa!!!" |
| X11Forwarding no cli | passou | `x11forwarding yes` |
| Usuarios gabriel/caio no grupo ifpb + sudo | passou | `id`; `%ifpb ALL=(ALL) NOPASSWD: ALL` |
| chrony / America/Recife | passou | `chronyc sources` mostra `*.ntp.br`; `Time zone: America/Recife` |
| mariadb ativo (db) | passou | `active` |
| apache2 com index.html (nomes e matriculas) | passou | `Gabriel (20251380035), Caio (20251380034)` via `wget localhost` na app |
| firefox-esr e xauth no cli | passou | `dpkg -l` ii ii |
| Resolver nomes a partir do hospedeiro (Windows) | nao testado | exige DNS 192.168.56.135 no Windows; nao alterei a rede do Windows |
| Chaves SSH de gabriel/caio (par proprio, publica no proprio authorized_keys) | passou | ver secao abaixo |

## Falha encontrada e corrigida

Em db/app/cli a `eth1` ficava `DOWN` (a box nao configura a rede privada), logo sem IP por DHCP e sem montar o NFS.
Correcao em `ansible/clientes.yml`: `/etc/network/interfaces.d/eth1` com `inet dhcp` (metric 1000 para nao tomar a rota padrao da NAT) e `ifup`.
Depois disso db/app/cli receberam .134/.154/.50 e o autofs montou o NFS.

## Login SSH por chave (arq)

Cada usuario tem seu par de chaves (`generate_ssh_key`); a publica de cada um vai no proprio `authorized_keys` (sem chave insecure do Vagrant). O usuario `vagrant` segue funcionando (Ansible rodou via `vagrant ssh`).

```text
gabriel (chave propria): LOGIN_OK / gabriel
caio (chave propria):    LOGIN_OK / caio
senha (gabriel):  Permission denied (publickey).
root:            Permission denied (publickey).
authorized_keys: 1 chave em cada usuario, 0 com 'insecure'
```
## Resolucao de nomes (item 2)
Adicionado registro cli (192.168.56.50) na zona direta/reversa. getent hosts e ping por nome em db, app e cli:
```text
db : arq=192.168.56.135 app=192.168.56.154 cli=192.168.56.50 ; ping cli.gabriel.caio.devops OK
app: arq=192.168.56.135 db=192.168.56.134  cli=192.168.56.50 ; ping cli.gabriel.caio.devops OK
cli: arq=192.168.56.135 db=192.168.56.134  app=192.168.56.154 ; ping arq.gabriel.caio.devops OK
```
Hospedeiro Windows: nao testado/alterado (usar hosts-windows.txt, ver README).

## Enunciado x implementacao
| Enunciado | Implementacao |
|---|---|
| Box debian/bookworm64, 512 MB (cli 1024), linked_clone, sem guest additions, insert_key=false | Vagrantfile: igual |
| Gatilho remove DHCP do VirtualBox | trigger before/after up (dhcpserver remove) |
| arq 192.168.56.1XX, 3 discos 10GB | .135, 3 discos de 10GB |
| db/app via DHCP + MAC; cli via DHCP | MACs ...02 e ...03; cli sem MAC |
| Hostnames nome1.nome2.devops | arq/db/app/cli.gabriel.caio.devops |
| DHCP: autoritativo, 180/3600, faixa 50-100, gw .1, DNS arq | dhcpd.conf.j2 |
| db 1YY, app 1XY | db .134; app .154 (XY = ultimo digito de cada matricula) |
| DNS: rede interna, forwarders 1.1.1.1/8.8.8.8, zonas direta/reversa | named.conf.options/local + zonas |
| LVM vg dados, lv ifpb 15G ext4 em /dados | arq.yml |
| NFS /dados/nfs, 192.168.56.0/24, nfs-ifpb, all_squash, sync+no_wdelay, sem shell | arq.yml |
| autofs /var/nfs em db, app, cli | clientes.yml |
| SSH, sudo, chrony, timezone, grupo ifpb, usuarios, banner, NFS client | common.yml |
| mariadb, apache2+index.html, firefox-esr+xauth+X11 | db.yml, app.yml, cli.yml |
| README com integrantes, disciplina, professor, execucao | README.md |
Resultado: nenhuma divergencia encontrada.
