#!/bin/bash
shopt -s expand_aliases
Font_Black="\033[30m"
Font_Red="\033[31m"
Font_Green="\033[32m"
Font_Yellow="\033[33m"
Font_Blue="\033[34m"
Font_Purple="\033[35m"
Font_SkyBlue="\033[36m"
Font_White="\033[37m"
Font_Suffix="\033[0m"

UA_BROWSER="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
UA_SEC_CH_UA='"Google Chrome";v="125", "Chromium";v="125", "Not.A/Brand";v="24"'
MEDIA_COOKIE=$(curl -s --retry 3 --max-time 10 "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/cookies")
CONFIG_FILE="/opt/unlock_check/unlock_check.config"
SCRIPT_PATH="/opt/unlock_check/unlock_check.sh"

parse_params() {
    while getopts ":I:M:X:P:w:k:i:hu" optname; do
        case "$optname" in
        "I")
            iface="$OPTARG"
            useNIC="--interface $iface"
            ;;
        "M")
            if [[ "$OPTARG" == "4" ]]; then
                NetworkType=4
            elif [[ "$OPTARG" == "6" ]]; then
                NetworkType=6
            fi
            ;;
        "X")
            XIP="$OPTARG"
            xForward="--header X-Forwarded-For:$XIP"
            ;;
        "P")
            proxy="$OPTARG"
            usePROXY="-x $proxy"
            ;;
        "w")
            WebApi="$OPTARG"
            ;;
        "k")
            WebApiKey="$OPTARG"
            ;;
        "i")
            NodeId="$OPTARG"
            ;;
        "u")
            uninstall
            exit 0
            ;;
        "h")
            help
            exit 0
            ;;
        "?")
            echo "Invalid option: -$OPTARG"
            echo "Use -h for help."
            exit 1
            ;;
        ":")
            echo "Option -$OPTARG requires an argument."
            echo "Use -h for help."
            exit 1
            ;;
        esac
    done
    
    useNIC="${useNIC:-}"
    xForward="${xForward:-}"
    usePROXY="${usePROXY:-}"
    WebApi="${WebApi:-}"
    WebApiKey="${WebApiKey:-}"
    NodeId="${NodeId:-}"
    if [ -n "${proxy:-}" ]; then
        NetworkType=4
    fi
    CURL_OPTS="${useNIC} ${usePROXY} ${xForward} --max-time 10 --retry 3 --retry-max-time 20"
}

checkOS() {
    ifTermux=$(echo $PWD | grep termux)
    ifMacOS=$(uname -a | grep Darwin)
    if [ -n "$ifTermux" ]; then
        os_version=Termux
        is_termux=1
    elif [ -n "$ifMacOS" ]; then
        os_version=MacOS
        is_macos=1
    else
        os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
    fi

    if [[ "$os_version" == "2004" ]] || [[ "$os_version" == "10" ]] || [[ "$os_version" == "11" ]]; then
        is_windows=1
        ssll="-k --ciphers DEFAULT@SECLEVEL=1"
    fi

    if [ "$(which apt 2>/dev/null)" ]; then
        InstallMethod="apt"
        is_debian=1
    elif [ "$(which dnf 2>/dev/null)" ] || [ "$(which yum 2>/dev/null)" ]; then
        InstallMethod="yum"
        is_redhat=1
    elif [[ "$os_version" == "Termux" ]]; then
        InstallMethod="pkg"
    elif [[ "$os_version" == "MacOS" ]]; then
        InstallMethod="brew"
    fi
}

checkCPU() {
    CPUArch=$(uname -m)
    if [[ "$CPUArch" == "aarch64" ]]; then
        arch=_arm64
    elif [[ "$CPUArch" == "i686" ]]; then
        arch=_i686
    elif [[ "$CPUArch" == "arm" ]]; then
        arch=_arm
    elif [[ "$CPUArch" == "x86_64" ]] && [ -n "$ifMacOS" ]; then
        arch=_darwin
    fi
}

