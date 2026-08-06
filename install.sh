#!/bin/sh
# z2m installer for OpenWrt.
#
# Запуск одной командой (busybox ash, работает и с wget, и с curl):
#   wget -O /tmp/z2m-install.sh https://raw.githubusercontent.com/OWNER/z2m/main/install.sh && sh /tmp/z2m-install.sh
#
# После установки менеджер запускается командой:  z2m
#
# Переменные окружения:
#   Z2M_REPO_OWNER  владелец репозитория (по умолчанию OWNER)
#   Z2M_REPO_NAME   имя репозитория (по умолчанию z2m)
#   Z2M_BRANCH      ветка (по умолчанию main)
#   Z2M_NO_LAUNCH=1 не запускать меню после установки

set -eu

OWNER="${Z2M_REPO_OWNER:-OWNER}"
REPO="${Z2M_REPO_NAME:-z2m}"
BRANCH="${Z2M_BRANCH:-main}"
BASE="https://raw.githubusercontent.com/$OWNER/$REPO/$BRANCH"

CFGDIR="/etc/z2m"
BIN="/usr/bin/z2m"
NO_LAUNCH="${Z2M_NO_LAUNCH:-0}"

for a in "$@"; do
	case "$a" in
		--no-launch) NO_LAUNCH=1 ;;
		--branch=*)  BRANCH="${a#--branch=}"; BASE="https://raw.githubusercontent.com/$OWNER/$REPO/$BRANCH" ;;
	esac
done

if [ -t 1 ] && [ -z "${Z2M_NOCOLOR:-}" ]; then
	C_G="\033[32m"; C_Y="\033[33m"; C_R="\033[31m"; C_B="\033[36m"; C_0="\033[0m"
else
	C_G=""; C_Y=""; C_R=""; C_B=""; C_0=""
fi
say()  { printf '%b\n' "$*"; }
info() { say "${C_B}[i]${C_0} $*"; }
ok()   { say "${C_G}[ok]${C_0} $*"; }
warn() { say "${C_Y}[!]${C_0} $*"; }
die()  { say "${C_R}[x]${C_0} $*" >&2; exit 1; }

say ""
say "  ${C_B}z2m${C_0} — Zapret2 Manager for OpenWrt"
say "  установщик"
say ""

[ "$(id -u)" = "0" ] || die "нужны права root"

# ---------- загрузчик ----------
if command -v curl >/dev/null 2>&1; then
	dl() { curl -fsSL -o "$1" "$2"; }
elif command -v wget >/dev/null 2>&1; then
	dl() { wget -q -O "$1" "$2"; }
else
	die "нет ни curl, ни wget — поставьте один из них: opkg install curl"
fi

# ---------- сам скрипт ----------
info "скачиваю z2m из $OWNER/$REPO ($BRANCH)"
dl /tmp/z2m.new "$BASE/z2m" || die "не смог скачать $BASE/z2m"
[ -s /tmp/z2m.new ] || die "скачался пустой файл"
head -n1 /tmp/z2m.new | grep -q '^#!/bin/sh' || die "это не тот файл (нет шебанга) — проверьте ссылку"
sh -n /tmp/z2m.new || die "синтаксическая ошибка в скачанном скрипте, установка отменена"

OLDVER=""
[ -x "$BIN" ] && OLDVER=$("$BIN" version 2>/dev/null | head -n1 || true)

mkdir -p "$CFGDIR/strategies" "$CFGDIR/lists" "$CFGDIR/backup"
mv /tmp/z2m.new "$BIN"
chmod 755 "$BIN"

NEWVER=$("$BIN" version 2>/dev/null | head -n1 || echo "z2m")
if [ -n "$OLDVER" ]; then
	ok "обновлено: $OLDVER -> $NEWVER"
else
	ok "установлено: $NEWVER -> $BIN"
fi

# ---------- пресеты и списки ----------
info "качаю пресеты стратегий"
SC=0
for s in z1-default z2-autottl z3-seqovl z4-youtube z5-http-fakedsplit z6-quic; do
	if dl "$CFGDIR/strategies/$s.conf.new" "$BASE/strategies/$s.conf" 2>/dev/null &&
	   [ -s "$CFGDIR/strategies/$s.conf.new" ]; then
		mv "$CFGDIR/strategies/$s.conf.new" "$CFGDIR/strategies/$s.conf"
		SC=$((SC+1))
	else
		rm -f "$CFGDIR/strategies/$s.conf.new"
	fi
done
if [ "$SC" -gt 0 ]; then
	ok "пресетов: $SC"
else
	warn "пресеты не скачались — z2m создаст встроенные при первом запуске"
fi

info "качаю наборы доменов"
LC=0
for l in youtube discord ai social torrent; do
	if dl "$CFGDIR/lists/$l.txt.new" "$BASE/lists/$l.txt" 2>/dev/null &&
	   [ -s "$CFGDIR/lists/$l.txt.new" ]; then
		mv "$CFGDIR/lists/$l.txt.new" "$CFGDIR/lists/$l.txt"
		LC=$((LC+1))
	else
		rm -f "$CFGDIR/lists/$l.txt.new"
	fi
done
[ "$LC" -gt 0 ] && ok "наборов доменов: $LC" || warn "наборы доменов не скачались (не критично)"

# ---------- итог ----------
say ""
ok "готово"
say "    Запуск менеджера:  ${C_B}z2m${C_0}"
say "    Справка:           ${C_B}z2m help${C_0}"
say "    Обновить себя:     ${C_B}z2m update-self${C_0}"
say ""

rm -f /tmp/z2m-install.sh 2>/dev/null || true

if [ "$NO_LAUNCH" != "1" ] && [ -t 0 ]; then
	printf 'Запустить менеджер сейчас? [Y/n]: '
	read -r ans || ans="n"
	case "$ans" in
		""|y|Y|д|Д) exec "$BIN" ;;
	esac
fi
