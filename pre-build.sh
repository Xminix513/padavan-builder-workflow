#!/bin/sh
echo "🔧 Фикс портов для MT7620A (Xiaomi Mi3)..."

find . -path "*/configs/boards/XIAOMI/*" -name "*.h" -type f | while read -r file; do
    # WAN = порт 4, LAN = 0,1,2,3
    sed -i 's/\(#define[[:space:]]*BOARD_WAN_PORT[[:space:]]*\)[0-9].*/\14/' "$file"
    sed -i 's/\(#define[[:space:]]*BOARD_LAN_PORTS[[:space:]]*\)[0-9,].*/\10,1,2,3/' "$file"
    
    # Если используются битовые маски:
    sed -i 's/\(#define[[:space:]]*BOARD_WAN_PORT_MASK[[:space:]]*\)0x[0-9A-F].*/\10x10/' "$file"   # 0x10 = порт 4
    sed -i 's/\(#define[[:space:]]*BOARD_LAN_PORT_MASK[[:space:]]*\)0x[0-9A-F].*/\10x0F/' "$file"   # 0x0F = порты 0-3
    
    echo "✅ Исправлено: $file"
done
echo "🎉 Готово! WAN=4, LAN=0,1,2,3"

# Настройка версии прошивки
sed -i 's/^FIRMWARE_ROOTFS_VER.*/FIRMWARE_ROOTFS_VER=3.9L/' padavan-ng/trunk/versions.inc
sed -i 's/^FIRMWARE_BUILDS_VER.*/FIRMWARE_BUILDS_VER=102/' padavan-ng/trunk/versions.inc

# Установка последней версии zapret
ZAPRET_REPO="https://github.com/bol-van/zapret.git"
ZAPRET_TAGS=$(git ls-remote --tags "$ZAPRET_REPO" | awk '{print $2}' | sed 's/refs\/tags\///g')
ZAPRET_VER=$(echo "$ZAPRET_TAGS" | sort -V | tail -n 1 | sed 's/^.//')
sed -i "s/^SRC_VER.*/SRC_VER = $ZAPRET_VER/g" padavan-ng/trunk/user/nfqws/Makefile
cd padavan-ng/trunk/user/nfqws
curl -o patches/firmware-specific.patch https://raw.githubusercontent.com/EdvardBill/npzp/refs/heads/main/firmware-specific.patch
find . -maxdepth 1 -not -name Makefile -not -name patches -print0 | xargs -0 rm -rf --


