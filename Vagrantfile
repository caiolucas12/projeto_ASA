# -*- mode: ruby -*-
# vi: set ft=ruby :
 
# ============================================================
# Projeto 01 - DevOps com Vagrant e Ansible
# Disciplina: Administração de Sistemas Abertos - IFPB
# ============================================================
 
# --- AJUSTE ESTAS VARIÁVEIS ---------------------------------
NOME1 = "gabriel"   # primeiro nome do integrante 1
NOME2 = "caio"      # primeiro nome do integrante 2
XX    = "35"      # dois últimos dígitos da matrícula do integrante 1 (arq = 192.168.56.135)
 
DOMINIO = "#{NOME1}.#{NOME2}.devops"
REDE    = "vboxnet0"   # rede host-only padrão do VirtualBox (192.168.56.0/24)
# ------------------------------------------------------------
 
Vagrant.configure("2") do |config|
  # Configurações comuns a todas as VMs
  config.vm.box = "debian/bookworm64"
  config.ssh.insert_key = false          # desativa a geração de chaves SSH
 
  config.vm.provider "virtualbox" do |vb|
    vb.memory = 512
    vb.linked_clone = true               # usa clones vinculados
    vb.check_guest_additions = false     # não verifica guest additions
  end
 
  # Gatilhos: desabilitam o servidor DHCP do VirtualBox na rede host-only.
  # Rodam antes E depois do "up", pois o Vagrant recria o servidor DHCP
  # nas VMs que usam private_network do tipo dhcp.
  # (Linux/macOS; no Windows o nome da rede é diferente - veja o README)
  [:before, :after].each do |momento|
    config.trigger.send(momento, :up) do |t|
      t.name = "Desabilitar DHCP do VirtualBox (#{momento})"
      t.on_error = :continue
      t.run = {
        inline: "bash -c 'VBoxManage dhcpserver remove --network=HostInterfaceNetworking-#{REDE} 2>/dev/null || " \
                "VBoxManage dhcpserver remove --netname HostInterfaceNetworking-#{REDE} 2>/dev/null || true'"
      }
    end
  end
 
  # ---------------- Servidor de arquivos (arq) ----------------
  config.vm.define "arq" do |arq|
    arq.vm.hostname = "arq.#{DOMINIO}"
    arq.vm.network "private_network", ip: "192.168.56.1#{XX}"
 
    # 3 discos adicionais de 10 GB
    (1..3).each do |i|
      arq.vm.disk :disk, size: "10GB", name: "disco#{i}"
    end
  end
 
  # ---------------- Servidor de banco de dados (db) -----------
  config.vm.define "db" do |db|
    db.vm.hostname = "db.#{DOMINIO}"
    # IP via DHCP (servidor DHCP do arq) com reserva por MAC
    db.vm.network "private_network",
                  type: "dhcp",
                  mac: "080027000002",
                  name: REDE,
                  auto_config: false
  end
 
  # ---------------- Servidor de aplicação (app) ---------------
  config.vm.define "app" do |app|
    app.vm.hostname = "app.#{DOMINIO}"
    app.vm.network "private_network",
                   type: "dhcp",
                   mac: "080027000003",
                   name: REDE,
                   auto_config: false
  end
 
  # ---------------- Host cliente (cli) ------------------------
  config.vm.define "cli" do |cli|
    cli.vm.hostname = "cli.#{DOMINIO}"
    cli.vm.network "private_network",
                   type: "dhcp",
                   name: REDE,
                   auto_config: false
    cli.vm.provider "virtualbox" do |vb|
      vb.memory = 1024
    end
  end
end
 