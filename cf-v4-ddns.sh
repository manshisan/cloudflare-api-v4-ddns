#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Automatically update your CloudFlare DNS record to the IP, Dynamic DNS
# Can retrieve cloudflare Domain id and list zone's, because, lazy

# Place at:
# curl https://raw.githubusercontent.com/manshisan/cloudflare-api-v4-ddns/master/cf-v4-ddns.sh > /usr/local/bin/cf-v4-ddns.sh && chmod +x /usr/local/bin/cf-v4-ddns.sh
# run `crontab -e` and add next line:
# */1 * * * * /usr/local/bin/cf-v4-ddns.sh >/dev/null 2>&1
# or you need log:
# */1 * * * * /usr/local/bin/cf-v4-ddns.sh >> /var/log/cf-v4-ddns.log 2>&1


# Usage:
# cf-v4-ddns.sh -k cloudflare-api-key \
#            -u user@example.com \
#            -h host.example.com \   # fqdn of the record you want to update
#            -z example.com \        # will show you all zones if forgot, but you need this
#            -t A|AAAA \             # specify ipv4/ipv6, default: ipv4
#            -b tg_bot_token \     # (Optional) telegram bot token for notifications
#            -c tg_chat_id         # (Optional) telegram chat id for notifications

# Optional flags:
#            -f false|true \         # force dns update, disregard local stored ip

# default config

# API key, see https://www.cloudflare.com/a/account/my-account,
# incorrect api-key results in E_UNAUTH error
CFKEY=

# Username, eg: user@example.com
CFUSER=

# Zone name, eg: example.com
CFZONE_NAME=

# Hostname to update, eg: homeserver.example.com
CFRECORD_NAME=

# Record type, A(IPv4)|AAAA(IPv6), default IPv4
CFRECORD_TYPE=A

# Cloudflare TTL for record, between 120 and 86400 seconds
CFTTL=120

# Ignore local file, update ip anyway
FORCE=false

# (Optional) telegram bot token. 
TG_BOT_TOKEN=
# (Optional) telegram chat id. 
TG_CHAT_ID=

WANIPSITE="http://ipv4.icanhazip.com"

# Site to retrieve WAN ip, other examples are: bot.whatismyipaddress.com, https://api.ipify.org/ ...
if [ "$CFRECORD_TYPE" = "A" ]; then
  :
elif [ "$CFRECORD_TYPE" = "AAAA" ]; then
  WANIPSITE="http://ipv6.icanhazip.com"
else
  echo "$CFRECORD_TYPE specified is invalid, CFRECORD_TYPE can only be A(for IPv4)|AAAA(for IPv6)"
  exit 2
fi

# Function to send a notification to Telegram
send_tg_notification() {
  local message="$1"
  # Exit if token or chat id is not set
  if [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
    return
  fi

  echo "Sending notification to Telegram..."
  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TG_CHAT_ID}" \
    --data-urlencode "text=${message}" \
    -d "parse_mode=Markdown" > /dev/null
}
# --> ADDED END

# get parameter
while getopts k:u:h:z:t:f:b:c: opts; do
  case ${opts} in
    k) CFKEY=${OPTARG} ;;
    u) CFUSER=${OPTARG} ;;
    h) CFRECORD_NAME=${OPTARG} ;;
    z) CFZONE_NAME=${OPTARG} ;;
    t) CFRECORD_TYPE=${OPTARG} ;;
    f) FORCE=${OPTARG} ;;
    b) TG_BOT_TOKEN=${OPTARG} ;;
    c) TG_CHAT_ID=${OPTARG} ;;
  esac
done

# If required settings are missing just exit
if [ "$CFKEY" = "" ]; then
  echo "Missing api-key, get at: https://www.cloudflare.com/a/account/my-account"
  echo "and save in ${0} or using the -k flag"
  exit 2
fi
if [ "$CFUSER" = "" ]; then
  echo "Missing username, probably your email-address"
  echo "and save in ${0} or using the -u flag"
  exit 2
fi
if [ "$CFRECORD_NAME" = "" ]; then 
  echo "Missing hostname, what host do you want to update?"
  echo "save in ${0} or using the -h flag"
  exit 2
fi

