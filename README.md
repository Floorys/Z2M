# z2m — Zapret2 Manager for OpenWrt

Интерактивный SSH-менеджер для пакетов **zapret2** из
[remittor/zapret-openwrt](https://github.com/remittor/zapret-openwrt)
(апстрим — [bol-van/zapret2](https://github.com/bol-van/zapret2)).

Один POSIX-`sh` файл без зависимостей, работает на busybox ash.

> zapret2 — это не VPN, а anti-DPI утилита. Она не шифрует трафик и не меняет IP.

## Запуск менеджера

Подключитесь по **SSH** к роутеру и выполните команду:

```
wget -O /tmp/z2m-install.sh https://raw.githubusercontent.com/FunnyDragon2010/Z2M/main/install.sh && sh /tmp/z2m-install.sh
```

или, если в системе есть curl:

```
curl -fsSL -o /tmp/z2m-install.sh https://raw.githubusercontent.com/FunnyDragon2010/Z2M/main/install.sh && sh /tmp/z2m-install.sh
```

После установки менеджер запускается в SSH командой:

```
z2m
```

Установщик не использует `curl | sh`: скрипт сначала ложится в `/tmp`, его
можно прочитать (`less /tmp/z2m-install.sh`) и только потом запустить. Скачанный
`z2m` проверяется на шебанг и `sh -n` до того, как попасть в `/usr/bin`.

Обновление самого менеджера потом — одной командой `z2m update-self`.

<details>
<summary>Альтернативные способы</summary>

Без установщика, одним файлом:

```
wget -O /tmp/z2m https://raw.githubusercontent.com/FunnyDragon2010/Z2M/main/z2m
sh /tmp/z2m install-self
```

Из клона репозитория (подхватит пресеты и списки из соседних папок):

```
cd /tmp && git clone https://github.com/FunnyDragon2010/Z2M && sh Z2M/z2m install-self
```

Без интернета на роутере: скопируйте файл `z2m` через scp в `/tmp` и
выполните `sh /tmp/z2m install-self`.

Установка без вопросов (для своих скриптов) и из другой ветки:

```
Z2M_NO_LAUNCH=1 sh /tmp/z2m-install.sh
sh /tmp/z2m-install.sh --branch=dev
```

</details>

## Что умеет

- Установка, обновление и откат на любую версию релиза
- Автоопределение архитектуры и пакетного менеджера: **opkg (ipk) и apk (OpenWrt 25+)**
- Проверка работоспособности бинарника сразу после установки
- Пресеты стратегий под nfqws2 (`--lua-desync`), а не старые `--dpi-desync`
- Автоподбор стратегии по списку доменов и обёртка над `blockcheck2.sh`
- Списки доменов: hostlist, hostlist-exclude и готовые наборы из `lists/`
- Бэкап и восстановление конфига перед каждым изменением
- Диагностика `z2m doctor`: конфликты, flow offloading, DNS, QUIC, правила firewall
- Полноценный неинтерактивный режим — годится для cron и своих скриптов

## Требования

- OpenWrt 21.02+ (основной сценарий — 23.05 / 24.10 с nftables; OpenWrt 25+ с apk тоже поддерживается)
- ~5 МБ свободного места на overlay
- `curl` и `unzip` — ставятся автоматически, если их нет

## Меню

Запустите `z2m` без аргументов — откроется меню из пяти пунктов:

```
  Z2M  zapret2 для OpenWrt · v0.3.0
  netis NX31 · OpenWrt 24.10.4 · aarch64_cortex-a53

  *  обход блокировок работает  · способ: z1-default

   1) Быстрая настройка — сделать всё за один раз
   2) Способ обхода
   3) Сайты и исключения
   4) Проверка и управление
   5) Дополнительно
   0) Выход
```

Новичку достаточно пункта 1: он ставит zapret2, заливает исключения,
подбирает рабочий способ обхода и включает автозапуск. То же самое из
командной строки: `z2m setup`.

## Как ищется релиз

Имена файлов в релизах remittor предсказуемы:
`zapret2_<тег>_<архитектура>.zip`. Поэтому z2m не тянет через API весь
список релизов (это мегабайты JSON и быстрый упор в лимит GitHub), а:

1. берёт список тегов — `releases.atom`, если молчит, то страница `/tags`, затем API;
2. собирает ссылку на zip и проверяет её HEAD-запросом;
3. если точной сборки нет, пробует `aarch64_generic` и три предыдущих релиза;
4. если GitHub недоступен вообще — берёт запасной тег `Z2M_FALLBACK_TAG`
   и предлагает вставить ссылку вручную.

Можно сразу назвать версию или дать прямую ссылку:

```
z2m install v0.9.20260307
z2m install https://github.com/remittor/zapret-openwrt/releases/download/v0.9.20260307/zapret2_v0.9.20260307_aarch64_cortex-a53.zip
```

## Быстрый старт

```
z2m setup                # мастер: установка + исключения + подбор стратегии
z2m install              # свежий релиз zapret2 под свою архитектуру
z2m list sync-exclude    # залить исключения в hostlist-exclude
z2m list bundle google   # добавить набор доменов в hostlist
z2m strategy             # список пресетов
z2m test                 # автоподбор по списку доменов
z2m doctor               # что не так
```

## Списки доменов

В папке `lists/` лежат готовые наборы. Установщик кладёт их в `/etc/z2m/lists/`
и подхватывает любые новые `.txt` автоматически — его не надо править
при добавлении файла в репозиторий.

Файлы со словом `exclude` в имени (например `zapret-hosts-user-exclude.txt`)
считаются **исключениями** и льются в `hostlist-exclude`, остальные — в `hostlist`.

```
z2m list bundle                    # список наборов и куда каждый пойдёт
z2m list bundle google             # по имени
z2m list bundle 2                  # по номеру из списка
z2m list bundle mylist exclude     # принудительно в исключения
z2m list sync-exclude              # залить все exclude-наборы сразу
```

Зачем нужен exclude: всё, что туда попало, проходит мимо дурения. Это спасает
банки, госуслуги, античиты и лаунчеры от случайных разрывов, особенно в
режиме "дурить всё подряд" без hostlist.

## Команды

| Команда | Что делает |
| --- | --- |
| `z2m` | интерактивное меню |
| `z2m setup` | мастер быстрой настройки |
| `z2m install` | установить / обновить zapret2 |
| `z2m install <тег\|url>` | конкретная версия, напр. `v0.9.20260307` |
| `z2m pick` | выбрать конкретную версию релиза |
| `z2m local [zip]` | установить из локального архива |
| `z2m uninstall` | удалить zapret2 |
| `z2m strategy [id]` | список или применение пресета |
| `z2m strategy save <имя>` | сохранить текущую стратегию как пресет |
| `z2m test` | прогнать все пресеты по доменам |
| `z2m blockcheck` | штатный blockcheck2.sh с сохранением лога |
| `z2m list add домен` | добавить домен в hostlist |
| `z2m list exclude add домен` | добавить домен в исключения |
| `z2m list bundle [имя]` | наборы доменов |
| `z2m list sync-exclude` | залить все exclude-наборы |
| `z2m status` / `z2m doctor` | состояние и диагностика |
| `z2m quic on\|off` | временно заблокировать UDP/443 |
| `z2m backup` / `z2m restore` | бэкап и откат конфига |
| `z2m update-self` | обновить сам менеджер |

Полный список: `z2m help`.

## Важно перед стартом

1. **zapret v1 и zapret2 одновременно не работают** — оба вешаются на nfqueue.
   Достаточно `/etc/init.d/zapret stop && /etc/init.d/zapret disable`, удалять не обязательно.
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
lists/*.txt              наборы доменов (exclude в имени = исключения)
docs/STRATEGIES.md       синтаксис и разбор пресетов
docs/TROUBLESHOOTING.md  частые проблемы
docs/COMPAT.md           таблица протестированных устройств
```

## Форк и свой репозиторий

Подмените источник без правки кода:

```
Z2M_REPO_OWNER=вашник Z2M_REPO_NAME=Z2M sh /tmp/z2m-install.sh
Z2M_SELF_REPO=вашник/Z2M z2m update-self
```

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
