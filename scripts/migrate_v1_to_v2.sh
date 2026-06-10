#!/bin/bash
# v1.4.0 -> v2.0.0 数据迁移脚本
set -e

BACKUP_DIR="$HOME/Library/Application Support/HearthstoneTracker/v1-backup-$(date +%Y%m%d)"
SOURCE_DIR="$HOME/Library/Application Support/HearthstoneTracker"

echo "📦 备份 v1.4.0 数据到 $BACKUP_DIR ..."
mkdir -p "$BACKUP_DIR"

if [ -f "$SOURCE_DIR/cards.json" ]; then
    cp "$SOURCE_DIR/cards.json" "$BACKUP_DIR/"
    echo "  ✅ cards.json"
fi

find "$SOURCE_DIR" -name "*.store" -o -name "*.sqlite" 2>/dev/null | while read f; do
    cp "$f" "$BACKUP_DIR/"
    echo "  ✅ $(basename "$f")"
done

echo ""
echo "✅ 备份完成！文件保存在: $BACKUP_DIR"
echo "   恢复命令: cp -R $BACKUP_DIR/* $SOURCE_DIR/"
