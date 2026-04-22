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


annot <- out_dir

# Define the directory where the files are located
directory <- annot  # Replace with your directory path

# List all .annot.gz files in the directory
files <- list.files(directory, pattern = "\\.annot\\.gz$", full.names = TRUE)
files <- files[!grepl("other", files)]

# Initialize an empty list to store the data frames
annot_list <- list()

# Loop through each file and read it
for (file_l in files) {
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


combined_annot_data <- do.call(rbind, annot_list)
combined_annot_data <- as.data.frame(combined_annot_data)
head(combined_annot_data); dim(combined_annot_data)


combined_annot_data <- combined_annot_data %>%
  mutate(
    base_name = sapply(strsplit(source_file, "\\."), `[`, 1),
    chromosome = sapply(strsplit(source_file, "\\."), `[`, 2)
  )
head(combined_annot_data); dim(combined_annot_data)


combined_annot_data <- as.data.frame(combined_annot_data)
combined_annot_data$'base_names' <- ifelse(combined_annot_data$ANNOT != 0,1,0)
combined_annot_data$other <- ifelse(combined_annot_data$ANNOT == 0,1,0)
head(combined_annot_data); dim(combined_annot_data)


bim_comb <- NULL
for (i in 1:22) {
	print(i);
	x <- paste("/apps/www/project/ldsc/ref/1000G_EUR_Phase3_plink/1000G.EUR.QC.",i,".bim",sep = "")
	bim <- fread(x)
	bim_comb <- rbind(bim_comb,bim)
}
		
head(bim_comb); dim(bim_comb)


dat_annot_bim <- cbind(bim_comb,combined_annot_data)
print(head(dat_annot_bim)); dim(dat_annot_bim)	
#table(dat_annot_bim$base_names, useNA = "ifany")
#table(dat_annot_bim$other, useNA = "ifany")


df_beta <- sumstat
df_beta <- as.data.frame(df_beta)
head(df_beta); dim(df_beta)

dat_annot_bim_ldpred <- merge(df_beta,dat_annot_bim,by.x = "SNP_ID",by.y = "V2", sort = FALSE)
dat_annot_bim_ldpred <- dat_annot_bim_ldpred[!duplicated(dat_annot_bim_ldpred$SNP_ID),]
dat_annot_bim_ldpred <- as.data.frame(dat_annot_bim_ldpred)
head(dat_annot_bim_ldpred); dim(dat_annot_bim_ldpred)


base_name_pgs <- dat_annot_bim_ldpred[dat_annot_bim_ldpred$base_names == 1,]
base_name_pgs <- base_name_pgs[,c("SNP_ID","A1","A2","Beta","SE","Pval")]
head(base_name_pgs); dim(base_name_pgs)


other_name_pgs <- dat_annot_bim_ldpred[dat_annot_bim_ldpred$other == 1,]
other_name_pgs <- other_name_pgs[,c("SNP_ID","A1","A2","Beta","SE","Pval")]
head(other_name_pgs); dim(other_name_pgs)


#out_dir <- "/apps/www/project/ldsc/Spencer"

fwrite(base_name_pgs,paste(out_dir,"/","PGS_prs_cs","/","sum_stat_",base_names,"_PGS.txt",sep = ""),sep = "\t")
fwrite(other_name_pgs,paste(out_dir,"/","PGS_prs_cs","/","sum_stat_","other","_PGS.txt",sep = ""),sep = "\t")



##################################################################
##################################################################
##################################################################

