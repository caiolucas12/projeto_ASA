# Projeto ASA

Projeto 01 - DevOps com Vagrant e Ansible.

- **Integrantes:** Gabriel e Caio
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
Vagrantfile              # define as 4 VMs
Doc/                     # enunciado do projeto (PDF)
ansible/
  ansible.cfg
  inventory.ini          # hosts e portas SSH
  site.yml               # playbook principal (executa todos na ordem)
  common.yml             # configuração comum: usuários, SSH, chrony, autofs/NFS, DNS
  arq.yml  db.yml  app.yml  cli.yml
  group_vars/all.yml     # variáveis (nomes, matrículas, IPs)
  templates/             # dhcpd, named (DNS), zonas, index.html
```

## Matrículas e IPs

> Matrículas: Gabriel 20251380035, Caio 20251380034. IPs: arq .135 (XX=35), db .134 (YY=34) e app .154.
>
> Interpretação do "1XY" do app: XY = último dígito de cada matrícula (5 e 4), logo .154. Para mudar, edite **em um único lugar**: `ansible/group_vars/all.yml`
> (`matricula_gabriel`, `matricula_caio`, `final_arq`, `final_db`, `final_app`).
>
> Mantenha consistente com o `Vagrantfile`: a variável `XX` deve ser igual a `final_arq`
> (IP do arq `192.168.56.1XX`).

## Pré-requisitos

- VirtualBox
- Vagrant
- Ansible (no Windows, use o WSL)

## Passo a passo

1. Suba primeiro a VM `arq` (ela é o servidor DHCP/DNS das outras):

   ```
   vagrant up arq
   ```

2. Suba as demais:

   ```
   vagrant up
   ```

3. Confira as portas SSH e ajuste o `ansible/inventory.ini` (db, app e cli usam `127.0.0.1` com portas diferentes):

   ```
   vagrant ssh-config
   ```

4. Rode o Ansible (a partir da pasta `ansible/`):

   ```
   cd ansible
   ansible-playbook -i inventory.ini site.yml
   ```

   No WSL, a chave `~/.vagrant.d/insecure_private_key` usada no inventário precisa existir no home do WSL
   (copie de `C:\Users\<usuario>\.vagrant.d\`) com `chmod 600`.

## Rede host-only no Windows

O `Vagrantfile` usa `REDE = "vboxnet0"` (nome no Linux/macOS) no gatilho que remove o servidor DHCP do VirtualBox.
No Windows o nome costuma ser **"VirtualBox Host-Only Ethernet Adapter"**. Ajuste `REDE` no `Vagrantfile` e,
no gatilho, o nome da rede DHCP (`HostInterfaceNetworking-<nome da rede>`). Para ver o nome:

```
VBoxManage list dhcpservers
VBoxManage list hostonlyifs
```

## Resolução de nomes no host

O host Windows não usa o DNS do arq. Há duas opções (o projeto não altera o Windows sozinho):

**Opção 1 - arquivo hosts.** Abra o Bloco de Notas como Administrador, abra
`C:\Windows\System32\drivers\etc\hosts` e cole as linhas de `hosts-windows.txt` (IPs de `ansible/group_vars/all.yml`;
o `cli` recebe 192.168.56.50 por DHCP). Teste: `ping arq.gabriel.caio.devops`.

**Opção 2 - DNS no adaptador host-only.** Em Configurações de rede > adaptador "VirtualBox Host-Only Ethernet Adapter" >
IPv4 > DNS preferencial `192.168.56.135`.

Dentro de cli, db e app a resolução já funciona pelo DNS do arq: `getent hosts db.gabriel.caio.devops`.
## Chave SSH dos usuários gabriel e caio

Em `ansible/common.yml` são criados o grupo `ifpb` e os usuários `gabriel` e `caio` (com `generate_ssh_key`).
Por simplicidade, a chave pública *insecure* do Vagrant é autorizada para os dois (`authorized_key`),
então o acesso funciona com a mesma chave privada do Vagrant:

```
ssh -i ~/.vagrant.d/insecure_private_key gabriel@arq.gabriel.caio.devops
```

O SSH fica apenas com chave (sem senha, sem root) e com banner de aviso. Em produção, use a chave pública de cada pessoa.

## Como validar

- **Nomes (DNS):** em db/app/cli, `nslookup arq.gabriel.caio.devops` e `nslookup app.gabriel.caio.devops`; também `hostname -f`.
- **NFS:** no arq, `exportfs -v`; em db/app/cli, `ls /var/nfs` (monta via autofs) e crie um arquivo para ver se aparece nas outras VMs.
- **Apache:** no app, `systemctl status apache2`; acesse `http://<ip do app>` no navegador (página com as matrículas).
- **X11:** conecte ao cli com `ssh -X` e rode `firefox-esr`; a janela deve abrir no host.
