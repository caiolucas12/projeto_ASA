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
# rede host-only padrão do VirtualBox (192.168.56.0/24); no Windows o nome é outro
WINDOWS = Vagrant::Util::Platform.windows?
REDE    = WINDOWS ? "VirtualBox Host-Only Ethernet Adapter" : "vboxnet0"
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
 
  # Gatilho: interrompe o servidor DHCP do VirtualBox (só o DHCP do arq deve responder).
  config.trigger.before :"Vagrant::Action::Builtin::WaitForCommunicator", type: :action do |t|
    t.warn = "Iterrompe o servidor dhcp do virtualbox"
    t.run = {inline: "vboxmanage dhcpserver stop --interface vboxnet0"}
  end
 
  # Provisionamento automático: quando a ÚLTIMA VM (cli) termina de subir, as 4 já estão
  # ligadas e este gatilho roda scripts/provisionar.sh (hospedeiro + Ansible).
  # Para subir só as VMs, sem provisionar:  SEM_ANSIBLE=1 vagrant up
  # (Linux/macOS; no Windows o Ansible não roda no hospedeiro - veja teste/README.md)
  unless WINDOWS || ENV["SEM_ANSIBLE"]
    config.trigger.after :up do |t|
      t.name = "Provisionar com Ansible (scripts/provisionar.sh)"
      t.only_on = ["cli"]
      t.run = { inline: "bash '#{File.expand_path("scripts/provisionar.sh", File.dirname(__FILE__))}'" }
    end
  end

  # ---------------- Servidor de arquivos (arq) ----------------
  config.vm.define "arq" do |arq|
    arq.vm.hostname = "arq.#{DOMINIO}"
    arq.vm.network "private_network", ip: "192.168.56.1#{XX}"
    # porta SSH fixa no host (o inventário do Ansible depende disso)
    arq.vm.network "forwarded_port", guest: 22, host: 2201, id: "ssh", auto_correct: false
 
    # 3 discos adicionais de 10 GB
    (1..3).each do |i|
      arq.vm.disk :disk, size: "10GB", name: "disco#{i}"
    end
  end
 
  # ---------------- Servidor de banco de dados (db) -----------
  config.vm.define "db" do |db|
    db.vm.hostname = "db.#{DOMINIO}"
    db.vm.network "forwarded_port", guest: 22, host: 2202, id: "ssh", auto_correct: false
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
    app.vm.network "forwarded_port", guest: 22, host: 2203, id: "ssh", auto_correct: false
    app.vm.network "private_network",
                   type: "dhcp",
                   mac: "080027000003",
                   name: REDE,
                   auto_config: false
  end
 
  # ---------------- Host cliente (cli) ------------------------
  config.vm.define "cli" do |cli|
    cli.vm.hostname = "cli.#{DOMINIO}"
    cli.vm.network "forwarded_port", guest: 22, host: 2204, id: "ssh", auto_correct: false
    # IP via DHCP (pool 50-100). MAC fixo para o cli receber sempre o mesmo IP
    # (o DNS do arq tem um registro A para ele; o script de verificação usa cli.<dominio>)
    cli.vm.network "private_network",
                   type: "dhcp",
                   mac: "080027000004",
                   name: REDE,
                   auto_config: false
    cli.vm.provider "virtualbox" do |vb|
      vb.memory = 1024
    end
  end
end
 
