#!/usr/bin/env python3
"""Summarize retained CSVs without dropping failed arms or missing intervals."""
import argparse, csv, json, math
from collections import defaultdict, Counter
from pathlib import Path

TAUS = ('Inf','1','2','4')
def number(x):
    try:
        v=float(x)
        return v if math.isfinite(v) else None
    except (ValueError,TypeError): return None
def yes(x): return str(x).lower() in ('true','1')
def mean(x): return sum(x)/len(x) if x else None
def sd(x):
    if len(x)<2:return None
    m=mean(x)
    return math.sqrt(sum((v-m)**2 for v in x)/(len(x)-1))
def stats(x):
    s=sd(x)
    return {'n':len(x),'mean':mean(x),'sd':s,'mcse':s/math.sqrt(len(x)) if s is not None else None}
def proportion(k,n):
    if not n:return {'estimate':None,'mcse':None,'wilson_lower':None,'wilson_upper':None}
    p=k/n; z=1.959963984540054; den=1+z*z/n
    mid=(p+z*z/(2*n))/den; half=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/den
    return {'estimate':p,'mcse':math.sqrt(p*(1-p)/n),'wilson_lower':mid-half,'wilson_upper':mid+half}
def errorsummary(errors):
    sq=[e*e for e in errors]; mse=stats(sq); rmse=math.sqrt(mse['mean']) if sq else None
    return {'valid_point_n':len(errors),'bias':mean(errors),'bias_mcse':stats(errors)['mcse'],'mse':mse['mean'],'mse_mcse':mse['mcse'],'rmse':rmse,'rmse_mcse_delta':mse['mcse']/(2*rmse) if rmse and mse['mcse'] is not None else None}
def cell(r):return (r['family'],int(r['n']),float(r['strength']),r['tau'])
def base(k):return dict(zip(('family','n','strength','tau'),k))
def dumpcsv(path,rows):
    fields=list(dict.fromkeys(k for r in rows for k in r))
    with path.open('w',newline='') as f:
        w=csv.DictWriter(f,fields);w.writeheader();w.writerows(rows)
def flatten(prefix,d):return {prefix+'_'+k:v for k,v in d.items()}
def paired_rmse(a,b):
    # Delta method on the paired mean squared errors, preserving covariance.
    if not a:return {'difference':None,'mcse_delta':None}
    ra=math.sqrt(mean([x*x for x in a])); rb=math.sqrt(mean([x*x for x in b]))
    influence=[(x*x-ra*ra)/(2*ra)-(y*y-rb*rb)/(2*rb) for x,y in zip(a,b)] if ra and rb else []
    return {'difference':ra-rb,'mcse_delta':stats(influence)['mcse']}
