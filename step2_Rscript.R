library(dplyr)
library(limma)
library(edgeR)
library(DESeq2)
library(FactoMineR)
library(factoextra)
library(clusterProfiler)
library(pheatmap)
library(org.Hs.eg.db)
library(org.Mm.eg.db)
library(ggpubr)
library(tidyr)

rm(list = ls())

#######################################过滤重复
RNA_dir <- "D:/work/sharedata/RNAseq/qinghua-FYX"

dir.create(sprintf("%s/gene_expression_csv_data",RNA_dir))
dir.create(sprintf("%s/GO_enrichment",RNA_dir))
dir.create(sprintf("%s/diff_expr_gene",RNA_dir))
setwd(RNA_dir)
options(stringsAsFactors = F)
library(stringr)

# 读取raw count表达矩阵
rawcount <- read.table("all_sample_raw_count.txt",row.names = 1, 
                       sep = "\t", header = T)
#rawcount <-rawcount[,c(10:18)]
colnames(rawcount) <-gsub('[.]','_',colnames(rawcount))
#colnames(rawcount) <-gsub('X','',colnames(rawcount))
boxplot(rawcount,outline = F)
# 查看表达谱
# 获取分组信息
group <- read.table("sample_list_RNAseq.csv",
                    header =F ,sep = ",")
colnames(group) <- c("sample","group")
group_list <- as.factor(group$group) 

## =================== 2.表达矩阵预处理
# 过滤低表达基因
# 1.过滤在至少在75%的样本中都不表达的基因
# 2.过滤平均值count<10的基因
# 3.过滤平均cpm <10 的基因

keep <- rowSums(rawcount>0) >= floor(0.75*ncol(rawcount))
table(keep)

filter_count <- rawcount[keep,]
filter_count[1:4,1:4]
dim(filter_count)
boxplot(filter_count,outline = F)
# edgeR包计算counts per millio(cpm) 表达矩阵,并对结果取log2值

express_cpm <- log2(cpm(filter_count)+ 1)
#express_cpm[1:6,1:9]
boxplot(express_cpm,outline = F)

# 统计表达量值的分布
exprset_state <- apply(express_cpm,2,summary)
exprset_state <- data.frame(t(exprset_state))
exprset_state$gene <- apply(express_cpm, 2, function(x) sum(x > 0))

exprset_state <- exprset_state[,c(7,2:6)]

write.csv(exprset_state,sprintf("%s/exprset_state.csv",RNA_dir)) 


###统计表达分布
exprSet <- express_cpm
#exprSet[1:6,1:9]

# 样本表达总体分布-箱式图
library(ggplot2)
# 构造绘图数据
data <- data.frame(expression=c(exprSet),
                   sample=rep(colnames(exprSet),each=nrow(exprSet)))
head(data)

p <- ggplot(data = data,aes(x=sample,y=expression,fill=sample))
p1 <- p + geom_boxplot() + theme(plot.title = element_text(hjust = 0.5 , size = 20),
                                 axis.title.x = element_text(size = 20),
                                 axis.title.y = element_text(size = 20),
                                 axis.text = element_text(size = 20),
                                 legend.text = element_text(size = 20),
                                 axis.text.x = element_text(angle = 90),
                                 legend.position = "none") + 
  xlab(NULL) + ylab("log2(CPM+1)")
p1


# 保存图片
png(file = sprintf("%s/sample_boxplot.png",RNA_dir),width = 800,height = 600)
print(p1)
dev.off()


# 样本表达总体分布-小提琴图
p2 <- p + geom_violin() + 
  theme(plot.title = element_text(hjust = 0.5 , size = 20),
        axis.title.x = element_text(size = 20),
        axis.title.y = element_text(size = 20),
        axis.text = element_text(size = 20),
        legend.text = element_text(size = 20),
        axis.text.x = element_text(angle = 90),
        legend.position = "none")  + 
  xlab(NULL) + ylab("log2(CPM+1)")
p2

# 保存图片
png(file = sprintf("%s/sample_violin.png",RNA_dir),width = 800,height = 600)
print(p2)
dev.off()

## 3.样本之间的相关性-cor----
exprSet <- express_cpm

