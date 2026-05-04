#!/bin/sh
set -eu

# Путь к конфигу подстрой под свой репозиторий/форк
CFG="trunk/configs/templates/Keenetic_Lite_3.config"

# Если у тебя в build.config другой путь — замени тут
[ -f "$CFG" ] || { echo "ERROR: config not found: $CFG" >&2; exit 1; }

# Включаем полезные опции, если они закомментированы
sed -i \
  -e 's/^#\(CONFIG_FIRMWARE_INCLUDE_IPSET=y\)/\1/' \
  -e 's/^#\(CONFIG_FIRMWARE_INCLUDE_TCPDUMP=y\)/\1/' \
  -e 's/^#\(CONFIG_FIRMWARE_INCLUDE_DROPBEAR=y\)/\1/' \
  -e 's/^#\(CONFIG_FIRMWARE_INCLUDE_IPV6=y\)/\1/' \
  "$CFG"

# Если опции уже отсутствуют — добавим их
for opt in \
  CONFIG_FIRMWARE_INCLUDE_IPSET=y \
  CONFIG_FIRMWARE_INCLUDE_TCPDUMP=y \
  CONFIG_FIRMWARE_INCLUDE_DROPBEAR=y \
  CONFIG_FIRMWARE_INCLUDE_IPV6=y
do
  grep -q "^${opt}$" "$CFG" || echo "$opt" >> "$CFG"
done

# Проверяем наличие netfilter/iptables модулей в дереве исходников
need_files=""

check_glob() {
  pattern="$1"
  if ! find . -type f \( -name "$pattern" -o -path "*/$pattern" \) | grep -q .; then
    need_files="$need_files $pattern"
  fi
}

check_glob 'xt_NFQUEUE.ko'
check_glob 'xt_connbytes.ko'
check_glob 'xt_multiport.ko'

if [ -n "$need_files" ]; then
  echo "ERROR: required kernel modules not found in source tree:$need_files" >&2
  exit 1
fi

# Проверяем, что в конфиге есть строки для включения модулей,
# если они поддерживаются именно через kernel config/defconfig
required_cfgs="
CONFIG_NETFILTER_XT_MATCH_CONNBYTES
CONFIG_NETFILTER_XT_MATCH_MULTIPORT
CONFIG_NETFILTER_XT_TARGET_NFQUEUE
"

missing_cfgs=""
for c in $required_cfgs; do
  if ! grep -Rqs "^#\?$c[= ]" .; then
    missing_cfgs="$missing_cfgs $c"
  fi
done

if [ -n "$missing_cfgs" ]; then
  echo "ERROR: required config symbols not found in tree:$missing_cfgs" >&2
  exit 1
fi

# Пытаемся включить, если символы есть в конкретном config-файле
for c in $required_cfgs; do
  f=$(grep -Rsl "^#\?$c[= ]" . | head -n 1 || true)
  if [ -n "${f:-}" ]; then
    sed -i "s/^#\(${c}=y\)/\1/" "$f" || true
    grep -q "^${c}=y$" "$f" || echo "${c}=y" >> "$f"
  fi
done

echo "pre-build checks passed"

