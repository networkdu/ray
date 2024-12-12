#!/bin/bash

# 定义云端配置文件链接
CONFIG_URL="https://github.com/networkdu/qb439/raw/refs/heads/main/123.zip"

# 检查系统类型
OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release)

# 安装 Nginx
if [[ "$OS" == *"Debian"* || "$OS" == *"Ubuntu"* ]]; then
    echo "Debian/Ubuntu 系统，安装 Nginx..."
    apt update
    apt install -y nginx unzip curl
elif [[ "$OS" == *"CentOS"* || "$OS" == *"RHEL"* ]]; then
    echo "CentOS/RHEL 系统，安装 Nginx..."
    yum install -y epel-release
    yum install -y nginx unzip curl
else
    echo "不支持的操作系统，退出..."
    exit 1
fi

# 启动 Nginx 服务并设置为开机自启
echo "启动并设置 Nginx 开机自启..."
systemctl start nginx
systemctl enable nginx

# 删除默认配置文件
echo "删除默认配置文件..."
rm -f /etc/nginx/nginx.conf
rm -rf /etc/nginx/conf.d/*

# 下载并解压配置文件
echo "下载云端配置文件并解压..."
wget -O /tmp/nginx-config.zip $CONFIG_URL
unzip /tmp/nginx-config.zip -d /tmp/nginx-config

# 复制配置文件到指定位置
echo "复制配置文件到 Nginx 目录..."
cp /tmp/nginx-config/etc/nginx/nginx.conf /etc/nginx/nginx.conf
cp /tmp/nginx-config/etc/nginx/conf.d/* /etc/nginx/conf.d/

# 删除临时下载的配置文件
rm -rf /tmp/nginx-config.zip /tmp/nginx-config

# 检查并重启 Nginx 服务
echo "检查 Nginx 配置并重启 Nginx..."
nginx -t && systemctl restart nginx

echo "Nginx 安装和配置完成！"