library(corrplot)
dim(exprSet)
# 计算相关性
M <- cor(exprSet)

# 绘制样本相关性的热图
library(pheatmap)
anno <- data.frame(sampleType=group$group)
rownames(anno) <- colnames(exprSet)
anno

p <- pheatmap::pheatmap(M,display_numbers = T,
                        annotation_col = anno,
                        cluster_rows = T,
                        cluster_cols = F,
                        fontsize = 18)


p
png(file = sprintf("%s/sample_cor_heatmap.png",RNA_dir),width = 1200,height = 1000)
print(p)
dev.off()




#####################################################################################################################

#DESeq2基因表达差异分析步骤：

#1.构建DESeq2的DESeq对象

#2.进行差异表达分析

#3.提取差异分析结果，trt组对untrt组的差异分析结果

exprSet <- filter_count
dim(exprSet)
#exprSet[1:6,1:6]
table(group_list)

#读取分组信息


sample_treat_control  <- read.table("sample_group.csv",
                    header =F ,sep = ",")
colnames(sample_treat_control) <- c("group1","group2","treat","control")

# 第一步，构建DESeq2的DESeq对象
colData <- data.frame(row.names=colnames(exprSet), 
                      group_list=as.factor(group_list))
colData

dds <- DESeqDataSetFromMatrix(countData = exprSet,
                              colData = colData,
                              design = ~ group_list)

# 第二步，进行差异表达分析
dds2 <- DESeq(dds)
norm_counts <- counts(dds2, normalized = TRUE)#获取标准化 counts

# 提取差异分析结果，trt组对untrt组的差异分析结果
#fc_cutoff <- 1.5
fc_cutoff <- 1.5
#pvalue <- 0.05
pvalue <- 0.01

gene_num_data <- data.frame(treat=character(),control=character(),normal= integer(0),up=integer(0),down=integer(0))


