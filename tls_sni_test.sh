#!/usr/bin/env bash

VERSION="2.1.0"

# =========================
# 默认配置
# =========================

TIMEOUT=1
CONCURRENCY=8
ROUNDS=3
TOPN=0
TLS13_CHECK=1

DOMAINS_FILE=""
CHECK_DOMAIN=""
EXTRA_DOMAINS=()

# 每行一个域名，方便增删
DEFAULT_DOMAINS=(
  "b.6sc.co"
  "lpcdn.lpsnmedia.net"
  "j.6sc.co"
  "xp.apple.com"
  "s.go-mpulse.net"
  "www.nvidia.com"
  "statici.icloud.com"
  "sisu.xboxlive.com"
  "www.wowt.com"
  "fpinit.itunes.apple.com"
  "c.s-microsoft.com"
  "www.icloud.com"
  "r.bing.com"
  "cdn.userway.org"
  "ts2.tc.mm.bing.net"
  "a0.awsstatic.com"
  "azure.microsoft.com"
  "amp-api-edge.apps.apple.com"
  "www.xilinx.com"
  "apps.mzstatic.com"
  "devblogs.microsoft.com"
  "snap.licdn.com"
  "s0.awsstatic.com"
  "ipv6.6sc.co"
  "th.bing.com"
  "ts4.tc.mm.bing.net"
  "drivers.amd.com"
  "go.microsoft.com"
  "d2c.aws.amazon.com"
  "ts1.tc.mm.bing.net"
  "t0.m.awsstatic.com"
  "digitalassets.tesla.com"
  "www.oracle.com"
  "downloadmirror.intel.com"
  "iosapps.itunes.apple.com"
  "cua-chat-ui.tesla.com"
  "mscom.demdex.net"
  "www.xbox.com"
  "i7158c100-ds-aksb-a.akamaihd.net"
  "intelcorp.scene7.com"
  "www.amd.com"
  "gray.video-player.arcpublishing.com"
  "c.6sc.co"
  "s.mp.marsflag.com"
  "ts3.tc.mm.bing.net"
  "ce.mf.marsflag.com"
  "www.tesla.com"
  "www.apple.com"
  "www.microsoft.com"
  "apps.apple.com"
  "www.cartoonbrew.com"
  "shin-ei-animation.jp"
  "www.ritao.co"
  "ani-com.hk"
  "valorant.secure.dyn.riotcdn.net"
  "fastcdn.hoyoverse.com"
  "lol.dyn.riotcdn.net"
  "endfield.gryphline.com"
  "lolesports.com"
)

# =========================
# 基础函数
# =========================

die() {
  printf '错误: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 ||
    die "未找到命令: $1"
}

is_positive_integer() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
  esac

  [ "$1" -ge 1 ]
}

is_non_negative_integer() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
  esac
}

show_help() {
  cat <<EOF
Reality SNI 域名优选脚本 v$VERSION

用法:
  $0 [选项] [域名...]
  bash -c "\$(curl -fsSL <脚本URL>)" [选项] [域名...]

选项:
  -t 秒       单次 TLS 测试超时时间，默认: $TIMEOUT
  -c N        并发测试数量，默认: $CONCURRENCY
  -r N        每个域名测试次数，默认: $ROUNDS
  -n N        只显示最快的 N 个稳定结果，0 表示全部
  -f 文件     从文件读取域名，每行一个；提供后替代默认列表
  --no-tls13 关闭 TLS 1.3 检测
  --check 域名
              深度检测单个域名
  -h, --help  显示帮助
  -V, --version
              显示版本

域名来源优先级:
  1. -f 指定的文件
  2. 命令行域名参数
  3. 脚本内置 DEFAULT_DOMAINS 列表

域名文件格式示例:
  www.apple.com
  https://www.microsoft.com/path
  www.example.com   # 支持行尾注释

--check 检测项目:
  连通性
  TLS 1.3
  证书信任
  HTTP/2
  HTTP 状态码
  证书 CN 和有效期
  Curve：临时密钥交换曲线

依赖:
  bash openssl awk sed grep sort
  --check 模式额外需要 curl
EOF
}

