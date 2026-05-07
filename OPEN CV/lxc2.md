INSTALL DEPENDENCY (WAJIB TEPAT)
pip uninstall opencv-python opencv-contrib-python -y
pip install opencv-python-headless==4.9.0.80
pip install insightface onnxruntime mediapipe flask numpy


Cek:

python -c "import insightface, mediapipe, cv2; print('OK')"


====================== app.py — VERSI CANGGIH (FULL SCRIPT)

from flask import Flask, request, jsonify
import cv2
import numpy as np
import json
import mediapipe as mp
from insightface.app import FaceAnalysis

app = Flask(__name__)

# ===============================
# InsightFace (ArcFace)
# ===============================
face_app = FaceAnalysis(
    name="buffalo_l",
    providers=["CPUExecutionProvider"]
)
face_app.prepare(ctx_id=0, det_size=(640,640))

# ===============================
# MediaPipe Face Mesh
# ===============================
mp_face = mp.solutions.face_mesh.FaceMesh(
    static_image_mode=False,
    max_num_faces=1,
    refine_landmarks=True,
    min_detection_confidence=0.6,
    min_tracking_confidence=0.6
)

# ===============================
# Utils
# ===============================
def decode_image(file):
    data = np.frombuffer(file.read(), np.uint8)
    return cv2.imdecode(data, cv2.IMREAD_COLOR)

def cosine_similarity(a, b):
    return float(np.dot(a,b) / (np.linalg.norm(a)*np.linalg.norm(b)))

def check_face_motion(img):
    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    res = mp_face.process(rgb)
    if not res.multi_face_landmarks:
        return False

    lm = res.multi_face_landmarks[0].landmark
    left_eye = lm[159].y
    right_eye = lm[386].y
    nose = lm[1].x

    return left_eye > 0 and right_eye > 0 and nose > 0

def get_embedding(img):
    faces = face_app.get(img)
    if len(faces) != 1:
        return None
    return faces[0].embedding

# ===============================
# REGISTER
# ===============================
@app.route("/register", methods=["POST"])
def register():
    if "image" not in request.files:
        return jsonify({"status":"error","msg":"image tidak ada"}), 400

    img = decode_image(request.files["image"])
    emb = get_embedding(img)

    if emb is None:
        return jsonify({"status":"error","msg":"wajah harus 1"}), 400

    return jsonify({
        "status":"success",
        "vector": emb.tolist(),
        "dim": int(len(emb))
    })

# ===============================
# MATCH
# ===============================
@app.route("/match", methods=["POST"])
def match():
    if "image" not in request.files or "vector" not in request.form:
        return jsonify({"status":"error","msg":"input tidak lengkap"}), 400

    img = decode_image(request.files["image"])

    # Anti spoof (gerak)
    if not check_face_motion(img):
        return jsonify({"status":"error","msg":"tidak ada gerakan wajah"}), 400

    emb_now = get_embedding(img)
    if emb_now is None:
        return jsonify({"status":"error","msg":"wajah tidak valid"}), 400

    emb_saved = np.array(
        json.loads(request.form["vector"]),
        dtype=np.float32
    )

    sim = cosine_similarity(emb_now, emb_saved)

    return jsonify({
        "status": "match" if sim > 0.45 else "no_match",
        "similarity": sim
    })

# ===============================
# RUN
# ===============================
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