for(i in 1:nrow(sample_treat_control)){
  # 获取对照组和处理组样本的索引
  treatment_samples <-rownames(colData)[colData$group_list == sample_treat_control[i,3]] 
  control_samples <- rownames(colData)[colData$group_list == sample_treat_control[i,4]] 
  # 计算各组的标准化平均表达量
  control_mean <- rowMeans(norm_counts[, control_samples, drop=FALSE])
  treatment_mean <- rowMeans(norm_counts[, treatment_samples, drop=FALSE])
 
  tmp <- results(dds2,contrast=c("group_list",sample_treat_control[i,3],sample_treat_control[i,4]))
  #将其添加到 DESeq2 结果中
  tmp$control_mean <- control_mean[rownames(tmp)]
  tmp$treatment_mean <- treatment_mean[rownames(tmp)]
  
  
  DEG_DESeq2 <- as.data.frame(tmp[order(tmp$padj),])
  DEG_DESeq2 = na.omit(DEG_DESeq2)#去除差异分析结果中包含NA值的行
  DEG_DESeq2$regulated <- "normal"
  loc_up <- intersect(which(DEG_DESeq2$log2FoldChange>log2(fc_cutoff)),
                      #which(DEG_DESeq2$padj<pvalue))
                      which(DEG_DESeq2$pvalue<pvalue))
  loc_down <- intersect(which(DEG_DESeq2$log2FoldChange< (-log2(fc_cutoff))),
                        #which(DEG_DESeq2$padj<pvalue))
                        which(DEG_DESeq2$pvalue<pvalue))
  
  DEG_DESeq2$regulated[loc_up] <- "up"
  DEG_DESeq2$regulated[loc_down] <- "down"
  DEG_DESeq2$regulated <- factor(DEG_DESeq2$regulated, levels=c("normal","up","down"))
  
  id2symbol <- bitr(rownames(DEG_DESeq2), 
                    fromType = "ENSEMBL", toType = "SYMBOL", 
                    OrgDb = org.Mm.eg.db )
#  id2symbol <- bitr(rownames(DEG_DESeq2), 
#                    fromType = "ENSEMBL", toType = "SYMBOL", 
#                    OrgDb = org.Hs.eg.db )  
  
  
  
  DEG_DESeq2 <- cbind(GeneID=rownames(DEG_DESeq2),DEG_DESeq2)
  DEG_DESeq2_symbol <- merge(id2symbol,DEG_DESeq2,by.x="ENSEMBL",by.y="GeneID",all.y=T)
  DEG_DESeq2 <- DEG_DESeq2_symbol[,c(1,2,10,9,4,7,8,11)]
  new_row <- data.frame(treat=sample_treat_control[i,1],control=sample_treat_control[i,2],
                        normal= table(DEG_DESeq2$regulated)[[1]],up=table(DEG_DESeq2$regulated)[[2]],down=table(DEG_DESeq2$regulated)[[3]])
  gene_num_data <-rbind(gene_num_data, new_row)
  
  
  write.csv(DEG_DESeq2,sprintf("%s/gene_expression_csv_data/treatment_%s_vs_control_%s_gene_expression.csv",
                               RNA_dir,sample_treat_control[i,1],sample_treat_control[i,2]), row.names = F)
  #绘制差异基因的火山图
  #colnames(DEG_DESeq2)
  #p_v <- ggplot(data=DEG_DESeq2, aes(x=log2FoldChange, y=-log10(padj),color=regulated)) + 
  #  geom_point(alpha=0.5, size=1.8) + 
  #  geom_hline(yintercept = -log10(0.05), linetype = "dashed", color = "black")+
  #  geom_vline(xintercept = -1, linetype = "dashed", color = "black")+
  #  geom_vline(xintercept = 1, linetype = "dashed", color = "black")+
  #  scale_colour_manual(values = c('grey','red','blue'))+
  #  labs(x ="log2FC",y= "-log10(padj)",title =sprintf("treatment_%s vs control_%s gene expression", sample_treat_control[i,1],sample_treat_control[i,2]) )+
  # theme_bw()+theme(plot.title = element_text(hjust = 0.5 , size = 20),
  #                   axis.title.x = element_text(size = 20),
  #                   axis.title.y = element_text(size = 20),
  #                   axis.text = element_text(size = 15),
  #                   legend.text = element_text(size = 15),
  #                   legend.title = element_text(size = 20))
 
   count_table <- table(DEG_DESeq2$regulated)  
  
  label_map <- c(
    'up' = sprintf('up (n=%d)', ifelse('up' %in% names(count_table), count_table['up'], 0)),
    'down' = sprintf('down (n=%d)', ifelse('down' %in% names(count_table), count_table['down'], 0)),
    'normal' = sprintf('normal (n=%d)', ifelse('normal' %in% names(count_table), count_table['normal'], 0))
  )
  
  # 绘图
  p_v <- ggplot(data=DEG_DESeq2, aes(x=log2FoldChange, y=-log10(pvalue), color=regulated)) + 
    geom_point(alpha=0.5, size=1.8) + 
    geom_hline(yintercept = -log10(0.01), linetype = "dashed", color = "black") +
    geom_vline(xintercept = c(-0.5849625, 0.5849625), linetype = "dashed", color = "black") +
    scale_colour_manual(
      values = c('normal'='grey', 'up'='red', 'down'='blue'),
      labels = label_map
    ) +
    labs(
      x = "log2FC",
      y = "-log10(padj)",
      title = sprintf("treatment_%s vs control_%s gene expression",
                      sample_treat_control[i,1], sample_treat_control[i,2]),
      color = NULL  # 不显示“regulated”作为图例标题
    ) +
    theme_bw() +
    theme(
      plot.title = element_text(hjust = 0.5 , size = 20),
      axis.title.x = element_text(size = 20),
      axis.title.y = element_text(size = 20),
      axis.text = element_text(size = 15),
      legend.text = element_text(size = 15),
      legend.title = element_blank()  # 同样确保不显示标题
    )
  
  png(file = sprintf("%s/gene_expression_csv_data/treatment_%s_vs_control_%s_gene_expression_Volcano_Plot.png",
                     RNA_dir,sample_treat_control[i,1],sample_treat_control[i,2]),width = 800,height = 600)
  print(p_v)
  dev.off()
 
  
}

write.csv(gene_num_data,sprintf("%s/gene_expression_diff_num_data.csv",RNA_dir),row.names = F)


###################
###差异基因的GSEA富集分析

