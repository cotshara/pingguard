#!/bin/sh

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

STATUS_DIR="/etc/ip_status"
CRON_ENTRY="* * * * * /root/check_ip.sh"
HOSTS_FILE="/etc/ip_hosts.conf"

is_interactive() {
  case "$-" in
    *i*) return 0 ;;
    *) [ -t 1 ] ;;
  esac
}

send_telegram_message() {
  local MESSAGE="$1" CHAT_ID="$2" BOT_ID="$3" BOT_TOKEN="$4" NAME="$5" IP="$6"
  local RESPONSE
  RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_ID}:${BOT_TOKEN}/sendMessage" \
    -d chat_id="$CHAT_ID" -d text="$MESSAGE")

  if echo "$RESPONSE" | grep -q '"ok":true'; then
    $INTERACTIVE && echo -e "${GREEN}→ Отправлено в чат $CHAT_ID ${GREEN}$MESSAGE"
  else
    echo -e "${RED}❌Ошибка отправки в чат $CHAT_ID проверте правильность CHAT_ID BOT_ID BOT_TOKEN и повторите попытку ${GREEN}$MESSAGE"
  fi
}

send_to_all_chats() {
  local MESSAGE="$1" CHAT_IDS="$2" BOT_ID="$3" BOT_TOKEN="$4" NAME="$5" IP="$6"
  OLD_IFS="$IFS"; IFS=','
  for CHAT_ID in $CHAT_IDS; do
    send_telegram_message "$MESSAGE" "$CHAT_ID" "$BOT_ID" "$BOT_TOKEN" "$NAME" "$IP"
  done
  IFS="$OLD_IFS"
}

INTERACTIVE=false
is_interactive && INTERACTIVE=true

if $INTERACTIVE; then
  echo -e "${CYAN}Запуск...${NC}"

  if ! command -v curl >/dev/null 2>&1; then
    echo -e "${RED}Ошибка: curl не установлен.${NC}"
    echo -e "${YELLOW}Установите его командой:${NC} ${CYAN}opkg install curl${NC}"
    exit 1
  fi

  if [ -d "$STATUS_DIR" ]; then
    echo -e "${YELLOW}Очищаю каталог $STATUS_DIR...${NC}"
    rm -rf "$STATUS_DIR"
  else
    echo -e "${YELLOW}Каталог $STATUS_DIR не найден. Создаю...${NC}"
  fi
  mkdir -p "$STATUS_DIR"
  echo -e "${GREEN}Каталог $STATUS_DIR готов.${NC}"

  TEMP_CRON=$(mktemp)
  crontab -l 2>/dev/null | grep -v "^\s*$" | grep -v "$CRON_ENTRY" > "$TEMP_CRON"
  echo "$CRON_ENTRY" >> "$TEMP_CRON"
  crontab "$TEMP_CRON"
  rm -f "$TEMP_CRON"
  echo -e "${GREEN}Добавлено в cron.${NC}"

  if [ ! -f "$HOSTS_FILE" ]; then
    echo -e "${YELLOW}Создаю шаблон $HOSTS_FILE...${NC}"
    cat <<EOF > "$HOSTS_FILE"
#host:name:chat_id1,chat_id2:bot_id:bot_token:max_errors:max_ping_ms
EOF
    echo -e "${GREEN}Файл $HOSTS_FILE создан.${NC}"
  fi

  echo -e "${CYAN}Открыть список хостов для редактирования? [Y/N]: ${NC} \c"
  read ANSWER
  if [ "$ANSWER" = "y" ] || [ "$ANSWER" = "Y" ]; then
    echo -e "${CYAN}Выберите редактор: [1] vi (по умолчанию), [2] nano: ${NC} \c"
    read EDITOR_CHOICE
    if [ "$EDITOR_CHOICE" = "2" ]; then
      if ! command -v nano >/dev/null 2>&1; then
        echo -e "${RED}Внимание: nano не установлен.${NC}"
        echo -e "${YELLOW}Для установки выполните:${NC} ${CYAN}opkg install nano${NC}"
        exit 1
      else
        nano "$HOSTS_FILE"
      fi
    else
      vi "$HOSTS_FILE"
    fi
  fi
fi

mkdir -p "$STATUS_DIR"
[ ! -f "$HOSTS_FILE" ] && { echo -e "${RED}Файл $HOSTS_FILE отсутствует.${NC}"; exit 1; }

if ! grep -qE '^[[:space:]]*[^#[:space:]]' "$HOSTS_FILE"; then
  $INTERACTIVE && echo -e "${YELLOW}В файле $HOSTS_FILE нет активных строк для мониторинга.${NC}"
  exit 0
fi

