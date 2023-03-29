#!/bin/bash
# Script Name: Instalador Speedtest Ookla baseado no Artigo do Blog Remontti
# Link do Artigo: https://blog.remontti.com.br/6051
# Author do Script: Anderson Barbosa
# Date : 29/03/2023
# Execute esse Script como root.
# Instalar Pacotes necessários

apt install wget unzip net-tools psmisc certbot sudo -y

# Melhorando Performace do Servidor
echo '# Kernel deve tentar manter o máximo possível de dados em memória principal 
vm.swappiness = 5
 
# Evitar que o sistema fique sobrecarregado com muitos dados sujos na memória.
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
 
# Aumentar o número máximo de conexões simultâneas
net.core.somaxconn = 65535
 
# Aumentar o tamanho máximo do buffer de recepção e transmissão de rede
net.ipv4.tcp_mem = 4096 87380 16777216
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
 
# Melhorar o desempenho da conexão e a evitar congestionamentos
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_timestamps = 1
 
# Reduzir o tempo limite de conexão TCP
net.ipv4.tcp_fin_timeout = 15
 
# Ativar o escalonamento de fila de recepção de pacotes de rede
net.core.netdev_max_backlog = 8192
 
# Aumentar o número máximo de portas locais que podem ser usadas
net.ipv4.ip_local_port_range = 1024 65535' | sudo tee -a /etc/sysctl.conf > /dev/null

# Carregando alterações para o Kernel
sysctl -p

# Módulos do Kernel
modprobe -a tcp_illinois
echo "tcp_illinois" >> /etc/modules 
modprobe -a tcp_westwood
echo "tcp_westwood" >> /etc/modules
modprobe -a tcp_htcp
echo "tcp_htcp" >> /etc/modules

# Criando diretorio Ookla
mkdir /usr/local/src/ooklaserver

# Acesso diretorio + Download e Instalação Ookla
cd /usr/local/src/ooklaserver
wget https://install.speedtest.net/ooklaserver/ooklaserver.sh
chmod +x ooklaserver.sh
./ooklaserver.sh install -f

# Parando Ookla Server
killall -9 OoklaServer

# Trecho de Codigo onde o dominio irá ser adicionado no Arquivo de Conf.
echo "Digite o nome do domínio:"
read dominio
echo 'OoklaServer.useIPv6 = true' | sudo tee -a /usr/local/src/ooklaserver/OoklaServer.properties > /dev/null
echo 'OoklaServer.allowedDomains = *.ookla.com, *.speedtest.net, *.remontti.com.br, *.'$dominio | sudo tee -a /usr/local/src/ooklaserver/OoklaServer.properties > /dev/null

# Backup do Arquivo de Conf.
cp /usr/local/src/ooklaserver/OoklaServer.properties /usr/local/src/ooklaserver/OoklaServer.properties.default

# Adicionando Ookla como um serviço para configurar inicio automatico
echo '[Unit]
Description=OoklaServer-SpeedTest 
After=network.target
 
[Service]
User=root
Group=root
Type=simple
RemainAfterExit=yes
 
WorkingDirectory=/usr/local/src/ooklaserver
ExecStart=/usr/local/src/ooklaserver/ooklaserver.sh start
ExecReload=/usr/local/src/ooklaserver/ooklaserver.sh restart
#ExecStop=/usr/local/src/ooklaserver/ooklaserver.sh stop
ExecStop=/usr/bin/killall -9 OoklaServer
 
TimeoutStartSec=60
TimeoutStopSec=300
 
[Install]
WantedBy=multi-user.target
Alias=speedtest.service' | sudo tee -a /lib/systemd/system/ooklaserver.service > /dev/null

# Restart Daemon
systemctl daemon-reload

# Adicionando ao Inicio automatico
systemctl enable ooklaserver
echo 'Digite o endereço de email para receber avisos e atualizações sobre o certificado'
read email
echo 'Digite o dominio para criação do certificado'
read dominiocert
echo "y" | sudo certbot certonly --standalone --agree-tos --email "$email" -d "$dominiocert" --non-interactive | sed '/Registering/,+1 d'
echo 'openSSL.server.certificateFile = /etc/letsencrypt/live/'$dominiocert'/fullchain.pem
openSSL.server.privateKeyFile = /etc/letsencrypt/live/'$dominiocert'/privkey.pem' | sudo tee -a /usr/local/src/ooklaserver/OoklaServer.properties > /dev/null

# Backup do Arquivo de Config
cp /usr/local/src/ooklaserver/OoklaServer.properties /usr/local/src/ooklaserver/OoklaServer.properties.default

# Reiniciando o Servidor
systemctl  restart ooklaserver.service

# Renovando Certificado Automaticamente
echo '#!/bin/bash
# Renova o certificado
/usr/bin/certbot renew -q
# Aguarda o certificado renovar
sleep 30
# Reinicie o OoklaServer
/usr/bin/systemctl restart ooklaserver' | sudo tee -a /usr/local/src/ooklaserver/renova-certificado > /dev/null

# Permissão de Execução do Script criado acima
chmod +x /usr/local/src/ooklaserver/renova-certificado

# Adicionando Arquivo na Contrab
echo '00 00   1 * *   root    /usr/local/src/ooklaserver/renova-certificado' >> /etc/crontab
systemctl restart cron
