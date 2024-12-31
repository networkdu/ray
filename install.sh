#!/bin/bash

# 一键部署 V2Ray 服务脚本
# 请确保运行该脚本的用户具备 root 权限

# 定义变量
DOWNLOAD_URL="https://github.com/networkdu/qb439/raw/refs/heads/main/v2ray-linux-64.zip"  # 替换为实际 URL
DOWNLOAD_DIR="/tmp"                                       # 临时下载目录
INSTALL_DIR="/usr/local/bin/v2ray"                        # 安装目录
SERVICE_FILE="/etc/systemd/system/v2ray.service"          # systemd 服务文件路径
LOG_DIR="/var/log/v2ray"                                  # 日志目录
ACCESS_LOG="$LOG_DIR/access.log"                          # 访问日志文件
ERROR_LOG="$LOG_DIR/error.log"                            # 错误日志文件

# 检查操作系统
OS_NAME=$(cat /etc/*release | grep ^ID= | cut -d= -f2 | tr -d '"')

# 步骤 1: 优化 TCP 设置
tcp_tune() {
    echo "==>  优化 TCP 设置中..."
    
    # 删除现有的 TCP 相关设置
    sed -i '/net.ipv4.tcp_no_metrics_save/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_frto/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_mtu_probing/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_rfc1337/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_sack/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_fack/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_window_scaling/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_adv_win_scale/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_moderate_rcvbuf/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
    sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
    sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
    sed -i '/net.ipv4.udp_rmem_min/d' /etc/sysctl.conf
    sed -i '/net.ipv4.udp_wmem_min/d' /etc/sysctl.conf
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf

    # 添加新的 TCP 优化设置
    cat >> /etc/sysctl.conf << EOF
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=2
net.ipv4.tcp_adv_win_scale=2
net.ipv4.tcp_moderate_rcvbuf=1
net.ipv4.tcp_rmem=4096 65536 37331520
net.ipv4.tcp_wmem=4096 65536 37331520
net.core.rmem_max=37331520
net.core.wmem_max=37331520
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

    # 应用系统配置
    sysctl -p && sysctl --system
    echo "TCP 设置已优化。"
}

# 步骤 2: 检查并安装所需依赖
echo "==> 步骤 1: 检查并安装所需依赖..."
if [[ "$OS_NAME" == "centos" || "$OS_NAME" == "rhel" ]]; then
    echo "检测到 CentOS 或 RHEL 系统..."
    yum clean all
    yum makecache
    yum update -y
    if ! command -v wget &> /dev/null; then
        yum install -y wget
    fi
    if ! command -v unzip &> /dev/null; then
        yum install -y unzip
    fi
elif [[ "$OS_NAME" == "ubuntu" || "$OS_NAME" == "debian" ]]; then
    echo "检测到 Ubuntu 或 Debian 系统..."
    apt update -y
    if ! command -v wget &> /dev/null; then
        apt install -y wget
    fi
    if ! command -v unzip &> /dev/null; then
        apt install -y unzip
    fi
else
    echo "不支持的操作系统：$OS_NAME"
    exit 1
fi

# 步骤 2: 创建日志目录和文件
echo "==> 步骤 2: 创建日志目录和文件..."
mkdir -p $LOG_DIR
touch $ACCESS_LOG
touch $ERROR_LOG

# 步骤 3: 下载压缩包
echo "==> 步骤 3: 下载 V2Ray 压缩包..."
mkdir -p $DOWNLOAD_DIR
wget -O $DOWNLOAD_DIR/v2ray-deployment.zip $DOWNLOAD_URL
if [ $? -ne 0 ]; then
    echo "下载失败，请检查 URL 是否正确。"
    exit 1
fi
echo "下载完成：$DOWNLOAD_DIR/v2ray-deployment.zip"

# 步骤 4: 解压文件
echo "==> 步骤 4: 解压文件到临时目录..."
mkdir -p $INSTALL_DIR
unzip $DOWNLOAD_DIR/v2ray-deployment.zip -d $INSTALL_DIR
if [ $? -ne 0 ]; then
    echo "解压失败，请检查压缩包是否有效。"
    exit 1
fi
echo "文件已解压到：$INSTALL_DIR"

# 步骤 5: 设置执行权限
echo "==> 步骤 5: 设置执行权限..."
chmod +x $INSTALL_DIR/v2ray

# 步骤 6: 配置 systemd 服务
echo "==> 步骤 6: 配置 V2Ray systemd 服务..."
cat > $SERVICE_FILE <<EOF
[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target

[Service]
User=$USER
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$INSTALL_DIR/v2ray run -config $INSTALL_DIR/config.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF

if [ $? -ne 0 ]; then
    echo "systemd 服务配置失败。"
    exit 1
fi
echo "systemd 服务文件已配置：$SERVICE_FILE"

# 步骤 7: 启用并启动 V2Ray 服务
echo "==> 步骤 7: 启用并启动 V2Ray 服务..."
systemctl daemon-reload
systemctl enable v2ray
systemctl restart v2ray
if [ $? -ne 0 ]; then
    echo "V2Ray 服务启动失败，请检查配置。"
    exit 1
fi
echo "V2Ray 服务已启动并设置为开机自启。"

# 步骤 8: 检查服务状态
echo "==> 步骤 8: 检查 V2Ray 服务状态..."
systemctl status v2ray --no-pager

# 步骤 9: 清理临时文件
echo "==> 步骤 9: 清理临时文件..."
rm -f $DOWNLOAD_DIR/v2ray-deployment.zip

# 调用 tcp_tune 函数优化 TCP 设置
tcp_tune

echo "V2Ray 部署完成！"
