#-----------------------------------------------------------
library(data.table)
library(ggplot2)
library(tidyr)
library(dplyr)


# Retrieve command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Count the number of arguments
arg_count <- length(args)

# Print the number of arguments
cat("Number of arguments passed:", arg_count, "\n")
sumstat <- args[1]
sample_size <- args[2]
out_dir <- args[3]
base_names <- args[4:length(args)]
#sumstat <- "/apps/www/project/ldsc/result/r_751855/DPW.gz"

cat("Base Names:\n")
print(base_names)

sumstat <- fread(sumstat,sep = "\t")
sumstat <- as.data.frame(sumstat)
#colnames(sumstat) <- c("rsid","chr","pos","a0","a1","beta","beta_se","p")
sumstat$Beta <- as.numeric(sumstat$Beta)
sumstat$n_eff <- sample_size
sumstat$n_eff <- as.numeric(sumstat$n_eff)
sumstat$CHR <- as.integer(sumstat$CHR)
print(head(sumstat)); dim(sumstat)


#result_dir <- "/apps/www/project/ldsc/result/r_419115/"
# The rest will be the base names
#base_names <- c("1777","399058","399061")
annot <- out_dir

# Define the directory where the files are located
directory <- annot  # Replace with your directory path
dir_union <- paste(directory,"/","union",sep = "")

# List all .annot.gz files in the directory
files <- list.files(directory, pattern = "\\.annot\\.gz$", full.names = TRUE)
files <- files[!grepl("other", files)]
files_union <- list.files(dir_union, pattern = "\\.annot\\.gz$", full.names = TRUE)
all_files <- c(files,files_union)
#files <- files[1:88]

# Initialize an empty list to store the data frames
annot_list <- list()

# Loop through each file and read it
for (file_l in all_files) {
  # Read the file (assuming it's tab-separated, adjust if necessary)
  annot_data <- fread(file_l, header = TRUE, sep = "\t")
  colnames(annot_data) <- "ANNOT"
  #print(head(annot_data))
  print(dim(annot_data))
  
  # Optionally, add a column to track the source file for debugging
  annot_data$source_file <- basename(file_l)
  
  # Append the data to the list
  annot_list[[length(annot_list) + 1]] <- annot_data
}

# Combine all data frames into one
combined_annot_data <- do.call(rbind, annot_list)
combined_annot_data <- as.data.frame(combined_annot_data)
head(combined_annot_data); dim(combined_annot_data)

table(combined_annot_data$source_file,useNA = "ifany")
#dim(combined_annot_data[(combined_annot_data$source_file == "407735.10.annot.gz" & combined_annot_data$ANNOT == 1),])



# Split the source_file column into base_name and chromosome
combined_annot_data <- combined_annot_data %>%
  mutate(
    base_name = sapply(strsplit(source_file, "\\."), `[`, 1),
    chromosome = sapply(strsplit(source_file, "\\."), `[`, 2)
  )
  
# 
sub_columns <- c("All_UnionGenes","other")
#sub_columns <- c("All_UnionGenes")
# Example base list
base <- c(base_names,sub_columns)
# Create a list to store split data by base and chromosome
split_data <- list()

# Loop through each base
for (b in base) {
  # Filter rows corresponding to the current base
  base_data <- combined_annot_data %>%
    filter(grepl(b, source_file))
  # Split the base data by chromosome
  split_data[[b]] <- split(base_data, base_data$chromosome) 
}

# Example: Accessing split data for a specific base and chromosome
# For base "407735", chromosome 1


dat_comb_other <- data.frame(A = numeric(0), B = numeric(0))
for (b in base) {
  # Filter rows corresponding to the current base
  dat_comb <- NULL
  for (i in 1:22) {
	annot_other <- split_data[[b]][[as.character(i)]]
	print(i)
	print(b)
    print(dim(annot_other))
	colnames(annot_other)[1] <- b
	print(head(annot_other))
	dat_comb <- rbind(dat_comb,annot_other)
  }
  dat_comb <- as.data.frame(dat_comb)
  # Check if the first data frame has 0 rows
	if (nrow(dat_comb_other) == 0) {
	  # If df1 has 0 rows, initialize it with the correct number of rows from df2
	  dat_comb_other <- data.frame(matrix(ncol = ncol(dat_comb_other), nrow = nrow(dat_comb)))
	  colnames(dat_comb_other) <- colnames(dat_comb_other)  # Preserve column names
	}
  dat_comb_other <- cbind(dat_comb_other,dat_comb)
  
}


head(dat_comb_other); dim(dat_comb_other)



