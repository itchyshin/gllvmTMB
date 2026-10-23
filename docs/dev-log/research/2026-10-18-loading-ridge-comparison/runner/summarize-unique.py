#!/usr/bin/env python3
"""Summarize separately retained public unique-variance recovery."""
import csv,math,sys
from pathlib import Path
from collections import defaultdict
root=Path(sys.argv[1]);groups=defaultdict(list)
for row in csv.DictReader((root/'summary/unique-recovery.csv').open()):groups[tuple(row[k]for k in ('family','n','strength','tau'))].append(row)
assert len(groups)==48 and all(len(v)==500 for v in groups.values())
out=[]
for key,rows in sorted(groups.items()):
 r=dict(zip(('family','n','strength','tau'),key));r['attempt_n']=len(rows)
 for metric in ('derived_unique_relative_F','derived_unique_diag_RMSE','derived_unique_offdiag_RMSE'):
  values=[]
  for x in rows:
   try:v=float(x[metric])
   except(ValueError,TypeError):continue
   if math.isfinite(v):values.append(v)
  n=len(values);m=sum(values)/n if n else None
  r[metric+'_n']=n;r[metric+'_unavailable']=len(rows)-n;r[metric+'_mean']=m
  r[metric+'_mcse']=math.sqrt(sum((v-m)**2 for v in values)/(n-1)/n)if n>1 else None
 out.append(r)
with(root/'summary/unique-recovery-summary.csv').open('w')as f:
 w=csv.DictWriter(f,list(out[0]));w.writeheader();w.writerows(out)
print('48 unique-recovery cells, 500 retained attempts each')
