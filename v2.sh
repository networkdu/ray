#!/bin/bash

# 检查是否为 root 用户
if [ "$(id -u)" -ne 0 ]; then
    echo "请使用 root 权限运行此脚本。"
    exit 1
fi

# 定义变量
ACME_SH_PATH="~/.acme.sh"
NGINX_CONFIG_URL="https://github.com/networkdu/qb439/raw/refs/heads/main/123.zip"
V2RAY_DOWNLOAD_URL="https://github.com/networkdu/qb439/raw/refs/heads/main/v2ray-linux-64.zip"
V2RAY_DOWNLOAD_DIR="/tmp"
V2RAY_INSTALL_DIR="/usr/local/bin/v2ray"
V2RAY_SERVICE_FILE="/etc/systemd/system/v2ray.service"
V2RAY_LOG_DIR="/var/log/v2ray"
V2RAY_ACCESS_LOG="$V2RAY_LOG_DIR/access.log"
V2RAY_ERROR_LOG="$V2RAY_LOG_DIR/error.log"

# 通用安装依赖
install_dependencies() {
    echo "检查并安装必要依赖..."
    if [ -f /etc/debian_version ]; then
        apt update -y && apt install -y curl socat  unzip wget
    elif [ -f /etc/redhat-release ]; then
        yum update -y && yum install -y curl socat epel-release  unzip wget
    else
        echo "不支持的操作系统，请手动安装依赖后再运行此脚本。"
        exit 1
    fi
}

# 检查并关闭占用 80 端口的进程
close_port_80() {
    echo "检查 80 端口是否被占用..."
    PORT_PROCESS=$(lsof -i:80 | awk 'NR>1 {print $2}' | head -n 1)
    if [ -n "$PORT_PROCESS" ]; then
        echo "检测到占用 80 端口的进程: PID=$PORT_PROCESS"
        kill -9 "$PORT_PROCESS"
        echo "已关闭占用 80 端口的进程。"
    else
        echo "80 端口未被占用。"
    fi
}

# 安装 acme.sh 并申请证书
# 修改后的 ACME 安装及证书申请逻辑
install_acme() {
    echo "安装 acme.sh..."
    ACME_SH_BIN="$HOME/.acme.sh/acme.sh"
    if [ ! -f "$ACME_SH_BIN" ]; then
        curl https://get.acme.sh | sh
    fi

    if [ ! -f "$ACME_SH_BIN" ]; then
        echo "acme.sh 安装失败，请检查网络连接或手动安装 acme.sh 后重试。"
        exit 1
    fi

    export PATH="$HOME/.acme.sh:$PATH"

    echo "请确保您的域名已解析到当前主机的 IP 地址。"
    read -p "请输入您的邮箱地址用于注册 acme.sh 账号（默认: admin@example.com）： " EMAIL
    EMAIL=${EMAIL:-admin@example.com}
    $ACME_SH_BIN --register-account -m "$EMAIL"

    read -p "请输入您的域名（默认: example.com）： " DOMAIN
    DOMAIN=${DOMAIN:-example.com}

    close_port_80

    $ACME_SH_BIN --issue -d "$DOMAIN" --standalone
    if [ $? -ne 0 ]; then
        echo "证书签发失败！可能的原因包括："
        echo "1. 域名未正确解析到当前主机 IP。"
        echo "2. 防火墙或安全组阻止了 80 端口访问。"
        echo "3. 输入的域名有误。"
        exit 1
    fi

    read -p "请输入证书保存目录（默认: /mnt）： " CERT_PATH
    CERT_PATH=${CERT_PATH:-/mnt}
    mkdir -p "$CERT_PATH"

    $ACME_SH_BIN --installcert -d "$DOMAIN" \
        --key-file "$CERT_PATH/1.key" \
        --fullchain-file "$CERT_PATH/1.crt"
    if [ $? -eq 0 ]; then
        echo "证书安装成功！"
    else
        echo "证书安装失败。"
        exit 1
    fi
}


# 安装并配置 Nginx
install_nginx() {
   apt install ngnix -y 
    echo "安装和配置 Nginx..."
    systemctl start nginx
    systemctl enable nginx

    echo "删除默认配置文件..."
    rm -f /etc/nginx/nginx.conf
    rm -rf /etc/nginx/conf.d/*

    echo "下载并解压配置文件..."
    wget -O /tmp/nginx-config.zip "$NGINX_CONFIG_URL"
    unzip /tmp/nginx-config.zip -d /tmp/nginx-config
    cp /tmp/nginx-config/etc/nginx/nginx.conf /etc/nginx/nginx.conf
    cp /tmp/nginx-config/etc/nginx/conf.d/* /etc/nginx/conf.d/

    rm -rf /tmp/nginx-config.zip /tmp/nginx-config

    echo "检查并重启 Nginx 服务..."
    nginx -t && systemctl restart nginx
}

# 安装并配置 V2Ray
install_v2ray() {
    echo "安装 V2Ray..."

    mkdir -p "$V2RAY_LOG_DIR"
    touch "$V2RAY_ACCESS_LOG"
    touch "$V2RAY_ERROR_LOG"

    echo "下载 V2Ray 压缩包..."
    mkdir -p "$V2RAY_DOWNLOAD_DIR"
    wget -O "$V2RAY_DOWNLOAD_DIR/v2ray-deployment.zip" "$V2RAY_DOWNLOAD_URL"
    mkdir -p "$V2RAY_INSTALL_DIR"
    unzip "$V2RAY_DOWNLOAD_DIR/v2ray-deployment.zip" -d "$V2RAY_INSTALL_DIR"
    chmod +x "$V2RAY_INSTALL_DIR/v2ray"

    echo "配置 V2Ray systemd 服务..."
    cat > "$V2RAY_SERVICE_FILE" <<EOF
[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$V2RAY_INSTALL_DIR/v2ray run -config $V2RAY_INSTALL_DIR/config.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable v2ray
    systemctl restart v2ray
    echo "V2Ray 服务已启动。"

    echo "清理临时文件..."
    rm -f "$V2RAY_DOWNLOAD_DIR/v2ray-deployment.zip"
}

# 提供选单让用户选择步骤
menu() {
    echo "请选择要执行的步骤："
    echo "1. 安装依赖"
    echo "2. 配置并申请证书 (acme.sh)"
    echo "3. 配置 Nginx"
    echo "4. 配置 V2Ray"
    echo "5. 全部执行"
    read -p "请输入对应的数字 (默认: 5): " CHOICE
    CHOICE=${CHOICE:-5}

    case $CHOICE in
        1)
            install_dependencies
            ;;
        2)
            install_acme
            ;;
        3)
            install_nginx
            ;;
        4)
            install_v2ray
            ;;
        5)
            install_dependencies
            install_acme
            install_nginx
            install_v2ray
            ;;
        *)
            echo "无效的选择，退出。"
            exit 1
            ;;
    esac
}

menu

echo "所有任务已完成！"