checkDependencies() {
    if ! command -v python &>/dev/null; then
        if command -v python3 &>/dev/null; then
            alias python="python3"
        else
            if [ "$is_debian" == 1 ]; then
                echo -e "${Font_Green}Installing python${Font_Suffix}"
                $InstallMethod update >/dev/null 2>&1
                $InstallMethod install python -y >/dev/null 2>&1
            elif [ "$is_redhat" == 1 ]; then
                echo -e "${Font_Green}Installing python${Font_Suffix}"
                if [[ "$os_version" -gt 7 ]]; then
                    $InstallMethod makecache >/dev/null 2>&1
                    $InstallMethod install python3 -y >/dev/null 2>&1
                    alias python="python3"
                else
                    $InstallMethod makecache >/dev/null 2>&1
                    $InstallMethod install python -y >/dev/null 2>&1
                fi

            elif [ "$is_termux" == 1 ]; then
                echo -e "${Font_Green}Installing python${Font_Suffix}"
                $InstallMethod update -y >/dev/null 2>&1
                $InstallMethod install python -y >/dev/null 2>&1

            elif [ "$is_macos" == 1 ]; then
                echo -e "${Font_Green}Installing python${Font_Suffix}"
                $InstallMethod install python
            fi
        fi
    fi

    if ! command -v dig &>/dev/null; then
        if [ "$is_debian" == 1 ]; then
            echo -e "${Font_Green}Installing dnsutils${Font_Suffix}"
            $InstallMethod update >/dev/null 2>&1
            $InstallMethod install dnsutils -y >/dev/null 2>&1
        elif [ "$is_redhat" == 1 ]; then
            echo -e "${Font_Green}Installing bind-utils${Font_Suffix}"
            $InstallMethod makecache >/dev/null 2>&1
            $InstallMethod install bind-utils -y >/dev/null 2>&1
        elif [ "$is_termux" == 1 ]; then
            echo -e "${Font_Green}Installing dnsutils${Font_Suffix}"
            $InstallMethod update -y >/dev/null 2>&1
            $InstallMethod install dnsutils -y >/dev/null 2>&1
        elif [ "$is_macos" == 1 ]; then
            echo -e "${Font_Green}Installing bind${Font_Suffix}"
            $InstallMethod install bind
        fi
    fi

    if [ "$is_macos" == 1 ]; then
        if ! command -v md5sum &>/dev/null; then
            echo -e "${Font_Green}Installing md5sha1sum${Font_Suffix}"
            $InstallMethod install md5sha1sum
        fi
    fi

}

###########################################
#                                         #
#           required check item           #
#                                         #
###########################################