file_list <- list.files(path = sprintf("%s/gene_expression_csv_data",RNA_dir), pattern = "*.csv", full.names = TRUE)
data_list <- lapply(file_list, read.csv)
data_list <- setNames(lapply(file_list, read.csv), 
                      nm = lapply( basename(file_list),function(x) gsub(".csv$", "", x))
)

#View(data_list[["D.FD.C_gene"]])
#for (i in seq_along(data_list)) {
for (i in 1:length(data_list)) {
  #print(i)
  #i = 3
  sample_name = names(data_list)[i]
  current_data <- data_list[[i]]
  print(paste("处理第", i, "组数据:"))
  
  current_data <- current_data[order(current_data$log2FoldChange, decreasing = T),]
  geneList <- current_data$log2FoldChange
  
  names(geneList) <- current_data$ENSEMBL
  sum(is.na(current_data$ENSEMBL))
  geneList <- na.omit(geneList)
  #[1:21000]
  gse <- gseGO(geneList=geneList,
               ont ="ALL",
               keyType = "ENSEMBL",
               nPerm = 10000,
               minGSSize = 3,
               maxGSSize = 800,
               pvalueCutoff = 0.05,
               verbose = TRUE,
               OrgDb = org.Mm.eg.db,
               #OrgDb = org.Hs.eg.db,
               pAdjustMethod = "BH")
  
  p3 <- dotplot(gse, showCategory=20)+
  theme(
    axis.text.y = element_text(size = 10),     # Y轴条目字体
    axis.text.x = element_text(size = 10),     # X轴字体
    legend.text = element_text(size = 9),      # 图例字体
    legend.title = element_text(size = 10),     # 图例标题
    plot.title = element_text(hjust = 0.5)  
  )+ ggtitle(sample_name)
  ggsave(paste0(RNA_dir,"/GO_enrichment/",sample_name, "_dotGse.png"), plot = p3, width = 10, height = 8, dpi = 300)
  
  gse_data <- as.data.frame(gse)
  gse_data <- gse_data[order(gse_data$NES, decreasing = T), ]
  write.csv(gse_data,paste0(RNA_dir,"/GO_enrichment/",sample_name, "_gse_path.csv"))
  
  
  
}



####个性化分析内容
##################################################################################################
##################################################################################################
##################################################################################################
##################################################################################################

## 4.指定基因的表达分布

#exprSet <- log2(cpm(rawcount)+ 1)
exprSet <- log2(cpm(filter_count)+ 1)

expr_id2symbol <- bitr(rownames(exprSet), 
                       fromType = "ENSEMBL", toType = "SYMBOL", 
                       OrgDb = org.Mm.eg.db )
#expr_id2symbol <- bitr(rownames(exprSet), 
#                    fromType = "ENSEMBL", toType = "SYMBOL", 
#                    OrgDb = org.Hs.eg.db )  



exprSet2 <- cbind(GeneID=rownames(exprSet),exprSet)
exprSet2_symbol <- merge(expr_id2symbol,exprSet2,by.x="ENSEMBL",by.y="GeneID",all.y=T)


gene_list_expr <- read.table("gene_list.csv",
                             header =F ,sep = ",")
#colnames(gene_list_expr) <- c("gene")

colnames(gene_list_expr) <- c("Group","gene")

gene_list <- unique(gene_list_expr$gene)
length(gene_list)

#gene_list <- c("Il21","Il1b","Il10","Il4","Ifng","Tnf","Il5","Il6","Il13","Csf2","Il18",
#               "Il2","Il12a","Il12b")

#gene_list <- c("Aire","H1f2","Egr2","Egr1","Zfp36","Ier2","Osgin1","Plcxd2","Gm23849")
#gene_list <- c("Aire","H1f2","Egr2","Egr1","Zfp36","Ier2","Osgin1","Plcxd2","Gm23849")


gene_expr_matrix <- exprSet2_symbol[exprSet2_symbol$SYMBOL %in% gene_list, , drop = FALSE]
dim(gene_expr_matrix)
table(duplicated(gene_expr_matrix$SYMBOL))
gene_expr_matrix <-gene_expr_matrix[!duplicated(gene_expr_matrix$SYMBOL),]
dim(gene_expr_matrix)


