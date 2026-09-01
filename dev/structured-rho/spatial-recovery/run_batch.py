"""Fail-closed spatial recovery runner with atomic attempt accounting."""
import concurrent.futures, csv, datetime, hashlib, json, os, re, signal, subprocess, sys, threading, time
from pathlib import Path

ROOT = Path(sys.argv[1]).resolve()
KIND = sys.argv[2]
if KIND not in {"engineering", "pilot", "remainder"}:
    raise SystemExit("kind must be engineering, pilot, or remainder")
os.chdir(ROOT)
if "totoro" not in subprocess.check_output(["hostname"], text=True).lower():
    raise SystemExit("Spatial recovery fits run on Totoro only")
work = ROOT / "dev/structured-rho/spatial-recovery"
fixtures = work / ("engineering-fixtures" if KIND == "engineering" else "fixtures")
output = ROOT / "results" / KIND
ledger = ROOT / "attempts.csv"

bundle = json.loads((ROOT / "bundle-manifest.json").read_text())
for name, sha in bundle["files"].items():
    if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != sha:
        raise SystemExit("Candidate bundle mismatch: " + name)
installation = json.loads((ROOT / "install-receipt.json").read_text())
if installation.get("exit_status") != 0 or installation.get("bundle_hash") != bundle["bundle_hash"]:
    raise SystemExit("Successful exact-bundle installation required")
fixture_manifest = json.loads((fixtures / "manifest.json").read_text())
for record in fixture_manifest["files"]:
    name, md5 = record["path"], record["md5"]
    if hashlib.md5((fixtures / name).read_bytes()).hexdigest() != md5:
        raise SystemExit("Frozen fixture mismatch: " + name)

jobs = list(csv.DictReader((fixtures / "jobs.csv").open()))
if KIND == "pilot":
    jobs = [job for job in jobs if job["pilot"] == "TRUE"]
    if len(jobs) != 32:
        raise SystemExit("Retained pilot must contain exactly 32 attempts")
    engineering = ROOT / "results/engineering/completion.json"
    if not engineering.exists() or json.loads(engineering.read_text()).get("attempts") != 8:
        raise SystemExit("Eight terminal engineering attempts required first")
    workers, total_seconds, per_attempt_seconds = 12, 1800, 840
elif KIND == "remainder":
    pilot_jobs = [job for job in jobs if job["pilot"] == "TRUE"]
    jobs = [job for job in jobs if job["pilot"] != "TRUE"]
    if len(pilot_jobs) != 32 or len(jobs) != 1568:
        raise SystemExit("Remainder requires 32 pilot and 1,568 non-pilot jobs")
    pilot = ROOT / "results/pilot/completion.json"
    if not pilot.exists():
        raise SystemExit("Measured 32-attempt pilot receipt required first")
    pilot_receipt = json.loads(pilot.read_text())
    if pilot_receipt.get("attempts") != 32 or pilot_receipt.get("counts", {}).get("launched") != 32:
        raise SystemExit("Pilot receipt does not account for all 32 planned attempts")
    if pilot_receipt.get("fixture_manifest_sha256") != hashlib.sha256((fixtures / "manifest.json").read_bytes()).hexdigest():
        raise SystemExit("Pilot and remainder must use the same frozen fixture manifest")
    workers, total_seconds, per_attempt_seconds = 12, 7200, 840
else:
    if len(jobs) != 8:
        raise SystemExit("Engineering smoke must contain exactly eight attempts")
    workers, total_seconds, per_attempt_seconds = 4, 600, 540

with ledger.open() as handle:
    reader = csv.DictReader(handle)
    fields = reader.fieldnames
    rows = list(reader)
job_ids = {job["attempt_id"] for job in jobs}
if any(row["attempt_id"] in job_ids for row in rows):
    raise SystemExit(KIND + " fit attempts already recorded; no restart")
if KIND == "remainder":
    pilot_ids = {job["attempt_id"] for job in pilot_jobs}
    recorded_pilot_ids = {row["attempt_id"] for row in rows if row["attempt_id"] in pilot_ids}
    if recorded_pilot_ids != pilot_ids:
        raise SystemExit("Attempt ledger must retain each of the exact 32 pilot IDs")
output.mkdir(parents=True, exist_ok=False)
fixture_hash = hashlib.sha256((fixtures / "manifest.json").read_bytes()).hexdigest()
run_manifest = {
    "kind": KIND, "bundle_hash": bundle["bundle_hash"],
    "fixture_manifest_sha256": fixture_hash, "jobs": jobs,
    "attempt_ceiling": len(jobs), "total_seconds": total_seconds,
    "per_attempt_seconds": per_attempt_seconds, "workers": workers,
    "blas_threads": 1,
    "numerical_success": "one optimizer; convergence0; pdHess; finite objective/parameters/covariance/gradient; max gradient <= .01",
    "started": datetime.datetime.now(datetime.timezone.utc).isoformat(),
}
(output / "manifest.json").write_text(json.dumps(run_manifest, indent=2) + "\n")
lock = threading.Lock()
started = time.monotonic()
deadline = started + total_seconds

