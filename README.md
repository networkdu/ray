# 🚀 V2Panel 一键部署脚本

这是一个适用于 Linux 系统的全自动部署脚本，专为部署基于 Flask 的 V2Panel 项目设计。  
支持系统依赖安装、Python 模块检测、代码包下载、systemd 服务注册与自启动。

---

## ✅ 功能亮点

- 🔍 自动识别系统类型（支持 Ubuntu/Debian/CentOS/Rocky/AlmaLinux）
- 💡 自动判断是否已安装依赖，避免重复安装（幂等执行）
- 📦 安装 `curl` / `wget` / `unzip` / `python3` / `pip3`（如缺失）
- 🧪 批量检测并安装 Python 模块（如 Flask / json5）
- 🌐 自动下载并解压 v2panel 安装包
- ⚙️ 自动创建并启用 systemd 启动服务
- 🔁 可重复执行，不会产生副作用

---

## 🚀 快速部署

```bash
curl -fsSL https://raw.githubusercontent.com/networkdu/ray/refs/heads/main/panel.sh |  bash
```

或者手动下载安装：

```bash
wget https://yourdomain.com/deploy.sh -O deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh
```



## 📦 Python 模块配置（批量处理）

你可以在脚本中编辑如下列表，自动安装所需模块：

```bash
PY_MODULES=(
  "flask:flask"
  "json5:json5"
)
```

支持 `模块名:pip包名` 格式，例如：

- `yaml:PyYAML` 表示 `import yaml`，安装 `PyYAML`
- `some_module:some-other-pkg`

---

## 🛠 systemd 服务信息

服务名：`v2panel`

```bash
systemctl status v2panel      # 查看状态
journalctl -fu v2panel        # 查看日志
systemctl restart v2panel     # 重启服务
systemctl stop v2panel        # 停止服务
```

---

## 🧩 端口说明

脚本默认运行 `/opt/v2panel/app.py`，你应确保其中：

```python
app.run(host="::", port=9000)  # 可支持 IPv4 + IPv6
```

如需更改端口，请在 `app.py` 或 systemd 中指定。

---

## 📜 License

MIT License

---

## 🙌 欢迎反馈与改进

如果你发现问题或希望功能增强，欢迎提交 Issue 或 PR！