# 转换为数据框（如果原来是 matrix）
gene_expr_data <- as.data.frame(gene_expr_matrix)

#gene_expr_data <- gene_expr_data[gene_expr_data$ENSEMBL != "ENSMUSG00000062593",]


rownames(gene_expr_data) <- gene_expr_data$SYMBOL
#rownames(gene_expr_data) <- gene_expr_data$ENSEMBL
gene_expr_data <- gene_expr_data[,-c(1,2)]

gene_expr_data <- as.matrix(gene_expr_data)
mode(gene_expr_data) <- "numeric"

#gene_expr_data <- gene_expr_data[,4:9]

anno <- data.frame(SampleType=group$group)
anno <- data.frame(SampleType=factor(c(rep("6Treg",3),rep("7PDH",3),rep("8PD1-1",3)),
                                     levels=c("6Treg","7PDH","8PD1-1")))
rownames(anno) <- colnames(gene_expr_data)
anno
row_anno <- data.frame(GeneType=factor(gene_list_expr$Group,
                                       levels=c("transcription factor","inhibitory marker","inhibitory cytokine","cytokine")))
rownames(row_anno) <- gene_list_expr$gene
row_anno
gene_expr_data <-gene_expr_data[gene_list_expr$gene,]

p <- pheatmap::pheatmap(gene_expr_data,
                        annotation_col = anno,
                        annotation_row = row_anno,
                        show_rownames = T,
                        cluster_rows = F,
                        cluster_cols = T,
                        fontsize = 18,          # 全局字体大小
                        fontsize_row = 15,       # 行名字体大小
                        fontsize_col = 15)


png(file = sprintf("%s/diff_expr_gene_cor_heatmap.png",RNA_dir),width = 800,height = 600)
pdf(file = sprintf("%s/diff_expr_gene_cor_heatmap.pdf",RNA_dir))

print(p)
dev.off()


ggsave(
  filename = sprintf("%s/diff_expr_gene_cor_heatmap.pdf", RNA_dir),
  plot = p,
  width = 12, height = 10, units = "in"
)

###############################
###根据基因list制作多个分组间的表达量（柱状图+P值）

#exprSet <- log2(cpm(rawcount)+ 1)
exprSet <- log2(cpm(filter_count)+ 1)

expr_id2symbol <- bitr(rownames(exprSet), 
                       fromType = "ENSEMBL", toType = "SYMBOL", 
                       OrgDb = org.Mm.eg.db )
#expr_id2symbol <- bitr(rownames(exprSet), 
#                    fromType = "ENSEMBL", toType = "SYMBOL", 
#                    OrgDb = org.Hs.eg.db )  



exprSet2 <- cbind(GeneID=rownames(exprSet),exprSet)
exprSet2_symbol <- merge(expr_id2symbol,exprSet2,by.x="ENSEMBL",by.y="GeneID",all.y=T)


#gene_list_expr <- read.table("gene_list.csv",
#                             header =F ,sep = ",")
#colnames(gene_list_expr) <- c("num","gene")
#gene_list <- unique(gene_list_expr$gene)
#length(gene_list)

#gene_list <- c("Il21","Il1b","Il10","Il4","Ifng","Tnf","Il5","Il6","Il13","Csf2","Il18",
#               "Il2","Il12a","Il12b")

gene_list <- c("Aire","H1f2","Egr2","Egr1","Zfp36","Ier2","Osgin1","Plcxd2","Gm23849")


