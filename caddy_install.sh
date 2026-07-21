#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

CADDY_BIN="/usr/local/bin/caddy"
CADDY_DIR="/etc/caddy"
CADDY_FILE="${CADDY_DIR}/Caddyfile"
CADDY_SERVICE="/etc/systemd/system/caddy.service"
CADDY_URL="https://github.com/lxhao61/integrated-examples/releases/download/20260605/caddy-linux-amd64.tar.gz"
WEB_ROOT="/var/www/html"
WEB_INDEX="${WEB_ROOT}/index.html"

check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误：请以 root 权限运行此脚本${RESET}"
    exit 1
  fi
}

check_caddy_installed() {
  command -v caddy >/dev/null 2>&1
}

create_caddy_user() {
  if ! id caddy >/dev/null 2>&1; then
    groupadd --system caddy
    useradd --system \
      --gid caddy \
      --create-home \
      --home-dir /var/lib/caddy \
      --shell "$(command -v nologin)" \
      --comment "Caddy web server" caddy
  fi
}

install_caddy_binary() {
  echo -e "${GREEN}正在安装 Caddy...${RESET}"
  curl -fsSL "$CADDY_URL" | tar --overwrite -zx caddy
  mv -f caddy "$CADDY_BIN"
  chmod +x "$CADDY_BIN"
}

install_caddy_service() {
  mkdir -p "$CADDY_DIR"
  chown -R caddy:caddy "$CADDY_DIR"
  chmod 700 "$CADDY_DIR"

  cat > "$CADDY_SERVICE" <<'EOF'
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
Environment=XDG_CONFIG_HOME=/etc XDG_DATA_HOME=/etc
ExecStart=/usr/local/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/etc/caddy
AmbientCapabilities=CAP_NET_BIND_SERVICE
RestartPreventExitStatus=1
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
}

