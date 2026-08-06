# z2m — Zapret2 Manager for OpenWrt

Интерактивный SSH-менеджер для пакетов **zapret2** из
[remittor/zapret-openwrt](https://github.com/remittor/zapret-openwrt)
(апстрим — [bol-van/zapret2](https://github.com/bol-van/zapret2)).

Один POSIX-`sh` файл без зависимостей, работает на busybox ash.

> zapret2 — это не VPN, а anti-DPI утилита. Она не шифрует трафик и не меняет IP.

## Запуск менеджера

Подключитесь по **SSH** к роутеру и выполните команду:

```
wget -O /tmp/z2m-install.sh https://raw.githubusercontent.com/OWNER/z2m/main/install.sh && sh /tmp/z2m-install.sh
```

или, если в системе есть curl:

```
curl -fsSL -o /tmp/z2m-install.sh https://raw.githubusercontent.com/OWNER/z2m/main/install.sh && sh /tmp/z2m-install.sh
```

После установки менеджер запускается в SSH командой:

```
z2m
```

Установщик не использует `curl | sh`: скрипт сначала ложится в `/tmp`, его
можно прочитать (`less /tmp/z2m-install.sh`) и только потом запустить. Скачанный
`z2m` проверяется на шебанг и `sh -n` до того, как попасть в `/usr/bin`.

<details>
<summary>Альтернативные способы</summary>

Без установщика, одним файлом:

```
wget -O /tmp/z2m https://raw.githubusercontent.com/OWNER/z2m/main/z2m
sh /tmp/z2m install-self
```

Из клона репозитория (подхватит пресеты и списки из соседних папок):

```
cd /tmp && git clone https://github.com/OWNER/z2m && sh z2m/z2m install-self
```

Без интернета на роутере: скопируйте файл `z2m` через scp в `/tmp` и
выполните `sh /tmp/z2m install-self`.

Установка без вопросов (для своих скриптов):

```
Z2M_NO_LAUNCH=1 sh /tmp/z2m-install.sh
```

</details>

## Что умеет

- Установка, обновление и откат на любую версию релиза
- Автоопределение архитектуры и пакетного менеджера: **opkg (ipk) и apk (OpenWrt 25+)**
- Проверка работоспособности бинарника сразу после установки
- Пресеты стратегий под nfqws2 (`--lua-desync`), а не старые `--dpi-desync`
- Автоподбор стратегии по списку доменов и обёртка над `blockcheck2.sh`
- Работа с hostlist / hostlist-exclude и готовыми наборами доменов
- Бэкап и восстановление конфига перед каждым изменением
- Диагностика `z2m doctor`: конфликты, flow offloading, DNS, QUIC, правила firewall
- Полноценный неинтерактивный режим — годится для cron и своих скриптов

## Требования

- OpenWrt 21.02+ (основной сценарий — 23.05 / 24.10 с nftables; OpenWrt 25+ с apk тоже поддерживается)
- ~5 МБ свободного места на overlay
- `curl` и `unzip` — ставятся автоматически, если их нет

## Быстрый старт

```
z2m install            # последний релиз zapret2 под свою архитектуру
z2m strategy           # список пресетов
z2m strategy z1-default
z2m test               # автоподбор по списку доменов
z2m doctor             # что не так
```

## Команды

| Команда | Что делает |
| --- | --- |
| `z2m` | интерактивное меню |
| `z2m install [url]` | установить / обновить zapret2 |
| `z2m pick` | выбрать конкретную версию релиза |
| `z2m local [zip]` | установить из локального архива |
| `z2m uninstall` | удалить zapret2 |
| `z2m strategy [id]` | список или применение пресета |
| `z2m strategy save <имя>` | сохранить текущую стратегию как пресет |
| `z2m test` | прогнать все пресеты по доменам |
| `z2m blockcheck` | штатный blockcheck2.sh с сохранением лога |
| `z2m list add домен` | добавить домен в hostlist |
| `z2m list bundle youtube` | добавить готовый набор |
| `z2m status` / `z2m doctor` | состояние и диагностика |
| `z2m quic on\|off` | временно заблокировать UDP/443 |
| `z2m backup` / `z2m restore` | бэкап и откат конфига |
| `z2m update-self` | обновить сам менеджер |

Полный список: `z2m help`.

## Важно перед стартом

1. **zapret v1 и zapret2 одновременно не работают** — оба вешаются на nfqueue.
2. **Flow offloading** уводит трафик мимо nfqueue — выключите его.
3. **Без DoH/DoT** часть блокировок не обходится в принципе.
4. На части сборок `nfqws2` падает — менеджер это ловит и предлагает другую версию.

## Стратегии

Стратегии zapret1 (v1–v9, Flowseal) **не совместимы** с nfqws2.
Здесь свой набор — см. `docs/STRATEGIES.md`.

Пресеты лежат в `/etc/z2m/strategies/*.conf`, обычные текстовые файлы — добавляйте
свои без правки скрипта.

## Структура репозитория

```
z2m                      главный скрипт (ставится в /usr/bin/z2m)
install.sh               однокомандный установщик
strategies/*.conf        пресеты стратегий nfqws2
lists/*.txt              наборы доменов
docs/STRATEGIES.md       синтаксис и разбор пресетов
docs/TROUBLESHOOTING.md  частые проблемы
docs/COMPAT.md           таблица протестированных устройств
```

## Что заменить перед публикацией форка

1. `OWNER` в этом README и в `install.sh` — на свой ник GitHub.
2. `Z2M_SELF_REPO` в начале файла `z2m` — чтобы работало `z2m update-self`.

## Что стоит проверить на своём железе

Имена UCI-опций в `/etc/config/zapret2` у пакета remittor могут меняться между
версиями. Менеджер находит нужную секцию динамически через `uci show`, но если
`z2m doctor` пишет "конфиг не найден" — пришлите вывод `uci show zapret2`.

## Благодарности

- `zapret2` — [bol-van](https://github.com/bol-van)
- OpenWrt-пакеты — [remittor](https://github.com/remittor)
- идея интерфейса — [Zapret-Manager](https://github.com/StressOzz/Zapret-Manager)

## Лицензия

MIT
