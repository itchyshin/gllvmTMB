"""Install the staged immutable candidate in a task-local Totoro library."""
import datetime, hashlib, json, os, signal, subprocess, sys, time
from pathlib import Path
root = Path(sys.argv[1]).resolve(); os.chdir(root)
manifest = json.loads((root / "bundle-manifest.json").read_text())
for name, sha in manifest["files"].items():
    if hashlib.sha256((root / name).read_bytes()).hexdigest() != sha:
        raise SystemExit("Bundle mismatch: " + name)
receipt = root / "install-receipt.json"
if receipt.exists(): raise SystemExit("No overwrite of installation receipt")
(root / "library").mkdir()
command = ["R", "CMD", "INSTALL", "--no-multiarch",
           "--library=" + str(root / "library"), str(root / "package")]
info = {"command": command, "bundle_hash": manifest["bundle_hash"],
        "started": datetime.datetime.now(datetime.timezone.utc).isoformat()}
receipt.write_text(json.dumps(info, indent=2) + "\n")
started = time.monotonic(); env = os.environ.copy()
for key in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS"):
    env[key] = "1"
with (root / "install.log").open("w") as log:
    process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                               env=env, start_new_session=True)
    try: code = process.wait(timeout=600); status = "finished"
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGTERM)
        try: process.wait(timeout=3)
        except subprocess.TimeoutExpired: os.killpg(process.pid, signal.SIGKILL); process.wait()
        code = 124; status = "timeout"
info.update(exit_status=code, status=status, seconds=time.monotonic()-started)
if code == 0:
    installed = {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
                 for path in sorted((root / "library/gllvmTMB").rglob("*")) if path.is_file()}
    info["installed_files"] = installed
    info["installed_hash"] = hashlib.sha256(json.dumps(installed, sort_keys=True).encode()).hexdigest()
receipt.write_text(json.dumps(info, indent=2) + "\n")
print(json.dumps(info), flush=True)
sys.exit(code)