#Netflix
MediaUnlockTest_Netflix() {
    # LEGO Ninjago
    local tmpresult1=$(curl ${CURL_OPTS} -${1} -fsL 'https://www.netflix.com/title/81280792' -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7'   -H 'accept-language: en-US,en;q=0.9'   -b 'flwssn=d2c72c47-49e9-48da-b7a2-2dc6d7ca9fcf; nfvdid=BQFmAAEBEMZa4XMYVzVGf9-kQ1HXumtAKsCyuBZU4QStC6CGEGIVznjNuuTerLAG8v2-9V_kYhg5uxTB5_yyrmqc02U5l1Ts74Qquezc9AE-LZKTo3kY3g%3D%3D; SecureNetflixId=v%3D3%26mac%3DAQEAEQABABSQHKcR1d0sLV0WTu0lL-BO63TKCCHAkeY.%26dt%3D1745376277212; NetflixId=v%3D3%26ct%3DBgjHlOvcAxLAAZuNS4_CJHy9NKJPzUV-9gElzTlTsmDS1B59TycR-fue7f6q7X9JQAOLttD7OnlldUtnYWXL7VUfu9q4pA0gruZKVIhScTYI1GKbyiEqKaULAXOt0PHQzgRLVTNVoXkxcbu7MYG4wm1870fZkd5qrDOEseZv2WIVk4xIeNL87EZh1vS3RZU3e-qWy2tSmfSNUC-FVDGwxbI6-hk3Zg2MbcWYd70-ghohcCSZp5WHAGXg_xWVC7FHM3aOUVTGwRCU1RgGIg4KDKGr_wsTRRw6HWKqeA..; gsid=09bb180e-fbb1-4bf6-adcb-a3fa1236e323; OptanonConsent=isGpcEnabled=0&datestamp=Wed+Apr+23+2025+10%3A47%3A11+GMT%2B0800+(%E4%B8%AD%E5%9B%BD%E6%A0%87%E5%87%86%E6%97%B6%E9%97%B4)&version=202411.1.0&browserGpcFlag=0&isIABGlobal=false&hosts=&consentId=f13f841e-c75d-4f95-ab04-d8f581cac53e&interactionCount=0&isAnonUser=1&landingPath=https%3A%2F%2Fwww.netflix.com%2Fsg-zh%2Ftitle%2F81280792&groups=C0001%3A1%2CC0002%3A1%2CC0003%3A1%2CC0004%3A1'   -H 'priority: u=0, i'   -H 'sec-ch-ua: "Microsoft Edge";v="135", "Not-A.Brand";v="8", "Chromium";v="135"'   -H 'sec-ch-ua-mobile: ?0'   -H 'sec-ch-ua-model: ""'   -H 'sec-ch-ua-platform: "Windows"'   -H 'sec-ch-ua-platform-version: "15.0.0"'   -H 'sec-fetch-dest: document'   -H 'sec-fetch-mode: navigate'   -H 'sec-fetch-site: none'   -H 'sec-fetch-user: ?1'   -H 'upgrade-insecure-requests: 1' --user-agent "${UA_BROWSER}")
    # Breaking bad
    local tmpresult2=$(curl ${CURL_OPTS} -${1} -fsL 'https://www.netflix.com/title/70143836' -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7'   -H 'accept-language: en-US,en;q=0.9'   -b 'flwssn=d2c72c47-49e9-48da-b7a2-2dc6d7ca9fcf; nfvdid=BQFmAAEBEMZa4XMYVzVGf9-kQ1HXumtAKsCyuBZU4QStC6CGEGIVznjNuuTerLAG8v2-9V_kYhg5uxTB5_yyrmqc02U5l1Ts74Qquezc9AE-LZKTo3kY3g%3D%3D; SecureNetflixId=v%3D3%26mac%3DAQEAEQABABSQHKcR1d0sLV0WTu0lL-BO63TKCCHAkeY.%26dt%3D1745376277212; NetflixId=v%3D3%26ct%3DBgjHlOvcAxLAAZuNS4_CJHy9NKJPzUV-9gElzTlTsmDS1B59TycR-fue7f6q7X9JQAOLttD7OnlldUtnYWXL7VUfu9q4pA0gruZKVIhScTYI1GKbyiEqKaULAXOt0PHQzgRLVTNVoXkxcbu7MYG4wm1870fZkd5qrDOEseZv2WIVk4xIeNL87EZh1vS3RZU3e-qWy2tSmfSNUC-FVDGwxbI6-hk3Zg2MbcWYd70-ghohcCSZp5WHAGXg_xWVC7FHM3aOUVTGwRCU1RgGIg4KDKGr_wsTRRw6HWKqeA..; gsid=09bb180e-fbb1-4bf6-adcb-a3fa1236e323; OptanonConsent=isGpcEnabled=0&datestamp=Wed+Apr+23+2025+10%3A47%3A11+GMT%2B0800+(%E4%B8%AD%E5%9B%BD%E6%A0%87%E5%87%86%E6%97%B6%E9%97%B4)&version=202411.1.0&browserGpcFlag=0&isIABGlobal=false&hosts=&consentId=f13f841e-c75d-4f95-ab04-d8f581cac53e&interactionCount=0&isAnonUser=1&landingPath=https%3A%2F%2Fwww.netflix.com%2Fsg-zh%2Ftitle%2F81280792&groups=C0001%3A1%2CC0002%3A1%2CC0003%3A1%2CC0004%3A1'   -H 'priority: u=0, i'   -H 'sec-ch-ua: "Microsoft Edge";v="135", "Not-A.Brand";v="8", "Chromium";v="135"'   -H 'sec-ch-ua-mobile: ?0'   -H 'sec-ch-ua-model: ""'   -H 'sec-ch-ua-platform: "Windows"'   -H 'sec-ch-ua-platform-version: "15.0.0"'   -H 'sec-fetch-dest: document'   -H 'sec-fetch-mode: navigate'   -H 'sec-fetch-site: none'   -H 'sec-fetch-user: ?1'   -H 'upgrade-insecure-requests: 1' --user-agent "${UA_BROWSER}")

    if [ -z "${tmpresult1}" ] || [ -z "${tmpresult2}" ]; then
        modifyJsonTemplate 'Netflix_result' 'Unknown'
        echo -n -e "\r Netflix:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local result1=$(echo ${tmpresult1} | grep 'Oh no!')
    local result2=$(echo ${tmpresult2} | grep 'Oh no!')

    if [ -n "${result1}" ] && [ -n "${result2}" ]; then
        modifyJsonTemplate 'Netflix_result' 'No' 'Originals Only'
        echo -n -e "\r Netflix:\t\t\t\t${Font_Yellow}Originals Only${Font_Suffix}\n"
        return
    fi
    
    if [ -z "${result1}" ] || [ -z "${result2}" ]; then
        local region=$(echo "$tmpresult1" | sed -n 's/.*"id":"\([^"]*\)".*"countryName":"[^"]*".*/\1/p'| head -n1)
        modifyJsonTemplate 'Netflix_result' 'Yes' "${region}"
        echo -n -e "\r Netflix:\t\t\t\t${Font_Green}Yes (Region: ${region})${Font_Suffix}\n"
        return
    fi

    modifyJsonTemplate 'Netflix_result' 'No'
    echo -n -e "\r Netflix:\t\t\t\t\t${Font_Red}Failed${Font_Suffix}\n"
}

#DisneyPlus
MediaUnlockTest_DisneyPlus() {
    if [ "${1}" == 6 ]; then
        modifyJsonTemplate 'DisneyPlus_result' 'Unknown'
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}IPv6 Is Not Currently Supported${Font_Suffix}\n"
        return
    fi

    local tempresult=$(curl ${CURL_OPTS} -${1} -s 'https://disney.api.edge.bamgrid.com/devices' -X POST -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -H "content-type: application/json; charset=UTF-8" -d '{"deviceFamily":"browser","applicationRuntime":"chrome","deviceProfile":"windows","attributes":{}}' --user-agent "${UA_BROWSER}")
    if [ -z "$tempresult" ]; then
        modifyJsonTemplate 'DisneyPlus_result' 'Unknown'
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local is403=$(echo "$tempresult" | grep -i '403 ERROR')
    if [ -n "$is403" ]; then
        modifyJsonTemplate 'DisneyPlus_result' 'No'
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}No (IP Banned By Disney+)${Font_Suffix}\n"
        return
    fi

    local assertion=$(echo "$tempresult" | grep -woP '"assertion"\s{0,}:\s{0,}"\K[^"]+')
    if [ -z "$assertion" ]; then
        modifyJsonTemplate 'DisneyPlus_result' 'Unknown'
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}Failed (Error: PAGE ERROR)${Font_Suffix}\n"
        return
    fi

    local preDisneyCookie=$(echo "$MEDIA_COOKIE" | sed -n '1p')
    local disneyCookie=$(echo "$preDisneyCookie" | sed "s/DISNEYASSERTION/${assertion}/g")
    local tokenContent=$(curl ${CURL_OPTS} -${1} -s 'https://disney.api.edge.bamgrid.com/token' -X POST -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -d "${disneyCookie}" --user-agent "${UA_BROWSER}")

    local isBlocked=$(echo "$tokenContent" | grep -i 'forbidden-location')
    local is403=$(echo "$tokenContent" | grep -i '403 ERROR')

    if [ -n "$isBlocked" ] || [ -n "$is403" ]; then
        modifyJsonTemplate 'DisneyPlus_result' 'Unknown'
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}No (IP Banned By Disney+ 1)${Font_Suffix}\n"
        return
    fi

    local fakeContent=$(echo "$MEDIA_COOKIE" | sed -n '8p')
    local refreshToken=$(echo "$tokenContent" | grep -woP '"refresh_token"\s{0,}:\s{0,}"\K[^"]+')
    local disneyContent=$(echo "$fakeContent" | sed "s/ILOVEDISNEY/${refreshToken}/g")
    local tmpresult=$(curl ${CURL_OPTS} -${1} -sL 'https://disney.api.edge.bamgrid.com/graph/v1/device/graphql' -X POST -H "authorization: ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -d "${disneyContent}" --user-agent "${UA_BROWSER}")

    local previewcheck=$(curl ${CURL_OPTS} -${1} -sL 'https://disneyplus.com' -w '%{url_effective}\n' -o /dev/null --user-agent "${UA_BROWSER}")
    local isUnavailable=$(echo "$previewcheck" | grep -E 'preview|unavailable')
    local region=$(echo "$tmpresult" | grep -woP '"countryCode"\s{0,}:\s{0,}"\K[^"]+')
    local inSupportedLocation=$(echo "$tmpresult" | grep -woP '"inSupportedLocation"\s{0,}:\s{0,}\K(false|true)')

    if [ -z "$region" ]; then
        modifyJsonTemplate 'DisneyPlus_result' 'No'
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        return
    fi
    if [ "$region" == 'JP' ]; then
        modifyJsonTemplate 'DisneyPlus_result' 'Yes' 'JP'
        echo -n -e "\r Disney+:\t\t\t\t${Font_Green}Yes (Region: JP)${Font_Suffix}\n"
        return
    fi
    if [ -n "$isUnavailable" ]; then
        modifyJsonTemplate 'DisneyPlus_result' 'No'
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        return
    fi
    if [ "$inSupportedLocation" == 'false' ]; then
        modifyJsonTemplate 'DisneyPlus_result' 'No'
        echo -n -e "\r Disney+:\t\t\t\t${Font_Yellow}Available For [Disney+ ${region}] Soon${Font_Suffix}\n"
        return
    fi
    if [ "$inSupportedLocation" == 'true' ]; then
        modifyJsonTemplate 'DisneyPlus_result' 'Yes' "${region}"
        echo -n -e "\r Disney+:\t\t\t\t${Font_Green}Yes (Region: ${region})${Font_Suffix}\n"
        return
    fi

    modifyJsonTemplate 'DisneyPlus_result' 'Unknown'
    echo -n -e "\r Disney+:\t\t\t\t${Font_Red}Failed (Error: ${inSupportedLocation}_${region})${Font_Suffix}\n"
}

