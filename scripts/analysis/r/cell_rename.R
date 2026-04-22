library(data.table)
library(tidyverse)
	
args <- commandArgs(trailingOnly = TRUE)
# Count the number of arguments
arg_count <- length(args)


result_dir <- args[1]
# The rest will be the base names
base_names <- args[2:length(args)]


for (name in base_names) {
	annot <- args[1]
	#annot <- result_dir
	cat(name, "\n")

	for (i in 1:22){
		print(i);
		ld1 <- paste(annot,"/",name,".",i,".l2.ldscore.gz",sep = "")
		ld1_dat <- fread(ld1)
		colnames(ld1_dat) <- c("CHR","SNP","BP",name)
		fwrite(ld1_dat,ld1,sep="\t")
	}
} 

# Define the directory where the files are located
directory <- annot  # Replace with your directory path

# List all .annot.gz files in the directory
files <- list.files(directory, pattern = "\\.annot\\.gz$", full.names = TRUE)
#files <- files[1:88]

# Initialize an empty list to store the data frames
annot_list <- list()

# Loop through each file and read it
for (file_l in files) {
  # Read the file (assuming it's tab-separated, adjust if necessary)
  annot_data <- fread(file_l, header = TRUE, sep = "\t")
  
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
  
  

# Example base list
base <- base_names
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

       # source_file chromosome 399058 399061 409427 409428
# 1 399058.1.annot.gz          1      0      0      0      0
# 2 399058.1.annot.gz          1      0      0      0      0
# 3 399058.1.annot.gz          1      0      0      0      0
# 4 399058.1.annot.gz          1      0      0      0      0
# 5 399058.1.annot.gz          1      0      0      0      0
# 6 399058.1.annot.gz          1      0      0      0      0
# [1] 9997231       6

parent_dir <- result_dir 

# for (col in base) {
  # base_other_name <- paste0(col, "_Dir_other")  # Dynamically name the new column
  # result[[base_other_name]] <- ifelse(result[[col]] == 0, 1, 0)  # Create '_other' column
  
  # dir_path <- file.path(parent_dir, base_other_name)
  
    # if (!dir.exists(dir_path)) {
    # dir.create(dir_path, recursive = TRUE)
    # message(paste("Created directory:", dir_path))
	
	# df <- data.frame(ANNOT = ifelse(dat_comb_other[[col]] == 0, 1, 0))
	# print(head(df))
	# print(table(df))
	
	# out_dir <- paste(dir_path,"/","other.",i,".annot.gz",sep = "")
	# fwrite(as.data.frame(df$ANNOT),out_dir)
  # } else {
    # message(paste("Directory already exists:", dir_path))
  # } 
# }


for (col in base) {
  base_other_name <- paste0(col, "_Dir_other")  # Dynamically name the directory
  result[[base_other_name]] <- ifelse(result[[col]] == 0, 1, 0)  # Create '_other' column
  dir_path <- file.path(parent_dir, base_other_name)  # Create the path for the directory
  
  # Create the directory if it doesn't exist
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
    message(paste("Created directory:", dir_path))
  } else {
    message(paste("Directory already exists:", dir_path))
  }
  
  # Loop over chromosomes 1 to 22
  for (i in 1:22) {
    # Create a dataframe for this chromosome
	result_annot <- result[result$chromosome == as.character(i),]
    df <- data.frame(ANNOT = ifelse(result_annot[[col]] == 0, 1, 0))
	print(head(df))
    
    # Construct the file path for the chromosome file
    out_file <- file.path(dir_path, paste0("other.", i, ".annot.gz"))
    
    # Write the dataframe to the file
    fwrite(df, out_file, compress = "gzip")
    message(paste("Saved file for chromosome", i, "in directory:", dir_path))
  }
}



result$ANNOT  <- apply(result[base], 1, function(x) ifelse(any(x == 1), 0, 1))
head(result); dim(result)


# head(result[result$'407735' == 1 ,])
# head(result[result$'ANNOT' == 0 ,])

# head(result[result$'407735' == 1 & result$'407745' == 0 ,])
# head(result[result$'407735' == 0 & result$'407745' == 1 ,])


for (i in 1:22) {
	result_annot <- result[result$chromosome == as.character(i),]
	print(head(result_annot))
	out_dir <- paste(annot,"/","other.",i,".annot.gz",sep = "")
    fwrite(as.data.frame(result_annot$ANNOT),out_dir)
}





# /usr/bin/Rscript /home/raheemsyedrameez12/LDSCORE_APP/script/cell_rename.R "/home/raheemsyedrameez12/LDSCORE_APP/result/r_239864" "GTEx_Cortex" "J_list_withdrawal_ENSG"