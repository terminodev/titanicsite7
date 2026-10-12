# TLS SNI 分流示例

此配置使用 `caddy-l4` 将指定 TLS SNI 流量转发到
`127.0.0.1:10001`，其余 TLS 流量转发到 Caddy 的 HTTPS 服务。

```caddyfile
{
    email example@example.com
    http_port 80
    https_port 8443
    layer4 {
        :443 {
            @tls-a tls sni intel.com www.intel.com
            route @tls-a {
                proxy 127.0.0.1:10001
            }

            route {
                proxy 127.0.0.1:8443
            }
        }
    }
}

https://a.example.com:8443 {
    tls example@example.com

    reverse_proxy 127.0.0.1:3000 {
        header_up Host a.example.com
    }
}

https://b.example.com:8443 {
    respond "OK" 200
}
}