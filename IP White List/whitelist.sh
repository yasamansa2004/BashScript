
#!/usr/bin/env bash

# color codes
green='\033[0;32m'
red='\033[0;31m'
yellow='\033[0;33m'
cyan='\033[0;36m'
reset='\033[0m'

# Show error message and exit
abort() {
  echo -e "${red}--X $1 ${reset}"
  exit 1
}

# Show information message
info() {
  echo -e "${cyan}--> $1 ${reset}"
}

# Show warning message
warn() {
  echo -e "${yellow}--! $1 ${reset}"
}

# Show success message
success() {
  echo -e "${green}--:) $1 ${reset}"
}

sync() {
  info "Downloading ArvanCloud list"

  IPsLinkv4="https://napi.arvancloud.ir/cdn/ips/v4"
  IPsLinkv6="https://napi.arvancloud.ir/cdn/ips/v6"
  IPsFilev4=$(mktemp /tmp/ar-ips-v4.XXXXXX)
  IPsFilev6=$(mktemp /tmp/ar-ips-v6.XXXXXX)

  # Delete the temp file if the script stopped for any reason
  trap 'rm -f ${IPsFilev4} ${IPsFilev6}' 0 2 3 15

  if [[ -x "$(command -v curl)" ]]; then
    downloadStatus=$(curl "${IPsLinkv4}" -o "${IPsFilev4}" -L -s -w "%{http_code}\n")
  elif [[ -x "$(command -v wget)" ]]; then
    downloadStatus=$(wget "${IPsLinkv4}" -O "${IPsFilev4}" --server-response 2>&1 | awk '/^  HTTP/{print $2}' | tail -n1)
  else
    abort "\`curl\` or \`wget\` is required to run this script."
  fi

  if [[ "$downloadStatus" -ne 200 ]]; then
    abort "Downloading the IPv4 list wasn't successful. status code: ${downloadStatus}"
  else
    IPs=$(cat "$IPsFilev4")
  fi

  if [[ "$2" == "2" || "$2" == "v4v6" ]]; then
    if [[ -x "$(command -v curl)" ]]; then
      downloadStatus=$(curl "${IPsLinkv6}" -o "${IPsFilev6}" -L -s -w "%{http_code}\n")
    elif [[ -x "$(command -v wget)" ]]; then
      downloadStatus=$(wget "${IPsLinkv6}" -O "${IPsFilev6}" --server-response 2>&1 | awk '/^  HTTP/{print $2}' | tail -n1)
    else
      abort "\`curl\` or \`wget\` is required to run this script."
    fi

    if [[ "$downloadStatus" -ne 200 ]]; then
      abort "Downloading the IPv6 list wasn't successful. status code: ${downloadStatus}"
    else
      IPsv6=$(cat "$IPsFilev6")
      IPs="${IPs} ${IPsv6}"
    fi
  fi

  info "Adding IPs to the selected firewall"

  # Process user input
  case "$1" in
  1 | ufw)
    if [[ ! -x "$(command -v ufw)" ]]; then
      abort "The \`ufw\` is not installed."
    fi

    warn "Delete old ArvanCloud rules if exist"

    ufw show added | awk '/arvancloud/{ gsub("ufw","ufw delete",$0); system($0)}'

    info "Adding new ArvanCloud rules"

    for IP in ${IPs}; do
      ufw allow from "$IP" to any comment "arvancloud"
    done

    ufw reload
    ;;
  2 | csf)
    if [[ ! -x "$(command -v csf)" ]]; then
      abort "The \`csf\` is not installed."
    fi

    CSF_CONF="/etc/csf/csf.conf"

    if [ -f "$CSF_CONF" ]; then
      warn "Delete old ArvanCloud rules if exist"
      awk '!/arvancloud/' /etc/csf/csf.allow >csf.t && mv csf.t /etc/csf/csf.allow

      info "Adding new ArvanCloud rules"

      if [[ "$2" == "2" || "$2" == "v4v6" ]]; then
        # Check if IPv6 is enabled for CSF
        IPV6_ENABLED=$(grep "^IPV6" "$CSF_CONF" | cut -d '=' -f2 | tr -d ' ')
        if [ !"$IPV6_ENABLED" == "1" ]; then
          abort "IPv6 is disabled in CSF."
        fi
      fi

      for IP in ${IPs}; do
        csf -a "$IP" "arvancloud"
      done

      csf -r
    else
      abort "CSF configuration file not found!"
    fi
    ;;
  3 | firewalld)
    if [[ ! -x "$(command -v firewall-cmd)" ]]; then
      abort "The \`firewalld\` is not installed."
    fi

    warn "Delete old ArvanCloud zone if exist"
    if [[ $(firewall-cmd --permanent --list-all-zones | grep arvancloud) ]]; then firewall-cmd --permanent --delete-zone=arvancloud; fi

    info "Adding new ArvanCloud zone"
    firewall-cmd --permanent --new-zone=arvancloud
    for IP in ${IPs}; do
      FAMILY=$([[ $IP =~ ":" ]] && echo "ipv6" || echo "ipv4")
      firewall-cmd --permanent --zone=arvancloud --add-rich-rule='rule family='"$FAMILY"' source address='"$IP"' port port=80 protocol="tcp" accept'
      firewall-cmd --permanent --zone=arvancloud --add-rich-rule='rule family='"$FAMILY"' source address='"$IP"' port port=443 protocol="tcp" accept'
    done

    firewall-cmd --reload
    ;;
  4 | iptables)
    if [[ ! -x "$(command -v iptables)" ]]; then
      abort "The \`iptables\` is not installed."
    fi

    warn "Delete old ArvanCloud rules if exist"

    CURRENT_RULES=$(iptables --line-number -nL INPUT | grep arvancloud | awk '{print $1}' | tac)
    for rule in $CURRENT_RULES; do
      iptables -D INPUT $rule
    done

    if [[ "$2" == "2" || "$2" == "v4v6" ]]; then
      CURRENT_RULES=$(ip6tables --line-number -nL INPUT | grep arvancloud | awk '{print $1}' | tac)
      for rule in $CURRENT_RULES; do
        ip6tables -D INPUT $rule
      done
    fi

    info "Adding new ArvanCloud rules"
    for IP in ${IPs}; do
      FAMILY=$([[ $IP =~ ":" ]] && echo "ip6tables" || echo "iptables")
      CMD="$FAMILY -A INPUT -p tcp -s "$IP" -m multiport --dports 80,443 -m comment --comment "arvancloud" -j ACCEPT"
      eval "$CMD"
    done
    ;;
  5 | ipset)
    if [[ ! -x "$(command -v ipset)" ]]; then
      abort "The \`ipset\` is not installed."
    fi
    if [[ ! -x "$(command -v iptables)" ]]; then
      abort "The \`iptables\` is not installed."
    fi

    warn "Delete old ArvanCloud ipset if exist"
    ipset list | grep -q "arvancloud-ipset"
    greprc=$?
    if [[ "$greprc" -eq 0 ]]; then
      iptables -D INPUT -p tcp -m set --match-set arvancloud-ipset-v4 src -m multiport --dports 80,443 -m comment --comment arvancloud -j ACCEPT 2>/dev/null
      sleep 0.5
      ipset destroy arvancloud-ipset-v4
      if [[ "$2" == "2" || "$2" == "v4v6" ]]; then
        ip6tables -D INPUT -p tcp -m set --match-set arvancloud-ipset-v6 src -m multiport --dports 80,443 -m comment --comment arvancloud -j ACCEPT 2>/dev/null
        sleep 0.5
        ipset destroy arvancloud-ipset-v6
      fi
    fi

    info "Adding new ArvanCloud ipset"
    ipset create arvancloud-ipset-v4 hash:net
    if [[ "$2" == "2" || "$2" == "v4v6" ]]; then
      ipset create arvancloud-ipset-v6 hash:net family inet6
    fi

    for IP in ${IPs}; do
      if [[ $IP =~ ":" ]]; then
        ipset add arvancloud-ipset-v6 "$IP"
        ip6tables -nvL | grep -q "arvancloud-ipset-v6"
        exitcode=$?
        if [[ "$exitcode" -eq 1 ]]; then
          ip6tables -I INPUT -p tcp -m set --match-set arvancloud-ipset-v6 src -m multiport --dports 80,443 -m comment --comment "arvancloud" -j ACCEPT
        fi
      else
        ipset add arvancloud-ipset-v4 "$IP"
        iptables -nvL | grep -q "arvancloud-ipset-v4"
        exitcode=$?
        if [[ "$exitcode" -eq 1 ]]; then
          iptables -I INPUT -p tcp -m set --match-set arvancloud-ipset-v4 src -m multiport --dports 80,443 -m comment --comment "arvancloud" -j ACCEPT
        fi
      fi
    done
    ;;
  6 | nftables)
    if [[ ! -x "$(command -v nft)" ]]; then
      abort "The \`nftables\` is not installed."
    fi
    # create filter table
    nft add table inet filter

    warn "Delete old ArvanCloud chain"
    if [[ $(nft list ruleset | grep arvancloud) ]]; then
      nft delete chain inet filter arvancloud
    fi

    info "Adding new ArvanCloud chain"
    nft add chain inet filter arvancloud '{ type filter hook input priority 0; }'
    IPv4=""
    IPv6=""
    for IP in ${IPs}; do
      if [[ $IP =~ ":" ]]; then
        IPv6+="$IP,"
      else
        IPv4+="$IP,"
      fi
    done
    nft insert rule inet filter arvancloud counter ip saddr "{ ${IPv4%,} }" tcp dport "{80, 443}" accept
    if [[ "$2" == "2" || "$2" == "v4v6" ]]; then
      nft insert rule inet filter arvancloud counter ip6 saddr "{ ${IPv6%,} }" tcp dport "{80, 443}" accept
    fi
    ;;
  *)
    abort "The selected firewall is not valid."
    ;;
  esac
}

