library(data.table)
library(tidyverse)

args <- commandArgs(trailingOnly = TRUE)
# Count the number of arguments
arg_count <- length(args)

result_dir <- args[1]
annot <- result_dir

############################ for model 1   #################################
############################ for model 1   #################################

#dir_uniq <- "/apps/www/project/ldsc/result/r_856690/Unique"
dir_uniq <- paste(annot,"/Unique",sep = "")
files_uniq <- list.files(path = dir_uniq, pattern = "^other\\..*\\.annot\\.gz$", full.names = TRUE)
files_uniq

#dir_int <- "/apps/www/project/ldsc/result/r_856690/intersection"
dir_int <- paste(annot,"/intersection",sep = "")
files_int <- list.files(path = dir_int, pattern = "^other\\..*\\.annot\\.gz$", full.names = TRUE)
files_int


annot_list_uniq <- list()
# Loop through each file and read it
for (file_l in files_uniq) {
  # Read the file (assuming it's tab-separated, adjust if necessary)
  annot_uniq <- fread(file_l, header = TRUE, sep = "\t")
  colnames(annot_uniq) <- "uniq"
  
  # Optionally, add a column to track the source file for debugging
  annot_uniq$source_file_uniq <- basename(file_l)
  
  # Append the data to the list
  annot_list_uniq[[length(annot_list_uniq) + 1]] <- annot_uniq
}

# Combine all data frames into one
combined_annot_uniq <- do.call(rbind, annot_list_uniq)
combined_annot_uniq <- as.data.frame(combined_annot_uniq)
head(combined_annot_uniq); dim(combined_annot_uniq)


annot_list_int <- list()
# Loop through each file and read it
for (file_l in files_int) {
  # Read the file (assuming it's tab-separated, adjust if necessary)
  annot_int <- fread(file_l, header = TRUE, sep = "\t")
  colnames(annot_int) <- "int"
  
  # Optionally, add a column to track the source file for debugging
  annot_int$source_file_int <- basename(file_l)
  
  # Append the data to the list
  annot_list_int[[length(annot_list_int) + 1]] <- annot_int
}

# Combine all data frames into one
combined_annot_int <- do.call(rbind, annot_list_int)
combined_annot_int <- as.data.frame(combined_annot_int)
head(combined_annot_int); dim(combined_annot_int)


comb_uniq_int <- cbind(combined_annot_uniq,combined_annot_int)
comb_uniq_int$ANNOT <- ifelse( (comb_uniq_int$uniq == 1 | comb_uniq_int$int == 1),1,0 )
head(comb_uniq_int); dim(comb_uniq_int)


for (i in 1:22) {
	result_annot <- comb_uniq_int[comb_uniq_int$source_file_uniq == paste("other.",as.character(i),".annot.gz",sep = ""),]
	#print(head(result_annot))
	out_dir <- paste(annot,"/model_1_enr/","other.",i,".annot.gz",sep = "")
    fwrite(as.data.frame(result_annot$ANNOT),out_dir)
}


