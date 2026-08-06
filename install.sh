#!/bin/sh
# z2m installer for OpenWrt.
#
# Запуск одной командой (busybox ash, работает и с wget, и с curl):
#   wget -O /tmp/z2m-install.sh https://raw.githubusercontent.com/FunnyDragon2010/Z2M/main/install.sh && sh /tmp/z2m-install.sh
#
# После установки менеджер запускается командой:  z2m
#
# Переменные окружения:
#   Z2M_REPO_OWNER   владелец репозитория
#   Z2M_REPO_NAME    имя репозитория
#   Z2M_BRANCH       ветка (по умолчанию main)
#   Z2M_NO_LAUNCH=1  не запускать меню после установки

set -eu

OWNER="${Z2M_REPO_OWNER:-FunnyDragon2010}"
REPO="${Z2M_REPO_NAME:-Z2M}"
BRANCH="${Z2M_BRANCH:-main}"

CFGDIR="/etc/z2m"
BIN="/usr/bin/z2m"
NO_LAUNCH="${Z2M_NO_LAUNCH:-0}"

for a in "$@"; do
	case "$a" in
		--no-launch) NO_LAUNCH=1 ;;
		--branch=*)  BRANCH="${a#--branch=}" ;;
		--owner=*)   OWNER="${a#--owner=}" ;;
		--repo=*)    REPO="${a#--repo=}" ;;
	esac
done

BASE="https://raw.githubusercontent.com/$OWNER/$REPO/$BRANCH"
API="https://api.github.com/repos/$OWNER/$REPO/contents"

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
say "  установщик  ($OWNER/$REPO, ветка $BRANCH)"
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

# Список файлов подкаталога берём через GitHub API, чтобы новые наборы
# и пресеты подхватывались автоматически, без правки установщика.
fetch_index() {
	_dir="$1"; _ext="$2"; _json="/tmp/z2m-idx.json"
	rm -f "$_json"
	if dl "$_json" "$API/$_dir?ref=$BRANCH" 2>/dev/null && [ -s "$_json" ]; then
		tr ',' '\n' <"$_json" \
			| grep -o "\"name\"[[:space:]]*:[[:space:]]*\"[^\"]*$_ext\"" \
			| sed 's/.*"\([^"]*\)"$/\1/' \
			| sort -u || true
	fi
	rm -f "$_json"
}

# ---------- сам скрипт ----------
info "скачиваю z2m"
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

# ---------- пресеты стратегий ----------
STRATS=$(fetch_index strategies '\.conf' || true)
[ -n "$STRATS" ] || STRATS="z1-default.conf z2-autottl.conf z3-seqovl.conf z4-youtube.conf z5-http-fakedsplit.conf z6-quic.conf"

info "качаю пресеты стратегий"
SC=0
for s in $STRATS; do
	if dl "$CFGDIR/strategies/$s.new" "$BASE/strategies/$s" 2>/dev/null && [ -s "$CFGDIR/strategies/$s.new" ]; then
		mv "$CFGDIR/strategies/$s.new" "$CFGDIR/strategies/$s"
		SC=$((SC+1))
	else
		rm -f "$CFGDIR/strategies/$s.new"
	fi
done
if [ "$SC" -gt 0 ]; then
	ok "пресетов: $SC"
else
	warn "пресеты не скачались — z2m создаст встроенные при первом запуске"
fi

# ---------- наборы доменов ----------
LISTS=$(fetch_index lists '\.txt' || true)
[ -n "$LISTS" ] || LISTS="google.txt discord.txt ai.txt social.txt torrent.txt zapret-hosts-user-exclude.txt"

info "качаю наборы доменов"
LC=0
for l in $LISTS; do
	if dl "$CFGDIR/lists/$l.new" "$BASE/lists/$l" 2>/dev/null && [ -s "$CFGDIR/lists/$l.new" ]; then
		mv "$CFGDIR/lists/$l.new" "$CFGDIR/lists/$l"
		LC=$((LC+1))
	else
		rm -f "$CFGDIR/lists/$l.new"
	fi
done
if [ "$LC" -gt 0 ]; then
	ok "наборов доменов: $LC"
else
	warn "наборы доменов не скачались (не критично)"
fi

# ---------- итог ----------
say ""
ok "готово"
say "    Запуск менеджера:   ${C_B}z2m${C_0}"
say "    Справка:            ${C_B}z2m help${C_0}"
say "    Наборы доменов:    ${C_B}z2m list bundle${C_0}"
say "    Исключения сразу:  ${C_B}z2m list sync-exclude${C_0}"
say ""

rm -f /tmp/z2m-install.sh 2>/dev/null || true

if [ "$NO_LAUNCH" != "1" ] && [ -t 0 ]; then
	printf 'Запустить менеджер сейчас? [Y/n]: '
	read -r ans || ans="n"
	case "$ans" in
		""|y|Y|д|Д) exec "$BIN" ;;
	esac
fi
