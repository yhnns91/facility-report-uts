// Pipeline CI/CD Laporan Kerusakan Fasilitas Kampus (Studi Kasus No. 8)
// Dipicu otomatis oleh GitHub Webhook setiap ada push ke branch main.
pipeline {
    agent any

    options {
        disableConcurrentBuilds()
    }

    environment {
        PYTHONUNBUFFERED   = '1'
        BACKEND_IMAGE      = 'facility-backend'
        BACKEND_CONTAINER  = 'facility-backend'
        FRONTEND_CONTAINER = 'facility-frontend'
        // Volume tempat /var/jenkins_home disimpan (dibuat oleh scripts/siapkan-jenkins.sh)
        JENKINS_HOME_VOLUME = 'jenkins-data'
    }

    stages {
        stage('1. Checkout') {
            steps {
                echo 'Mengambil source code dari GitHub'
                checkout scm
                sh 'git log -1 --oneline'
            }
        }

        stage('2. Syntax Check') {
            steps {
                sh '''
                    python3 --version
                    python3 -m py_compile app.py
                    echo "app.py: sintaks Python OK"

                    test -s frontend/index.html
                    grep -q "fetch(" frontend/index.html
                    echo "frontend/index.html: ada dan memakai fetch() API"

                    docker compose version
                    docker compose config --quiet
                    echo "docker-compose.yml: konfigurasi valid"
                '''
            }
        }

        stage('3. Build Image') {
            steps {
                sh '''
                    SHORT_SHA=$(git rev-parse --short HEAD)
                    echo "Commit SHA: ${SHORT_SHA}"
                    docker compose build backend
                    docker tag ${BACKEND_IMAGE}:latest ${BACKEND_IMAGE}:${BUILD_NUMBER}
                    docker tag ${BACKEND_IMAGE}:latest ${BACKEND_IMAGE}:${SHORT_SHA}
                    docker compose pull frontend || echo "Pull nginx dilewati (offline?), memakai image lokal"
                    docker images ${BACKEND_IMAGE}
                '''
            }
        }

        stage('4. Automated Deployment') {
            steps {
                // Jenkins berjalan di dalam kontainer. Path workspace /var/jenkins_home/...
                // tidak dikenal oleh Docker Engine, jadi bind mount diarahkan ke lokasi
                // asli workspace di dalam volume jenkins-data.
                sh '''
                    VOLUME_ROOT=$(docker volume inspect ${JENKINS_HOME_VOLUME} --format '{{ .Mountpoint }}')
                    export HOST_ROOT="${VOLUME_ROOT}${WORKSPACE#/var/jenkins_home}"
                    echo "Sumber bind mount frontend: ${HOST_ROOT}/frontend"

                    docker compose up -d --force-recreate --remove-orphans
                    docker compose ps
                '''
            }
        }

        stage('5. Health Check') {
            steps {
                sh '''
                    echo "Menunggu backend siap..."
                    for i in $(seq 1 15); do
                      if docker exec ${FRONTEND_CONTAINER} wget -qO- http://backend:5000/health; then
                        echo ""
                        echo "Backend terjangkau dari frontend lewat DNS service name 'backend' (percobaan ke-$i)"
                        break
                      fi
                      if [ "$i" -eq 15 ]; then
                        echo "Health check GAGAL setelah 15 percobaan"
                        docker compose logs --tail 50
                        exit 1
                      fi
                      sleep 2
                    done

                    echo "--- Uji API lewat reverse proxy Nginx (/api/reports) ---"
                    docker exec ${FRONTEND_CONTAINER} wget -qO- http://localhost/api/reports
                    echo ""

                    echo "--- Uji halaman frontend dari bind mount ---"
                    docker exec ${FRONTEND_CONTAINER} wget -qO- http://localhost/ | grep -q "Laporan Kerusakan Fasilitas Kampus"
                    echo "Frontend tersaji oleh Nginx: OK"
                    docker exec ${FRONTEND_CONTAINER} nginx -t

                    echo "--- Jenis penyimpanan kontainer ---"
                    docker inspect --format '{{ .Name }}{{ range .Mounts }} | {{ .Type }}: {{ .Destination }}{{ end }}' ${FRONTEND_CONTAINER} ${BACKEND_CONTAINER}
                    echo "Status Docker HEALTHCHECK backend: $(docker inspect --format '{{ .State.Health.Status }}' ${BACKEND_CONTAINER})"
                '''
            }
        }
    }

    post {
        success {
            echo 'Pipeline selesai: aplikasi berjalan di http://localhost:8090'
        }
        failure {
            echo 'Pipeline gagal. Periksa Console Output.'
        }
    }
}