normalize_domain() {
  local value="$1"

  value=$(printf '%s' "$value" | tr 'A-Z' 'a-z')

  value=$(printf '%s' "$value" | sed \
    -e 's/[[:space:]]*#.*$//' \
    -e 's#^[a-z][a-z0-9+.-]*://##' \
    -e 's#/.*$##' \
    -e 's/:.*$//' \
    -e 's/^[[:space:]]*//' \
    -e 's/[[:space:]]*$//')

  [ -n "$value" ] && printf '%s\n' "$value"
}

validate_options() {
  is_positive_integer "$TIMEOUT" ||
    die "-t 必须是大于等于 1 的整数"

  is_positive_integer "$CONCURRENCY" ||
    die "-c 必须是大于等于 1 的整数"

  is_positive_integer "$ROUNDS" ||
    die "-r 必须是大于等于 1 的整数"

  is_non_negative_integer "$TOPN" ||
    die "-n 必须是大于等于 0 的整数"
}

# =========================
# 参数处理
# =========================

parse_arguments() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -t)
        [ $# -ge 2 ] || die "-t 缺少参数"
        TIMEOUT="$2"
        shift 2
        ;;

      -c)
        [ $# -ge 2 ] || die "-c 缺少参数"
        CONCURRENCY="$2"
        shift 2
        ;;

      -r)
        [ $# -ge 2 ] || die "-r 缺少参数"
        ROUNDS="$2"
        shift 2
        ;;

      -n)
        [ $# -ge 2 ] || die "-n 缺少参数"
        TOPN="$2"
        shift 2
        ;;

      -f)
        [ $# -ge 2 ] || die "-f 缺少参数"
        DOMAINS_FILE="$2"
        shift 2
        ;;

      --tls13)
        TLS13_CHECK=1
        shift
        ;;

      --no-tls13)
        TLS13_CHECK=0
        shift
        ;;

      --check)
        [ $# -ge 2 ] || die "--check 缺少域名"
        CHECK_DOMAIN="$2"
        shift 2
        ;;

      -h|--help)
        show_help
        exit 0
        ;;

      -V|--version)
        printf 'sni_tls_test.sh %s\n' "$VERSION"
        exit 0
        ;;

      --)
        shift

        while [ $# -gt 0 ]; do
          EXTRA_DOMAINS+=("$1")
          shift
        done
        ;;

      -*)
        die "未知选项: $1，使用 -h 查看帮助"
        ;;

      *)
        EXTRA_DOMAINS+=("$1")
        shift
        ;;
    esac
  done

  validate_options
}

# =========================
# 域名列表
# =========================

build_domain_list() {
  local output_file="$1"
  local domain

  if [ -n "$DOMAINS_FILE" ]; then
    [ -r "$DOMAINS_FILE" ] ||
      die "无法读取域名文件: $DOMAINS_FILE"

    while IFS= read -r domain || [ -n "$domain" ]; do
      normalize_domain "$domain"
    done < "$DOMAINS_FILE"

  elif [ "${#EXTRA_DOMAINS[@]}" -gt 0 ]; then
    for domain in "${EXTRA_DOMAINS[@]}"; do
      normalize_domain "$domain"
    done

  else
    for domain in "${DEFAULT_DOMAINS[@]}"; do
      normalize_domain "$domain"
    done
  fi |
    awk 'NF && !seen[$0]++' > "$output_file"

  [ -s "$output_file" ] ||
    die "域名列表为空"
}

# =========================
# 超时和计时
# =========================

detect_timeout_command() {
  TIMEOUT_MODE="fallback"
  TIMEOUT_DESC="后台进程加 kill"

  if command -v timeout >/dev/null 2>&1; then
    if timeout 1 true >/dev/null 2>&1; then
      TIMEOUT_MODE="gnu"
      TIMEOUT_DESC="GNU timeout"
    elif timeout -t 1 true >/dev/null 2>&1; then
      TIMEOUT_MODE="busybox"
      TIMEOUT_DESC="BusyBox timeout"
    fi
  fi
}

