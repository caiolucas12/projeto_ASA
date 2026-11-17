#!/usr/bin/env bash
# Checagem prévia (SOMENTE LEITURA): detecta o que costuma atrapalhar num computador compartilhado
# (VMs de outros grupos, DHCP do VirtualBox, portas, resolvedor, sudo, internet, RAM, disco).
# Uso, na raiz do projeto: bash scripts/preflight.sh
cd "$(dirname "$0")/.."
ok()   { printf '  [ OK ] %s\n' "$1"; }
ruim() { printf '  [FALHA] %s\n' "$1"; PROBLEMAS=$((PROBLEMAS+1)); }
aviso(){ printf '  [AVISO] %s\n' "$1"; }
PROBLEMAS=0

echo "== Ferramentas"
for c in VBoxManage vagrant ansible-playbook ssh python3; do
  command -v "$c" >/dev/null && ok "$c: $(command -v "$c")" || ruim "$c não encontrado"
done
command -v vagrant >/dev/null && aviso "Vagrant: $(vagrant --version)"
command -v VBoxManage >/dev/null && aviso "VirtualBox: $(VBoxManage --version)"
if command -v ansible-doc >/dev/null; then
  ansible-doc -t module community.general.lvg >/dev/null 2>&1 && ansible-doc -t module ansible.posix.mount >/dev/null 2>&1 \
    && ok "coleções do Ansible (community.general, ansible.posix)" \
    || aviso "coleções do Ansible ausentes: ansible-galaxy collection install -r ansible/requirements.yml (precisa de internet)"
fi
if command -v vagrant >/dev/null; then
  vagrant box list 2>/dev/null | grep -q 'debian/bookworm64' && ok "box debian/bookworm64 já baixada" \
    || aviso "box debian/bookworm64 ausente: será baixada no vagrant up (~500 MB, precisa de internet)"
fi

echo "== KVM (conflita com o VirtualBox)"
if lsmod | grep -q '^kvm'; then ruim "módulo KVM carregado: sudo modprobe -r kvm_intel kvm_amd kvm"; else ok "KVM descarregado"; fi

echo "== VMs em execução (de outros grupos)"
if command -v VBoxManage >/dev/null; then
  RODANDO=$(VBoxManage list runningvms 2>/dev/null)
  if [ -n "$RODANDO" ]; then
    ruim "há VMs ligadas: o DHCP/DNS delas responde na mesma rede (peça para desligarem: vagrant halt)"
    echo "$RODANDO" | sed 's/^/         /'
  else ok "nenhuma VM ligada"; fi

  echo "== Servidor DHCP do VirtualBox (o gatilho do Vagrantfile faz 'dhcpserver stop' e precisa que ele exista)"
  if VBoxManage list dhcpservers 2>/dev/null | grep -q 'HostInterfaceNetworking-vboxnet0'; then
    ok "servidor DHCP existe em vboxnet0"
    pgrep -f VBoxNetDHCP >/dev/null 2>&1 && aviso "está em execução; o gatilho o interrompe quando cada VM sobe (normal)"
  else
    ruim "não há servidor DHCP em vboxnet0 (o vagrant up falharia). Crie: VBoxManage dhcpserver add --interface=vboxnet0 --server-ip=192.168.56.100 --netmask=255.255.255.0 --lower-ip=192.168.56.101 --upper-ip=192.168.56.254 --enable"
  fi
fi

echo "== Portas SSH do projeto (2201-2204)"
for p in 2201 2202 2203 2204; do
  ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$p\$" && ruim "porta $p já em uso" || ok "porta $p livre"
done

echo "== Rede 192.168.56.0/24"
if ip -4 -br a | grep -q '192\.168\.56\.'; then
  aviso "interface host-only existe: $(ip -4 -br a | grep '192\.168\.56\.' | tr -s ' ')"
else aviso "ainda não há interface na 192.168.56.0/24 (o vagrant up cria)"; fi
for ip in 192.168.56.135 192.168.56.134 192.168.56.154 192.168.56.50; do
  ping -c1 -W1 "$ip" >/dev/null 2>&1 && ruim "$ip já responde (outra VM usando esse IP?)"
done

echo "== Resolvedor do hospedeiro (restos de outros grupos)"
if command -v resolvectl >/dev/null 2>&1 && systemctl is-active --quiet systemd-resolved 2>/dev/null; then
  aviso "systemd-resolved ativo; vboxnet0 hoje: $(resolvectl dns vboxnet0 2>/dev/null | sed 's/^Link [0-9]* (vboxnet0): *//') (o configurar-host.sh sobrescreve)"
else
  aviso "systemd-resolved inativo: o configurar-host.sh usará o /etc/resolv.conf"
fi

echo "== sudo e internet"
if sudo -n true 2>/dev/null; then ok "sudo sem senha"; else aviso "sudo pede senha: rode 'sudo -v' antes do vagrant up (o passo do hospedeiro usa sudo)"; fi
if command -v curl >/dev/null; then
  curl -sI --max-time 6 https://deb.debian.org >/dev/null 2>&1 && ok "internet (deb.debian.org)" \
    || ruim "sem acesso a deb.debian.org: o apt das VMs e a box dependem de internet"
fi

echo "== Recursos"
LIVRE=$(free -m | awk '/^Mem:/ {print $7}')
[ "${LIVRE:-0}" -ge 3000 ] && ok "RAM disponível: ${LIVRE} MB" || ruim "RAM disponível ${LIVRE} MB (precisa de ~3000 MB)"
DISCO=$(df -m --output=avail . | tail -1 | tr -d ' ')
[ "${DISCO:-0}" -ge 25000 ] && ok "disco livre: ${DISCO} MB" || ruim "disco livre ${DISCO} MB (precisa de ~25000 MB)"

echo "== Estado deste projeto"
command -v vagrant >/dev/null && vagrant status 2>/dev/null | grep -E '^(arq|db|app|cli) '

echo
[ "$PROBLEMAS" -eq 0 ] && echo "Tudo certo para subir." || echo "$PROBLEMAS problema(s) acima. Resolva antes do 'vagrant up'."
exit 0
