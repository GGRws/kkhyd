#!/usr/bin/env bash

# 璁剧疆鍚勫彉閲?UUID='89c64594-ea89-4036-b4f2-174fe6fa3388'
VMESS_WSPATH='/$UUID/vmess'
VLESS_WSPATH='/$UUID/vless'
TROJAN_WSPATH='/$UUID/trojan'
SS_WSPATH='/$UUID/shadowsocks'


# 瀹夎绯荤粺渚濊禆
check_dependencies() {
  DEPS_CHECK=("wget" "unzip")
  DEPS_INSTALL=(" wget" " unzip")
  for ((i=0;i<${#DEPS_CHECK[@]};i++)); do [[ ! $(type -p ${DEPS_CHECK[i]}) ]] && DEPS+=${DEPS_INSTALL[i]}; done
  [ -n "$DEPS" ] && { apt-get update >/dev/null 2>&1; apt-get install -y $DEPS >/dev/null 2>&1; }
}

generate_config() {
  cat > config.json << EOF
{
    "log": {
        "access": "/dev/null",
        "error": "/dev/null",
        "loglevel": "none"
    },
    "inbounds": [
        {
            "port": 8080,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}",
                        "flow": "xtls-rprx-direct"
                    }
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": 3001
                    },
                    {
                        "path": "${VLESS_WSPATH}",
                        "dest": 3002
                    },
                    {
                        "path": "${VMESS_WSPATH}",
                        "dest": 3003
                    },
                    {
                        "path": "${TROJAN_WSPATH}",
                        "dest": 3004
                    },
                    {
                        "path": "${SS_WSPATH}",
                        "dest": 3005
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp"
            }
        },
        {
            "port": 3001,
            "listen": "127.0.0.1",
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "none"
            }
        },
        {
            "port": 3002,
            "listen": "127.0.0.1",
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}",
                        "level": 0
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "path": "${VLESS_WSPATH}"
                }
            },
            "sniffing": {
                "enabled": false,
                "destOverride": [
                    "http",
                    "tls"
                ],
                "metadataOnly": false
            }
        },
        {
            "port": 3003,
            "listen": "127.0.0.1",
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}",
                        "alterId": 0
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "${VMESS_WSPATH}"
                }
            },
            "sniffing": {
                "enabled": false,
                "destOverride": [
                    "http",
                    "tls"
                ],
                "metadataOnly": false
            }
        },
        {
            "port": 3004,
            "listen": "127.0.0.1",
            "protocol": "trojan",
            "settings": {
                "clients": [
                    {
                        "password": "${UUID}"
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "path": "${TROJAN_WSPATH}"
                }
            },
            "sniffing": {
                "enabled": false,
                "destOverride": [
                    "http",
                    "tls"
                ],
                "metadataOnly": false
            }
        },
        {
            "port": 3005,
            "listen": "127.0.0.1",
            "protocol": "shadowsocks",
            "settings": {
                "clients": [
                    {
                        "method": "chacha20-ietf-poly1305",
                        "password": "${UUID}"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "${SS_WSPATH}"
                }
            },
            "sniffing": {
                "enabled": false,
                "destOverride": [
                    "http",
                    "tls"
                ],
                "metadataOnly": false
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        },
        {
            "tag": "WARP",
            "protocol": "wireguard",
            "settings": {
                "secretKey": "GAl2z55U2UzNU5FG+LW3kowK+BA/WGMi1dWYwx20pWk=",
                "address": [
                    "172.16.0.2/32",
                    "2606:4700:110:8f0a:fcdb:db2f:3b3:4d49/128"
                ],
                "peers": [
                    {
                        "publicKey": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
                        "endpoint": "engage.cloudflareclient.com:2408"
                    }
                ]
            }
        }
    ],
    "routing": {
        "domainStrategy": "AsIs",
        "rules": [
            {
                "type": "field",
                "domain": [
                    "domain:openai.com",
                    "domain:ai.com"
                ],
                "outboundTag": "WARP"
            }
        ]
    },
    "dns": {
        "server": [
            "8.8.8.8",
            "8.8.4.4"
        ]
    }
}
EOF
}

