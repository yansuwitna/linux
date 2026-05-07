==================== BUAT LXC DEBIAN DI PROXMOX 
Template Debian

Di Proxmox:

Datacenter → Storage → local → CT Templates


Download:

debian-12-standard

Buat Container

Klik Create CT

Hostname: opencv-api

Password: bebas

OS Template: Debian 12

Disk: 8–16 GB

CPU: 2 core

RAM: 2 GB (minimum 1 GB)

Network: DHCP / Static

Unprivileged: ✅ (recommended)

Finish → Start CT


======================= KONFIGURASI DASAR DEBIAN

Masuk console LXC:

apt update && apt upgrade -y
apt install -y sudo curl git


Opsional timezone:

timedatectl set-timezone Asia/Makassar


========================= INSTALL PYTHON & DEPENDENSI OPENCV
apt install -y python3 python3-pip python3-venv build-essential cmake libgl1 libglib2.0-0

======================== BUAT VIRTUAL ENV (DISARANKAN)
mkdir /opt/opencv
cd /opt/opencv
python3 -m venv venv
source venv/bin/activate


========================== NSTALL OPENCV & FLASK
pip install --upgrade pip
pip install opencv-python flask numpy


Cek:

python -c "import cv2; print(cv2.__version__)"


=========================== BUAT API OPENCV (FLASK)
nano /opt/opencv/app.py


Isi:

from flask import Flask, request, jsonify
import cv2, numpy as np, json

app = Flask(__name__)

face_cascade = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)

def decode_image(file):
    data = np.frombuffer(file.read(), np.uint8)
    return cv2.imdecode(data, cv2.IMREAD_COLOR)

def extract_lbp_histogram(img):
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    faces = face_cascade.detectMultiScale(gray, 1.3, 5)

    if len(faces) != 1:
        return None

    x, y, w, h = faces[0]
    face = gray[y:y+h, x:x+w]
    face = cv2.resize(face, (128, 128))

    # LBP manual (aman)
    lbp = np.zeros_like(face)
    for i in range(1, face.shape[0]-1):
        for j in range(1, face.shape[1]-1):
            center = face[i, j]
            binary = 0
            binary |= (face[i-1,j-1] > center) << 7
            binary |= (face[i-1,j]   > center) << 6
            binary |= (face[i-1,j+1] > center) << 5
            binary |= (face[i,j+1]   > center) << 4
            binary |= (face[i+1,j+1] > center) << 3
            binary |= (face[i+1,j]   > center) << 2
            binary |= (face[i+1,j-1] > center) << 1
            binary |= (face[i,j-1]   > center)
            lbp[i, j] = binary

    hist = cv2.calcHist([lbp], [0], None, [256], [0, 256])
    cv2.normalize(hist, hist)

    return hist.flatten().astype(np.float32)


@app.route("/ping")
def ping():
    return {"status": "ok"}

@app.route("/register", methods=["POST"])
def register():
    if "image" not in request.files:
        return jsonify({"status":"error","msg":"image tidak ada"}), 400

    face_vector = extract_lbp_histogram(decode_image(request.files["image"]))
    if face_vector is None:
        return jsonify({"status":"error","msg":"wajah harus 1"}), 400

    return jsonify({
        "status":"success",
        "face_vector": face_vector.tolist()
    })

@app.route("/match", methods=["POST"])
def match():
    if "image" not in request.files or "face_vector" not in request.form:
        return jsonify({"status":"error","msg":"input tidak lengkap"}), 400

    face_vector = extract_lbp_histogram(decode_image(request.files["image"]))
    if face_vector is None:
        return jsonify({"status":"error","msg":"wajah tidak valid"}), 400

    try:
        saved_vector = np.array(
            json.loads(request.form["face_vector"]),
            dtype=np.float32
        )
    except:
        return jsonify({"status":"error","msg":"face_vector rusak"}), 400

    if face_vector.shape != saved_vector.shape:
        return jsonify({"status":"error","msg":"ukuran vector beda"}), 400

    distance = np.linalg.norm(face_vector - saved_vector)

    return jsonify({
        "status": "match" if distance < 35 else "no_match",
        "distance": float(distance)
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)


===================== JALANKAN & TEST
source /opt/opencv/venv/bin/activate
python /opt/opencv/app.py


Test dari Proxmox host / PC:

curl http://IP_LXC:5000/ping


Harus:

{"status":"ok"}

=========================== BUAT SERVICE SYSTEMD (AUTO START)
nano /etc/systemd/system/opencv-api.service


Isi:

[Unit]
Description=OpenCV Flask API
After=network.target

[Service]
User=root
WorkingDirectory=/opt/opencv
ExecStart=/opt/opencv/venv/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target


Aktifkan:

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now opencv-api


Cek:

systemctl status opencv-api


============================ AKSES DARI PHP
$url = "http://IP_LXC:5000/match";


===== Cek Terakhir 
reboot


========= Buat File 
index.html
register.php
match.php


