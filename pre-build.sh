#!/bin/sh

# 1. Гарантируем включение нужных опций в конфиге устройства
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
    # раскомментируем, если есть закомментированная строка
    sed -i "s/^#\(${opt}\)/\1/" "$CFG" || true
    if ! grep -q "^$key=" "$CFG"; then
        echo "$opt" >> "$CFG"
        echo "[pre-build] added $opt to $CFG"
    else
        sed -i "s/^${key}=.*/${opt}/" "$CFG"
        echo "[pre-build] forced $opt in $CFG"
    fi
done

# 2. Проверка наличия модулей xt_NFQUEUE, xt_connbytes, xt_multiport в исходниках
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
    echo "ERROR: required netfilter sources not found:$MISSING_FILES" >&2
    echo "nfqws2-keenetic will very likely not work without these." >&2
    exit 1
fi

# 3. Проверка наличия нужных Kconfig-символов
REQ_CFG_SYMS="
CONFIG_NETFILTER_XT_MATCH_CONNBYTES
CONFIG_NETFILTER_XT_MATCH_MULTIPORT
CONFIG_NETFILTER_XT_TARGET_NFQUEUE
"

echo "[pre-build] checking for config symbols in kernel tree..."
MISSING_SYMS=""

for sym in $REQ_CFG_SYMS; do
    if ! grep -Rqs "^$sym[= ]" linux-3* trunk 2>/dev/null; then
        MISSING_SYMS="$MISSING_SYMS $sym"
    fi
done

if [ -n "$MISSING_SYMS" ]; then
    echo "ERROR: required netfilter config symbols not found:$MISSING_SYMS" >&2
    echo "You need to add them to kernel config/patches for full nfqws2-keenetic support." >&2
    exit 1
fi

# 4. Пытаемся включить эти символы в первом попавшемся конфиге ядра
echo "[pre-build] trying to enable netfilter symbols..."

for sym in $REQ_CFG_SYMS; do
    CONF_FILE=$(grep -Rsl "^$sym[= ]" linux-3* trunk 2>/dev/null | head -n 1 || true)
    [ -z "${CONF_FILE:-}" ] && continue

    # # CONFIG_... is not set -> включаем
    sed -i "s/^# $sym is not set\$/${sym}=y/" "$CONF_FILE" || true

    if grep -q "^${sym}=" "$CONF_FILE"; then
        sed -i "s/^${sym}=.*/${sym}=y/" "$CONF_FILE"
    else
        echo "${sym}=y" >> "$CONF_FILE"
    fi
    echo "[pre-build] enabled ${sym}=y in $CONF_FILE"
done

echo "[pre-build] done"
