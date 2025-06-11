# 🛡️ pingguard

**pingguard** — это лёгкий скрипт для мониторинга IP-адресов с Telegram-уведомлениями.  
Подходит для OpenWRT и других Linux-устройств. Не требует ничего, кроме `curl`.

---

## 🚀 Возможности

- Мониторинг доступности IP-адресов (`ping`)
- Уведомления в Telegram:
  - при недоступности хоста ❌
  - при восстановлении соединения ✅
  - при превышении допустимого пинга ⚠️
- Автоматический запуск через `cron`
- Поддержка нескольких Telegram-чатов и ботов
- Интерактивная настройка при первом запуске
- Минимальные зависимости

---

## 📦 Установка

```sh
wget -O /usr/bin/check_ip.sh https://raw.githubusercontent.com/cotshara/pingguard/refs/heads/main/check_ip.sh
chmod +x /usr/bin/check_ip.sh
/usr/bin/check_ip.sh
```

⚠️ Убедитесь, что используется кодировка UTF-8, иначе русские сообщения будут отображаться некорректно.

⚙️ Формат конфигурации /etc/ip_hosts.conf

#host:name:chat_id1,chat_id2:bot_id:bot_token:max_errors:max_ping_ms
8.8.8.8:GoogleDNS:123456789:987654321:abcdef12345:3:100

Пояснение полей:
Поле	Описание
host	IP-адрес для мониторинга
name	Название хоста
chat_id	Список Telegram chat ID (через запятую)
bot_id	ID Telegram-бота
bot_token	Токен Telegram-бота
max_errors	Кол-во неудачных ping до уведомления (по умолчанию 5)
max_ping_ms	Максимально допустимый ping (в мс). Превышение вызывает предупреждение

![image](https://github.com/user-attachments/assets/e59d326a-507a-4d92-bedc-7f318eacdb2f)

![image](https://github.com/user-attachments/assets/25099bbb-b7f8-41b7-8eba-7e8fc3de2b24)