#YouTube_Premium
MediaUnlockTest_YouTube_Premium() {
    local tmpresult=$(curl ${CURL_OPTS} -${1} -sL 'https://www.youtube.com/premium' -H 'accept-language: en-US,en;q=0.9' -H 'cookie: YSC=FSCWhKo2Zgw; VISITOR_PRIVACY_METADATA=CgJERRIEEgAgYQ%3D%3D; PREF=f7=4000; __Secure-YEC=CgtRWTBGTFExeV9Iayjele2yBjIKCgJERRIEEgAgYQ%3D%3D; SOCS=CAISOAgDEitib3FfaWRlbnRpdHlmcm9udGVuZHVpc2VydmVyXzIwMjQwNTI2LjAxX3AwGgV6aC1DTiACGgYIgMnpsgY; VISITOR_INFO1_LIVE=Di84mAIbgKY; __Secure-BUCKET=CGQ' --user-agent "${UA_BROWSER}")
    if [ -z "$tmpresult" ]; then
        modifyJsonTemplate 'YouTube_Premium_result' 'Unknown'
        echo -n -e "\r YouTube Premium:\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local isCN=$(echo "$tmpresult" | grep 'www.google.cn')

    if [ -n "$isCN" ]; then
        modifyJsonTemplate 'YouTube_Premium_result' 'No' 'CN'
        echo -n -e "\r YouTube Premium:\t\t\t${Font_Red}No${Font_Suffix} ${Font_Green} (Region: CN)${Font_Suffix} \n"
        return
    fi

    local isNotAvailable=$(echo "$tmpresult" | grep -i 'Premium is not available in your country')
    local region=$(echo "$tmpresult" | grep -woP '"INNERTUBE_CONTEXT_GL"\s{0,}:\s{0,}"\K[^"]+')
    local isAvailable=$(echo "$tmpresult" | grep -i 'ad-free')

    if [ -n "$isNotAvailable" ]; then
        modifyJsonTemplate 'YouTube_Premium_result' 'No'
        echo -n -e "\r YouTube Premium:\t\t\t${Font_Red}No${Font_Suffix}\n"
        return
    fi
    if [ -z "$region" ]; then
        local region='UNKNOWN'
    fi
    if [ -n "$isAvailable" ]; then
        modifyJsonTemplate 'YouTube_Premium_result' 'Yes' "${region}"
        echo -n -e "\r YouTube Premium:\t\t\t${Font_Green}Yes (Region: ${region})${Font_Suffix}\n"
        return
    fi
    
    modifyJsonTemplate 'YouTube_Premium_result' 'Unknown'
    echo -n -e "\r YouTube Premium:\t\t\t${Font_Red}Failed (Error: PAGE ERROR)${Font_Suffix}\n"
}

