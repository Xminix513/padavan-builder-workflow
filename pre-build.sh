#!/bin/sh
set -eu

echo "[pre-build] start"

# 1. Определяем конфиг устройства, который правим
# Если у тебя другой путь/имя — поменяй здесь
CFG="trunk/configs/templates/Keenetic_Lite_3.config"

if [ ! -f "$CFG" ]; then
    echo "ERROR: device config not found: $CFG" >&2
    exit 1
fi

echo "[pre-build] using device config: $CFG"

# 2. Гарантируем включение нужных опций из build.config
NEEDED_FW_OPTS="
CONFIG_FIRMWARE_INCLUDE_IPSET=y
CONFIG_FIRMWARE_INCLUDE_TCPDUMP=y
CONFIG_FIRMWARE_INCLUDE_DROPBEAR=y
CONFIG_FIRMWARE_INCLUDE_DROPBEAR_FAST_CODE=y
CONFIG_FIRMWARE_INCLUDE_OPENSSL_EXE=y
CONFIG_FIRMWARE_INCLUDE_DDNS_SSL=y
CONFIG_FIRMWARE_INCLUDE_HTTPS=y
CONFIG_FIRMWARE_INCLUDE_CURL=y
CONFIG_FIRMWARE_INCLUDE_STUBBY=y
CONFIG_FIRMWARE_INCLUDE_DOH=y
CONFIG_FIRMWARE_ENABLE_IPV6=y
CONFIG_FIRMWARE_INCLUDE_LANG_RU=y
"

for opt in $NEEDED_FW_OPTS; do
    key="${opt%=*}"
    # Если строка закомментирована — раскомментируем
    sed -i "s/^#\(${opt}\)/\1/" "$CFG" || true
    # Если всё равно нет — добавим
    if ! grep -q "^$key=" "$CFG"; then
        echo "$opt" >> "$CFG"
        echo "[pre-build] added $opt to $CFG"
    else
        # Если есть, но с другим значением — принудительно выставим нужное
        sed -i "s/^${key}=.*/${opt}/" "$CFG"
        echo "[pre-build] forced $opt in $CFG"
    fi
done

# 3. Проверка наличия модулей xt_NFQUEUE, xt_connbytes, xt_multiport в дереве
MISSING_FILES=""

check_mod_file() {
    pattern="$1"
    if ! find . -type f -name "$pattern" | grep -q . 2>/dev/null; then
        MISSING_FILES="$MISSING_FILES $pattern"
    fi
}

echo "[pre-build] checking for netfilter modules in source tree..."
check_mod_file "xt_NFQUEUE.c"
check_mod_file "xt_connbytes.c"
check_mod_file "xt_multiport.c"

if [ -n "$MISSING_FILES" ]; then
    echo "ERROR: required netfilter sources not found: $MISSING_FILES" >&2
    echo "nfqws2-keenetic will very likely not work without these." >&2
    exit 1
fi

# 4. Проверка наличия символов в kconfig/defconfig
REQ_CFG_SYMS="
CONFIG_NETFILTER_XT_MATCH_CONNBYTES
CONFIG_NETFILTER_XT_MATCH_MULTIPORT
CONFIG_NETFILTER_XT_TARGET_NFQUEUE
"

echo "[pre-build] checking for config symbols..."
MISSING_SYMS=""

for sym in $REQ_CFG_SYMS; do
    if ! grep -Rqs "^$sym[= ]" trunk linux-3* 2>/dev/null; then
        MISSING_SYMS="$MISSING_SYMS $sym"
    fi
done

if [ -n "$MISSING_SYMS" ]; then
    echo "ERROR: required netfilter config symbols not found:$MISSING_SYMS" >&2
    echo "You need to add them to kernel config/patches for full nfqws2-keenetic support." >&2
    exit 1
fi

# 5. Попытка включить эти символы в дефолтном конфиге ядра (если присутствуют)
echo "[pre-build] trying to enable netfilter symbols..."

for sym in $REQ_CFG_SYMS; do
    # ищем первый файл, где упоминается этот символ
    CONF_FILE=$(grep -Rsl "^$sym[= ]" trunk linux-3* 2>/dev/null | head -n 1 || true)
    [ -z "${CONF_FILE:-}" ] && continue

    # Если строка закомментирована как # CONFIG_... is not set — включаем
    sed -i "s/^# $sym is not set\$/${sym}=y/" "$CONF_FILE" || true
    # Если есть другая строка — заменим на =y
    if grep -q "^$sym=" "$CONF_FILE"; then
        sed -i "s/^${sym}=.*/${sym}=y/" "$CONF_FILE"
    else
        echo "${sym}=y" >> "$CONF_FILE"
    fi
    echo "[pre-build] enabled ${sym}=y in $CONF_FILE"
done

echo "[pre-build] done"
