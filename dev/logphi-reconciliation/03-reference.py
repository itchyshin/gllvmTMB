import csv, mpmath as mp
mp.mp.dps = 60
D = "/private/tmp/gllvmtmb-logphi/dev/logphi-reconciliation"

def logphi(x):
    return mp.log(mp.ncdf(mp.mpf(x)))

# ---- pointwise ----
rows = list(csv.DictReader(open(D + "/grid.csv")))
agg = {}
for r in rows:
    x = mp.mpf(r["x"]); ref = logphi(x)
    for impl in ("ship", "va"):
        v = mp.mpf(r[impl])
        rel = abs(v - ref) / abs(ref) if ref != 0 else abs(v - ref)
        k = (r["region"], impl)
        cur = agg.get(k)
        if cur is None or rel > cur[0]:
            agg[k] = (rel, float(x), float(abs(v-ref)))
print("=== POINTWISE: max relative error in log Phi ===")
print(f"{'region':32s} {'ship rel':>11s} {'@x':>9s} {'va rel':>11s} {'@x':>9s}")
seen=[]
for r in rows:
    if r["region"] not in seen: seen.append(r["region"])
for reg in seen:
    s = agg[(reg,"ship")]; v = agg[(reg,"va")]
    print(f"{reg:32s} {float(s[0]):11.3e} {s[1]:9.2f} {float(v[0]):11.3e} {v[1]:9.2f}")
print()
print("=== POINTWISE: max ABSOLUTE error in log Phi (= rel err of the probability) ===")
aggA={}
for r in rows:
    x = mp.mpf(r["x"]); ref = logphi(x)
    for impl in ("ship","va"):
        e = abs(mp.mpf(r[impl]) - ref)
        k=(r["region"],impl)
        if k not in aggA or e>aggA[k][0]: aggA[k]=(e,float(x))
print(f"{'region':32s} {'ship abs':>11s} {'@x':>9s} {'va abs':>11s} {'@x':>9s}")
for reg in seen:
    s=aggA[(reg,"ship")]; v=aggA[(reg,"va")]
    print(f"{reg:32s} {float(s[0]):11.3e} {s[1]:9.2f} {float(v[0]):11.3e} {v[1]:9.2f}")

# ---- difference ----
print()
drows = list(csv.DictReader(open(D + "/diffs.csv")))
out=[]
for r in drows:
    a = mp.mpf(r["a"]); b = mp.mpf(r["b"])
    ref = mp.log(mp.ncdf(a) - mp.ncdf(b))
    rec = {"a":float(a),"gap":float(r["gap"]),"ref":float(ref)}
    for col in ("ship_diff","va_diff","ship_lss","va_lss"):
        v = r[col]
        if v in ("NA","NaN","-Inf","Inf"):
            rec[col]=float("nan"); continue
        v = mp.mpf(v)
        rec[col]=float(abs(v-ref)/abs(ref)) if ref!=0 else float(abs(v-ref))
    out.append(rec)
with open(D+"/diff_err.csv","w",newline="") as f:
    w=csv.DictWriter(f,fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)

print("=== DIFFERENCE: rel err of log(Phi(a)-Phi(b)) by gap, worst over a ===")
print(f"{'gap':>10s} {'gll_diff ship':>14s} {'gll_diff va':>14s} {'lsp_sub ship':>14s} {'lsp_sub va':>14s}  worst-a(ship_diff)")
gaps=[]
for r in out:
    if r["gap"] not in gaps: gaps.append(r["gap"])
for g in sorted(gaps):
    sub=[r for r in out if r["gap"]==g]
    def mx(c):
        vals=[(r[c],r["a"]) for r in sub if r[c]==r[c]]
        return max(vals) if vals else (float("nan"),0)
    a1=mx("ship_diff"); a2=mx("va_diff"); a3=mx("ship_lss"); a4=mx("va_lss")
    print(f"{g:10.0e} {a1[0]:14.3e} {a2[0]:14.3e} {a3[0]:14.3e} {a4[0]:14.3e}   {a1[1]:8.2f}")

print()
print("=== DIFFERENCE: rel err by a-region, worst over gap (gll_log_pnorm_diff, the shipped form) ===")
print(f"{'a':>8s} {'ship':>12s} {'va':>12s}   {'worst gap(ship)':>16s}")
as_=[]
for r in out:
    if r["a"] not in as_: as_.append(r["a"])
for a in sorted(as_, reverse=True):
    sub=[r for r in out if r["a"]==a]
    s=max((r["ship_diff"],r["gap"]) for r in sub if r["ship_diff"]==r["ship_diff"])
    v=max((r["va_diff"],r["gap"]) for r in sub if r["va_diff"]==r["va_diff"])
    print(f"{a:8.2f} {s[0]:12.3e} {v[0]:12.3e}   {s[1]:16.0e}")

print()
print("=== ABSOLUTE error in log-cell-probability (what enters the log-likelihood) ===")
outA=[]
for r in drows:
    a=mp.mpf(r["a"]); b=mp.mpf(r["b"])
    ref=mp.log(mp.ncdf(a)-mp.ncdf(b))
    e={"a":float(a),"gap":float(r["gap"])}
    for col in ("ship_diff","va_diff"):
        e[col]=float(abs(mp.mpf(r[col])-ref))
    outA.append(e)
print(f"{'gap':>10s} {'ship abs':>12s} {'@a':>8s} {'va abs':>12s} {'@a':>8s}")
for g in sorted(gaps):
    sub=[r for r in outA if r["gap"]==g]
    s=max((r["ship_diff"],r["a"]) for r in sub)
    v=max((r["va_diff"],r["a"]) for r in sub)
    print(f"{g:10.0e} {s[0]:12.3e} {s[1]:8.2f} {v[0]:12.3e} {v[1]:8.2f}")
