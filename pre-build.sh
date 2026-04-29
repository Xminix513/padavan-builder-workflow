#!/bin/sh
echo "🔧 Применяем фикс LAN/WAN для MT7621 (Xiaomi Mi3 SPI)..."

# Находим все заголовочные файлы плат XIAOMI
find . -path "*/configs/boards/XIAOMI/*" -name "*.h" -type f | while read -r file; do
    # Меняем WAN порт на 3 (синий разъём)
    sed -i 's/\(#define[[:space:]]*BOARD_WAN_PORT[[:space:]]*\)[0-9].*/\13/' "$file"
    # Меняем LAN порты на 0,1,2 (три оставшихся разъёма)
    sed -i 's/\(#define[[:space:]]*BOARD_LAN_PORTS[[:space:]]*\)[0-9,].*/\10,1,2/' "$file"
    echo "✅ Исправлено: $file"
done

echo "🎉 Готово! WAN=3, LAN=0,1,2. Запускаю сборку..."