generate_argo() {
  cat > argo.sh << ABC
#!/usr/bin/env bash
  
# 涓嬭浇骞惰繍琛?Argo
check_file() {
  [ ! -e cloudflared ] && wget -O cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && chmod +x cloudflared
}

run() {
  if [[ -e cloudflared && ! \$(ss -nltp) =~ cloudflared ]]; then
    chmod +x ./cloudflared && ./cloudflared tunnel --url http://localhost:8080 --no-autoupdate > argo.log 2>&1 &
    sleep 10
    ARGO=\$(cat argo.log | grep -oE "https://.*[a-z]+cloudflare.com" | sed "s#https://##")
    VMESS="{ \"v\": \"2\", \"ps\": \"Argo_xray_vmess\", \"add\": \"icook.hk\", \"port\": \"443\", \"id\": \"${UUID}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"\${ARGO}\", \"path\": \"${VMESS_WSPATH}?ed=2048\", \"tls\": \"tls\", \"sni\": \"\${ARGO}\", \"alpn\": \"\" }"
    
    cat > list << EOF
<html>
<head>
<title>Argo-xray</title>
<style type="text/css">
body {
	  font-family: Geneva, Arial, Helvetica, san-serif;
    }
div {
	  margin: 0 auto;
	  text-align: left;
      white-space: pre-wrap;
      word-break: break-all;
      max-width: 80%;
	  margin-bottom: 10px;
}
</style>
</head>
<body bgcolor="#FFFFFF" text="#000000">
<div><font color="#009900"><b>VMESS鍗忚閾炬帴锛?/b></font></div>
<div>vmess://\$(echo \$VMESS | base64 -w0)</div>
<div><font color="#009900"><b>VLESS鍗忚閾炬帴锛?/b></font></div>
<div>vless://${UUID}@icook.hk:443?encryption=none&security=tls&sni=\${ARGO}&type=ws&host=\${ARGO}&path=${VLESS_WSPATH}?ed=2048#Argo_xray_vless</div>
<div><font color="#009900"><b>TROJAN鍗忚閾炬帴锛?/b></font></div>
<div>trojan://${UUID}@icook.hk:443?security=tls&sni=\${ARGO}&type=ws&host=\${ARGO}&path=${TROJAN_WSPATH}?ed=2048#Argo_xray_trojan</div>
<div><font color="#009900"><b>SS鍗忚鏄庢枃锛?/b></font></div>
<div>鏈嶅姟鍣ㄥ湴鍧€锛歩cook.hk</div>
<div>绔彛锛?43</div>
<div>瀵嗙爜锛?{UUID}</div>
<div>鍔犲瘑鏂瑰紡锛歝hacha20-ietf-poly1305</div>
<div>浼犺緭鍗忚锛歸s</div>
<div>host锛歕${ARGO}</div>
<div>path璺緞锛?SS_WSPATH?ed=2048</div>
<div>TLS锛氬紑鍚?/div>
</body>
</html>
EOF
    cat list
  fi
}

check_file
run
wait
ABC
}

generate_nezha() {
  cat > nezha.sh << EOF
#!/usr/bin/env bash

# 鍝悞鐨勪笁涓弬鏁?NEZHA_SERVER=${NEZHA_SERVER}
NEZHA_PORT=${NEZHA_PORT}
NEZHA_KEY=${NEZHA_KEY}

# 妫€娴嬫槸鍚﹀凡杩愯
check_run() {
  [[ \$(pidof nezha-agent) ]] && echo "鍝悞瀹㈡埛绔鍦ㄨ繍琛屼腑" && exit
}

# 涓変釜鍙橀噺涓嶅叏鍒欎笉瀹夎鍝悞瀹㈡埛绔?check_variable() {
  [[ -z "\${NEZHA_SERVER}" || -z "\${NEZHA_PORT}" || -z "\${NEZHA_KEY}" ]] && exit
}

# 涓嬭浇鏈€鏂扮増鏈?Nezha Agent
download_agent() {
  if [ ! -e nezha-agent ]; then
    URL=\$(wget -qO- -4 "https://api.github.com/repos/naiba/nezha/releases/latest" | grep -o "https.*linux_amd64.zip")
    wget -t 2 -T 10 -N \${URL}
    unzip -qod ./ nezha-agent_linux_amd64.zip && rm -f nezha-agent_linux_amd64.zip
  fi
}

# 杩愯瀹㈡埛绔?run() {
  [[ ! \$PROCESS =~ nezha-agent && -e nezha-agent ]] && chmod +x ./nezha-agent && ./nezha-agent -s \${NEZHA_SERVER}:\${NEZHA_PORT} -p \${NEZHA_KEY}
}

check_run
check_variable
download_agent
run
wait
EOF
}

check_dependencies
generate_config
generate_argo
generate_nezha
[ -e nezha.sh ] && bash nezha.sh 2>&1 &
[ -e argo.sh ] && bash argo.sh 2>&1 &
wait