write_default_index_html() {
  mkdir -p "$WEB_ROOT"

  cat > "$WEB_INDEX" <<'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Global Content Delivery Network | Node 007</title>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@300;500&display=swap">
    <style>
        :root { --main-blue: #0071e3; --bg-gray: #f5f5f7; }
        body { font-family: 'Inter', -apple-system, sans-serif; margin: 0; background: #fff; color: #1d1d1f; }
        .nav-bar { height: 50px; background: rgba(251,251,253,0.8); border-bottom: 1px solid #d2d2d7; }
        .hero { max-width: 1000px; margin: 100px auto; padding: 0 40px; text-align: center; }
        h1 { font-size: 56px; font-weight: 600; letter-spacing: -0.01em; margin-bottom: 20px; }
        p { font-size: 24px; color: #86868b; line-height: 1.4; max-width: 700px; margin: 0 auto; }
        .features { display: flex; justify-content: space-between; max-width: 900px; margin: 80px auto; gap: 30px; }
        .item { flex: 1; padding: 30px; background: var(--bg-gray); border-radius: 18px; }
        .item h3 { margin-top: 0; font-size: 21px; }
        .item p { font-size: 16px; margin-top: 10px; }
        footer { margin-top: 100px; padding: 40px; font-size: 12px; color: #86868b; text-align: center; border-top: 1px solid #d2d2d7; }
        .resource-manifest { display: none; visibility: hidden; }
    </style>
</head>
<body>

<div class="nav-bar"></div>

<main class="hero">
    <h1>分布式边缘分发节点</h1>
    <p>为全球用户提供高速、稳定的静态资源调度服务。通过智能路径优化，确保数据传输的高效与合规。</p>
    
    <div class="features">
        <div class="item">
            <h3>低延迟响应</h3>
            <p>基于全球骨干网，大幅提升静态资源加载速度。</p>
        </div>
        <div class="item">
            <h3>高可用架构</h3>
            <p>多节点冗余设计，保障 99.9% 的系统在线率。</p>
        </div>
        <div class="item">
            <h3>自动化调度</h3>
            <p>实时分析入站流量，动态分配最优资源路径。</p>
        </div>
    </div>
</main>

<div class="resource-manifest">
    <a href="https://www.google.com/images/phd/user_photos/any_name.png">Resource_01</a>
    <a href="https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png">Resource_02</a>
    <a href="https://fonts.gstatic.com/s/inter/v12/UcC73FwrK3iLTeHuS_fvQtMwCp50KnMa2boKoduKmMEVuLyfMZhrib2Bg-4.woff2">Resource_03</a>
    <a href="https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=1000&q=80">Resource_04</a>
    <img src="https://www.google-analytics.com/analytics.js" alt="ping">
</div>

<footer>
    &copy; <span id="year"></span> Global Infrastructure Group. Node Status: Operational.
</footer>

<script>
  document.getElementById('year').textContent = new Date().getFullYear();

  document.title = `Global Content Delivery Network | Node ${String(
    Math.floor(Math.random() * 1000)
  ).padStart(3, '0')}`;
</script>

</body>
</html>
EOF
}

write_fallback_caddyfile() {
  cat > "$CADDY_FILE" <<'EOF'
{
    admin off
    # local_certs
    # skip_install_trust
    # email admin@example.com
    # default_sni example.com
    log default {
        level ERROR
    }
    servers {
        protocols h1 h2c
    }
    # layer4 {
    #     tcp/:4443 {
    #         route {
    #             # the handler below will choose a relevant certificate
    #             # from all the certificates available for the HTTP app
    #             # based on the requested server name
    #             tls {
    #                 connection_policy {
    #                     # the ALPN below is required to allow proxying to port 80,
    #                     # if the client supports HTTP/2 in addition to HTTP/1.1
    #                     alpn http/1.1
    #                 }
    #             }
    #             proxy tcp/127.0.0.1:1234
    #         }
    #     }
    # }
    # caddy-l4配置参考自：https://github.com/mholt/caddy-l4/issues/244
}

http://:77 {
    log default
    root * /var/www/html
    file_server
}

# *.example.com {
#     # makes Caddy obtain a wildcard TLS certificate by default
#     # use the internal TLS issuer
#     tls {
#         issuer internal
#     }
#     # load a custom TLS certificate in the HTTP app
#     tls <cert_file> <key_file>
#     respond "OK" 200
# }
EOF
}

validate_and_reload() {
  echo -e "${GREEN}校验 Caddy 配置...${RESET}"
  caddy fmt --overwrite "$CADDY_FILE" >/dev/null
  caddy validate --config "$CADDY_FILE"

  systemctl enable caddy >/dev/null 2>&1 || true
  if systemctl is-active --quiet caddy; then
    systemctl reload caddy
  else
    systemctl start caddy
  fi
  echo -e "${GREEN}操作完成${RESET}"
}

install_caddy() {
  check_root
  create_caddy_user
  install_caddy_binary
  install_caddy_service
  write_default_index_html
  write_fallback_caddyfile
  validate_and_reload
  echo -e "${GREEN}Caddy 安装完成，当前为默认配置${RESET}"
}

switch_to_default() {
  check_root
  if ! check_caddy_installed; then
    echo -e "${RED}错误：Caddy 未安装${RESET}"
    exit 1
  fi
  write_default_index_html
  write_fallback_caddyfile
  validate_and_reload
  echo -e "${GREEN}已切换为默认配置${RESET}"
}

uninstall_caddy() {
  check_root
  echo -e "${YELLOW}正在卸载 Caddy...${RESET}"

  systemctl stop caddy.service >/dev/null 2>&1 || true
  systemctl disable caddy.service >/dev/null 2>&1 || true

  rm -f "$CADDY_SERVICE"
  systemctl daemon-reload

  rm -f "$CADDY_BIN"
  rm -rf "$CADDY_DIR"

  rm -f "$WEB_INDEX"
  rmdir "$WEB_ROOT" >/dev/null 2>&1 || true

  if id caddy >/dev/null 2>&1; then
    userdel -r caddy >/dev/null 2>&1 || true
  fi

  if getent group caddy >/dev/null 2>&1; then
    groupdel caddy >/dev/null 2>&1 || true
  fi

  echo -e "${GREEN}Caddy 卸载成功${RESET}"
}

show_usage() {
  cat <<EOF
用法:
  $0         默认安装 Caddy，并写入默认配置
  $0 -f      切换为默认配置
  $0 -u      卸载 Caddy
说明:
  - 默认安装与 -f 切换后都会自动校验并重载配置
示例:
  $0
  $0 -f
  $0 -u
EOF
}

main() {
  case "${1:-}" in
    "")
      install_caddy
      ;;
    -f)
      switch_to_default
      ;;
    -u)
      uninstall_caddy
      ;;
    -h|--help)
      show_usage
      ;;
    *)
      echo -e "${RED}错误：未知参数 $1${RESET}"
      show_usage
      exit 1
      ;;
  esac
}

trap 'echo -e "${RED}已取消操作${RESET}"; exit 1' INT
main "$@"