def summarize(root,partial=False):
    arms={}; effects={}; groups=defaultdict(list); egroups=defaultdict(list); audit=[]
    for p in sorted((root/'results').glob('task-*/arm-*.csv')):
        if partial and not p.with_name(p.name.replace('arm-','result-')).with_suffix('.rds').exists():continue
        for r in csv.DictReader(p.open()):
            key=(int(r['task']),r['tau'])
            if key in arms:raise ValueError('Duplicate arm '+str(key))
            if r['tau'] not in TAUS:raise ValueError('Unknown tau')
            arms[key]=r;groups[cell(r)].append(r)
    for p in sorted((root/'results').glob('task-*/effects-*.csv')):
        for r in csv.DictReader(p.open()):
            key=(int(r['task']),r['tau'],r['trait'])
            if partial and key[:2] not in arms:continue
            if key in effects:raise ValueError('Duplicate effect '+str(key))
            if key[:2] in arms and cell(r)!=cell(arms[key[:2]]):raise ValueError('Effect/arm cell mismatch '+str(key))
            effects[key]=r;egroups[cell(r)+(r['trait'],)].append(r)
    manifest_path=root/'task-manifest.csv'
    if manifest_path.exists():
        manifest={}
        for r in csv.DictReader(manifest_path.open()):
            task=int(r['task'])
            if task in manifest:raise ValueError('Duplicate manifest task')
            manifest[task]=r
        for r in list(arms.values())+list(effects.values()):
            task=int(r['task']);tau=r['tau']
            if task not in manifest:raise ValueError('Arm task absent from manifest '+str(task))
            for field in ('task','family','n','strength','rep','data_seed','init_seed'):
                if field in r and field in manifest[task]:
                    a=r[field];b=manifest[task][field]
                    if (number(a)!=number(b) if field!='family' else a!=b):raise ValueError('Manifest mismatch '+str((task,tau,field)))
    elif not partial:raise ValueError('Missing task-manifest.csv')
    for (task,tau),r in arms.items():
        if (task,'Inf') in arms:
            ref=arms[task,'Inf']
            if cell(r)[:3]!=cell(ref)[:3] or r['rep']!=ref['rep']:raise ValueError('Paired reference cell mismatch '+str((task,tau)))
    expected={(f,n,s,t) for f in ('binomial','gaussian','poisson') for n in (100,400) for s in (.5,2.) for t in TAUS}
    if not partial and len({k[0] for k in arms})!=6000:raise ValueError('Wrong dataset count')
    if not partial and any(sum((t,tau) in arms for tau in TAUS)!=4 for t in {k[0] for k in arms}):raise ValueError('Incomplete paired dataset')
    if not partial and (set(groups)!=expected or len(arms)!=24000 or any(len(x)!=500 for x in groups.values())):raise ValueError('Incomplete campaign; use --partial for interim summary')
    for key in arms:
        rs=[effects.get(key+(t,)) for t in ('t1','t2','t3','t4','t5','t6')]
        if any(x is None for x in rs):audit.append('missing effect rows '+str(key))
    if set(k[:2] for k in effects)-set(arms):audit.append('effects without arms')
    if not partial and (audit or len(effects)!=144000):raise ValueError(str(audit or 'Wrong effect count'))
    truth_by_target=defaultdict(set)
    for r in effects.values():truth_by_target[cell(r)[:3]+(r['trait'],)].add(number(r.get('truth')))
    if any(None in x or len(x)!=1 for x in truth_by_target.values()):raise ValueError('Truth differs across paired taus')
    recovery=[]
    excluded={'task','rep','n','strength','tau','convergence','pdHess','intervals_available','curvature_matches'}
    metrics=sorted({k for r in arms.values() for k,v in r.items() if k not in excluded and number(v) is not None})
    for k,rs in sorted(groups.items()):
        out=base(k);out.update(attempt_n=len(rs),fit_errors=sum(bool(r.get('fit_error')) for r in rs),convergence0=sum(number(r.get('convergence'))==0 for r in rs),npd=sum(str(r.get('pdHess')).lower()=='false' for r in rs),pdHess_unavailable=sum(str(r.get('pdHess')).lower() not in ('true','false') for r in rs),all_six_intervals_available=sum(number(r.get('intervals_available'))==6 for r in rs))
        curvature=[str(r.get('curvature_matches','')).lower() for r in rs]
        out.update(curvature_matches_true=sum(v=='true' for v in curvature),curvature_matches_false=sum(v=='false' for v in curvature),curvature_matches_unavailable=sum(v not in ('true','false') for v in curvature))
        for metric in metrics:
            vals=[number(r.get(metric)) for r in rs]; finite=[v for v in vals if v is not None]
            out.update(flatten(metric,stats(finite)));out[metric+'_unavailable']=len(rs)-len(finite)
        recovery.append(out)
    effectrows=[]
    for k,rs in sorted(egroups.items()):
        out=base(k[:4]);out.update(target=k[4],primary=k[4] in ('t1','t3','t4'),attempt_n=len(groups[k[:4]]),effect_rows=len(rs))
        truths={number(r.get('truth')) for r in rs}
        if None in truths or len(truths)!=1:raise ValueError('Inconsistent truth '+str(k))
        truth=next(iter(truths));out['truth']=truth
        if k[4]=='t3' and abs(truth)>1e-12:raise ValueError('Zero target is not zero')
        errors=[number(r['estimate'])-truth for r in rs if number(r.get('estimate')) is not None]
        out.update(errorsummary(errors));out['point_unavailable']=out['attempt_n']-len(errors)
        eligible=[r for r in rs if yes(r.get('available')) and number(r.get('lower')) is not None and number(r.get('upper')) is not None]
        covered=sum(float(r['lower'])<=truth<=float(r['upper']) for r in eligible)
        eligible_est=[number(r.get('estimate')) for r in eligible if number(r.get('estimate')) is not None]
        reported_sd=[number(r.get('std.error')) for r in eligible if number(r.get('std.error')) is not None]
        empirical_all=sd([e+truth for e in errors]); empirical_eligible=sd(eligible_est)
        mean_sd=mean(reported_sd);rms_sd=math.sqrt(mean([v*v for v in reported_sd])) if reported_sd else None
        out.update(interval_below_truth_n=sum(float(r['upper'])<truth for r in eligible),interval_above_truth_n=sum(float(r['lower'])>truth for r in eligible),empirical_estimator_sd_all_point=empirical_all,empirical_estimator_sd_eligible=empirical_eligible,reported_sd_eligible_n=len(reported_sd),mean_reported_sd_eligible=mean_sd,rms_reported_sd_eligible=rms_sd,mean_reported_sd_over_empirical_estimator_sd_eligible=mean_sd/empirical_eligible if mean_sd is not None and empirical_eligible else None,rms_reported_sd_over_empirical_estimator_sd_eligible=rms_sd/empirical_eligible if rms_sd is not None and empirical_eligible else None)
        out.update(eligible_interval_n=len(eligible),interval_unavailable=out['attempt_n']-len(eligible),covered_n=covered,mean_width_eligible=mean([float(r['upper'])-float(r['lower']) for r in eligible]))
        out.update(flatten('conditional_coverage',proportion(covered,len(eligible))));out.update(flatten('all_attempt_covered_fraction',proportion(covered,out['attempt_n'])))
        effectrows.append(out)
    paired=[]
    for k,rs in sorted(groups.items()):
        if k[3]=='Inf':continue
        tasks=[int(r['task']) for r in rs]; matched=[t for t in tasks if (t,'Inf') in arms]
        for metric in ['Sigma_total_relative_F','prediction_mean_RMSE','t1','t3','t4']:
            out=base(k);out.update(metric=metric,attempt_n=len(tasks),matched_arm_n=len(matched),missing_reference_arm_n=len(tasks)-len(matched));a=[];b=[];successdiff=[];coverdiff=[]
            for t in matched:
                if metric.startswith('t'):
                    x=effects.get((t,k[3],metric),{});y=effects.get((t,'Inf',metric),{})
                    xv=number(x.get('estimate'));yv=number(y.get('estimate'));truth=number(x.get('truth'))
                    successdiff.append(int(yes(x.get('available')))-int(yes(y.get('available'))))
                    def covered_indicator(r):
                        lo=number(r.get('lower'));hi=number(r.get('upper'));tr=number(r.get('truth'))
                        return int(yes(r.get('available')) and lo is not None and hi is not None and tr is not None and lo<=tr<=hi)
                    coverdiff.append(covered_indicator(x)-covered_indicator(y))
                    if xv is not None and yv is not None and truth is not None:a.append(xv-truth);b.append(yv-truth)
                else:
                    xv=number(arms[t,k[3]].get(metric));yv=number(arms[t,'Inf'].get(metric));successdiff.append(int(xv is not None)-int(yv is not None))
                    if xv is not None and yv is not None:a.append(xv);b.append(yv)
            out.update(finite_pair_n=len(a),dropped_pair_n=len(tasks)-len(a));out.update(flatten('all_attempt_availability_difference',stats(successdiff)));
            if metric.startswith('t'):out.update(flatten('all_attempt_covered_indicator_difference',stats(coverdiff)))
            out.update(flatten('paired_mean_difference',stats([x-y for x,y in zip(a,b)])))
            if metric.startswith('t'):out.update(flatten('paired_rmse',paired_rmse(a,b)))
            paired.append(out)
    output=root/'summary';output.mkdir(exist_ok=True)
    dumpcsv(output/'recovery.csv',recovery);dumpcsv(output/'effects.csv',effectrows);dumpcsv(output/'paired-vs-Inf.csv',paired)
    summary={'partial':partial,'arm_n':len(arms),'dataset_n':len({k[0] for k in arms}),'effect_n':len(effects),'recovery_rows':len(recovery),'effect_summary_rows':len(effectrows),'paired_rows':len(paired),'fit_errors':sum(bool(r.get('fit_error')) for r in arms.values()),'error_status_counts':dict(Counter(r.get('errors','') or 'none' for r in arms.values())),'uncertainty_status_counts':dict(Counter(r.get('uncertainty_status','') for r in effects.values())),'fit_error_messages':dict(Counter(r.get('fit_error','') for r in arms.values() if r.get('fit_error'))),'audit':audit,'metric_columns':metrics,'notes':['Point estimates are not filtered by convergence.','Conditional coverage uses available finite-bound intervals, without a convergence filter; it is conditional on interval availability.','All-attempt coverage counts unavailable intervals as not covered; it is operational availability times conditional coverage.','Runtime metadata must be reported separately from per-fit elapsed values.','Paired RMSE differences use common finite pairs and a covariance-preserving delta-method MCSE.']}
    (output/'summary.json').write_text(json.dumps(summary,indent=2,allow_nan=False)+'\n');print(json.dumps(summary,indent=2));return summary
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('root',type=Path);parser.add_argument('--partial',action='store_true');args=parser.parse_args();summarize(args.root,args.partial)
