#!/usr/bin/env bash
# Membuat commit kecil lalu push ke GitHub untuk memicu webhook Jenkins.
#   bash scripts/uji-webhook.sh
#   bash scripts/uji-webhook.sh "feat: ubah judul halaman"
PESAN="${1:-test: trigger GitHub webhook}"
WAKTU=$(date '+%Y-%m-%d %H:%M:%S')
echo "Webhook test $WAKTU" >> docs/webhook-log.txt
echo -e "\033[0;90m\$ git add docs/webhook-log.txt && git commit -m \"$PESAN\" && git push origin main\033[0m"
git add docs/webhook-log.txt && git commit -m "$PESAN" && git push origin main
echo
echo -e "\033[1;32mPush selesai pukul $WAKTU. Buka Jenkins: build baru harus muncul otomatis tanpa Build Now.\033[0m"
