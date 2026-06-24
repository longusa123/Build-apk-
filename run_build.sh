#!/bin/bash

echo "=================================================="
echo "🚀 BẮT ĐẦU QUY TRÌNH BUILD APK TỰ ĐỘNG"
echo "=================================================="

echo "📁 1. Đang gom file ZIP và đẩy lên GitHub..."
git add .
git commit -m "Cập nhật file ZIP tự động" --allow-empty
git push origin main --force

echo "⚡ 2. Đang kích hoạt GitHub Actions..."
gh workflow run build.yml

echo "⏳ 3. Chờ Server GitHub khởi động (5 giây)..."
sleep 5

echo "📺 4. Đang treo máy theo dõi tiến trình build..."
echo "     (Khi nào chạy xong, script sẽ tự chạy tiếp bước sau)"
gh run watch

echo "📦 5. Build xong! Đang tự động tải APK về Termux..."
# Tải về và tự động giải nén file Artifacts ra luôn
gh run download --unzip

echo "=================================================="
echo "🎉 THÀNH CÔNG! File APK đã được đưa vào Termux."
echo "=================================================="
echo "Danh sách file APK đang có trong thư mục:"
find . -name "*.apk"
