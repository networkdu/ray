#!/bin/bash

# 判断是否为root用户
if [ "$(id -u)" -ne 0 ]; then
    echo "请使用root权限运行此脚本。"
    exit 1
fi

# 判断系统并更新软件源
if [ -f /etc/debian_version ]; then
    OS="debian"
    echo "检测到系统为Debian/Ubuntu，正在更新软件源..."
    apt update -y && apt install -y curl socat
elif [ -f /etc/redhat-release ]; then
    OS="centos"
    echo "检测到系统为CentOS，正在更新软件源..."
    yum update -y && yum install -y curl socat
else
    echo "无法识别的系统，请手动安装curl和socat后再运行此脚本。"
    exit 1
fi

# 安装acme.sh
if [ ! -f ~/.acme.sh/acme.sh ]; then
    echo "正在安装acme.sh..."
    curl https://get.acme.sh | sh
else
    echo "acme.sh已安装。"
fi

# 设置环境变量
export PATH="~/.acme.sh:$PATH"

# 输入域名
read -p "请输入您的域名（例如example.com）：" DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "域名不能为空，请重新运行脚本。"
    exit 1
fi

# 签发证书
~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone
if [ $? -ne 0 ]; then
    echo "证书签发失败，请检查域名解析或防火墙设置。"
    exit 1
fi

# 输入证书保存路径
read -p "请输入证书保存目录（例如/mnt）：" CERT_PATH
if [ ! -d "$CERT_PATH" ]; then
    echo "目录不存在，正在创建..."
    mkdir -p "$CERT_PATH"
fi

# 安装证书到指定目录
~/.acme.sh/acme.sh --installcert -d "$DOMAIN" \
    --key-file "$CERT_PATH/1.key" \
    --fullchain-file "$CERT_PATH/1.crt"

if [ $? -eq 0 ]; then
    echo "证书安装成功！"
    echo "私钥路径: $CERT_PATH/1.key"
    echo "证书路径: $CERT_PATH/1.crt"
else
    echo "证书安装失败，请检查日志。"
    exit 1
fi