# Extract only the columns for source_file and base
selected_columns <- c("source_file","chromosome", base)
result <- dat_comb_other[, selected_columns]
head(result); dim(result)

     # source_file chromosome 1777 399058 399061 All_UnionGenes other
# 1 1777.1.annot.gz          1    0      0      0              0     1
# 2 1777.1.annot.gz          1    0      0      0              0     1
# 3 1777.1.annot.gz          1    0      0      0              0     1
# 4 1777.1.annot.gz          1    0      0      0              0     1
# 5 1777.1.annot.gz          1    0      0      0              0     1
# 6 1777.1.annot.gz          1    0      0      0              0     1
# [1] 9997231       7

#table(result$'1777')
#table(result$other)


bim_comb <- NULL
for (i in 1:22) {
	print(i);
	x <- paste("/apps/www-dev/support/data/ref/1000G_EUR_Phase3_plink/1000G.EUR.QC.",i,".bim",sep = "")
	bim <- fread(x)
	bim_comb <- rbind(bim_comb,bim)
}
		
head(bim_comb); dim(bim_comb)


     # V1          V2    V3    V4     V5     V6
   # <int>      <char> <num> <int> <char> <char>
# 1:     1 rs575272151     0 11008      G      C
# 2:     1 rs544419019     0 11012      G      C
# 3:     1 rs540538026     0 13110      A      G
# 4:     1  rs62635286     0 13116      G      T
# 5:     1 rs200579949     0 13118      G      A
# 6:     1 rs531730856     0 13273      C      G
# [1] 9997231       6



dat_annot_bim <- cbind(bim_comb,result)
print(head(dat_annot_bim)); dim(dat_annot_bim)		

      # V1          V2    V3    V4     V5     V6     source_file chromosome  1777
   # <int>      <char> <num> <int> <char> <char>          <char>     <char> <int>
# 1:     1 rs575272151     0 11008      G      C 1777.1.annot.gz          1     0
# 2:     1 rs544419019     0 11012      G      C 1777.1.annot.gz          1     0
# 3:     1 rs540538026     0 13110      A      G 1777.1.annot.gz          1     0
# 4:     1  rs62635286     0 13116      G      T 1777.1.annot.gz          1     0
# 5:     1 rs200579949     0 13118      G      A 1777.1.annot.gz          1     0
# 6:     1 rs531730856     0 13273      C      G 1777.1.annot.gz          1     0
   # 399058 399061 All_UnionGenes other
    # <int>  <int>          <int> <int>
# 1:      0      0              0     1
# 2:      0      0              0     1
# 3:      0      0              0     1
# 4:      0      0              0     1
# 5:      0      0              0     1
# 6:      0      0              0     1
# [1] 9997231      13

#x <- dat_annot_bim[dat_annot_bim$V1 == 15,]
#head(x); dim(x)


df_beta <- sumstat
df_beta <- as.data.frame(df_beta)
head(df_beta); dim(df_beta)

dat_annot_bim_ldpred <- merge(df_beta,dat_annot_bim,by.x = "SNP_ID",by.y = "V2", sort = FALSE)
dat_annot_bim_ldpred <- dat_annot_bim_ldpred[!duplicated(dat_annot_bim_ldpred$SNP_ID),]
dat_annot_bim_ldpred <- as.data.frame(dat_annot_bim_ldpred)
head(dat_annot_bim_ldpred); dim(dat_annot_bim_ldpred)


fwrite(dat_annot_bim_ldpred,paste(out_dir,"/","ldpred","_PGS.txt.gz",sep = ""),sep = "\t")


for (b in base) {
  # Filter rows corresponding to the current base
	annot_ldpred <- NULL
	ldpred_base <- c("SNP_ID","A1","A2","Beta","SE","Pval", b)
	# Subset the data frame by column names
	annot_ldpred <- dat_annot_bim_ldpred[, ldpred_base, drop = FALSE]
	colnames(annot_ldpred)[1:6] <- c("SNP","A1","A2","BETA","SE","P")
	annot_ldpred <- annot_ldpred[annot_ldpred[[b]] == 1, ]

	# Print the first few rows of the subsetted data frame
	
	print(b)
	print(head(annot_ldpred))
	print ("          ")
	fwrite(annot_ldpred[,1:6],paste(out_dir,"/","PGS_prs_cs","/","sum_stat_",b,"_PGS.txt",sep = ""),sep = "\t")
	#fwrite(annot_ldpred,paste(out_dir,"/",b,"_ldpred","_PGS.txt.gz",sep = ""),sep = "\t")
}



# --------------------------










#------------------------------------------------------------