#!/usr/bin/env bash
# Simulasi Data Immunity: hapus paksa kontainer backend, buat ulang, data tetap ada.
#   bash scripts/data-immunity.sh
export MSYS_NO_PATHCONV=1
BASE="${BASE:-http://localhost:8090/api}"
C='\033[1;36m'; Y='\033[1;33m'; G='\033[1;32m'; D='\033[0;90m'; N='\033[0m'
judul() { echo; echo -e "${C}>>> $1${N}"; }
cmd()   { echo -e "${D}\$ $*${N}"; "$@"; }
jeda()  { echo -e "${Y}(lanjut dalam $1 detik...)${N}"; sleep "$1"; }

judul "1. Kondisi awal: kontainer backend dan isi data"
cmd docker ps --filter name=facility-backend --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}'
cmd curl -s "$BASE/reports"; echo
jeda 3

judul "2. Hapus paksa kontainer backend (docker rm -f)"
cmd docker rm -f facility-backend
echo "HTTP dari $BASE/reports saat backend tidak ada: $(curl -s -o /dev/null -w '%{http_code}' "$BASE/reports")  (502/504 = backend tidak tersedia)"
cmd docker volume ls --filter name=facility-data
jeda 3

judul "3. Buat ulang backend dengan docker compose"
cmd docker compose up -d backend
for i in $(seq 1 20); do
    [ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/health")" = "200" ] && break
    sleep 1
done

judul "4. Kondisi akhir: CONTAINER ID baru, data tetap sama"
cmd docker ps --filter name=facility-backend --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}'
cmd curl -s "$BASE/reports"; echo
echo -e "${G}Data selamat karena tersimpan di Named Volume facility-data, bukan di dalam kontainer.${N}"
