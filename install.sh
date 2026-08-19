#!/bin/sh
# Zapret2 Manager - установщик для OpenWrt
#
# Сетевая установка одной командой:
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/YOURNICK/zapret2-manager/main/install.sh)"
#   sh -c "$(wget -qO- https://raw.githubusercontent.com/YOURNICK/zapret2-manager/main/install.sh)"
#
# Локально из распакованной папки:  sh install.sh
# Свой репозиторий/ветка:            Z2M_REPO=nick/repo Z2M_BRANCH=dev sh install.sh

REPO="${Z2M_REPO:-YOURNICK/zapret2-manager}"
BRANCH="${Z2M_BRANCH:-main}"
RAW="https://raw.githubusercontent.com/$REPO/$BRANCH"
D=/opt/z2m
SRC=$(cd "$(dirname "$0")" 2>/dev/null && pwd)

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; N='\033[0m'
say(){ printf "%b\n" "$1"; }

# ---------- загрузчик ----------
if command -v curl >/dev/null 2>&1; then DLT=curl
elif command -v wget >/dev/null 2>&1; then DLT=wget
elif command -v uclient-fetch >/dev/null 2>&1; then DLT=uclient
else DLT=""; fi

dl(){ # $1 url  $2 куда
  case "$DLT" in
    curl)    curl -fsSL "$1" -o "$2" 2>/dev/null;;
    wget)    wget -q -O "$2" "$1" 2>/dev/null;;
    uclient) uclient-fetch -q -O "$2" "$1" 2>/dev/null;;
    *) return 1;;
  esac }

fix_tls(){ # на чистом OpenWrt часто нет CA-сертификатов
  say "${Y}[!] не скачалось, ставлю ca-bundle${N}"
  if command -v opkg >/dev/null 2>&1; then opkg update >/dev/null 2>&1; opkg install ca-bundle ca-certificates >/dev/null 2>&1
  elif command -v apk >/dev/null 2>&1; then apk update >/dev/null 2>&1; apk add ca-bundle ca-certificates >/dev/null 2>&1; fi }

# ---------- проверки ----------
say "${C}[*] проверка окружения${N}"
[ -x /opt/zapret2/nfq2/nfqws2 ] || say "${Y}[!] /opt/zapret2/nfq2/nfqws2 не найден - сначала установи zapret2${N}"
uci -q get zapret2.main >/dev/null 2>&1 || say "${Y}[!] нет UCI-конфига zapret2${N}"
command -v curl >/dev/null 2>&1 || say "${Y}[!] нет curl - автопроверки сайтов в меню не будут работать (opkg install curl)${N}"

mkdir -p $D/lib $D/strategies

if [ "$1" != "--remote" ] && [ -f "$SRC/lib/port.awk" ] && [ -f "$SRC/z2m" ]; then
  # ---------- локальный режим ----------
  say "${C}[*] локальная установка из $SRC${N}"
  cp -f "$SRC/lib/port.awk" $D/lib/port.awk
  for f in "$SRC"/strategies/*.txt; do [ -f "$f" ] && cp -f "$f" "$D/strategies/$(basename "$f")"; done
  cp -f "$SRC/z2m" /usr/bin/z2m
else
  # ---------- сетевой режим ----------
  [ -n "$DLT" ] || { say "${R}[x] нет ни curl, ни wget${N}"; exit 1; }
  say "${C}[*] загрузка из $REPO ($BRANCH), через $DLT${N}"
  dl "$RAW/manifest.txt" /tmp/z2m.manifest || { fix_tls; dl "$RAW/manifest.txt" /tmp/z2m.manifest; }
  [ -s /tmp/z2m.manifest ] || { say "${R}[x] не скачался manifest.txt из $RAW${N}"; exit 1; }
  while read -r f; do
    [ -z "$f" ] && continue
    case "$f" in \#*) continue;; esac
    case "$f" in z2m) out=/usr/bin/z2m;; *) out="$D/$f";; esac
    mkdir -p "$(dirname "$out")"
    printf "    %-34s " "$f"
    if dl "$RAW/$f" "$out.new" && [ -s "$out.new" ]; then mv -f "$out.new" "$out"; say "${G}ok${N}"
    else rm -f "$out.new"; say "${R}ошибка${N}"; fi
  done < /tmp/z2m.manifest
  [ -s /usr/bin/z2m ] || { say "${R}[x] главный файл не скачался${N}"; exit 1; }
  sed -i "s|^Z2M_REPO=.*|Z2M_REPO=\"\${Z2M_REPO:-$REPO}\"|" /usr/bin/z2m 2>/dev/null
fi

chmod +x /usr/bin/z2m
sed -i 's/\r$//' /usr/bin/z2m $D/lib/port.awk 2>/dev/null

say "${C}[*] бэкап текущего конфига -> /root/z2m.bak${N}"
uci export zapret2 > /root/z2m.bak 2>/dev/null

say ""
say "${G}Готово.${N} Запуск: ${C}z2m${N}   Обновление: ${C}z2m update${N}"