run_with_timeout() {
  local seconds="$1"
  shift

  case "$TIMEOUT_MODE" in
    gnu)
      timeout "$seconds" "$@"
      ;;

    busybox)
      timeout -t "$seconds" "$@"
      ;;

    fallback)
      "$@" &
      local command_pid=$!

      (
        sleep "$seconds" 2>/dev/null
        kill "$command_pid" 2>/dev/null
      ) &

      local killer_pid=$!
      local result

      wait "$command_pid" 2>/dev/null
      result=$?

      kill "$killer_pid" 2>/dev/null
      wait "$killer_pid" 2>/dev/null

      return "$result"
      ;;
  esac
}

now_ms() {
  local value

  if [ -n "${EPOCHREALTIME:-}" ]; then
    printf '%s\n' "${EPOCHREALTIME//./}" | cut -c1-13
    return
  fi

  value=$(date +%s%3N 2>/dev/null)

  case "$value" in
    ''|*[!0-9]*)
      printf '%s000\n' "$(date +%s)"
      ;;

    *)
      printf '%s\n' "$value"
      ;;
  esac
}

# =========================
# TLS 检测
# =========================

detect_tls13_support() {
  if openssl s_client -help 2>&1 | grep -q -- '-tls1_3'; then
    TLS13_AVAILABLE=1
  else
    TLS13_AVAILABLE=0
  fi
}

get_tls_details() {
  local domain="$1"

  printf '\n' |
    run_with_timeout "$TIMEOUT" \
    openssl s_client \
    -connect "$domain:443" \
    -servername "$domain" \
    2>&1
}

get_curve_name() {
  local tls_output="$1"
  local curve

  curve=$(printf '%s\n' "$tls_output" |
    sed -n 's/.*Server Temp Key:[[:space:]]*//p' |
    head -1)

  if [ -n "$curve" ]; then
    printf '%s\n' "$curve"
  else
    printf '%s\n' "无法获取"
  fi
}

test_tls_domain() {
  local domain="$1"
  local result_file="$2"

  local round
  local start_time
  local end_time
  local elapsed

  local total=0
  local success=0
  local failed=0
  local slow_failure=0

  local average
  local status
  local tls13="n/a"

  round=1

  while [ "$round" -le "$ROUNDS" ]; do
    start_time=$(now_ms)

    if run_with_timeout "$TIMEOUT" \
      openssl s_client \
      -connect "$domain:443" \
      -servername "$domain" \
      </dev/null >/dev/null 2>&1
    then
      end_time=$(now_ms)
      elapsed=$((end_time - start_time))

      [ "$elapsed" -lt 1 ] && elapsed=1

      total=$((total + elapsed))
      success=$((success + 1))
    else
      end_time=$(now_ms)
      elapsed=$((end_time - start_time))

      if [ "$elapsed" -ge $((TIMEOUT * 1000 - 150)) ]; then
        slow_failure=1
      fi

      failed=$((failed + 1))
    fi

    round=$((round + 1))
  done

  if [ "$success" -eq 0 ]; then
    average=999999999

    if [ "$slow_failure" -eq 1 ]; then
      status="TIMEOUT"
    else
      status="FAIL"
    fi
  else
    average=$(((total + success / 2) / success))
    [ "$average" -lt 1 ] && average=1

    if [ "$failed" -eq 0 ]; then
      status="OK"
    else
      status="PART"
    fi
  fi

  if [ "$TLS13_CHECK" -eq 1 ] && [ "$success" -gt 0 ]; then
    if [ "$TLS13_AVAILABLE" -eq 1 ]; then
      if run_with_timeout "$TIMEOUT" \
        openssl s_client \
        -tls1_3 \
        -connect "$domain:443" \
        -servername "$domain" \
        </dev/null >/dev/null 2>&1
      then
        tls13="yes"
      else
        tls13="no"
      fi
    fi
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$average" \
    "$status" \
    "$tls13" \
    "$domain" \
    "$success/$ROUNDS" > "$result_file"

  printf '.' >&2
}

