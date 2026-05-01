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