gene_expr_matrix <- exprSet2_symbol[exprSet2_symbol$SYMBOL %in% gene_list, , drop = FALSE]
dim(gene_expr_matrix)
# 转换为数据框（如果原来是 matrix）
gene_expr_data <- as.data.frame(gene_expr_matrix)
rownames(gene_expr_data) <- gene_expr_data$SYMBOL
gene_expr_data <- gene_expr_data[,-c(1,2)]
gene_expr_data <- as.matrix(gene_expr_data)
mode(gene_expr_data) <- "numeric"
#i=1
for (i in 1: nrow(gene_expr_data)) {
  sub_data <-data.frame(sample=colnames(gene_expr_data),gene_expr=gene_expr_data[i,],
                        #sampleType=factor(c(rep("Control",3),rep("FLASH-RT",3),
                        #             rep("Convention+nsa",3),rep("Convention-RT",3)),
                        sampleType=factor(c(rep("FLASH-RT",3),rep("Convention-RT",3)),
                        #levels = c("Control","FLASH-RT","Convention-RT","Convention+nsa")))
                        levels = c("FLASH-RT","Convention-RT")))
 
  Pbox <- ggplot(sub_data,aes(x =sampleType  , y = gene_expr , fill= sampleType))+
    geom_boxplot( )+
    #stat_compare_means(comparisons = list(c("Control","FLASH-RT"),c("Control","Convention-RT"),c("Control","Convention+nsa"),
    #                                      c("FLASH-RT","Convention-RT"),c("FLASH-RT","Convention+nsa"),c("Convention+nsa","Convention-RT")),method = "t.test",label = "p.signif")+
    stat_compare_means(comparisons = list(c("FLASH-RT","Convention-RT")),method = "t.test",label = "p.signif")+
    
    
    labs(y = 'Gene expression level\n(log2(CPM + 1))',x=rownames(gene_expr_data)[i])+
    theme_bw()+
    theme_bw()+theme(plot.title = element_text(hjust = 0.5 , size = 20),
                     axis.title.x =  element_text(size = 20),
                     axis.title.y = element_text(size = 20),
                     axis.text = element_text(size = 20),
                     legend.text = element_text(size = 15),
                     legend.title = element_text(size = 20))
  png(file = sprintf("%s/diff_expr_gene/diff_expr_gene_%s_boxplot.png",RNA_dir,rownames(gene_expr_data)[i]),width = 800,height = 600)
  print(Pbox)
  dev.off()

}


###############################################################################
#######根据基因列表绘制基因表达量热图，便于挑选两组之间的有差异基因。

# 第一次聚类
ph <- pheatmap(gene_expr_data, cluster_rows = TRUE, cluster_cols = TRUE)

# 提取行聚类结果 (hclust 对象)
row_tree <- ph$tree_row

# 按树切成3组
groups <- cutree(row_tree, k = 3)

# 查看每个基因属于哪个组
head(groups)

# 把基因分组后画3张子图
for (i in 1:3) {
  cat("画第", i, "组\n")
  sub_mat <- gene_expr_data[names(groups[groups == i]), , drop = FALSE]
  p <- pheatmap::pheatmap(sub_mat,
                          annotation_col = anno,
                          cluster_rows = T,
                          cluster_cols = T,
                          fontsize = 18,          # 全局字体大小
                          fontsize_row = 10,       # 行名字体大小
                          fontsize_col = 15)
  
  png(file = sprintf("%s/grou%s_gene_cor_heatmap.png",RNA_dir,i),width = 1000,height = 800)
  print(p)
  dev.off()
  
}

write.csv(groups,sprintf("%s/gene_group_list.csv",RNA_dir)) 


###############################################################################
#######根据gseGO结果提取感兴趣的pathway，制作气泡图和GSEA图
####GO 网站

target_GO_list <- read.table("target_GO_list.csv",
                             header =F ,sep = ",")

pathway_interest <- target_GO_list$V1

#gse 是前面步骤生成的结果

gse_sub <- gse
gse_sub@result <- subset(gse@result, ID %in% pathway_interest)
gse_sub@result <- gse_sub@result[order(gse_sub@result$NES, decreasing = TRUE), ]
p3 <- dotplot(gse_sub, showCategory=20)+
  theme(
    axis.text.y = element_text(size = 10),     # Y轴条目字体
    axis.text.x = element_text(size = 10),     # X轴字体
    legend.text = element_text(size = 9),      # 图例字体
    legend.title = element_text(size = 10),     # 图例标题
    plot.title = element_text(hjust = 0.5)  
  )
ggsave(paste0(RNA_dir,"/GO_enrichment/Target_GO_dotGse.png"), plot = p3, width = 10, height = 8, dpi = 300)
gse_sub_data <- as.data.frame(gse_sub)
write.csv(gse_sub_data,paste0(RNA_dir,"/GO_enrichment/Target_GO_gse_path.csv"))

######
##每个pathway生成GSEA富集图

