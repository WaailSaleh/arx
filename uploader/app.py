from flask import Flask, request, redirect, url_for, render_template_string, jsonify
import os
import tempfile
import zipfile
import shutil
import uuid

# Optional docker restart support
DOCKER_AVAILABLE = True
try:
    import docker  # type: ignore
except Exception:
    DOCKER_AVAILABLE = False

app = Flask(__name__)

SAVES_DIR = os.environ.get("SAVES_DIR", "/data")
DEST_BASE = os.path.join(SAVES_DIR, "SaveGames", "0")
ALLOW_OVERWRITE = True
DOCKER_LABEL_SERVICE = os.environ.get("DOCKER_LABEL_SERVICE", "palworld-server")

INDEX_HTML = """
<!doctype html>
<title>Palworld Save Uploader</title>
<h2>Upload your Palworld world (ZIP)</h2>
<form method="post" action="/upload" enctype="multipart/form-data">
  <input type="file" name="file" accept=".zip" required />
  <div>
    <label><input type="checkbox" name="overwrite" checked /> Overwrite if world folder exists</label>
  </div>
  <div>
    <label><input type="checkbox" name="restart" checked /> Restart server after upload</label>
  </div>
  <button type="submit">Upload</button>
</form>
<p>Destination on server: <code>{{dest_base}}</code></p>
"""


def ensure_dirs_exist() -> None:
    os.makedirs(DEST_BASE, exist_ok=True)


def is_world_folder(path: str) -> bool:
    # Palworld worlds contain these files
    expected_files = {"Level.sav", "WorldOption.sav"}
    try:
        entries = set(os.listdir(path))
    except Exception:
        return False
    return any(name in entries for name in expected_files)


def find_world_folders(root: str) -> list[str]:
    candidates: list[str] = []

    # If the root itself is a world folder
    if is_world_folder(root):
        candidates.append(root)

    for dirpath, dirnames, filenames in os.walk(root):
        # If this path looks like a world folder (contains Level.sav or WorldOption.sav)
        if "Level.sav" in filenames or "WorldOption.sav" in filenames:
            candidates.append(dirpath)

    # Filter out duplicates and nested duplicates by sorting by depth and unique
    unique: list[str] = []
    seen: set[str] = set()
    for p in sorted(candidates, key=lambda p: p.count(os.sep)):
        if p not in seen:
            # Skip if a parent is already included
            if any(p.startswith(parent + os.sep) for parent in unique):
                continue
            unique.append(p)
            seen.add(p)
    return unique


def extract_zip_to_temp(zip_path: str) -> str:
    tmp_dir = tempfile.mkdtemp(prefix="palworld_upload_")
    with zipfile.ZipFile(zip_path, 'r') as zf:
        zf.extractall(tmp_dir)
    # If there is a single top-level folder, use it as root to simplify
    entries = [e for e in os.listdir(tmp_dir) if not e.startswith("__MACOSX")]
    if len(entries) == 1:
        sole = os.path.join(tmp_dir, entries[0])
        if os.path.isdir(sole):
            return sole
    return tmp_dir


def move_world_folder(src_world_dir: str, overwrite: bool) -> str:
    ensure_dirs_exist()
    world_folder_name = os.path.basename(src_world_dir.rstrip(os.sep))
    dest_dir = os.path.join(DEST_BASE, world_folder_name)

    if os.path.exists(dest_dir):
        if not overwrite:
            raise RuntimeError(f"Destination already exists: {dest_dir}")
        # Move existing to backup then replace
        backup_dir = dest_dir + f".bak_{uuid.uuid4().hex[:8]}"
        shutil.move(dest_dir, backup_dir)
    shutil.move(src_world_dir, dest_dir)
    return dest_dir


def restart_palworld_service() -> dict:
    if not DOCKER_AVAILABLE:
        return {"restarted": False, "reason": "docker SDK not available in image"}
    try:
        client = docker.from_env()
        # Prefer compose label
        containers = client.containers.list(all=True, filters={"label": f"com.docker.compose.service={DOCKER_LABEL_SERVICE}"})
        if not containers:
            # Fallback by name contains
            containers = [c for c in client.containers.list(all=True) if DOCKER_LABEL_SERVICE in (c.name or "")] 
        restarted = []
        for c in containers:
            try:
                c.restart()
                restarted.append(c.name)
            except Exception as e:
                pass
        return {"restarted": bool(restarted), "containers": restarted}
    except Exception as e:
        return {"restarted": False, "reason": str(e)}


@app.route("/", methods=["GET"])
def index():
    return render_template_string(INDEX_HTML, dest_base=DEST_BASE)


@app.route("/upload", methods=["POST"])
def upload():
    if "file" not in request.files:
        return jsonify({"ok": False, "error": "No file part"}), 400
    file = request.files["file"]
    if file.filename == "":
        return jsonify({"ok": False, "error": "No selected file"}), 400
    if not file.filename.lower().endswith(".zip"):
        return jsonify({"ok": False, "error": "Only .zip files are supported"}), 400

    overwrite = request.form.get("overwrite") == "on"
    do_restart = request.form.get("restart") == "on"

    tmp_zip_fd, tmp_zip_path = tempfile.mkstemp(suffix=".zip")
    os.close(tmp_zip_fd)
    file.save(tmp_zip_path)

    work_root = None
    try:
        work_root = extract_zip_to_temp(tmp_zip_path)
        world_folders = find_world_folders(work_root)
        if not world_folders:
            return jsonify({"ok": False, "error": "Could not find a valid Palworld world folder in the zip"}), 400
        if len(world_folders) > 1:
            return jsonify({"ok": False, "error": f"Multiple world folders found: {world_folders}. Please zip a single world folder."}), 400

        dest_dir = move_world_folder(world_folders[0], overwrite=overwrite)

        restart_result = {"restarted": False}
        if do_restart:
            restart_result = restart_palworld_service()

        return jsonify({
            "ok": True,
            "message": "World uploaded successfully",
            "destination": dest_dir,
            "restart": restart_result,
        })
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500
    finally:
        try:
            if work_root and os.path.exists(work_root):
                shutil.rmtree(work_root, ignore_errors=True)
        except Exception:
            pass
        try:
            if os.path.exists(tmp_zip_path):
                os.remove(tmp_zip_path)
        except Exception:
            pass


if __name__ == "__main__":
    # Simple dev server
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8080")), debug=False)