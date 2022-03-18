#!/bin/sh
export LANG=en_US.UTF-8

mkdir -p /etc/hysteria
version=`wget -qO- -t1 -T2 --no-check-certificate "https://api.github.com/repos/HyNetwork/hysteria/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g'`

wget -q -O /etc/hysteria/hysteria --no-check-certificate https://github.com/HyNetwork/hysteria/releases/download/$version/hysteria-linux-amd64

chmod 755 /etc/hysteria/hysteria

delay=200
ip=`curl -4 -s ip.sb`
download=$(($download + $download / 4))
upload=$(($upload + $upload / 4))
r_client=$(($delay * 2 * $download / 1000 * 1024 * 1024))
r_conn=$(($r_client / 4))

if [ -z "${protocol}" ] || [ $protocol == "3" ];then
  protocol="wechat-video"
  iptables -I INPUT -p udp --dport ${port} -m comment --comment "allow udp(hihysteria)" -j ACCEPT
elif [ $protocol == "2" ];then
  protocol="faketcp"
  iptables -I INPUT -p tcp --dport ${port}  -m comment --comment "allow tcp(hihysteria)" -j ACCEPT
else 
  protocol="udp"
  iptables -I INPUT -p udp --dport ${port} -m comment --comment "allow udp(hihysteria)" -j ACCEPT
fi

if [ "$domain" = "wechat.com" ];then
mail="admin@qq.com"
days=36500

echo -e "\033[1;;35mSIGN...\n \033[0m"
openssl genrsa -out /etc/hysteria/$domain.ca.key 2048

openssl req -new -x509 -days $days -key /etc/hysteria/$domain.ca.key -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=PonyMa/OU=Tecent/emailAddress=$mail/CN=Tencent Root CA" -out /etc/hysteria/$domain.ca.crt

openssl req -newkey rsa:2048 -nodes -keyout /etc/hysteria/$domain.key -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=PonyMa/OU=Tecent/emailAddress=$mail/CN=Tencent Root CA" -out /etc/hysteria/$domain.csr

openssl x509 -req -extfile <(printf "subjectAltName=DNS:$domain,DNS:$domain") -days $days -in /etc/hysteria/$domain.csr -CA /etc/hysteria/$domain.ca.crt -CAkey /etc/hysteria/$domain.ca.key -CAcreateserial -out /etc/hysteria/$domain.crt

rm /etc/hysteria/${domain}.ca.key /etc/hysteria/${domain}.ca.srl /etc/hysteria/${domain}.csr
echo -e "\033[1;;35mOK.\n \033[0m"

cat <<EOF > /etc/hysteria/config.json
{
  "listen": ":$port",
  "protocol": "$protocol",
  "disable_udp": false,
  "cert": "/etc/hysteria/$domain.crt",
  "key": "/etc/hysteria/$domain.key",
  "auth": {
    "mode": "password",
    "config": {
      "password": "$auth_str"
    }
  },
  "alpn": "h3",
  "recv_window_conn": $r_conn,
  "recv_window_client": $r_client,
  "max_conn_client": 4096,
  "disable_mtu_discovery": false,
  "resolver": "8.8.8.8:53"
}
EOF

cat <<EOF > config.json
{
"server": "$ip:$port",
"protocol": "$protocol",
"up_mbps": $upload,
"down_mbps": $download,
"http": {
"listen": "127.0.0.1:8888",
"timeout" : 300,
"disable_udp": false
},
"socks5": {
"listen": "127.0.0.1:8889",
"timeout": 300,
"disable_udp": false,
"user": "pekora",
"password": "pekopeko"
},
"alpn": "h3",
"acl": "acl/routes.acl",
"mmdb": "acl/Country.mmdb",
"auth_str": "$auth_str",
"server_name": "$domain",
"insecure": true,
"recv_window_conn": $r_conn,
"recv_window": $r_client,
"disable_mtu_discovery": false,
"resolver": "119.29.29.29:53",
"retry": 5,
"retry_interval": 3
}
EOF

else
iptables -I INPUT -p tcp --dport 80  -m comment --comment "allow tcp(hihysteria)" -j ACCEPT
iptables -I INPUT -p tcp --dport 443  -m comment --comment "allow tcp(hihysteria)" -j ACCEPT
cat <<EOF > /etc/hysteria/config.json
{
  "listen": ":$port",
  "protocol": "$protocol",
  "acme": {
    "domains": [
	"$domain"
    ],
    "email": "pekora@$domain"
  },
  "disable_udp": false,
  "auth": {
    "mode": "password",
    "config": {
      "password": "$auth_str"
    }
  },
  "alpn": "h3",
  "recv_window_conn": $r_conn,
  "recv_window_client": $r_client,
  "max_conn_client": 4096,
  "disable_mtu_discovery": false,
  "resolver": "8.8.8.8:53"
}
EOF

cat <<EOF > config.json
{
"server": "$domain:$port",
"protocol": "$protocol",
"up_mbps": $upload,
"down_mbps": $download,
"http": {
"listen": "127.0.0.1:8888",
"timeout" : 300,
"disable_udp": false
},
"socks5": {
"listen": "127.0.0.1:8889",
"timeout": 300,
"disable_udp": false,
"user": "pekora",
"password": "pekopeko"
},
"alpn": "h3",
"acl": "acl/routes.acl",
"mmdb": "acl/Country.mmdb",
"auth_str": "$auth_str",
"server_name": "$domain",
"insecure": false,
"recv_window_conn": $r_conn,
"recv_window": $r_client,
"disable_mtu_discovery": false,
"resolver": "119.29.29.29:53",
"retry": 5,
"retry_interval": 3
}
EOF

fi

cat <<EOF >/etc/systemd/system/hysteria.service
[Unit]
Description=hysteria:Hello World!
After=network.target
[Service]
Type=simple
PIDFile=/run/hysteria.pid
ExecStart=/etc/hysteria/hysteria --log-level warn -c /etc/hysteria/config.json server
#Restart=on-failure
#RestartSec=10s
[Install]
WantedBy=multi-user.target
EOF

sysctl -w net.core.rmem_max=8000000
sysctl -p
netfilter-persistent save
netfilter-persistent reload
chmod 644 /etc/systemd/system/hysteria.service
systemctl daemon-reload
systemctl enable hysteria
systemctl start hysteria
echo -e "\033[1;;35m\nwait...\n\033[0m"
sleep 3
status=`systemctl is-active hysteria`
if [ "${status}" = "active" ];then
crontab -l > ./crontab.tmp
echo  "0 4 * * * systemctl restart hysteria" >> ./crontab.tmp
crontab ./crontab.tmp
rm -rf ./crontab.tmp

echo -e "\033[35m↓***********************************↓↓↓copy↓↓↓*******************************↓\033[0m"
cat ./config.json
echo -e "\033[35m↑***********************************↑↑↑copy↑↑↑*******************************↑\033[0m"