while IFS= read -r LINE; do
  [ -z "$LINE" ] || echo "$LINE" | grep -q '^#' && continue

  IP=$(echo "$LINE" | cut -d':' -f1)
  NAME=$(echo "$LINE" | cut -d':' -f2)
  CHAT_IDS=$(echo "$LINE" | cut -d':' -f3)
  BOT_ID=$(echo "$LINE" | cut -d':' -f4)
  BOT_TOKEN=$(echo "$LINE" | cut -d':' -f5)
  MAX_FAILS=$(echo "$LINE" | cut -d':' -f6)
  MAX_RTT_MS=$(echo "$LINE" | cut -d':' -f7)
  [ -z "$MAX_FAILS" ] && MAX_FAILS=5
  [ "$MAX_RTT_MS" = "0" ] && MAX_RTT_MS=""

  STATUS_FILE="${STATUS_DIR}/${IP}.status"
  FAIL_FILE="${STATUS_DIR}/${IP}.failcount"
  DELAY_FILE="${STATUS_DIR}/${IP}.delaywarned"

  [ ! -f "$STATUS_FILE" ] && echo "unknown" > "$STATUS_FILE"
  [ ! -f "$FAIL_FILE" ] && echo "0" > "$FAIL_FILE"

  PING_OUTPUT=$(ping -c 1 -W 2 "$IP" 2>/dev/null)
  if echo "$PING_OUTPUT" | grep -q "time="; then
    CURRENT_STATUS="UP"
    RTT=$(echo "$PING_OUTPUT" | grep "time=" | sed -E 's/.*time=([0-9.]+) ms.*/\1/')
  else
    CURRENT_STATUS="DOWN"
    RTT=""
  fi

  PREVIOUS_STATUS=$(cat "$STATUS_FILE")
  FAIL_COUNT=$(cat "$FAIL_FILE")

  if [ "$CURRENT_STATUS" = "UP" ]; then
    echo "0" > "$FAIL_FILE"

    PREVIOUS_DELAY_WARNED=false
    [ -f "$DELAY_FILE" ] && PREVIOUS_DELAY_WARNED=true

    if [ "$PREVIOUS_STATUS" != "UP" ]; then
      
      if [ -n "$RTT" ] && [ -n "$MAX_RTT_MS" ] && awk "BEGIN{exit !($RTT > $MAX_RTT_MS)}"; then
        MESSAGE="$NAME ($IP) в сети, но высокий ping: ${RTT}мс ⚠️"
        touch "$DELAY_FILE"
      else
        MESSAGE="$NAME ($IP) в сети ✅"
        rm -f "$DELAY_FILE"
      fi
      send_to_all_chats "$MESSAGE" "$CHAT_IDS" "$BOT_ID" "$BOT_TOKEN" "$NAME" "$IP"
    else
      
      if [ -n "$RTT" ] && [ -n "$MAX_RTT_MS" ]; then
        if awk "BEGIN{exit !($RTT > $MAX_RTT_MS)}"; then
          if ! $PREVIOUS_DELAY_WARNED; then
            MESSAGE="$NAME ($IP) в сети, но высокий ping: ${RTT}мс ⚠️"
            send_to_all_chats "$MESSAGE" "$CHAT_IDS" "$BOT_ID" "$BOT_TOKEN" "$NAME" "$IP"
            touch "$DELAY_FILE"
          fi
        else
          if $PREVIOUS_DELAY_WARNED; then
            MESSAGE="$NAME ($IP) ping в норме ✅ (${RTT}мс)"
            send_to_all_chats "$MESSAGE" "$CHAT_IDS" "$BOT_ID" "$BOT_TOKEN" "$NAME" "$IP"
            rm -f "$DELAY_FILE"
          fi
        fi
      fi
    fi

    echo "UP" > "$STATUS_FILE"
  else
    if [ "$FAIL_COUNT" -eq 0 ]; then
      # $INTERACTIVE && echo -e "${YELLOW}$NAME ($IP) Не в сети ❌${NC}"
      :
    fi

    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "$FAIL_COUNT" > "$FAIL_FILE"

    if [ "$FAIL_COUNT" -eq "$MAX_FAILS" ]; then
      MESSAGE="$NAME ($IP) не в сети ❌"
      send_to_all_chats "$MESSAGE" "$CHAT_IDS" "$BOT_ID" "$BOT_TOKEN" "$NAME" "$IP"
      echo "DOWN" > "$STATUS_FILE"
    fi

    $INTERACTIVE && echo -e "${RED}$NAME ($IP) Не в сети ❌ или проверте правильность IP адреса и повторите попытку (попытка $FAIL_COUNT/$MAX_FAILS) ${NC}"
  fi
done < "$HOSTS_FILE"