#HBOMax
MediaUnlockTest_HBOMax() {
    local tmpresult=$(curl ${CURL_OPTS} -${1} -sLi 'https://www.max.com/' -w "_TAG_%{http_code}_TAG_" --user-agent "${UA_BROWSER}")
    local httpCode=$(echo "$tmpresult" | grep '_TAG_' | awk -F'_TAG_' '{print $2}')
    if [ "$httpCode" == '000' ]; then
        modifyJsonTemplate 'HBOMax_result' 'Unknown'
        echo -n -e "\r HBO Max:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local countryList=$(echo "$tmpresult" | grep -woP '"url":"/[a-z]{2}/[a-z]{2}"' | cut -f4 -d'"' | cut -f2 -d'/' | sort -n | uniq | xargs | tr a-z A-Z)
    local countryList="${countryList} US"
    local region=$(echo "$tmpresult" | grep -woP 'countryCode=\K[A-Z]{2}' | head -n 1)
    local isUnavailable=$(echo "$countryList" | grep "$region")

    if [ -z "$region" ]; then
        modifyJsonTemplate 'HBOMax_result' 'Unknown'
        echo -n -e "\r HBO Max:\t\t\t\t${Font_Red}Failed (Error: Country Code Not Found)${Font_Suffix}\n"
        return
    fi
    if [ -n "$isUnavailable" ]; then
        modifyJsonTemplate 'HBOMax_result' 'Yes' "${region}"
        echo -n -e "\r HBO Max:\t\t\t\t${Font_Green}Yes (Region: ${region})${Font_Suffix}\n"
        return
    fi

    modifyJsonTemplate 'HBOMax_result' 'No'
    echo -n -e "\r HBO Max:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
}

#Amazon Prime Video
MediaUnlockTest_PrimeVideo() {
    if [ "${1}" == 6 ]; then
        modifyJsonTemplate 'AmazonPrime_result' 'No'
        echo -n -e "\r Amazon Prime Video:\t\t\t${Font_Red}IPv6 Is Not Currently Supported${Font_Suffix}\n"
        return
    fi

    local tmpresult=$(curl ${CURL_OPTS} -${1} -sL 'https://www.primevideo.com' --user-agent "${UA_BROWSER}")
    if [ -z "$tmpresult" ]; then
        modifyJsonTemplate 'AmazonPrime_result' 'Unknown'
        echo -n -e "\r Amazon Prime Video:\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local isBlocked=$(echo "$tmpresult" | grep -i 'isServiceRestricted')
    local region=$(echo "$tmpresult" | grep -woP '"currentTerritory":"\K[^"]+' | head -n 1)

    if [ -z "$isBlocked" ] && [ -z "$region" ]; then
        modifyJsonTemplate 'AmazonPrime_result' 'Unknown'
        echo -n -e "\r Amazon Prime Video:\t\t\t${Font_Red}Failed (Error: PAGE ERROR)${Font_Suffix}\n"
        return
    fi
    if [ -n "$isBlocked" ]; then
        modifyJsonTemplate 'AmazonPrime_result' 'No'
        echo -n -e "\r Amazon Prime Video:\t\t\t${Font_Red}No (Service Not Available)${Font_Suffix}\n"
        return
    fi
    if [ -n "$region" ]; then
        modifyJsonTemplate 'AmazonPrime_result' 'Yes' "${region}"
        echo -n -e "\r Amazon Prime Video:\t\t\t${Font_Green}Yes (Region: ${region})${Font_Suffix}\n"
        return
    fi

    modifyJsonTemplate 'AmazonPrime_result' 'Unknown'
    echo -n -e "\r Amazon Prime Video:\t\t\t${Font_Red}Failed (Error: Unknown Region)${Font_Suffix}\n"
}

