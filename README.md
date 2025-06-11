pingguard — это лёгкий скрипт мониторинга IP-адресов с уведомлениями в Telegram. Не требует дополнительных зависимостей, кроме curl

Этот скрипт выполняет мониторинг IP-адресов с уведомлением через Telegram и имеет функции:

проверки доступности хостов;

отслеживания потерь соединения и высокого ping;

отправки уведомлений в Telegram при изменении состояния;

автозапуска через cron;

поддержки нескольких получателей и ботов.

Установка:

`wget -O /root/check_ip.sh https://raw.githubusercontent.com/cotshara/pingguard/refs/heads/main/check_ip.sh`

Делаем его исполняемым `chmod +x /root/check_ip.sh`

И запускаем его `/root/check_ip.sh`

Скрипт автоматически:

создаст файл /etc/ip_hosts.conf (если не существует);

добавит задачу в crontab;

предложит отредактировать список хостов для мониторинга.

Формат: /etc/ip_hosts.conf 
#host:name:chat_id1,chat_id2:bot_id:bot_token:max_errors:max_ping_ms

host — IP-адрес хоста

name — отображаемое имя

chat_id1,chat_id2 — список Telegram chat ID через запятую

bot_id — ID Telegram-бота

bot_token — токен Telegram-бота

max_errors — число неудачных попыток перед отправкой уведомления (по умолчанию 5)

max_ping_ms — максимальное значение RTT в мс (если превышено — предупреждение)
