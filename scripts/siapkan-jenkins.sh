#!/usr/bin/env bash
# Menyiapkan / meng-upgrade Jenkins untuk tugas UTS (Tahap 4).
# Aman dijalankan ulang: akun admin, credential, dan job tersimpan di volume jenkins-data.
# Jalankan dari folder facility-report-uts di Git Bash:
#   bash scripts/siapkan-jenkins.sh

# Mencegah Git Bash mengubah path Linux (/var/run/...) menjadi path Windows.
export MSYS_NO_PATHCONV=1

C='\033[1;36m'; R='\033[1;31m'; Y='\033[1;33m'; G='\033[1;32m'; D='\033[0;90m'; N='\033[0m'
langkah() { echo; echo -e "${C}=== $1 ===${N}"; }
gagal()   { echo; echo -e "${R}GAGAL: $1${N}"; exit 1; }
perintah() { echo -e "${D}\$ $1${N}"; }

[ -f jenkins/Dockerfile ] || gagal "Jalankan skrip ini dari folder facility-report-uts (folder yang berisi Jenkinsfile)."

langkah "1. Cek Docker"
docker info --format '{{.ServerVersion}}' >/dev/null 2>&1 || gagal "Docker belum berjalan. Buka Docker Desktop dan tunggu sampai Engine running."
docker --version

langkah "2. Cek port"
pakai8080=$(docker ps --filter publish=8080 --format '{{.Names}}' | grep -v '^jenkins-server$')
[ -z "$pakai8080" ] || gagal "Port 8080 dipakai kontainer: $pakai8080. Hentikan dengan: docker stop NAMA_KONTAINER, lalu jalankan skrip ini lagi."
for port in 8090 5050; do
    pakai=$(docker ps --filter publish=$port --format '{{.Names}}' | grep -v '^facility-')
    [ -z "$pakai" ] || gagal "Port $port dipakai kontainer: $pakai. Hentikan dengan: docker stop NAMA_KONTAINER, lalu jalankan skrip ini lagi."
done
echo "Port 8080 (Jenkins), 8090 (frontend), dan 5050 (backend) aman."

langkah "3. Build image Jenkins kustom + Docker Compose (bisa beberapa menit)"
docker build -t jenkins-cicd:lab ./jenkins || gagal "Build image Jenkins gagal. Lihat pesan error di atas."

langkah "4. Network dan volume Jenkins"
docker network inspect jenkins-net >/dev/null 2>&1 || docker network create jenkins-net >/dev/null
docker volume create jenkins-data >/dev/null
echo "Network jenkins-net dan volume jenkins-data siap."

langkah "5. Jalankan Jenkins"
if [ -n "$(docker ps -aq --filter 'name=^/jenkins-server$')" ]; then
    echo "Kontainer jenkins-server lama dibuat ulang (data Jenkins tetap aman di volume jenkins-data)."
    docker rm -f jenkins-server >/dev/null
fi
docker run -d --name jenkins-server --network jenkins-net \
    -p 8080:8080 -p 50000:50000 \
    -v jenkins-data:/var/jenkins_home \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --user root --restart unless-stopped \
    jenkins-cicd:lab >/dev/null || gagal "Jenkins gagal dijalankan. Lihat pesan error di atas."
echo "jenkins-server berjalan."

langkah "6. Verifikasi alat di dalam Jenkins (screenshot untuk laporan)"
perintah "docker exec jenkins-server docker version --format 'Client {{.Client.Version}} | Server {{.Server.Version}}'"
docker exec jenkins-server docker version --format 'Client {{.Client.Version}} | Server {{.Server.Version}}' || gagal "Jenkins tidak bisa mengakses Docker."
perintah "docker exec jenkins-server docker compose version"
docker exec jenkins-server docker compose version || gagal "Plugin Docker Compose tidak ada di image Jenkins."
perintah "docker exec jenkins-server python3 --version"
docker exec jenkins-server python3 --version || gagal "Python 3 tidak ditemukan di Jenkins."

langkah "7. Menunggu Jenkins siap"
for i in $(seq 1 40); do
    kode=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/login)
    [ "$kode" = "200" ] && break
    echo "  menunggu... ($i/40)"
    sleep 3
done
pw=$(docker exec jenkins-server cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null)
echo
if [ -n "$pw" ]; then
    echo -e "${Y}Jenkins baru (belum pernah di-setup). Password awal: $pw${N}"
    echo "Salin password ini ke halaman Jenkins. JANGAN sertakan di screenshot."
else
    echo -e "${G}Jenkins lama terdeteksi: login dengan akun admin yang sudah pernah dibuat.${N}"
fi
explorer.exe "http://localhost:8080" >/dev/null 2>&1 || true
echo
echo -e "${G}SELESAI. Buka http://localhost:8080${N}"