#OpenAI
WebTest_OpenAI() {
    local tmpresult1=$(curl ${CURL_OPTS} -${1} -s 'https://api.openai.com/compliance/cookie_requirements' -H 'authority: api.openai.com' -H 'accept: */*' -H 'accept-language: en-US,en;q=0.9' -H 'authorization: Bearer null' -H 'content-type: application/json' -H 'origin: https://platform.openai.com' -H 'referer: https://platform.openai.com/' -H "sec-ch-ua: ${UA_SEC_CH_UA}" -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: "Windows"' -H 'sec-fetch-dest: empty' -H 'sec-fetch-mode: cors' -H 'sec-fetch-site: same-site' --user-agent "${UA_BROWSER}")
    local tmpresult2=$(curl ${CURL_OPTS} -${1} -s 'https://ios.chat.openai.com/' -H 'authority: ios.chat.openai.com' -H 'accept: */*;q=0.8,application/signed-exchange;v=b3;q=0.7' -H 'accept-language: en-US,en;q=0.9' -H "sec-ch-ua: ${UA_SEC_CH_UA}" -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: "Windows"' -H 'sec-fetch-dest: document' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-site: none' -H 'sec-fetch-user: ?1' -H 'upgrade-insecure-requests: 1' --user-agent "${UA_BROWSER}")
    if [ -z "$tmpresult1" ]; then
        modifyJsonTemplate 'OpenAI_result' 'Unknown'
        echo -n -e "\r ChatGPT:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi
    if [ -z "$tmpresult2" ]; then
        modifyJsonTemplate 'OpenAI_result' 'Unknown'
        echo -n -e "\r ChatGPT:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local result1=$(echo "$tmpresult1" | grep -i 'unsupported_country')
    local result2=$(echo "$tmpresult2" | grep -i 'VPN')
    if [ -z "$result2" ] && [ -z "$result1" ]; then
        modifyJsonTemplate 'OpenAI_result' 'Yes'
        echo -n -e "\r ChatGPT:\t\t\t\t${Font_Green}Yes${Font_Suffix}\n"
        return
    fi
    if [ -n "$result2" ] && [ -n "$result1" ]; then
        modifyJsonTemplate 'OpenAI_result' 'No'
        echo -n -e "\r ChatGPT:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        return
    fi
    if [ -z "$result1" ] && [ -n "$result2" ]; then
        modifyJsonTemplate 'OpenAI_result' 'No' 'Web Only'
        echo -n -e "\r ChatGPT:\t\t\t\t${Font_Yellow}No (Only Available with Web Browser)${Font_Suffix}\n"
        return
    fi
    if [ -n "$result1" ] && [ -z "$result2" ]; then
        modifyJsonTemplate 'OpenAI_result' 'No' 'APP Only'
        echo -n -e "\r ChatGPT:\t\t\t\t${Font_Yellow}No (Only Available with Mobile APP)${Font_Suffix}\n"
        return
    fi

    modifyJsonTemplate 'OpenAI_result' 'Unknown'
    echo -n -e "\r ChatGPT:\t\t\t\t${Font_Red}Failed (Error: Unknown)${Font_Suffix}\n"
}

#Gemini
WebTest_Gemini() {
    local tmpresult=$(curl ${CURL_OPTS} -${1} -sL "https://gemini.google.com" --user-agent "${UA_BROWSER}")
    if [[ "$tmpresult" = "curl"* ]]; then
        modifyJsonTemplate 'Gemini_result' 'Unknown'
        echo -n -e "\r Google Gemini:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi
    result=$(echo "$tmpresult" | grep -q '45631641,null,true' && echo "Yes" || echo "")
    countrycode=$(echo "$tmpresult" | grep -o ',2,1,200,"[A-Z]\{3\}"' | sed 's/,2,1,200,"//;s/"//' || echo "")
    if [ -n "$result" ] && [ -n "$countrycode" ]; then
        modifyJsonTemplate 'Gemini_result' 'Yes' "${countrycode}"
        echo -n -e "\r Google Gemini:\t\t\t\t${Font_Green}Yes (Region: $countrycode)${Font_Suffix}\n"
        return
    elif [ -n "$result" ]; then
        modifyJsonTemplate 'Gemini_result' 'Yes'
        echo -n -e "\r Google Gemini:\t\t\t\t${Font_Green}Yes${Font_Suffix}\n"
        return
    else
        modifyJsonTemplate 'Gemini_result' 'No'
        echo -n -e "\r Google Gemini:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        return
    fi
}

#Claude
WebTest_Claude() {
    local UA_BROWSER="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
    local response=$(curl ${CURL_OPTS} -${1} -s -L -A "${UA_BROWSER}" -o /dev/null -w '%{url_effective}' "https://claude.ai/")
    if [ -z "$response" ]; then
        modifyJsonTemplate 'Claude_result' 'Unknown'
        echo -n -e "\r Claude:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi
    if [[ "$response" == "https://claude.ai/" ]]; then
        modifyJsonTemplate 'Claude_result' 'Yes'
        echo -n -e "\r Claude:\t\t\t\t${Font_Green}Yes${Font_Suffix}\n"
    elif [[ "$response" == "https://www.anthropic.com/app-unavailable-in-region" ]]; then
        modifyJsonTemplate 'Claude_result' 'No'
        echo -n -e "\r Claude:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
    else
        modifyJsonTemplate 'Claude_result' 'Unknown'
        echo -n -e "\r Claude:\t\t\t\t${Font_Yellow}Unknown (${response})${Font_Suffix}\n"
    fi
}

#TikTok
MediaUnlockTest_TikTok() {
    local Ftmpresult=$(curl ${CURL_OPTS} -${1} --user-agent "${UA_BROWSER}" -s "https://www.TikTok.com/")
    if [[ "$Ftmpresult" = "curl"* ]]; then
        modifyJsonTemplate 'TikTok_result' 'Unknown'
        echo -n -e "\r TikTok:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local FRegion=$(echo $Ftmpresult | grep '"region":' | sed 's/.*"region"//' | cut -f2 -d'"')
    if [ -n "$FRegion" ]; then
        modifyJsonTemplate 'TikTok_result' 'Yes' "${FRegion}"
        echo -n -e "\r TikTok:\t\t\t\t${Font_Green}Yes (Region: ${FRegion})${Font_Suffix}\n"
        return
    fi

    local STmpresult=$(curl ${CURL_OPTS} -${1} --user-agent "${UA_BROWSER}" -sL --max-time 10 -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9" -H "Accept-Encoding: gzip" -H "Accept-Language: en" "https://www.TikTok.com" | gunzip 2>/dev/null)
    local SRegion=$(echo $STmpresult | grep '"region":' | sed 's/.*"region"//' | cut -f2 -d'"')
    if [ -n "$SRegion" ]; then
        modifyJsonTemplate 'TikTok_result' 'Yes' "${SRegion}"
        echo -n -e "\r TikTok:\t\t\t\t${Font_Green}Yes (Region: ${SRegion})${Font_Suffix}\n"
        return
    else
        modifyJsonTemplate 'TikTok_result' 'No'
        echo -n -e "\r TikTok:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        return
    fi
}

###########################################
#                                         #
#     unlock check control code           #
#                                         #
###########################################

createJsonTemplate() {
    JSON_TMP=""
    JSON_TMP=$(mktemp)
    echo '{
    "YouTube": "YouTube_Premium_result",
    "Netflix": "Netflix_result",
    "DisneyPlus": "DisneyPlus_result",
    "HBOMax": "HBOMax_result",
    "AmazonPrime": "AmazonPrime_result",
    "OpenAI": "OpenAI_result",
    "Gemini": "Gemini_result",
    "Claude": "Claude_result",
    "TikTok": "TikTok_result"	

}' > "$JSON_TMP"
}

modifyJsonTemplate() {
    key_word=$1
    result=$2
    region=$3

    if [[ -z "$JSON_TMP" ]]; then
        echo "Error: JSON template not initialized" >&2
        return 1
    fi

    if [[ -z "$region" ]]; then
        sed -i "s#${key_word}#${result}#g" "$JSON_TMP"
    else
        sed -i "s#${key_word}#${result} (${region})#g" "$JSON_TMP"
    fi
    
}

runCheck() {
    MediaUnlockTest_Netflix 4
    MediaUnlockTest_YouTube_Premium 4
    MediaUnlockTest_DisneyPlus 4
    MediaUnlockTest_HBOMax 4
    MediaUnlockTest_PrimeVideo 4
    WebTest_OpenAI 4
    WebTest_Gemini 4
    WebTest_Claude 4
    MediaUnlockTest_TikTok 4
}

checkData() {
    local counter=0
    local max_check_num=3

    if [[ -z "$JSON_TMP" ]] || [[ ! -f "$JSON_TMP" ]]; then
        echo "Error: JSON template not available" >&2
        return 1
    fi

    while grep -q "_result" "$JSON_TMP" && [[ $counter -lt $max_check_num ]]; do
        sleep 1
        runCheck > /dev/null
        ((counter++))
        echo -e "\033[33mData incomplete, retrying (${counter}/${max_check_num})...\033[0m"
    done
}

postData() {
    if [[ ! -e "${CONFIG_FILE}" ]];then
        echo -e "Missing configuration file."
        exit 1
    fi
    if [[ -z "$JSON_TMP" ]] || [[ ! -f "$JSON_TMP" ]];then
        echo -e "Missing detection report."
        exit 1
    fi
    
    local panel_address mu_key node_id
    panel_address=$(sed -n 1p "${CONFIG_FILE}")
    mu_key=$(sed -n 2p "${CONFIG_FILE}")
    node_id=$(sed -n 3p "${CONFIG_FILE}")
    if [[ -z "$panel_address" ]] || [[ -z "$mu_key" ]] || [[ -z "$node_id" ]]; then
        echo "Error: Invalid configuration file" >&2
        exit 1
    fi

    RESPONSE_TMP=$(mktemp)
    content=$(base64 "$JSON_TMP" | tr -d '\n\r ')
    curl -s -X POST -d "content=$content" \
        "${panel_address}/mod_mu/media/save_report?key=${mu_key}&node_id=${node_id}" \
        > "$RESPONSE_TMP"
    if [[ "$(cat "$RESPONSE_TMP")" != "ok" ]]; then
        curl -s -X POST -d "content=$content" \
            "${panel_address}/mod_mu/media/saveReport?key=${mu_key}&node_id=${node_id}" \
            > "$RESPONSE_TMP"
    fi
    
    #curl -s -X POST -d "content=$(cat $JSON_TMP | base64 | xargs echo -n | sed 's# ##g')" "${panel_address}/mod_mu/media/save_report?key=${mu_key}&node_id=${node_id}" > "$RESPONSE_TMP"
    #if [[ "$(cat "$RESPONSE_TMP")" != "ok" ]];then
    #    curl -s -X POST -d "content=$(cat $JSON_TMP | base64 | xargs echo -n | sed 's# ##g')" "${panel_address}/mod_mu/media/saveReport?key=${mu_key}&node_id=${node_id}" > "$RESPONSE_TMP"
    #fi
}

install() {
    if [[ -f "/root/.csm.config" ]]; then
        cleanupLegacy
    fi
    local dir_path=$(dirname "$SCRIPT_PATH")
    [[ -d "$dir_path" ]] || mkdir -p "$dir_path"
    wget -qO "$SCRIPT_PATH" https://raw.githubusercontent.com/terminodev/titanicsite7/main/unlock_check.sh
    if [[ ! -s "$SCRIPT_PATH" ]]; then
        echo "Error: Failed to download script to ${SCRIPT_PATH}"
        exit 1
    fi
    chmod +x "$SCRIPT_PATH"
    local cron_tmp=$(mktemp)
    crontab -l 2>/dev/null | grep -v "${SCRIPT_PATH}" > "$cron_tmp"
    echo "0 7 * * * /bin/bash ${SCRIPT_PATH}" >> "$cron_tmp"
    crontab "$cron_tmp"
    rm -f "$cron_tmp"
    echo "Cron job added: Daily at 7:00 AM"
}

uninstall() {
    local cron_tmp=$(mktemp)
    crontab -l 2>/dev/null | grep -v "${SCRIPT_PATH}" > "$cron_tmp"
    crontab "$cron_tmp" 2>/dev/null
    rm -f "$cron_tmp"
    [[ -f "${SCRIPT_PATH}" ]] && rm -f "${SCRIPT_PATH}"
    [[ -f "${CONFIG_FILE}" ]] && rm -f "${CONFIG_FILE}"
    echo "Uninstall completed."
    echo "Removed:"
    echo "  - Script: ${SCRIPT_PATH}"
    echo "  - Config: ${CONFIG_FILE}"
    echo "  - Cron job related to this script"
}

cleanupLegacy() {
    local legacy_config="/root/.csm.config"
    local legacy_script="/opt/csm.sh"
    local cron_tmp=$(mktemp)
    crontab -l 2>/dev/null | grep -v "/bin/bash ${legacy_script}" | grep -v "${legacy_script}" > "$cron_tmp"
    crontab "$cron_tmp" 2>/dev/null
    rm -f "$cron_tmp"
    [[ -f "${legacy_script}" ]] && rm -f "${legacy_script}"
    [[ -f "${legacy_config}" ]] && rm -f "${legacy_config}"
}

checkConfig() {
    if [[ -e "${CONFIG_FILE}" ]]; then
        return 0
    fi
    if [[ -z "$WebApi" ]] || [[ -z "$WebApiKey" ]] || [[ -z "$NodeId" ]]; then
        echo "Error: WebApi, WebApiKey and NodeId are required."
        echo "Use -h for help."
        exit 1
    fi
    install
    local response
    response=$(curl -s --max-time 10 --retry 3 --retry-max-time 20 "${WebApi}/mod_mu/nodes?key=${WebApiKey}" 2>/dev/null)
    if echo "$response" | grep -q "invalid"; then
        echo -e "Bad WebApi address or bad WebApiKey."
        exit 1
    fi
    echo "${WebApi}" > "${CONFIG_FILE}"
    echo "${WebApiKey}" >> "${CONFIG_FILE}"
    echo "${NodeId}" >> "${CONFIG_FILE}"
}

printInfo() {
    echo -e "${Font_Green}[Stream Platform & AI Platform Restriction Test]${Font_Suffix}"
    echo -e "${Font_Green}Test Starts At: $(date)${Font_Suffix}"
    echo -e "${Font_Green}Version: 2026-03-18${Font_Suffix}"
}

help() {
    echo "使用示例：bash $0 -w http://www.domain.com -k apikey -i 10"
    echo "          bash $0 -u"
    echo ""
    echo "  -h     显示帮助信息"
    echo "  -u     卸载脚本、配置文件及对应 cron 任务"
    echo "  -w     【首次安装必填】指定WebApi地址，例：http://www.domain.com"
    echo "  -k     【首次安装必填】指定WebApikey"
    echo "  -i     【首次安装必填】指定节点ID"
    echo ""
}

cleanup() {
    [[ -n "$JSON_TMP" && -f "$JSON_TMP" ]] && rm -f "$JSON_TMP"
    [[ -n "$RESPONSE_TMP" && -f "$RESPONSE_TMP" ]] && rm -f "$RESPONSE_TMP"
}

main() {
    parse_params "$@"
    #checkOS
    #checkCPU
    #checkDependencies
    printInfo
    checkConfig
    createJsonTemplate
    runCheck
    checkData
    postData
}

trap cleanup EXIT

main "$@"