library(enrichplot)
gse_result <- gse_sub@result
#gse_result <- gse@result
#gse_sub <- gse
gse_result <- gse_result[order(gse_result$NES, decreasing = TRUE), ]
top20_IDs <- gse_result$ID

for (i in seq_along(top20_IDs)) {
  term_id <- top20_IDs[i]
  term_name <- gse_result[gse_result$ID == term_id, "Description"]
  gse_sub@result[gse_sub@result$ID == term_id, "Description"] <- ""
  message(sprintf("[%02d/%02d] 绘制 %s (%s)", i, length(top20_IDs), term_name, term_id))
  
  p_gseaplot <- gseaplot2(
    gse_sub,
    geneSetID = term_id,
    pvalue_table = T,
    title = paste0(term_name, "\n(", term_id, ")"),
    subplots = 1:3,   # 包含富集曲线、running ES、热图
    color = "firebrick",
    base_size = 16 
  ) 
  
  png(file = sprintf("%s/GO_enrichment/GSEA_Top20_%s_terms.png",
                     RNA_dir,i),width = 800,height = 600)
  print(p_gseaplot)
  dev.off()
}

#############################################################################################################################
####enrichment score 的基因再多个分组中的表达热图

#exprSet <- log2(cpm(rawcount)+ 1)
exprSet <- log2(cpm(filter_count)+ 1)

expr_id2symbol <- bitr(rownames(exprSet), 
                       fromType = "ENSEMBL", toType = "SYMBOL", 
                       OrgDb = org.Mm.eg.db )
#expr_id2symbol <- bitr(rownames(exprSet), 
#                    fromType = "ENSEMBL", toType = "SYMBOL", 
#                    OrgDb = org.Hs.eg.db )  

exprSet2 <- cbind(GeneID=rownames(exprSet),exprSet)
exprSet2_symbol <- merge(expr_id2symbol,exprSet2,by.x="ENSEMBL",by.y="GeneID",all.y=T)
exprSet2_symbol_unique <- exprSet2_symbol %>%
  distinct(ENSEMBL, .keep_all = TRUE)

# 提取每个GO term的core_enrichment基因
core_df <- gse_sub@result %>%
  dplyr::select(ID, core_enrichment) %>%
  mutate(core_enrichment = strsplit(core_enrichment, "/")) %>%
  tidyr::unnest(core_enrichment) %>%
  dplyr::rename(GO_ID = ID, ENSEMBL = core_enrichment)

head(core_df)
dim(core_df)

core_gene_expr_data<- left_join (core_df,exprSet2_symbol_unique,by="ENSEMBL",relationship = "many-to-many")
dim(core_gene_expr_data)

###添加分组信息
heatmap_cor_gene_data <- core_gene_expr_data[,-c(1:3)]
#heatmap_cor_gene_data <- core_gene_expr_data[,-c(1:6)]
rownames(heatmap_cor_gene_data) <- paste(core_gene_expr_data$GO_ID,rownames(core_gene_expr_data),sep="_")
heatmap_cor_gene_data <- as.matrix(heatmap_cor_gene_data)
mode(heatmap_cor_gene_data) <- "numeric"

col_anno <- data.frame(sampleType=c(rep("FLASH-RT",3),rep("Convention-RT",3)))
#col_anno <- data.frame(sampleType=c(rep("FLASH-RT",2),rep("Convention-RT",2)))
rownames(col_anno) <- colnames(heatmap_cor_gene_data)
row_anno <- data.frame(pathway_ID=core_gene_expr_data$GO_ID)
rownames(row_anno) <- rownames(heatmap_cor_gene_data)

core_gene_heatmap_p <- pheatmap::pheatmap(heatmap_cor_gene_data,
                        annotation_col = col_anno,
                        annotation_row = row_anno,
                        show_rownames = F,
                        cluster_rows = F,
                        cluster_cols = T,
                        fontsize = 18,          # 全局字体大小
                        fontsize_row = 15,       # 行名字体大小
                        fontsize_col = 15)

png(file = sprintf("%s/GO_enrichment/Target_GO_pathway_heatmap.png",RNA_dir),width = 1000,height = 1000)
print(core_gene_heatmap_p)
dev.off()


























































