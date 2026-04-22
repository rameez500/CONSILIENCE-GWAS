library(data.table)
args <- commandArgs(trailingOnly = TRUE)
# Count the number of arguments
arg_count <- length(args)

#uploadeddir_files <- args[1:length(args)]
# Store the file paths from the command-line arguments into uploadeddir_files
# (this is the list of gene files you want to process)
uploadeddir_files <- commandArgs(trailingOnly = TRUE)
print("from micedata script ")
print(uploadeddir_files)

for (file_list in uploadeddir_files) {
	# Load the organism reference file (mapping Ensembl gene IDs to gene names)
	ref <- fread("/apps/www-dev/support/data/ref/organism_dat.txt")
	ref <- as.data.frame(ref)
	# Remove duplicate rows based on Ensembl gene ID (keep unique mappings only)
	ref <- ref[!duplicated(ref$ensembl_gene_id),]
	
	# Read the input gene list file (V1 is assumed to be gene IDs)
	# 'fill=TRUE' ensures it can handle uneven rows
	gene <- fread(file_list,header=FALSE,,fill=TRUE)
	# Remove rows where the gene ID is "-" (invalid/missing entries)
	gene <- gene[gene$V1 != "-",]
	
	# Load additional reference file containing GRCh37 human genome gene positions
	GRCh37_human <- fread("/apps/www-dev/support/data/ref/GRCh37_human.txt")
	
	# Merge input gene list with reference annotation (organism_dat)
	# Match input gene IDs (V1) with reference Ensembl gene IDs
	
	ref_gen <- merge(gene,ref,by.x = "V1", by.y = "ensembl_gene_id", sort = FALSE)
	
	# Convert gene names to lowercase (to ensure case-insensitive matching later)
	ref_gen$external_gene_name <- tolower(ref_gen$external_gene_name)
	
	# Merge with GRCh37 human gene positions by external gene name
	# This attaches chromosome/start/end positions for each gene
	geneweaver_biomart_human <- merge(ref_gen,GRCh37_human,by = "external_gene_name", sort = FALSE)
	geneweaver_biomart_human <- geneweaver_biomart_human[!duplicated(geneweaver_biomart_human$external_gene_name),]
	print(head(geneweaver_biomart_human)); dim(geneweaver_biomart_human)
	
	# y <- geneweaver_biomart_human[,c("chromosome_name.y","start_position.y","end_position.y")]
	# y <- as.data.frame(y)
	# y$chromosome_name.y <- paste("chr",y$chromosome_name.y,paste = "")
	# y$chromosome_name.y <- gsub("chr ", "chr", y$chromosome_name.y)
	# y$chromosome_name.y <- gsub("\\s+$", "", y$chromosome_name.y)
	# head(y); dim(y)	

	# Final output: write the Ensembl gene IDs (after mapping/cleaning)
	# back into the same file (overwrite) as a plain tab-separated file
	
	# fwrite(y,file_list,col.names = FALSE, sep = "\t")
	fwrite(as.data.frame(geneweaver_biomart_human$ensembl_gene_id),file_list,col.names = FALSE, sep = "\t")
}


