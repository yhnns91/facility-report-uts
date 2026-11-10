"""Facility Issue Reporting API (Laporan Kerusakan Fasilitas Kampus).

REST API berbasis JSON tanpa framework, hanya memakai standard library Python.
Data disimpan di file JSON di dalam Docker Named Volume (facility-data).

Endpoint:
  GET    /health              -> status layanan
  GET    /reports             -> daftar aduan
  POST   /reports             -> kirim aduan baru (body JSON)
  DELETE /reports?index=X     -> hapus aduan yang sudah selesai
"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from datetime import datetime, timezone
from urllib.parse import urlparse, parse_qs
from pathlib import Path
import json
import os
import threading

DATA_FILE = Path(os.getenv(
    "DATA_FILE", "/var/lib/backend_data/facility_reports.json"
))
PORT = int(os.getenv("PORT", "5000"))
MAX_BODY_BYTES = 10_000

FASILITAS = ["AC", "Proyektor", "Listrik", "Kursi/Meja", "Jaringan/WiFi",
             "Kebersihan", "Lainnya"]
PRIORITAS = ["Rendah", "Sedang", "Tinggi"]
BATAS_PANJANG = {"pelapor": 80, "lokasi": 80, "deskripsi": 500}

_lock = threading.Lock()


def read_reports():
    if not DATA_FILE.exists():
        return []
    try:
        data = json.loads(DATA_FILE.read_text(encoding="utf-8"))
        return data if isinstance(data, list) else []
    except (json.JSONDecodeError, OSError):
        return []


def write_reports(reports):
    DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = DATA_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(reports, indent=2, ensure_ascii=False),
                   encoding="utf-8")
    os.replace(tmp, DATA_FILE)  # tulis atomik: file tidak setengah jadi


def validate(payload):
    """Kembalikan (report, None) jika valid, atau (None, pesan_error)."""
    if not isinstance(payload, dict):
        return None, "Body harus berupa objek JSON"
    report = {}
    for field in ("pelapor", "lokasi", "deskripsi"):
        value = str(payload.get(field, "")).strip()
        if not value:
            return None, f"Field '{field}' wajib diisi"
        if len(value) > BATAS_PANJANG[field]:
            return None, (f"Field '{field}' maksimal "
                          f"{BATAS_PANJANG[field]} karakter")
        report[field] = value
    fasilitas = str(payload.get("fasilitas", "")).strip()
    if fasilitas not in FASILITAS:
        return None, f"Field 'fasilitas' harus salah satu dari: {', '.join(FASILITAS)}"
    prioritas = str(payload.get("prioritas", "Sedang")).strip() or "Sedang"
    if prioritas not in PRIORITAS:
        return None, f"Field 'prioritas' harus salah satu dari: {', '.join(PRIORITAS)}"
    report["fasilitas"] = fasilitas
    report["prioritas"] = prioritas
    report["created_at"] = datetime.now(timezone.utc).isoformat()
    return {k: report[k] for k in ("pelapor", "lokasi", "fasilitas",
                                   "prioritas", "deskripsi",
                                   "created_at")}, None


class APIHandler(BaseHTTPRequestHandler):
    server_version = "FacilityReportAPI/1.0"

    def send_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods",
                         "GET, POST, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_json(200, {"status": "ok"})

    def do_GET(self):
        path = urlparse(self.path).path
        if path in ("/", "/health"):
            with _lock:
                total = len(read_reports())
            return self.send_json(200, {
                "status": "active",
                "service": "Facility Report API",
                "total_reports": total,
            })
        if path == "/reports":
            with _lock:
                reports = read_reports()
            return self.send_json(200, {"reports": reports,
                                        "total": len(reports)})
        return self.send_json(404, {"error": "Endpoint not found"})

    def do_POST(self):
        if urlparse(self.path).path != "/reports":
            return self.send_json(404, {"error": "Endpoint not found"})
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return self.send_json(400, {"error": "Invalid Content-Length"})
        if length <= 0:
            return self.send_json(400, {"error": "Request body is empty"})
        if length > MAX_BODY_BYTES:
            return self.send_json(413, {"error": "Request body too large"})
        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return self.send_json(400, {"error": "Invalid JSON request body"})
        report, error = validate(payload)
        if error:
            return self.send_json(400, {"error": error})
        with _lock:
            reports = read_reports()
            reports.append(report)
            write_reports(reports)
            index = len(reports) - 1
        return self.send_json(201, {"status": "created", "index": index,
                                    "report": report})

    def do_DELETE(self):
        parsed = urlparse(self.path)
        if parsed.path != "/reports":
            return self.send_json(404, {"error": "Endpoint not found"})
        query = parse_qs(parsed.query)
        if "index" not in query:
            return self.send_json(400, {"error": "Missing index parameter"})
        try:
            index = int(query["index"][0])
        except ValueError:
            return self.send_json(400, {"error": "Index must be an integer"})
        with _lock:
            reports = read_reports()
            if index < 0 or index >= len(reports):
                return self.send_json(404, {"error": "Report not found"})
            removed = reports.pop(index)
            write_reports(reports)
            remaining = len(reports)
        return self.send_json(200, {"status": "deleted", "removed": removed,
                                    "total": remaining})

    def method_not_allowed(self):
        self.send_json(405, {"error": "Method not allowed"})

    do_PUT = do_PATCH = method_not_allowed

    def log_message(self, fmt, *args):
        print(f"[{self.log_date_time_string()}] {fmt % args}", flush=True)


if __name__ == "__main__":
    print(f"Facility Report API listening on 0.0.0.0:{PORT}", flush=True)
    print(f"Data file: {DATA_FILE}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), APIHandler).serve_forever()
