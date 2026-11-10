#!/usr/bin/env bash
# Uji endpoint API lewat Nginx (http://localhost:8090/api). Satu bagian per screenshot:
#   bash scripts/uji-api.sh 1   -> health + GET daftar aduan
#   bash scripts/uji-api.sh 2   -> POST valid + POST tidak valid (400)
#   bash scripts/uji-api.sh 3   -> DELETE valid + DELETE index tidak ada (404) + tanpa index (400)
#   bash scripts/uji-api.sh     -> semua bagian
BAGIAN="${1:-0}"
BASE="${BASE:-http://localhost:8090/api}"
C='\033[1;36m'; D='\033[0;90m'; N='\033[0m'

uji() { echo; echo -e "${C}>>> $1  (diharapkan: $2)${N}"; echo -e "${D}\$ $3${N}"; }

if [ "$BAGIAN" = 0 ] || [ "$BAGIAN" = 1 ]; then
    uji "Health" "HTTP 200, status active" "curl -i $BASE/health"
    curl -s -i "$BASE/health"; echo
    uji "Daftar aduan" "HTTP 200, JSON reports dan total" "curl -s $BASE/reports"
    curl -s "$BASE/reports"; echo
fi

if [ "$BAGIAN" = 0 ] || [ "$BAGIAN" = 2 ]; then
    uji "Kirim aduan valid" "HTTP 201 Created" "curl -i -X POST $BASE/reports -H 'Content-Type: application/json' -d '{...}'"
    curl -s -i -X POST "$BASE/reports" -H 'Content-Type: application/json' \
        -d '{"pelapor":"Uji API","lokasi":"TULT 0704","fasilitas":"Proyektor","prioritas":"Tinggi","deskripsi":"Proyektor tidak menyala"}'; echo
    uji "Kirim aduan tanpa deskripsi" "HTTP 400" "curl -i -X POST $BASE/reports -d '{\"pelapor\":\"Uji\",\"lokasi\":\"TULT\",\"fasilitas\":\"AC\"}'"
    curl -s -i -X POST "$BASE/reports" -H 'Content-Type: application/json' \
        -d '{"pelapor":"Uji","lokasi":"TULT","fasilitas":"AC"}'; echo
    uji "Kirim JSON rusak" "HTTP 400" "curl -i -X POST $BASE/reports -d '{rusak'"
    curl -s -i -X POST "$BASE/reports" -H 'Content-Type: application/json' -d '{rusak'; echo
fi

if [ "$BAGIAN" = 0 ] || [ "$BAGIAN" = 3 ]; then
    TERAKHIR=$(( $(curl -s "$BASE/health" | sed -n 's/.*"total_reports": *\([0-9]*\).*/\1/p') - 1 ))
    [ "$TERAKHIR" -lt 0 ] && TERAKHIR=0
    uji "Hapus aduan terakhir (index=$TERAKHIR)" "HTTP 200, status deleted" "curl -i -X DELETE '$BASE/reports?index=$TERAKHIR'"
    curl -s -i -X DELETE "$BASE/reports?index=$TERAKHIR"; echo
    uji "Hapus index yang tidak ada" "HTTP 404" "curl -i -X DELETE '$BASE/reports?index=999'"
    curl -s -i -X DELETE "$BASE/reports?index=999"; echo
    uji "Hapus tanpa parameter index" "HTTP 400" "curl -i -X DELETE '$BASE/reports'"
    curl -s -i -X DELETE "$BASE/reports"; echo
fi
