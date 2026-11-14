#!/usr/bin/env bash
# Checagem prévia (só leitura): detecta o que costuma atrapalhar num computador compartilhado.
# Uso: bash scripts/preflight.sh
cd "$(dirname "$0")/.."
ok()   { printf '  [ OK ] %s\n' "$1"; }
ruim() { printf '  [FALHA] %s\n' "$1"; PROBLEMAS=$((PROBLEMAS+1)); }
aviso(){ printf '  [AVISO] %s\n' "$1"; }
PROBLEMAS=0

echo "== Ferramentas"
for c in VBoxManage vagrant ansible-playbook ssh python3; do
  command -v "$c" >/dev/null && ok "$c: $(command -v "$c")" || ruim "$c não encontrado"
done
command -v vagrant >/dev/null && aviso "Vagrant: $(vagrant --version) (precisa de 2.4.9+ para VirtualBox 7.2)"
command -v VBoxManage >/dev/null && aviso "VirtualBox: $(VBoxManage --version)"

echo "== KVM (conflita com o VirtualBox)"
if lsmod | grep -q '^kvm'; then ruim "módulo KVM carregado: sudo modprobe -r kvm_intel kvm_amd kvm"; else ok "KVM descarregado"; fi

echo "== VMs já em execução (de outros grupos)"
if command -v VBoxManage >/dev/null; then
  RODANDO=$(VBoxManage list runningvms 2>/dev/null)
  if [ -n "$RODANDO" ]; then
    ruim "há VMs ligadas: podem responder DHCP/DNS na mesma rede ou usar os mesmos MACs"
    echo "$RODANDO" | sed 's/^/         /'
  else ok "nenhuma VM ligada"; fi

  echo "== Servidor DHCP do VirtualBox"
  if VBoxManage list dhcpservers 2>/dev/null | grep -q NetworkName; then
    ruim "DHCP do VirtualBox ativo: VBoxManage dhcpserver remove --network=HostInterfaceNetworking-vboxnet0"
  else ok "nenhum DHCP do VirtualBox"; fi
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
