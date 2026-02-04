# Caddy-Quick #

#### Caddy一键安装脚本，仅需一行命令 ####

- 该项目支持使用免费域名与SSL证书，同时支持自签名证书。

- 系统支持RHEL 7+ (CentOS、RedHat、AlmaLinux、RockyLinux)、Debian 9+、Ubuntu 16+

- 提供caddy`v2.10.2`的预编译二进制包，并附带编译安装方式，不写入系统环境变量，确保系统干净如初。

- Caddy包含插件：[caddy-trojan](https://github.com/imgk/caddy-trojan) | [forwardproxy-naive](https://github.com/klzgrad/forwardproxy) 

---

#### 一键安装 ####
```
bash <(curl -Ls https://raw.githubusercontent.com/terminodev/titanicsite7/main/caddy/caddy-quick.sh)
```

#### 参数说明 ####
全部参数均为选填
```
-h               显示帮助信息
-n user1        【选填】自定义用户名 (默认: 随机生成)
-w password     【选填】自定义密码 (默认: 随机生成)
-d example.com  【选填】自定义域名 (默认: 随机生成)
-p 4433         【选填】自定义监听端口 (默认: 443)
-s              【选填】申请可信SSL证书 (默认: 自签名证书)
-6              【选填】使用IPv6地址并验证域名AAAA记录 (默认: IPv4模式,验证A记录)
-b              【选填】从源码编译安装 (默认: 二进制安装)
-t trojan       【选填】指定安装类型: trojan, naiveproxy (默认: trojan)
-u              卸载
```

#### 开放端口 ####
Caddy会自动申请免费ssl证书，其验证方式为`HTTP-01`（80端口），`TLS-ALPN-01`（443端口），请放开80和443端口用于证书验证；有条件的可以使用`DNS-01`验证方式，更稳定。

以下为防火墙命令示例
```
# RHEL(CentOS、RedHat、AlmaLinux、RockyLinux) 放行端口
firewall-cmd --permanent --add-port={80,443}/tcp
firewall-cmd --reload

# RHEL(CentOS、RedHat、AlmaLinux、RockyLinux) 关闭防火墙
systemctl disable firewalld.service --now

# Debian/Ubuntu 放行端口
ufw prepend allow proto tcp from any to any port 80,443

# Debian/Ubuntu 关闭防火墙
ufw disable
```

#### 卸载 ####
```
bash caddy-quick.sh -u
```

#### 密码管理 ####
将结尾的password更换为自己的密码，仅限字母、数字、下划线，非多密码管理用途无需使用
```
# 下载trojan密码管理脚本
curl https://raw.githubusercontent.com/terminodev/titanicsite7/main/caddy/managetro.sh -o managetro.sh

# 创建密码
bash managetro.sh add password

# 一次创建多个密码示例
bash managetro.sh add password1 password2 ...

# 删除密码
bash managetro.sh del password

# 一次删除多个密码示例
bash managetro.sh del password1 password2 ...

# 流量查询
bash managetro.sh status password1 password2 ...

# 流量归零
bash managetro.sh rotate
*流量统计归零后会自动在/etc/caddy/trojan/data目录下生成历史记录

# 密码列表
bash managetro.sh list
```

---

#### 说明 ####

- 免费域名

```
使用sslip.io提供的免费域名解析服务，域名由ipddress+sslip.io组成
例如服务器IP为1.3.5.7，对应域名是1.3.5.7.sslip.io
```

- 更换端口

仅建议在443端口被阻断时临时使用
```
# 将443端口更换为8443端口示例
sed -i "s/443/8443/g" /etc/caddy/Caddyfile && systemctl restart caddy.service
```
>请将新端口在防火墙中放行</br> 
>当新端口超过48小时未阻断后，建议更换IP并重新安装，使用默认的443端口

---

#### 连接方式 ####

客户端推荐选用 Xray 客户端，支持`uTLS指纹`伪造。

配置示例（1.3.5.7为示例IP）
```
地址：1.3.5.7.sslip.io  #服务器IP或域名，自签名证书时填写IP
端口：443
密码：123456
ALPN: h2/http1.1
SNI: example.com       #域名
```
> 提示：尽量不要在移动设备及其它除Mac外的ARM设备上使用Clash及不包含`uTLS指纹`的客户端连接

---

#### 手动编译 ####

有顾虑的用户可使用xcaddy自行编译，然后替换/usr/local/bin目录中的caddy二进制文件

- 配置Go环境
```
curl -L https://go.dev/dl/go1.25.1.linux-amd64.tar.gz | tar -zx -C /usr/local
echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile.d/golang.sh
source /etc/profile.d/golang.sh
go version
```

- 安装xcaddy并编译amd64架构安装包
```
go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
# amd64架构
CADDY_VERSION=latest CGO_ENABLED=0 GOOS=linux GOARCH=amd64 ~/go/bin/xcaddy build --with github.com/imgk/caddy-trojan --with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@naive
# arm64架构
CADDY_VERSION=latest CGO_ENABLED=0 GOOS=linux GOARCH=arm64 ~/go/bin/xcaddy build --with github.com/imgk/caddy-trojan --with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@naive
```
