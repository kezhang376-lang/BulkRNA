YYMM=20261018_xiehe_zhou
mian_dir=/home/zhangke/RNA-seq
data_dir=${mian_dir}/${YYMM}
raw_data=${mian_dir}/${YYMM}/raw_data
clean_data=${mian_dir}/${YYMM}/clean_data
bam_data=${mian_dir}/${YYMM}/bam_data
qc_data=${mian_dir}/${YYMM}/qc_data
bed_insert=${mian_dir}/${YYMM}/bed_insert
gene_expr=${mian_dir}/${YYMM}/gene_expr
script_data=${mian_dir}/${YYMM}/script
bed_bam=${mian_dir}/${YYMM}/bed_bam
mkdir -p {${data_dir},${raw_data},${clean_data},${bam_data},${qc_data},${bed_insert},${bed_bam},${script_data},${gene_expr},${bed_bam}}
#人类参考基因组版本
#genome_ref=/home/zhangke/public_database/STAR_hg38_ref/ref_seq/Homo_sapiens.GRCh38.dna.primary_assembly.fa
#gnome_gtf=/home/zhangke/public_database/STAR_hg38_ref/ref_seq/Homo_sapiens.GRCh38.104.gtf
#genome_index=/home/zhangke/public_database/STAR_hg38_ref/index
#小鼠参考基因组
genome_ref=/home/zhangke/public_database/STAR_Mus_musculus_GRCm39/fasta_gtf/Mus_musculus.GRCm39.dna.primary_assembly.fa
gnome_gtf=/home/zhangke/public_database/STAR_Mus_musculus_GRCm39/fasta_gtf/Mus_musculus.GRCm39.109.gtf
genome_index=/home/zhangke/public_database/STAR_Mus_musculus_GRCm39/index
#蛇的参考基因版本
#genome_ref=/home/zhangke/public_database/snake_Naja_naja_genome_for_RNAseq/fasta_gtf/GCA_009733165.1_Nana_v5_genomic.fna
#gnome_gtf=/home/zhangke/public_database/snake_Naja_naja_genome_for_RNAseq/fasta_gtf/GCA_009733165.1_Nana_v5_genomic.gtf
#genome_index=/home/zhangke/public_database/snake_Naja_naja_genome_for_RNAseq/index
#调用脚本路径信息

fastp=/home/zhangke/soft/fastp_dir/fastp
start_fastp=/home/zhangke/soft/fastp_dir/start_fastp.py
fastp_config=/home/zhangke/soft/fastp_dir/Illumina_fastp.config
#fastp_config=/home/zhangke/soft/fastp_dir/Illumina_ATAC_fastp.config


###########################################################################################################

#fastp软件过滤低质量和接头
echo $(date)
echo "fastp start "
python ${start_fastp} -r ${raw_data}  -c ${clean_data} -f ${fastp_config}
echo $(date)
echo "fastp over "


