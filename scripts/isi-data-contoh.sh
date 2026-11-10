#!/usr/bin/env bash
# Mengisi 3 aduan contoh agar tampilan UI terisi saat demo.
#   bash scripts/isi-data-contoh.sh
BASE="${BASE:-http://localhost:8090/api}"
kirim() {
    curl -s -o /dev/null -w "  POST -> HTTP %{http_code}\n" -X POST "$BASE/reports" \
        -H 'Content-Type: application/json' -d "$1"
}
echo "Mengisi data contoh ke $BASE/reports"
kirim '{"pelapor":"Yohannes","lokasi":"Gedung TULT Lt. 7 Ruang 0704","fasilitas":"AC","prioritas":"Tinggi","deskripsi":"AC tidak dingin sejak pagi, ruangan panas saat kuliah."}'
kirim '{"pelapor":"Anggota 2","lokasi":"Gedung P Ruang 201","fasilitas":"Proyektor","prioritas":"Sedang","deskripsi":"Proyektor berkedip dan warnanya pudar."}'
kirim '{"pelapor":"Anggota 3","lokasi":"Lab Jaringan Lt. 3","fasilitas":"Jaringan/WiFi","prioritas":"Rendah","deskripsi":"WiFi sering putus di sisi belakang lab."}'
echo "Selesai. Buka http://localhost:8090"
