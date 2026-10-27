"""Read-only observer for the authorized Shell run; never launches/restarts analysis."""
import json
from pathlib import Path
import subprocess
import time

REMOTE = r'''
import datetime,json,os,pathlib
p=pathlib.Path('/home/zhangke/RNA-seq/20261027_xiehe_zhou/results/runs/v1_test6_20261027_release')
s=p/'shell'
state=json.loads((s/'status.json').read_text()) if (s/'status.json').exists() else {'status':'starting'}
commands=[json.loads(x) for x in (s/'commands.jsonl').read_text().splitlines()] if (s/'commands.jsonl').exists() else []
last=commands[-1] if commands else {}
reports=sorted(x.name for x in (s/'qc').glob('*.fastp.json'))
bams=sorted(str(x.relative_to(s)) for x in (s/'bam').glob('*/*.bam.bai'))
logs=sorted((s/'logs').glob('*.log'),key=lambda x:x.stat().st_mtime)
tail=logs[-1].read_text(errors='replace').splitlines()[-7:] if logs else []
launch=json.loads((p/'launcher/shell.launch.json').read_text())
pid=launch['pid']
proc=pathlib.Path('/proc')/str(pid)
detail={}
if proc.exists():
 detail={'cmdline':(proc/'cmdline').read_bytes().replace(b'\0',b' ').decode(errors='replace'),'state':(proc/'stat').read_text().split()[2]}
out={'observed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'uid':os.geteuid(),'status':state,'pid':pid,'process':detail,'last_command':last,'fastp_reports':reports,'indexed_bams':bams,'latest_log':str(logs[-1]) if logs else None,'log_tail':tail,'r_output_exists':(p/'analysis').exists()}
print(json.dumps(out))
'''

def main():
    folder = Path(__file__).resolve().parent
    command = ['kubectl', '--context', 'zhangke@med.thu', '--namespace', 'renkelab-zhangke',
               'exec', '-i', 'zk1-med-6ff4f46898-rlbtd', '-c', 'zk250904-container',
               '--', 'runuser', '-u', 'zhangke', '--', 'python3', '-']
    failures = 0
    while True:
        result = subprocess.run(command, input=REMOTE, text=True, capture_output=True, timeout=40)
        if result.returncode:
            failures += 1
            print(json.dumps({'observer_connection_error': result.stderr, 'consecutive_errors': failures}), flush=True)
            if failures >= 3:
                raise SystemExit('Observer stopped; remote worker was not touched')
        else:
            failures = 0
            state = json.loads(result.stdout)
            (folder/'shell_observation.latest.json').write_text(json.dumps(state, indent=2), encoding='utf-8')
            with (folder/'shell_observations.jsonl').open('a', encoding='utf-8') as stream:
                stream.write(json.dumps(state)+'\n')
            print(json.dumps(state), flush=True)
            if state['status']['status'] in ('succeeded', 'failed'):
                return
            if not state['process'] or state['process']['state'] == 'Z':
                raise SystemExit('Worker absent/zombie without terminal status; inspect, do not restart')
        time.sleep(45)

if __name__ == '__main__':
    main()