main() {
  # Check root access
  if [[ $EUID -ne 0 ]]; then
    abort "This script needs to be run with superuser privileges."
  fi

  clear

  # Get firewall
  if [[ -z $1 ]]; then
    echo "Select a firewall to add IPs:"
    echo "   1) UFW"
    echo "   2) CSF"
    echo "   3) firewalld"
    echo "   4) iptables"
    echo "   5) ipset+iptables"
    echo "   6) nftables"
    read -r -p "Firewall: " firewall
  else
    firewall=$1
  fi
  if ! [[ "$firewall" =~ ^[1-6]$ || "$firewall" =~ ^(csf|ufw|firewalld|iptables|ipset|nftables)$ ]]; then
    abort "Invalid firewall selected. It should be 1-6 or one of: csf, ufw, firewalld, iptables, ipset, nftables."
  fi

  clear

  # Get IP Version
  # TODO: Support IPv6 only
  if [[ -z $2 ]]; then
    echo "Select IP version:"
    echo "   1) IPv4"
    echo "   2) IPv4 + IPv6"
    read -r -p "Version: " version
  else
    version=$2
  fi
  if [ -z "$version" ]; then
    version="1"
  fi
  if ! [[ "$version" =~ ^(1|2|v4|v4v6)$ ]]; then
    abort "Invalid IP version. It should be 1-2 or one of: v4, v4v6"
  fi

  clear

  sync $firewall $version

  success "DONE!"
}

main "$@"