def flush():
    tmp = ledger.with_suffix(".tmp")
    with tmp.open("w") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader(); writer.writerows(rows); handle.flush(); os.fsync(handle.fileno())
    tmp.replace(ledger)

def run(job):
    if deadline - time.monotonic() <= 3:
        record = {"id": job["attempt_id"], "status": "not_launched_deadline", "job": job}
        (output / (job["attempt_id"] + "-not-launched.json")).write_text(json.dumps(record, indent=2) + "\n")
        return record
    dest = output / job["attempt_id"]
    dest.mkdir()
    command = ["/usr/bin/time", "-v", "-o", str(dest / "resources.txt"),
               "Rscript", "--vanilla", str(work / "fit-study.R"), str(ROOT),
               job["attempt_id"], str(dest), str(fixtures)]
    env = os.environ.copy()
    for key in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"):
        env[key] = "1"
    row = {
        "bucket": KIND, "attempt_id": job["attempt_id"],
        "candidate_hash": bundle["bundle_hash"], "fixture_hash": fixture_hash,
        "command": json.dumps(command), "seed": job["seed"],
        "regime": job["regime"], "mode": job["mode"], "rho": job["rho"],
        "method": job["method"], "status": "running", "elapsed_seconds": "",
        "evidence": str(dest.relative_to(ROOT)),
    }
    with lock:
        rows.append(row); flush()
    receipt = {
        "job": job, "command": command, "bundle_hash": bundle["bundle_hash"],
        "fixture_manifest_sha256": fixture_hash,
        "started": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }
    (dest / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    tick = time.monotonic(); process = None; status = "launch_error"; code = 1
    try:
        with (dest / "output.log").open("w") as log:
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                       env=env, start_new_session=True)
            try:
                code = process.wait(timeout=min(per_attempt_seconds, max(.01, deadline-time.monotonic()-3)))
                status = "finished" if code == 0 else "failed"
            except subprocess.TimeoutExpired:
                status = "timeout"; code = 124; os.killpg(process.pid, signal.SIGTERM)
                try: process.wait(timeout=2)
                except subprocess.TimeoutExpired: os.killpg(process.pid, signal.SIGKILL); process.wait()
    except BaseException as error:
        receipt["error"] = str(error)
        if process is not None and process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM); process.wait()
    elapsed = time.monotonic() - tick
    result_path = dest / "result.json"
    try: result = json.loads(result_path.read_text()) if result_path.exists() else {}
    except (OSError, json.JSONDecodeError): result = {}
    receipt["fit_status"] = result.get("status", "no_result")
    receipt["optimizer_entries"] = result.get("optimizer_entries")
    receipt["numerical_success"] = bool(code == 0 and result.get("numerical_success") is True and result.get("optimizer_entries") == 1)
    if result.get("status") == "returned" and not receipt["numerical_success"] and status != "timeout":
        status = "numerical_failure"
    with lock:
        row.update(status=status, elapsed_seconds=elapsed); flush()
    resource = dest / "resources.txt"
    match = re.search(r"Maximum resident set size \(kbytes\):\s*(\d+)", resource.read_text()) if resource.exists() else None
    receipt.update(status=status, exit_status=code, elapsed_seconds=elapsed,
                   peak_rss_kib=int(match.group(1)) if match else None)
    (dest / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    return {"id": job["attempt_id"], "status": status, "seconds": elapsed,
            "peak_rss_kib": receipt["peak_rss_kib"],
            "numerical_success": receipt["numerical_success"]}

results = []
with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
    for record in pool.map(run, jobs):
        results.append(record); print(json.dumps(record), flush=True)
receipts = [json.loads(path.read_text()) for path in output.glob("*/receipt.json")]
counts = {
    "planned": len(jobs), "launched": len(receipts),
    "returned": sum(r.get("fit_status") == "returned" for r in receipts),
    "numerical_success": sum(r.get("numerical_success", False) for r in receipts),
    "numerical_failure": sum(r.get("fit_status") == "returned" and not r.get("numerical_success", False) for r in receipts),
    "fit_errors": sum(r.get("fit_status") == "error" for r in receipts),
    "timeout": sum(r.get("status") == "timeout" for r in receipts),
    "optimizer_entry_violations": sum(r.get("optimizer_entries") is not None and r.get("optimizer_entries") != 1 for r in receipts),
    "missing_result": sum(r.get("fit_status") == "no_result" for r in receipts),
    "not_launched": sum(r.get("status") == "not_launched_deadline" for r in results),
}
completion = {"kind": KIND, "attempts": len(receipts), "seconds": time.monotonic()-started,
              "bundle_hash": bundle["bundle_hash"], "fixture_manifest_sha256": fixture_hash,
              "counts": counts,
              "peak_rss_kib": max((r.get("peak_rss_kib") or 0 for r in receipts), default=0)}
(output / "completion.json").write_text(json.dumps(completion, indent=2) + "\n")
print(json.dumps(completion), flush=True)
