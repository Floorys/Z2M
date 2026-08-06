#!/bin/sh
# Установщик z2m на OpenWrt.
# Запуск:
#   wget -O /tmp/install.sh https://raw.githubusercontent.com/OWNER/z2m/main/install.sh
#   sh /tmp/install.sh
#
# Специально без "curl | sh": сначала скачайте, прочитайте, потом запускайте.

set -eu

OWNER="${Z2M_REPO_OWNER:-OWNER}"
REPO="${Z2M_REPO_NAME:-z2m}"
BRANCH="${Z2M_BRANCH:-main}"
BASE="https://raw.githubusercontent.com/$OWNER/$REPO/$BRANCH"

CFGDIR="/etc/z2m"
BIN="/usr/bin/z2m"

say() { printf '%s\n' "$*"; }
die() { printf '[x] %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = "0" ] || die "нужны права root"

if command -v curl >/dev/null 2>&1; then
	DL="curl -fsSL -o"
elif command -v wget >/dev/null 2>&1; then
	DL="wget -q -O"
else
	die "нет ни curl, ни wget"
fi

say "[i] скачиваю z2m"
$DL /tmp/z2m.new "$BASE/z2m" || die "не смог скачать $BASE/z2m"
head -n1 /tmp/z2m.new | grep -q '^#!/bin/sh' || die "скачался не тот файл"
sh -n /tmp/z2m.new || die "синтаксическая ошибка в скрипте"

mkdir -p "$CFGDIR/strategies" "$CFGDIR/lists" "$CFGDIR/backup"
mv /tmp/z2m.new "$BIN"
chmod +x "$BIN"

say "[i] качаю пресеты стратегий"
for s in z1-default z2-autottl z3-seqovl z4-youtube z5-http-fakedsplit z6-quic; do
	$DL "$CFGDIR/strategies/$s.conf" "$BASE/strategies/$s.conf" 2>/dev/null || true
done

say "[i] качаю наборы доменов"
for l in youtube discord ai social torrent; do
	$DL "$CFGDIR/lists/$l.txt" "$BASE/lists/$l.txt" 2>/dev/null || true
done

say ""
say "[ok] z2m установлен: $BIN"
say "     Запуск:  z2m"
say "     Справка: z2m help"
