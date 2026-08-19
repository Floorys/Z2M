# Zapret2 Manager (OpenWrt)

![Platform](https://img.shields.io/badge/Platform-OpenWrt-orange)
![Script](https://img.shields.io/badge/Script-sh-informational)
![Engine](https://img.shields.io/badge/Engine-nfqws2%20(zapret2)-blue)

Меню в SSH для управления **zapret2** на роутере (сборка Routerich / `nfqws2` + `luci-app-zapret2`)
с **корректным портированием стратегий Windows-генератора [Zapret2UI](https://github.com/Asterlike/zapret2UI)**.

Стратегию больше не нужно разбирать руками: вставил текст из GUI — получил готовые UCI-секции,
включённые блобы, правильные хостлисты и порты.

---

## Возможности

- Выбор и применение стратегии из списка пресетов в один пункт меню
- Портирование любого текста стратегии Zapret2UI (winws2) в UCI — с предпросмотром
- Автоподбор: перебор всех стратегий с проверкой Discord/YouTube и выбором лучшей
- Свои стратегии для теста из `/root/custom_test.txt` (блоки `#Название`)
- Автопроверка запуска демона и **автооткат** при неудаче (+ печать точной ошибки nfqws2)
- Управление хостлистами и исключениями
- Настройки перехвата: порты TCP/UDP, лимиты пакетов, IPv6, QUIC-профили, свои скрипты
- Диагностика: счётчики NFQUEUE, процессы, CPU, IPv6, DNS, лог, валидация аргументов
- Бэкап/откат конфига, системное меню (автозапуск, FIX flow offloading, версии, удаление)

---

## Требования

- OpenWrt 23.05+ (проверено на 24.10)
- Установленный zapret2: `/opt/zapret2/nfq2/nfqws2` + UCI-конфиг `zapret2`
- `curl` на роутере (для автопроверок): `opkg install curl`

---

## Установка

```sh
cd /tmp
wget -O z2m.zip https://github.com/USER/zapret2-manager/archive/refs/heads/main.zip
unzip z2m.zip
cd zapret2-manager-main
sh install.sh
```

Затем запуск:

```sh
z2m
```

Удаление: меню → 8) Системное меню → 7) удалить менеджер.

---

## Меню

```
=== Zapret2 Manager v0.1.0 (OpenWrt) ===
 статус: РАБОТАЕТ | профилей: 7 | обработано пакетов (q300): 18234
------------------------------------------
 1) Стратегии - выбрать и применить
 2) Подбор и тест
 3) Портировать стратегию из Zapret2UI
 4) Хостлисты
 5) Настройки перехвата
 6) Диагностика
 7) Бэкап и откат
 8) Системное меню
 0) Выход
```

---

## Стратегии

Пресеты — обычные `.txt` в `strategies/` (после установки — `/opt/z2m/strategies/`)
в том же виде, в каком их выдаёт Zapret2UI. Кинул файл — он сразу в меню.

| Файл | Суть |
|---|---|
| `01-combo-md5.txt` | fake tls_google + `tcp_md5`, затем `multisplit:pos=1,midsld` |
| `02-multidisorder.txt` | без fake, `multidisorder` по маркерам host/sld/sniext |
| `03-seqovl681.txt` | `multisplit:pos=2,midsld-2:seqovl=681:seqovl_pattern=tls_google` |
| `04-autottl.txt` | fake с `ip_autottl` вместо md5 |
| `05-tcpts.txt` | fake с `tcp_ts=-1000` |
| `06-voice-only.txt` | только голосовой диапазон Discord |

### Формат файла

- Одна строка = одна или несколько опций, `#` — комментарий
- `--new` разделяет профили (каждый станет отдельной секцией `strategy`)
- Липкие флаги (`--payload`, `--out-range`, `--in-range`) ставь ДО своего `--lua-desync`

### Поддерживаемые токены Zapret2UI

| Токен | Во что превращается |
|---|---|
| `{WF_TCP}` / `{WF_UDP}` | отбрасываются, порты берутся из `--filter-tcp/udp` в `nfqws_ports_tcp/udp` |
| `--blob=alias:@{FILES}\fake\x.bin` | включается `blob_x`, алиас подменяется в `blob=` и `seqovl_pattern=` |
| `{HOSTLIST:name}` | `hostlist` → `list_hosts_<name>` (без учёта регистра) |
| `{EXCLUDE:name}` | `hostlist_exclude` (`exclude` → `list_hosts_user_exclude`) |
| `--lua-init=<код>` | `/opt/zapret2/lua/zz-custom.lua` + секция `luascript` |
| `--ipcache-*` | добавляется в первый профиль |
| `--lua-gc=`, `--ctrack-timeouts=` | в `zapret2.main` |
| `--wf-*`, `--wf-raw-part=*` | отбрасываются (Windows-only) |
| `{IPSET*}` | не переносится, выводится предупреждение |

### Свои стратегии для перебора

`/root/custom_test.txt`:

```
#Strategy1
--filter-tcp=443 --filter-l7=tls {HOSTLIST:discord}
--payload=tls_client_hello
--lua-desync=multisplit:pos=1,midsld
#Strategy2
--filter-tcp=443 --filter-l7=tls {HOSTLIST:discord}
--payload=tls_client_hello
--lua-desync=multidisorder:pos=1,midsld
```

Меню → 2) Подбор и тест → 2.

---

## Если не работает

1. **Демон не запускается.** Менеджер сам покажет вывод `nfqws2 --intercept=0` и откатится.
   Типовые причины: неизвестное имя блоба, лишний пробел перед `:` в `--lua-desync`,
   неподдерживаемый параметр desync.
2. **Счётчик пакетов не растёт** (пункт 6): трафик не доходит до nfqws2 — смотри
   flow offloading (пункт 8 → 5), `postnat`, порты захвата. Стратегия тут ни при чём.
3. **Есть global IPv6** — часть трафика идёт мимо (профили ставятся как `filter_l3=ipv4`):
   или гаси IPv6 на LAN, или включай обработку IPv6 (пункт 5 → 6).
4. **Подмена DNS** — проверь `nslookup discord.com 127.0.0.1` в диагностике, при нужде ставь DoH.
5. **Ни одна стратегия не подходит** — blockcheck2 (пункт 2 → 4 или вкладка в LuCI),
   затем собери найденное в новый пресет.

Заметка про Windows-клиенты: для стратегий с `tcp_ts` один раз выполни
`netsh int tcp set global timestamps=enabled`.

---

## Структура

```
zapret2-manager/
├── z2m                  # меню -> /usr/bin/z2m
├── install.sh
├── lib/port.awk         # конвертер winws2 -> UCI
├── strategies/*.txt     # пресеты
├── README.md
└── LICENSE
```

Файлы и пути на роутере: `/opt/z2m/`, `/usr/bin/z2m`, бэкап `/root/z2m.bak`,
временные `/tmp/z2m.in`, `/tmp/z2m.uci`.

---

## Благодарности

- **zapret2 / nfqws2** — [bol-van](https://github.com/bol-van/zapret2)
- **Zapret2 Routerich Edition** — [Routerich](https://github.com/routerich)
- **Zapret2UI** (генератор и подбор стратегий) — [Asterlike](https://github.com/Asterlike/zapret2UI)
- Идея SSH-меню — [Zapret-Manager](https://github.com/StressOzz/Zapret-Manager)

## Лицензия

MIT
