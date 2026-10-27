"""Read-only post-run output audit. Does not launch R or alter remote results."""
import json
from pathlib import Path
import subprocess

REMOTE = r'''
import csv,datetime,hashlib,json,os,pathlib,subprocess
b=pathlib.Path('/home/zhangke/RNA-seq/20261027_xiehe_zhou/workflow/v1_test6_20261027_release')
runtime=json.loads((b/'runtime.json').read_text())
p=pathlib.Path(runtime['run_root']); s=p/'shell'
assert os.geteuid()==1482
status=json.loads((s/'status.json').read_text()); assert status['status']=='succeeded',status
manifest=json.loads((b/'MANIFEST.sha256.json').read_text())['files']
assert all(hashlib.sha256((b/f).read_bytes()).hexdigest()==h for f,h in manifest.items())
samples=list(csv.DictReader((b/'samples.tsv').open(),delimiter='\t')); ids=[x['sample_id'] for x in samples]
matrix=list(csv.reader((s/'counts/raw_counts.tsv').open(),delimiter='\t'))
assert matrix[0]==['gene_id']+ids
genes=set(); totals=[0]*len(ids)
for row in matrix[1:]:
 assert len(row)==len(ids)+1 and row[0] and row[0] not in genes
 genes.add(row[0]); assert all(x.isdecimal() for x in row[1:])
 totals=[a+int(v) for a,v in zip(totals,row[1:])]
assert genes and all(x>0 for x in totals)
assignment=list(csv.DictReader((s/'qc/assignment_summary.tsv').open(),delimiter='\t'))
assert [x['sample_id'] for x in assignment]==ids
assert [int(x['assigned_units']) for x in assignment]==totals
summary=[]
for row in samples:
 sid=row['sample_id']; fastp=json.loads((s/'qc'/f'{sid}.fastp.json').read_text())['summary']
 before,after=fastp['before_filtering'],fastp['after_filtering']
 assert before['total_reads']>=after['total_reads']>0
 assert before['total_reads']%2==after['total_reads']%2==0
 prefix=s/'bam'/sid/(sid+'.')
 bam=pathlib.Path(str(prefix)+'Aligned.sortedByCoord.out.bam')
 assert bam.is_file() and bam.stat().st_size>0
 assert pathlib.Path(str(bam)+'.bai').stat().st_size>0
 check=subprocess.run(['/miniconda3/bin/samtools','quickcheck','-v',str(bam)],capture_output=True,text=True)
 assert check.returncode==0,check.stdout+check.stderr
 star=json.loads((s/'qc'/f'{sid}.star.json').read_text())
 assert int(star['Number of input reads'])==after['total_reads']//2
 for mate in (1,2): assert (s/'clean'/f'{sid}_clean_{mate}.fq.gz').stat().st_size>0
 summary.append({'sample_id':sid,'raw_pairs':before['total_reads']//2,'clean_pairs':after['total_reads']//2,'raw_q30':before['q30_rate'],'clean_q30':after['q30_rate'],'unique_mapping':star['Uniquely mapped reads %'],'bam_bytes':bam.stat().st_size,'assigned_fragments':totals[ids.index(sid)],'assigned_fraction':float(assignment[ids.index(sid)]['assigned_fraction']),'bam_quickcheck':'passed','bam_check_stderr':check.stderr})
mq=s/'qc/multiqc/multiqc_report.html'; assert mq.stat().st_size>0
assert not (p/'analysis').exists() and not (p/'launcher/r.launch.json').exists()
commands=[json.loads(x) for x in (s/'commands.jsonl').read_text().splitlines()]
tools=[pathlib.Path(x['argv'][0]).name for x in commands]
assert tools.count('fastp')==6 and tools.count('STAR')==6 and tools.count('samtools')==12 and tools.count('featureCounts')==1 and tools.count('multiqc')==1
assert (s/'counts/featurecounts.txt.summary').stat().st_size>0
print(json.dumps({'audit_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'shell_outputs_verified','run_id':runtime['run_id'],'shell_status':status,'uid':os.geteuid(),'gene_rows':len(genes),'sample_columns':ids,'samples':summary,'tool_command_counts':{t:tools.count(t) for t in sorted(set(tools))},'raw_counts_sha256':hashlib.sha256((s/'counts/raw_counts.tsv').read_bytes()).hexdigest(),'multiqc_bytes':mq.stat().st_size,'r_started':False,'note':'BAM quickcheck/index presence verified; this is not exhaustive BAM/FASTQ full-stream validation or a biological conclusion.'},indent=2))
'''

command = ['kubectl','--context','zhangke@med.thu','--namespace','renkelab-zhangke',
           'exec','-i','zk1-med-6ff4f46898-rlbtd','-c','zk250904-container',
           '--','runuser','-u','zhangke','--','python3','-']
if __name__ == '__main__':
    result=subprocess.run(command,input=REMOTE,text=True,capture_output=True,timeout=120)
    print(result.stdout)
    if result.stderr: print(result.stderr)
    if result.returncode: raise SystemExit(result.returncode)
    audit=json.loads(result.stdout)
    (Path(__file__).parent/'shell_final_audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
