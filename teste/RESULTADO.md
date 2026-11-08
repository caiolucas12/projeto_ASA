# Resultado dos testes (4 VMs reais no VirtualBox)

Comandos usados (host, PowerShell):

```powershell
$env:Path += ";C:\Program Files\Vagrant\bin"
vagrant ssh <arq|db|app|cli> -c "bash /vagrant/teste/verificar.sh"   # todas as verificacoes
vagrant ssh arq -c "cd /vagrant/ansible && ansible-playbook -i /vagrant/teste/inventory.ini clientes.yml"
```

A saida completa de cada VM esta em `teste/saida.txt` (gerada pelo `verificar.sh`).

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
| Gerar chaves SSH dos usuarios gabriel/caio funcionando por login | nao testado | so conferi usuarios e sshd; nao fiz login como eles |

## Falha encontrada e corrigida

Em db/app/cli a `eth1` ficava `DOWN` (a box nao configura a rede privada), logo sem IP por DHCP e sem montar o NFS.
Correcao em `ansible/clientes.yml`: `/etc/network/interfaces.d/eth1` com `inet dhcp` (metric 1000 para nao tomar a rota padrao da NAT) e `ifup`.
Depois disso db/app/cli receberam .134/.154/.50 e o autofs montou o NFS.
