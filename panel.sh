#!/bin/bash

set -e  # 脚本中任一命令失败则终止
set -o pipefail  # 管道中任一失败也导致整体失败

###############################################
# 0. 必须 root
###############################################
if [ "$(id -u)" -ne 0 ]; then
  echo "[❌ 错误] 请以 root 用户运行此脚本（例如 sudo -i 后再执行）"
  exit 1
fi

echo "[0] ✔ 已确认以 root 身份运行"

###############################################
# 1. 检测系统类型并设置包管理器
###############################################
echo "[1] 🔍 检测系统类型..."

if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS_ID="${ID}"
  OS_NAME="${PRETTY_NAME:-$ID}"
else
  echo "[❌ 错误] 无法识别系统（缺少 /etc/os-release）"
  exit 1
fi

if [[ "$OS_ID" == "debian" || "$OS_ID" == "ubuntu" ]]; then
  PKG_UPDATE="apt update -y"
  PKG_INSTALL="apt install -y"
elif [[ "$OS_ID" == "centos" || "$OS_ID" == "rhel" || "$OS_ID" == "rocky" || "$OS_ID" == "almalinux" ]]; then
  PKG_UPDATE="yum makecache -y"
  PKG_INSTALL="yum install -y"
else
  echo "[❌ 错误] 不支持的系统类型：$OS_NAME ($OS_ID)"
  exit 1
fi

echo "[1] ✔ 系统识别成功：$OS_NAME"

###############################################
# 2. 安装系统依赖
###############################################
echo "[2] 🧱 安装系统依赖：curl wget unzip python3 pip3 flask json5 ..."
$PKG_UPDATE
$PKG_INSTALL curl wget unzip python3 pip python3-flask python3-json5

echo "[2] ✔ 系统依赖安装完成"

###############################################
# 3. 验证 Python 模块是否可用
###############################################
echo "[3] 🧪 验证 Python 模块 flask 和 json5 是否可用..."
if python3 -c "import flask, json5" >/dev/null 2>&1; then
  echo "[3] ✔ 模块导入成功"
else
  echo "[❌ 错误] flask/json5 模块导入失败，请检查环境"
  exit 1
fi

###############################################
# 4. 下载 v2.zip 安装包
###############################################
ZIP_URL="https://raw.githubusercontent.com/networkdu/ray/refs/heads/main/v2panel1119.zip"
ZIP_PATH="/tmp/v2.zip"
echo "[4] 🌐 下载安装包 v2.zip ..."
curl -fSL "$ZIP_URL" -o "$ZIP_PATH"
echo "[4] ✔ 下载完成：$ZIP_PATH"

###############################################
# 5. 解压安装包到 /opt/v2panel
###############################################
TARGET_DIR="/opt/v2panel"
echo "[5] 📦 解压安装包到 $TARGET_DIR ..."
rm -rf "$TARGET_DIR"
unzip -o "$ZIP_PATH" -d /opt
echo "[5] ✔ 解压完成"

###############################################
# 6. 创建 systemd 启动服务
###############################################
echo "[6] 🛠 创建 systemd 服务 v2panel.service ..."
cat >/etc/systemd/system/v2panel.service <<EOF
[Unit]
Description=V2Panel Flask App
After=network.target

[Service]
User=root
WorkingDirectory=/opt/v2panel
ExecStart=/usr/bin/python3 app.py
Restart=always
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF
echo "[6] ✔ 服务文件创建成功"

###############################################
# 7. 启动服务 & 设置开机自启
###############################################
echo "[7] 🚀 启动服务并设置为开机自启..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable v2panel
systemctl restart v2panel
echo "[7] ✔ 服务已启动并开机自启"

###############################################
# 8. 部署完成提示
###############################################
echo
echo "🎉 部署完成！以下是服务管理命令："
echo "▶ 查看服务状态： systemctl status v2panel"
echo "▶ 查看服务日志： journalctl -fu v2panel"
echo "▶ 测试访问地址： http://127.0.0.1:9000"
echo
