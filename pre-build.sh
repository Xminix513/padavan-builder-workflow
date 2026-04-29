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
