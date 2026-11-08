#!/bin/bash
# Verificacoes do enunciado. Rodar dentro de cada VM: bash /vagrant/teste/verificar.sh
vm=$(hostname -s)
echo "== $vm: hostname/IP"; hostname -f; ip -4 -br a | grep -v '^lo'
echo "== resolucao de nomes"; for h in arq db app; do getent hosts $h.gabriel.caio.devops; done
echo "== timezone/chrony"; timedatectl | grep 'Time zone'; chronyc sources | tail -2
echo "== sshd"; sudo sshd -T | grep -Ei '^(passwordauthentication|permitrootlogin|allowgroups|banner|x11forwarding|pubkeyauthentication) '
echo "== usuarios"; getent passwd gabriel caio; id gabriel; id caio; grep -h ifpb /etc/sudoers.d/* 2>/dev/null
echo "== banner/sudo/dig"; cat /etc/ssh/banner; sudo grep -rh ifpb /etc/sudoers /etc/sudoers.d; dig +short app.gabriel.caio.devops; dig +short -x 192.168.56.154
echo "== NFS/autofs"; ls /var/nfs | head -3; findmnt -t nfs4,nfs
if [ $vm != arq ]; then
  echo "== escrita NFS (root e gabriel devem falhar/mapear; ver dono dos arquivos)"
  sudo touch /var/nfs/t_root; sudo -u gabriel touch /var/nfs/t_gabriel; ls -l /var/nfs; sudo rm -f /var/nfs/t_*
fi
case $vm in
arq)
  echo "== servicos"; systemctl is-active isc-dhcp-server named nfs-server chrony
  echo "== dhcpd.conf"; grep -vE '^\s*(#|$)' /etc/dhcp/dhcpd.conf
  echo "== leases"; sudo grep -E '^lease|hardware|client-hostname' /var/lib/dhcp/dhcpd.leases | tail -12
  echo "== DNS direto/reverso"; dig +short @127.0.0.1 arq.gabriel.caio.devops db.gabriel.caio.devops app.gabriel.caio.devops
  dig +short -x 192.168.56.134 @127.0.0.1; dig +short -x 192.168.56.154 @127.0.0.1
  echo "== LVM"; sudo vgs; sudo lvs; findmnt /dados; ls -ld /dados/nfs
  echo "== NFS"; sudo exportfs -v; getent passwd nfs-ifpb ;;
db)  echo "== mariadb/autofs"; systemctl is-active mariadb autofs ;;
app) echo "== apache/autofs"; systemctl is-active apache2 autofs
     wget -qO- localhost | grep -Ei 'gabriel|caio|20251380' ;;
cli) echo "== firefox/xauth"; dpkg -l firefox-esr xauth | tail -2; systemctl is-active autofs ;;
esac