# If the hostname is not a FQDN
if [ "$CFRECORD_NAME" != "$CFZONE_NAME" ] && ! [ -z "${CFRECORD_NAME##*$CFZONE_NAME}" ]; then
  CFRECORD_NAME="$CFRECORD_NAME.$CFZONE_NAME"
  echo " => Hostname is not a FQDN, assuming $CFRECORD_NAME"
fi

# Get current and old WAN ip
WAN_IP=$(curl -s ${WANIPSITE})
WAN_IP_FILE=$HOME/.cf-wan_ip_$CFRECORD_NAME.txt
if [ -f $WAN_IP_FILE ]; then
  OLD_WAN_IP=$(cat $WAN_IP_FILE)
else
  echo "No file, need IP"
  OLD_WAN_IP=""
fi

# If WAN IP is unchanged an not -f flag, exit here
if [ "$WAN_IP" = "$OLD_WAN_IP" ] && [ "$FORCE" = false ]; then
  echo "WAN IP Unchanged, to update anyway use flag -f true"
  exit 0
fi

# Get zone_identifier & record_identifier
ID_FILE=$HOME/.cf-id_$CFRECORD_NAME.txt
if [ -f $ID_FILE ] && [ $(wc -l < "$ID_FILE") -eq 4 ] \
  && [ "$(sed -n '3p' "$ID_FILE")" = "$CFZONE_NAME" ] \
  && [ "$(sed -n '4p' "$ID_FILE")" = "$CFRECORD_NAME" ]; then
    CFZONE_ID=$(sed -n '1p' "$ID_FILE")
    CFRECORD_ID=$(sed -n '2p' "$ID_FILE")
else
    echo "Updating zone_identifier & record_identifier"
    
    # Get zone ID
    echo "Getting zone ID for: $CFZONE_NAME"
    ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CFZONE_NAME" -H "Authorization: Bearer $CFKEY" -H "Content-Type: application/json")
    #echo "Zone API response: $ZONE_RESPONSE"
    
    CFZONE_ID=$(echo "$ZONE_RESPONSE" | grep -Po '(?<="id":")[^"]*' | head -1)
    echo "Zone ID: $CFZONE_ID"
    
    if [ -z "$CFZONE_ID" ]; then
        echo "Error: Could not get zone ID. Check your domain name and API credentials."
        exit 1
    fi
    
    # Get record ID
    echo "Getting record ID for: $CFRECORD_NAME"
    RECORD_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=$CFRECORD_NAME" -H "Authorization: Bearer $CFKEY" -H "Content-Type: application/json")
    #echo "Record API response: $RECORD_RESPONSE"
    
    CFRECORD_ID=$(echo "$RECORD_RESPONSE" | grep -Po '(?<="id":")[^"]*' | head -1)
    echo "Record ID: $CFRECORD_ID"
    
    if [ -z "$CFRECORD_ID" ]; then
        echo "Error: Could not get record ID. Check if the DNS record exists."
        exit 1
    fi
    
    echo "$CFZONE_ID" > "$ID_FILE"
    echo "$CFRECORD_ID" >> "$ID_FILE"
    echo "$CFZONE_NAME" >> "$ID_FILE"
    echo "$CFRECORD_NAME" >> "$ID_FILE"
fi

# If WAN is changed, update cloudflare
echo "Updating DNS to $WAN_IP"

RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
  -H "Authorization: Bearer $CFKEY" \
  -H "Content-Type: application/json" \
  --data "{\"id\":\"$CFZONE_ID\",\"type\":\"$CFRECORD_TYPE\",\"name\":\"$CFRECORD_NAME\",\"content\":\"$WAN_IP\", \"ttl\":$CFTTL}")

if [ "$RESPONSE" != "${RESPONSE%success*}" ] && [ "$(echo $RESPONSE | grep "\"success\":true")" != "" ]; then
  log_msg="✅ DDNS Update Successful! The IP for *${CFRECORD_NAME}* has been updated to *${WAN_IP}*."
  echo "$log_msg"
  send_tg_notification "$log_msg"
  echo "$WAN_IP" > "$WAN_IP_FILE"
  exit
else
  error_msg="❌ DDNS Update FAILED for *${CFRECORD_NAME}*. Response: \`\`\`${RESPONSE}\`\`\`"
  echo "$error_msg"
  send_tg_notification "$error_msg"
  exit 1
fi
