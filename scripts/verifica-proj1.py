#!/usr/bin/env python3
import sys
import os

HOSTS = ['arq', 'app', 'db', 'cli']
GRUPO = 'leonidas.estela'

if len(sys.argv) > 1:
    GRUPO = sys.argv[1]

dominio  = GRUPO + '.devops'
usuarios = GRUPO.split('.')

for h in HOSTS:
    host = h + '.' + dominio
    print('--------------------- Verificando {} ---------------------'.format(host), flush=True)
    if os.system('ping -c1 {} > /dev/null 2> /dev/null'.format(host)) != 0:
        print('Falha ao acessar {}'.format(host), flush=True)
    os.system('ssh {}@{} -i keys/{} sh -c "date; chronyc sources"'.format(usuarios[0], host, usuarios[0]))
    if os.system('ssh root@{} id > /dev/null 2> /dev/null'.format(host)) == 0:
        print('Acessar {} como root não foi bloqueado'.format(host), flush=True)
    for u in usuarios:
        if os.system('ssh {}@{} sudo id {} > /dev/null 2> /dev/null'.format(u, host, u)) == 0:
            print('Login em {} com usuário e senha não foi bloqueado'.format(host), flush=True)
        os.system('ssh {}@{} -i keys/{} sudo id {}'.format(u, host, u, u))
        if h == 'app':
            os.system('ssh {}@{} -i keys/{} "echo Dados NFS de {} > /var/nfs/{}.txt"'.format(u, host, u, u, u))
            os.system('ssh {}@{} -i keys/{} ls -l /var/nfs/{}.txt'.format(u, host, u, u))
    if not os.path.isfile('keys/intruso') or not os.path.isfile('keys/intruso.pub'):
        os.system('ssh-keygen -q -t ed25519 -N "" -f keys/intruso')
    os.system('scp -i keys/{} keys/intruso.pub {}@{}:/tmp > /dev/null 2> /dev/null'.format(usuarios[0], usuarios[0], host))
    os.system('ssh {}@{} -i keys/{} sudo sh -c "useradd -m intruso; mkdir /home/intruso/.ssh; mv /tmp/intruso.pub /home/intruso/.ssh/authorized_keys" > /dev/null 2> /dev/null'.format(usuarios[0], host, usuarios[0]))
    os.system('ssh {}@{} -i keys/{} sudo sh -c "chown -R intruso:intruso /home/intruso/.ssh; chmod u=rwx,g=,o= /home/intruso/.ssh; chmod u=rw,g=,o= /home/intruso/.ssh/authorized_keys" > /dev/null 2> /dev/null'.format(usuarios[0], host, usuarios[0]))
    if os.system('ssh intruso@{} -i keys/intruso id > /dev/null 2> /dev/null'.format(host)) == 0:
        print('Acessar {} como usuário intruso não foi bloqueado'.format(host))
    os.system('ssh {}@{} -i keys/{} sudo userdel -r intruso > /dev/null 2> /dev/null'.format(usuarios[0], host, usuarios[0]))
    if h == 'arq':
        os.system('ssh {}@{} -i keys/{} sudo pvs'.format(usuarios[0], host, usuarios[0]))
        os.system('ssh {}@{} -i keys/{} sudo lvs dados/ifpb'.format(usuarios[0], host, usuarios[0]))
    elif h == 'db':
        if os.system('ssh {}@{} -i keys/{} sudo ss -ntlp | grep mariadb > /dev/null 2> /dev/null'.format(usuarios[0], host, usuarios[0])) != 0:
            print('Servidor mariadb não foi instalado em {}'.format(host))
        os.system('ssh {}@{} -i keys/{} cat /var/nfs/{}.txt'.format(usuarios[0], host, usuarios[0], usuarios[0]))
    elif h == 'cli':
        os.system('ssh {}@{} -i keys/{} cat /var/nfs/{}.txt'.format(usuarios[1], host, usuarios[1], usuarios[1]))
        os.system('ssh {}@{} -i keys/{} -X firefox http://app.{} > /dev/null 2> /dev/null &'.format(usuarios[1], host, usuarios[1], dominio))
