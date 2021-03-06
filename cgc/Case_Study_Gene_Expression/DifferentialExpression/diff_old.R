# Import libraries
library(limma)
library(DESeq2)
library(pheatmap)
library(RColorBrewer)
options(warn=-1)
print("Library imports done")

# Collect arguments from the command line
args <- commandArgs(TRUE)

# Read CSV files (harcoded for now)
gene <- read.csv(args[1], header=TRUE, row.names=1) # get the counts per gene (row) per sample/case (col)
meta <- read.csv(args[2], header=TRUE) # get the metadata matrix
print("CSV files read")

## For testing only:
# gene = read.csv("brca_gene.csv", header = TRUE, row.names=1)
# meta = read.csv("brca_meta.csv", header = TRUE)
gene = gene[,1:20]
meta = meta[1:20,]

# Get the Differential Expression results
print("Initializing Differential Expression Analysis -- go grab a coffee :)")
meta.df = data.frame(meta)
dds = DESeqDataSetFromMatrix(countData = gene, colData = meta.df, ~ sample_type + X.case_id)
design(dds) <- ~ sample_type + X.case_id
dds = DESeq(dds)
#resultsNames(dds)
res <- results(dds, contrast = c("sample_type", "Solid Tissue Normal", "Primary Tumor"))
resOrdered <- res[order(res$padj),] # order the results by adjusted p-value
print("Differential Expression analysis DONE!")

# Output your data report
'%&%' <- function(x, y)paste0(x,y) # create string concat func
output_title <- args[3] %&% "_rnaseq.csv"
write.csv(resOrdered, output_title) # output df as csv
print("Ordered list of adjust p-values recorded per gene as a CSV file")

#### PLOTS ####

# Create PDF with custom title
plot_title <- args[4] %&% "_plots_rnaseq.pdf"
pdf(plot_title)

# Plot -- Volcano plot
plotMA(res,main="DESeq2", ylim = c(-4,4))

# Heatmap -- Gene Expression
select <- order(rowMeans(counts(dds,normalized=TRUE)), decreasing=TRUE)[1:20]
nt <- normTransform(dds) # log2(count+1) normalization 
log2.norm.counts <- assay(nt)[select,]
df <- as.data.frame(colData(dds)[,c("sample_type")])
colnames(df) <- "sample_type"
pheatmap(log2.norm.counts, cluster_rows=FALSE, show_rownames=FALSE, cluster_cols=FALSE, annotation_col=df)

# Heatmap -- Sample-Sample Distance 
rld <- rlog(dds,blind=FALSE)
sampleDists <- (dist(t(assay(rld))))
sampleDistMatrix <- as.matrix(sampleDists)
colnames(sampleDistMatrix) <- NULL
colors <- colorRampPalette( rev(brewer.pal(9,"Blues")))(255)
rownames(sampleDistMatrix) <- paste(rld$condition, rld$sample_type, sep="-")
pheatmap(sampleDistMatrix, clustering_distance_rows=sampleDists, clustering_distance_cols=sampleDists,col=colors)

# PCA plot -- sample-type
plotPCA(rld,intgroup=c("sample_type"))

# Finish up
dev.off()
print("PDF plot saved")

########

# To run in the command line of your Docker container:
# Rscript diff_exp_rnaseq.R brca_gene.csv brca_meta.csv csv_filename pdf_filename