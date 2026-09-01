"""Create an immutable task bundle without including historical bulky evidence."""
import hashlib, json, shutil, subprocess, sys, tarfile
from pathlib import Path
root = Path(__file__).resolve().parents[3]
dest = Path(sys.argv[1]).resolve()
if dest.exists(): raise SystemExit("Refusing to replace staged bundle")
dest.mkdir()
package = dest / "package"; package.mkdir()
for name in ("DESCRIPTION", "NAMESPACE", "LICENSE", "R", "src", "inst", "man"):
    source = root / name
    if not source.exists(): continue
    if source.is_dir():
        shutil.copytree(source, package / name,
                        ignore=shutil.ignore_patterns("*.o", "*.so", "*.dll", "*.dylib", "symbols.rds"))
    else: shutil.copy2(source, package / name)
work = dest / "dev/structured-rho/spatial-recovery"; work.mkdir(parents=True)
scripts = (
    "study-metrics.R", "freeze-engineering.R", "freeze-study.R", "fit-study.R",
    "run_batch.py", "run-engineering.py", "run-pilot.py", "run-remainder.py", "install.py",
    "summarize-study.R"
)
for name in scripts: shutil.copy2(root / "dev/structured-rho/spatial-recovery" / name, work / name)
shutil.copy2(root / "dev/structured-rho/spatial-recovery/attempts.csv", dest / "attempts.csv")
files = {str(path.relative_to(dest)): hashlib.sha256(path.read_bytes()).hexdigest()
         for path in sorted(dest.rglob("*")) if path.is_file() and path != dest / "attempts.csv"}
manifest = {
    "files": files,
    "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
    "initial_attempt_ledger_sha256": hashlib.sha256((dest / "attempts.csv").read_bytes()).hexdigest(),
    "task": "structured-rho-spatial-recovery",
    "source_root": str(root),
    "purpose": "approved smoke/pilot tooling; 1,568-attempt remainder requires measured-checkpoint approval",
}
manifest["bundle_hash"] = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()
(dest / "bundle-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
archive = dest.with_suffix(".tar.gz")
with tarfile.open(archive, "w:gz") as tar:
    for path in sorted(dest.iterdir()): tar.add(path, arcname=path.name)
receipt = {
    "path": str(archive), "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
    "bytes": archive.stat().st_size, "bundle_hash": manifest["bundle_hash"],
    "head": manifest["head"],
}
local = root / "dev/structured-rho/spatial-recovery/local-evidence"
local.mkdir(exist_ok=True)
(local / "stage.json").write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps(receipt))
