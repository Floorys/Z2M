#!/bin/sh
# Установщик Zapret2 Manager (OpenWrt)
# Запуск из распакованной папки:  sh install.sh
set -e
SRC=$(cd "$(dirname "$0")" && pwd)
D=/opt/z2m

echo "[*] проверка окружения"
[ -x /opt/zapret2/nfq2/nfqws2 ] || echo "[!] /opt/zapret2/nfq2/nfqws2 не найден - сначала установи zapret2"
command -v curl >/dev/null || echo "[!] нет curl - проверки сайтов не будут работать (opkg install curl)"

echo "[*] установка в $D"
mkdir -p $D/lib $D/strategies
cp -f "$SRC/lib/port.awk" $D/lib/port.awk
for f in "$SRC"/strategies/*.txt; do
  b=$(basename "$f")
  [ -f "$D/strategies/$b" ] || cp -f "$f" "$D/strategies/$b"
done
cp -f "$SRC/z2m" /usr/bin/z2m
chmod +x /usr/bin/z2m

echo "[*] бэкап текущего конфига -> /root/z2m.bak"
uci export zapret2 > /root/z2m.bak 2>/dev/null || true

echo
echo "Готово. Запуск: z2m"
