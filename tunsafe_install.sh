#!/bin/bash

function blue(){
    echo -e "\033[34m\033[01m $1 \033[0m"
}
function green(){
    echo -e "\033[32m\033[01m $1 \033[0m"
}
function red(){
    echo -e "\033[31m\033[01m $1 \033[0m"
}
function yellow(){
    echo -e "\033[33m\033[01m $1 \033[0m"
}
function bred(){
    echo -e "\033[31m\033[01m\033[05m $1 \033[0m"
}
function byellow(){
    echo -e "\033[33m\033[01m\033[05m $1 \033[0m"
}

rand(){
    min=$1
    max=$(($2-$min+1))
    num=$(cat /dev/urandom | head -n 10 | cksum | awk -F ' ' '{print $1}')
    echo $(($num%$max+$min))  
}

tunsafe_install(){
    version=$(cat /etc/os-release | awk -F '[".]' '$1=="VERSION="{print $2}')  
    apt-get update -y
    sudo apt-get install -y git curl make
    git clone https://github.com/TunSafe/TunSafe.git
    cd TunSafe
    sudo apt-get install -y clang-6.0 
    sudo make && sudo make install
    
    sudo echo net.ipv4.ip_forward = 1 >> /etc/sysctl.conf
    sysctl -p
    echo "1"> /proc/sys/net/ipv4/ip_forward
    
    mkdir /etc/tunsafe
    cd /etc/tunsafe
    tunsafe genkey | tee sprivatekey | tunsafe pubkey > spublickey
    tunsafe genkey | tee cprivatekey | tunsafe pubkey > cpublickey
    s1=$(cat sprivatekey)
    s2=$(cat spublickey)
    c1=$(cat cprivatekey)
    c2=$(cat cpublickey)
    serverip=$(curl ipv4.icanhazip.com)
    port=$(rand 10000 60000)
    eth=$(ls /sys/class/net | awk '/^e/{print}')
    obfsstr=$(cat /dev/urandom | head -1 | md5sum | head -c 4)
    green "Enter 1 to enable the default UDP + obfuscation mode (recommended)"
    green "Enter 2 to enable the default TCP + obfuscation mode"
    green "Enter 3 to enable the default TCP + obfuscation + HTTPS masquerading mode"
    read choose
if [ $choose == 1 ]
then

sudo cat > /etc/tunsafe/TunSafe.conf <<-EOF
[Interface]
PrivateKey = $s1
Address = 10.0.0.1/24 
ObfuscateKey = $obfsstr
PostUp   = iptables -A FORWARD -i tun0 -j ACCEPT; iptables -A FORWARD -o tun0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $eth -j MASQUERADE
PostDown = iptables -D FORWARD -i tun0 -j ACCEPT; iptables -D FORWARD -o tun0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $eth -j MASQUERADE
ListenPort = $port
DNS = 8.8.8.8
MTU = 1380

[Peer]
PublicKey = $c2
AllowedIPs = 10.0.0.2/32
EOF


sudo cat > /etc/tunsafe/client.conf <<-EOF
[Interface]
PrivateKey = $c1
Address = 10.0.0.2/24 
ObfuscateKey = $obfsstr
DNS = 8.8.8.8
MTU = 1380

[Peer]
PublicKey = $s2
Endpoint = $serverip:$port
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25
EOF

fi
if [ $choose == 2 ]
then
sudo cat > /etc/tunsafe/TunSafe.conf <<-EOF
[Interface]
PrivateKey = $s1
Address = 10.0.0.1/24 
ObfuscateKey = $obfsstr
ListenPortTCP = $port
PostUp   = iptables -A FORWARD -i tun0 -j ACCEPT; iptables -A FORWARD -o tun0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $eth -j MASQUERADE
PostDown = iptables -D FORWARD -i tun0 -j ACCEPT; iptables -D FORWARD -o tun0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $eth -j MASQUERADE
DNS = 8.8.8.8
MTU = 1380

[Peer]
PublicKey = $c2
AllowedIPs = 10.0.0.2/32
EOF


sudo cat > /etc/tunsafe/client.conf <<-EOF
[Interface]
PrivateKey = $c1
Address = 10.0.0.2/24 
ObfuscateKey = $obfsstr
DNS = 8.8.8.8
MTU = 1380

[Peer]
PublicKey = $s2
Endpoint = tcp://$serverip:$port
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25
EOF

fi
if [ $choose == 3 ]
then
sudo cat > /etc/tunsafe/TunSafe.conf <<-EOF
[Interface]
PrivateKey = $s1
Address = 10.0.0.1/24 
ObfuscateKey = $obfsstr
ListenPortTCP = 443
ObfuscateTCP=tls-chrome
PostUp   = iptables -A FORWARD -i tun0 -j ACCEPT; iptables -A FORWARD -o tun0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $eth -j MASQUERADE
PostDown = iptables -D FORWARD -i tun0 -j ACCEPT; iptables -D FORWARD -o tun0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $eth -j MASQUERADE
ListenPort = $port
DNS = 8.8.8.8
MTU = 1380

[Peer]
PublicKey = $c2
AllowedIPs = 10.0.0.2/32
EOF


sudo cat > /etc/tunsafe/client.conf <<-EOF
[Interface]
PrivateKey = $c1
Address = 10.0.0.2/24 
ObfuscateKey = $obfsstr
ObfuscateTCP=tls-chrome
DNS = 8.8.8.8
MTU = 1380

[Peer]
PublicKey = $s2
Endpoint = tcp://$serverip:443
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25
EOF

fi

    sudo apt-get install -y qrencode

sudo cat > /etc/init.d/tunstart <<-EOF
#! /bin/bash
### BEGIN INIT INFO
# Provides:		tunstart
# Required-Start:	$remote_fs $syslog
# Required-Stop:    $remote_fs $syslog
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	tunstart
### END INIT INFO
cd /etc/tunsafe/
sudo tunsafe start -d TunSafe.conf
EOF

    sudo chmod +x /etc/init.d/tunstart
    cd /etc/init.d
    sudo update-rc.d tunstart defaults
    cd /etc/tunsafe
    sudo tunsafe start -d TunSafe.conf
    
    content=$(cat /etc/tunsafe/client.conf)
    green "电脑端请下载/etc/tunsafe/client.conf，手机端可直接使用软件扫码"
    echo "${content}" | qrencode -o - -t UTF8
}