# =========================
# 深度检测
# =========================

check_domain() {
  local domain="$1"

  local green=""
  local red=""
  local yellow=""
  local reset=""

  if [ -t 1 ]; then
    green=$'\033[32m'
    red=$'\033[31m'
    yellow=$'\033[33m'
    reset=$'\033[0m'
  fi

  printf 'Reality 伪装域名检测: %s\n\n' "$domain"

  # -------------------------
  # TLS 连通性
  # -------------------------

  local i
  local start_time
  local end_time
  local elapsed

  local total=0
  local success=0
  local average=0

  i=1

  while [ "$i" -le 3 ]; do
    start_time=$(now_ms)

    if run_with_timeout "$TIMEOUT" \
      openssl s_client \
      -connect "$domain:443" \
      -servername "$domain" \
      </dev/null >/dev/null 2>&1
    then
      end_time=$(now_ms)
      elapsed=$((end_time - start_time))

      [ "$elapsed" -lt 1 ] && elapsed=1

      total=$((total + elapsed))
      success=$((success + 1))
    fi

    i=$((i + 1))
  done

  if [ "$success" -gt 0 ]; then
    average=$(((total + success / 2) / success))
  fi

  if [ "$success" -eq 3 ]; then
    printf '连通性    %s成功 3/3，平均 %s ms%s\n' \
      "$green" "$average" "$reset"
  elif [ "$success" -gt 0 ]; then
    printf '连通性    %s部分成功 %s/3，平均 %s ms%s\n' \
      "$yellow" "$success" "$average" "$reset"
  else
    printf '连通性    %s失败 0/3%s\n' \
      "$red" "$reset"
  fi

  # -------------------------
  # TLS 1.3
  # -------------------------

  local tls13_success=0

  if [ "$TLS13_AVAILABLE" -eq 1 ]; then
    i=1

    while [ "$i" -le 3 ]; do
      if run_with_timeout "$TIMEOUT" \
        openssl s_client \
        -tls1_3 \
        -connect "$domain:443" \
        -servername "$domain" \
        </dev/null >/dev/null 2>&1
      then
        tls13_success=$((tls13_success + 1))
      fi

      i=$((i + 1))
    done

    if [ "$tls13_success" -eq 3 ]; then
      printf 'TLS 1.3   %s支持%s\n' \
        "$green" "$reset"
    elif [ "$tls13_success" -gt 0 ]; then
      printf 'TLS 1.3   %s部分成功 %s/3%s\n' \
        "$yellow" "$tls13_success" "$reset"
    else
      printf 'TLS 1.3   %s不支持%s\n' \
        "$red" "$reset"
    fi
  else
    printf 'TLS 1.3   %s本机 OpenSSL 不支持检测%s\n' \
      "$yellow" "$reset"
  fi

  # -------------------------
  # curl、证书和 HTTP/2
  # -------------------------

  require_command curl

  local curl_result
  local curl_code
  local http_code
  local http_version
  local curl_rc

  curl_result=$(
    curl \
      --silent \
      --show-error \
      --location \
      --max-time 5 \
      --output /dev/null \
      --write-out '%{http_code} %{http_version}' \
      "https://$domain" 2>/dev/null
  )
  curl_rc=$?

  http_code=$(printf '%s\n' "$curl_result" | awk '{print $1}')
  http_version=$(printf '%s\n' "$curl_result" | awk '{print $2}')

  [ -n "$http_code" ] || http_code="-"
  [ -n "$http_version" ] || http_version="-"

  if [ "$curl_rc" -eq 0 ]; then
    printf '证书信任  %s通过%s\n' \
      "$green" "$reset"
  else
    printf '证书信任  %s失败，curl rc=%s%s\n' \
      "$red" "$curl_rc" "$reset"
  fi

  if [ "$http_version" = "2" ] ||
     [ "$http_version" = "2.0" ]; then
    printf 'HTTP/2    %s支持%s\n' \
      "$green" "$reset"
  else
    printf 'HTTP/2    %s不支持或未协商，版本=%s%s\n' \
      "$yellow" "$http_version" "$reset"
  fi

  printf 'HTTP      %s\n' "$http_code"

  # -------------------------
  # 证书详情和临时密钥交换曲线
  # -------------------------

  local tls_output
  local cert_subject
  local cert_expire
  local curve

  tls_output=$(get_tls_details "$domain")

  cert_subject=$(printf '%s\n' "$tls_output" |
    openssl x509 -noout -subject 2>/dev/null |
    sed -n 's/.*CN *= *//p' |
    head -1)

  cert_expire=$(printf '%s\n' "$tls_output" |
    openssl x509 -noout -enddate 2>/dev/null |
    sed -n 's/^notAfter=//p')

  if [ -n "$cert_subject" ]; then
    printf '证书详情  CN=%s\n' "$cert_subject"
  else
    printf '证书详情  无法获取 CN\n'
  fi

if [ -n "$cert_expire" ]; then
  readable_expire=$(
    LC_ALL=C TZ=Asia/Shanghai \
      date -d "$cert_expire" '+%Y年%-m月%-d日 %H:%M:%S' \
      2>/dev/null
  )
  if [ -n "$readable_expire" ]; then
    printf '证书有效期至  %s\n' "$readable_expire"
  else
    printf '证书有效期至  %s\n' "$cert_expire"
  fi
else
  printf '证书有效期至  无法获取\n'
fi

  curve=$(get_curve_name "$tls_output")
  printf 'Curve     %s\n' "$curve"

  # -------------------------
  # 最终结论
  # -------------------------

  printf '\n'

  if [ "$success" -eq 0 ]; then
    printf '结论: %s不可用%s：无法建立 TLS 连接\n' \
      "$red" "$reset"
    return 1
  fi

  if [ "$TLS13_AVAILABLE" -eq 1 ] &&
     [ "$tls13_success" -eq 0 ]; then
    printf '结论: %s不推荐%s：不支持 TLS 1.3\n' \
      "$red" "$reset"
    return 1
  fi

  if [ "$curl_rc" -ne 0 ]; then
    printf '结论: %s不推荐%s：HTTPS 证书校验失败\n' \
      "$red" "$reset"
    return 1
  fi

  if [ "$success" -lt 3 ]; then
    printf '结论: %s可用但不稳定%s：TLS 成功率 %s/3\n' \
      "$yellow" "$reset" "$success"
    return 0
  fi

  if [ "$http_version" != "2" ] &&
     [ "$http_version" != "2.0" ]; then
    printf '结论: %s基本可用%s：未协商到 HTTP/2\n' \
      "$yellow" "$reset"
    return 0
  fi

  printf '结论: %s可作为 Reality 伪装域名%s\n' \
    "$green" "$reset"

  return 0
}

