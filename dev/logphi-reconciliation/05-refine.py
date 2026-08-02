import csv, mpmath as mp
mp.mp.dps=60
D="/private/tmp/gllvmtmb-logphi/dev/logphi-reconciliation"
rows=list(csv.DictReader(open(D+"/diffs_dense.csv")))
print("=== DENSE a-sweep, REALISTIC cutpoint gaps only (0.05..3.0), a in [-45,10] step 0.005 ===")
print(f"{'gap':>6s} {'ship max|abs err|':>18s} {'@a':>8s} {'va max|abs err|':>18s} {'@a':>8s}")
gaps=sorted({float(r['gap']) for r in rows})
gmaxS=(0,0); gmaxV=(0,0)
for g in gaps:
    bS=(0,0); bV=(0,0)
    for r in rows:
        if float(r['gap'])!=g: continue
        a=mp.mpf(r['a']); b=mp.mpf(r['b'])
        ref=mp.log(mp.ncdf(a)-mp.ncdf(b))
        eS=float(abs(mp.mpf(r['ship'])-ref)); eV=float(abs(mp.mpf(r['va'])-ref))
        if eS>bS[0]: bS=(eS,float(a))
        if eV>bV[0]: bV=(eV,float(a))
    if bS[0]>gmaxS[0]: gmaxS=bS
    if bV[0]>gmaxV[0]: gmaxV=bV
    print(f"{g:6.2f} {bS[0]:18.3e} {bS[1]:8.2f} {bV[0]:18.3e} {bV[1]:8.2f}")
print(f"OVERALL  ship {gmaxS[0]:.3e} @a={gmaxS[1]:.2f}   va {gmaxV[0]:.3e} @a={gmaxV[1]:.2f}")

print()
print("=== ANALYTIC one-sided derivative of log Phi at each switch (d/dx, exact in 60 dp) ===")
def lam(x):
    x=mp.mpf(x); return mp.npdf(x)/mp.ncdf(x)
def ship_tail_deriv(x):
    x=mp.mpf(x)
    S = 1 - 1/x**2 + 3/x**4 - 15/x**6 + 105/x**8
    Sp = 2/x**3 - 12/x**5 + 90/x**7 - 840/x**9
    return -x - 1/x + Sp/S
def va_tail_deriv(x):
    z=-mp.mpf(x); K=20; c=mp.mpf(0)
    for k in range(K,0,-1): c=k/(z+c)
    return z+c   # d/dx log Phi(x) = inverse Mills = z + c  (exact identity)
for cut,name,f in ((-20,"shipped -20",ship_tail_deriv),(-10,"VA -10",va_tail_deriv)):
    t=f(cut); e=lam(cut)
    print(f"{name:14s} tail-branch f'={mp.nstr(t,17)}  exact lambda={mp.nstr(e,17)}"
          f"  jump={float(t-e):.3e}  rel={float((t-e)/e):.3e}")

print()
print("=== VALUE at each switch (60 dp reference) ===")
def ship_v(x):
    x=mp.mpf(x); S=1-1/x**2+3/x**4-15/x**6+105/x**8
    return -x*x/2 - mp.log(-x) - mp.log(mp.sqrt(2*mp.pi)) + mp.log(S)
def va_v(x):
    z=-mp.mpf(x); c=mp.mpf(0)
    for k in range(20,0,-1): c=k/(z+c)
    return -z*z/2 - mp.log(mp.sqrt(2*mp.pi)) - mp.log(z+c)
for cut,name,f in ((-20,"shipped -20",ship_v),(-10,"VA -10",va_v)):
    ref=mp.log(mp.ncdf(mp.mpf(cut)))
    print(f"{name:14s} truncation err (math, not float) = {float(f(cut)-ref):.3e}"
          f"   rel = {float((f(cut)-ref)/ref):.3e}")