#STAR比对分析，一定要核实fq数据是1，还是R1
echo $(date)
echo "STAR start "
ls ${clean_data}/*_*1.fq.gz |while read id
do
sample_name=$(basename $id _clean_1.fq.gz )
echo ${sample_name}
printf ${sample_name}"\t" >>${qc_data}/fastp_seq_data.txt
sed -n '5p;9p;12p;16p;20p;23p' ${clean_data}/${sample_name}_.json|awk -F "[:,]" '{print $2}'|xargs|awk '{printf "%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\n",$1/1000000000,$2*100,$3*100,$4/1000000000,$5*100,$6*100}' >>${qc_data}/fastp_seq_data.txt

mkdir -p ${bam_data}/${sample_name}
#STAR  --runThreadN 5 --genomeDir ${genome_index} --readFilesCommand zcat --readFilesIn ${clean_data}/${sample_name}_Rclean_1.fq.gz ${clean_data}/${sample_name}_Rclean_2.fq.gz --outFileNamePrefix ${bam_data}/${sample_name}/${sample_name} --outSAMtype BAM SortedByCoordinate --outBAMsortingThreadN 5 --quantMode TranscriptomeSAM  GeneCounts

zcat ${clean_data}/${sample_name}_clean_1.fq.gz >${clean_data}/${sample_name}_clean_1.fq
zcat ${clean_data}/${sample_name}_clean_2.fq.gz >${clean_data}/${sample_name}_clean_2.fq
STAR  --runThreadN 10 --genomeDir ${genome_index}  --readFilesIn ${clean_data}/${sample_name}_clean_1.fq ${clean_data}/${sample_name}_clean_2.fq --outFileNamePrefix ${bam_data}/${sample_name}/${sample_name} --outSAMtype BAM SortedByCoordinate --outBAMsortingThreadN 5 --quantMode TranscriptomeSAM  GeneCounts 
rm ${clean_data}/${sample_name}_clean_1.fq
rm ${clean_data}/${sample_name}_clean_2.fq
printf ${sample_name}"\t" >>${qc_data}/genome_map_data.txt
sed -n '6P;9P;24P;26P;29P;31P;33P' ${bam_data}/${sample_name}/${sample_name}Log.final.out|awk -F '|' '{print $2}'|xargs|awk '{printf ("%.2f\t%.2f(%.2f%)\t%.2f(%.2f%)\t%.2f(%.2f%)\n",$1/1000000,$2/1000000,$2/$1*100,($3+$4)/1000000,($3+$4)/$1*100,($5+$6+$7)/1000000,($5+$6+$7)/$1*100)}' >>${qc_data}/genome_map_data.txt
##基因测序饱和分析
for i in $(seq 0.1 0.1 1); do
    #echo "当前数值: $i"
    samtools view -h -b  -s ${i} ${bam_data}/${sample_name}/${sample_name}Aligned.sortedByCoord.out.bam >${bed_bam}/${sample_name}_${i}_bed.bam
    featureCounts -T 10 -p -t exon -g gene_id -a ${gnome_gtf} -o ${bed_bam}/${sample_name}_${i}_counts.txt ${bed_bam}/${sample_name}_${i}_bed.bam
    gene_num=$(tail -n +3 ${bed_bam}/${sample_name}_${i}_counts.txt|awk '$7>3'|wc -l )
    read_num=$(tail -n +2 ${bed_bam}/${sample_name}_${i}_counts.txt.summary|awk 'BEGIN{sum}{sum+=$2}END{print sum}')
    printf "${sample_name}\t${gene_num}\t${read_num}\n" >>${qc_data}/gene_reads_num.txt
done

done
echo $(date)
echo "STAR over "
multiqc -o ${qc_data} -n all_sample_STAR_summary  ${bam_data}/*/*Log.final.out
featureCounts -T 10 -p -t exon -g gene_id -a ${gnome_gtf} -o ${gene_expr}/all_sample_gene_featurecount ${bam_data}/*/*Aligned.sortedByCoord.out.bam
multiqc -o ${qc_data} -n all_sample_gene_featurecount_summary ${gene_expr}/all_sample_gene_featurecount.summary
less ${gene_expr}/all_sample_gene_featurecount|tail -n +2|cut -f 1,7-|sed "s#${bam_data}/##g"|sed 's/\/[^/]*Aligned.sortedByCoord.out.bam//g' > ${gene_expr}/all_sample_raw_count.txt

###统计转录组文库片段长度分布
ls ${bam_data}/*/*Aligned.toTranscriptome.out.bam |while read fd
do
sample=$(basename $fd Aligned.toTranscriptome.out.bam)
echo ${sample}
samtools view -@ 5 -q 2   ${fd} |awk -F'\t' 'function abs(x){return ((x < 0.0) ? -x : x)} {if(abs($9) <1000 && abs($9) >0) print $1"\t"abs($9)} ' >${bed_insert}/temp.txt
less ${bed_insert}/temp.txt|sort| uniq | cut -f 2|sort -n|uniq -c > ${bed_insert}/${sample}.fragment.length.lib
done
ls ${bed_insert}/*.fragment.length.lib |while read id
do
b_name=$(basename $id .fragment.length.lib )
sum=$(less ${id}|awk 'BEGIN{sum}{sum+=$1}END{print sum}')
less ${id} |awk -v sum=${sum} '{print $1/sum"\t"$2}' >${bed_insert}/${b_name}.fragment.length.grouprate.lib
done
ls ${bed_insert}/*.fragment.length.grouprate.lib |while read id
do
sampl_name=$(basename $id .fragment.length.grouprate.lib)
less ${id} |awk -v name=${sampl_name} '{print name"\t"$1"\t"$2}' >>${bed_insert}/Transcriptome_fragment_length_rate
done