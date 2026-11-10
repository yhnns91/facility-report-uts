#!/usr/bin/env bash
# Menampilkan bukti arsitektur Docker: service, network app-net, DNS, volume, bind mount.
#   bash scripts/cek-arsitektur.sh
export MSYS_NO_PATHCONV=1
C='\033[1;36m'; D='\033[0;90m'; N='\033[0m'
judul() { echo; echo -e "${C}>>> $1${N}"; }
cmd()   { echo -e "${D}\$ $*${N}"; "$@"; }

judul "Service yang berjalan (docker compose ps)"
cmd docker compose ps

judul "Kontainer di dalam Custom Bridge Network app-net"
cmd docker network inspect app-net --format '{{ .Name }} (driver: {{ .Driver }}){{ range .Containers }} | {{ .Name }} {{ .IPv4Address }}{{ end }}'

judul "Frontend memanggil backend lewat nama service 'backend' (DNS Docker)"
cmd docker exec facility-frontend wget -qO- http://backend:5000/health; echo

judul "Jenis penyimpanan tiap kontainer"
cmd docker inspect --format '{{ .Name }}{{ range .Mounts }} | {{ .Type }}: {{ .Source }} -> {{ .Destination }}{{ end }}' facility-frontend facility-backend

judul "Named Volume facility-data"
cmd docker volume inspect facility-data --format 'Volume {{ .Name }} | dibuat {{ .CreatedAt }} | {{ .Mountpoint }}'