add_user(){
    green "给新用户起个名字，不能和已有用户重复"
    read -p "请输入用户名：" newname
    cd /etc/tunsafe/
    cp client.conf $newname.conf
    tunsafe genkey | tee temprikey | tunsafe pubkey > tempubkey
    ipnum=$(grep Allowed /etc/tunsafe/TunSafe.conf | tail -1 | awk -F '[ ./]' '{print $6}')
    newnum=$((10#${ipnum}+1))
    sed -i 's%^PrivateKey.*$%'"PrivateKey = $(cat temprikey)"'%' $newname.conf
    sed -i 's%^Address.*$%'"Address = 10.0.0.$newnum\/24"'%' $newname.conf

cat >> /etc/tunsafe/TunSafe.conf <<-EOF
[Peer]
PublicKey = $(cat tempubkey)
AllowedIPs = 10.0.0.$newnum/32
EOF
    tunsafe set tun0 peer $(cat tempubkey) allowed-ips 10.0.0.$newnum/32
    green "添加完成，文件：/etc/tunsafe/$newname.conf"
    rm -f temprikey tempubkey
}

#开始菜单
start_menu(){
    clear
    green " ================================================"
    green " Introduction: One-click installation of TunSafe "
    green " System: Ubuntu> = 16.04                         "
    green " Author: atrandys                                "
    green " WebSite：www.atrandys.com                       "
    green " Youtube：atrandys                               "
    green " ================================================"
    echo
    green " 1. Install TunSafe"
    green " 2. View the client QR code"
    green " 3.  Add users "
    yellow " 0. Exit script"
    echo
    read -p "Please Enter key in numbers:" num
    case "$num" in
    1)
    tunsafe_install
    ;;
    2)
    content=$(cat /etc/tunsafe/client.conf)
    green "Only the QR code of the first client added by default is displayed here."
    echo "${content}" | qrencode -o - -t UTF8
    ;;
    3)
    add_user
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    red "Please enter the correct number"
    sleep 2s
    start_menu
    ;;
    esac
}

start_menu