# =========================
# 主程序
# =========================

require_command openssl
require_command awk
require_command sed
require_command grep
require_command sort

parse_arguments "$@"

TEMP_DIR=$(mktemp -d 2>/dev/null) ||
  die "无法创建临时目录"

cleanup() {
  rm -rf "$TEMP_DIR"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

detect_timeout_command
detect_tls13_support

DOMAIN_FILE="$TEMP_DIR/domains"
build_domain_list "$DOMAIN_FILE"

DOMAIN_COUNT=$(grep -c . "$DOMAIN_FILE")

if [ -n "$CHECK_DOMAIN" ]; then
  CHECK_DOMAIN=$(normalize_domain "$CHECK_DOMAIN")
  [ -n "$CHECK_DOMAIN" ] ||
    die "--check 域名无效"

  check_domain "$CHECK_DOMAIN"
  exit $?
fi

printf 'Reality SNI 域名优选脚本 v%s\n' "$VERSION"
printf 'OpenSSL: %s\n' "$(openssl version 2>/dev/null)"
printf '超时工具: %s\n' "$TIMEOUT_DESC"
printf '域名数: %s | 超时: %ss | 并发: %s | 测试次数: %s\n\n' \
  "$DOMAIN_COUNT" \
  "$TIMEOUT" \
  "$CONCURRENCY" \
  "$ROUNDS"

if [ "$TLS13_CHECK" -eq 1 ] &&
   [ "$TLS13_AVAILABLE" -eq 0 ]; then
  printf '警告: 当前 OpenSSL 不支持 TLS 1.3，TLS1.3 列显示 n/a\n' >&2
fi

index=0

while IFS= read -r domain; do
  index=$((index + 1))

  test_tls_domain \
    "$domain" \
    "$TEMP_DIR/result_$index" &

  while [ "$(jobs -rp | wc -l)" -ge "$CONCURRENCY" ]; do
    sleep 0.05
  done
done < "$DOMAIN_FILE"

wait
printf '\n' >&2

sort -t '	' -k1,1n -k4,4 \
  "$TEMP_DIR"/result_* > "$TEMP_DIR/all_results"

if [ "$TLS13_CHECK" -eq 1 ]; then
  printf '%-4s  %-44s  %11s  %-6s\n' \
    "#" "DOMAIN" "LATENCY" "TLS1.3"
else
  printf '%-4s  %-44s  %11s\n' \
    "#" "DOMAIN" "LATENCY"
fi

rank=0
stable_count=0
partial_count=0
failed_count=0

fastest=""
fastest_tls13=""

while IFS='	' read -r latency status tls13 domain success_count; do
  case "$status" in
    OK)
      stable_count=$((stable_count + 1))
      rank=$((rank + 1))

      if [ -z "$fastest" ]; then
        fastest="$domain ($latency ms)"
      fi

      if [ "$tls13" = "yes" ] &&
         [ -z "$fastest_tls13" ]; then
        fastest_tls13="$domain ($latency ms)"
      fi

      if [ "$TOPN" -eq 0 ] ||
         [ "$rank" -le "$TOPN" ]; then

        if [ "$TLS13_CHECK" -eq 1 ]; then
          printf '%-4s  %-44s  %8s ms  %-6s\n' \
            "$rank" "$domain" "$latency" "$tls13"
        else
          printf '%-4s  %-44s  %8s ms\n' \
            "$rank" "$domain" "$latency"
        fi
      fi
      ;;

    PART)
      partial_count=$((partial_count + 1))

      if [ "$TLS13_CHECK" -eq 1 ]; then
        printf '%-4s  %-44s  %11s  %-6s\n' \
          "-" \
          "$domain" \
          "$latency ms $success_count" \
          "$tls13"
      else
        printf '%-4s  %-44s  %11s\n' \
          "-" \
          "$domain" \
          "$latency ms $success_count"
      fi
      ;;

    *)
      failed_count=$((failed_count + 1))

      if [ "$TLS13_CHECK" -eq 1 ]; then
        printf '%-4s  %-44s  %11s  %-6s\n' \
          "-" \
          "$domain" \
          "$status" \
          "$tls13"
      else
        printf '%-4s  %-44s  %11s\n' \
          "-" \
          "$domain" \
          "$status"
      fi
      ;;
  esac
done < "$TEMP_DIR/all_results"

printf '\n'
printf '完成: 共 %s 个域名，稳定 %s，部分成功 %s，失败/超时 %s\n' \
  "$DOMAIN_COUNT" \
  "$stable_count" \
  "$partial_count" \
  "$failed_count"

if [ -n "$fastest" ]; then
  printf '最快: %s\n' "$fastest"
fi

if [ -n "$fastest_tls13" ]; then
  printf '推荐: %s\n' "$fastest_tls13"
fi

exit 0