import pathlib,subprocess,os,signal,time,json,sys,datetime,csv
root=pathlib.Path(sys.argv[1]).resolve();smoke=len(sys.argv)>2 and sys.argv[2]=='smoke'
workers=1 if smoke else 32
assert workers<=32 and workers<=150
(root/'logs').mkdir(exist_ok=True);(root/'progress').mkdir(exist_ok=True)
children={};start=time.monotonic();statuses=[]
meta={'pid':os.getpid(),'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'workers':workers,'mode':'smoke'if smoke else'full','cap_seconds':3600,'root':str(root)}
(root/('smoke-start.json'if smoke else'campaign-start.json')).write_text(json.dumps(meta,indent=2))
def cleanup():
 for p in children.values():
  if p.poll()is None:
   try:os.killpg(p.pid,signal.SIGTERM)
   except ProcessLookupError:pass
 for p in children.values():
  if p.poll()is None:
   try:p.wait(timeout=10)
   except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
def stop(sig,frame):cleanup();raise SystemExit(128+sig)
signal.signal(signal.SIGTERM,stop);signal.signal(signal.SIGINT,stop)
env=dict(os.environ,OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1',MKL_NUM_THREADS='1',VECLIB_MAXIMUM_THREADS='1',R_LIBS_USER=str(pathlib.Path.home()/'R/lib'))
try:
 for j in range(workers):
  name='smoke'if smoke else f'worker-{j+1:02d}'
  f=(root/'logs'/(name+'.log')).open('x')
  p=subprocess.Popen(['Rscript','--vanilla',str(root/'runner'/'campaign-task.R'),str(root),str(root/'chunks'/(name+'.txt'))],stdout=f,stderr=subprocess.STDOUT,env=env,start_new_session=True);f.close();children[name]=p
 print(json.dumps(meta),flush=True)
 lastprint=-60
 while children:
  now=time.monotonic();elapsed=now-start
  for name,p in list(children.items()):
   rc=p.poll()
   if rc is not None:statuses.append({'worker':name,'pid':p.pid,'returncode':p.wait(),'elapsed':elapsed});del children[name]
  if elapsed>3600:raise RuntimeError('60-minute estimate cap reached; stop and re-report')
  complete=set()
  for pp in (root/'progress').glob('*.csv'):
   with pp.open()as f:
    for row in csv.DictReader(f):
     if row.get('phase')in ('arm_complete','retained_arm'):complete.add((row['task'],row['tau']))
  state=dict(meta,elapsed_seconds=elapsed,active_workers=len(children),completed_arms=len(complete),worker_status=statuses)
  temp=root/'progress'/('smoke-status.tmp'if smoke else'status.tmp');temp.write_text(json.dumps(state,indent=2));temp.replace(root/'progress'/('smoke-status.json'if smoke else'status.json'))
  if elapsed-lastprint>=30 or not children:print(json.dumps({k:state[k]for k in ('elapsed_seconds','active_workers','completed_arms')}),flush=True);lastprint=elapsed
  if children:time.sleep(5)
finally:cleanup()
print('OWNED_CHILDREN_REAPED',len(children),flush=True)
if not all(x['returncode']==0for x in statuses):sys.exit(1)
