from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import matlab.engine
from werkzeug.utils import secure_filename



UPLOAD_FOLDER = 'uploaded_audio'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

app = Flask(__name__)
CORS(app)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

@app.route("/analyze", methods=["POST"])
def analyze():
    if 'original' not in request.files or 'performance' not in request.files:
        return jsonify({"error": "Missing audio files"}), 400

    original = request.files['original']
    performance = request.files['performance']

    # Save files
    original_path = os.path.join(app.config['UPLOAD_FOLDER'], secure_filename(original.filename))
    performance_path = os.path.join(app.config['UPLOAD_FOLDER'], secure_filename(performance.filename))
    original.save(original_path)
    performance.save(performance_path)

    # Call MATLAB
    eng = matlab.engine.start_matlab()
    eng.addpath(r'C:\Users\user1\Desktop\Piano-Note-Recognition-master')

    try:
        accuracy, mismatches = eng.compare_notes(original_path, performance_path, nargout=2)
        mismatches_py = [{"Index": int(m['Index']), "Expected": m['Expected'], "Played": m['Played']} for m in mismatches]
    except Exception as e:
        eng.quit()
        return jsonify({"error": str(e)}), 500

    eng.quit()

    return jsonify({
        "accuracy": accuracy,
        "mismatches": mismatches_py
    })

if __name__ == "__main__":
    app.run(debug=True)
