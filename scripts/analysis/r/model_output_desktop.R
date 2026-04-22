library(data.table)
library(tidyverse)


#result <- "/apps/www/project/ldsc/result/r_210782/"
#result <- "/apps/www/project/ldsc/result/r_934089/"
#result <- "/apps/www/project/ldsc/result/r_505512/"


# Retrieve command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Count the number of arguments
arg_count <- length(args)

# Print the number of arguments
cat("Number of arguments passed:", arg_count, "\n")
annot <- args[1]
result <- annot

####################### Model 1 ######################################
####################### Model 1 ######################################
enrich_model <- fread(paste(result,"/model_1_enr/enrich_model.txt",sep = ""),header = FALSE)
enrich_model <- as.data.frame(enrich_model)
print(enrich_model); dim(enrich_model)


model_1 <- paste(result,"/model_1_enr/model_1_enrichment_out.results",sep = "")
model_1 <- fread(model_1)
model_1$p_fdr <- p.adjust(model_1$Enrichment_p, method = "fdr")
head(model_1); dim(model_1)
#out_dir <- paste(result,"/","HTML_model_1_3_output/Baseline_Include_model_1.csv",sep = "")
#fwrite(model_1,out_dir,sep = ",")
#fwrite(model_1,"/HTML_model_1_3_output/Baseline_Include_model_1.csv",sep = ",")

matching_rows <- sapply(enrich_model$V1, function(pattern) {
  grep(pattern, model_1$Category)
})


# Find rows with "L2_" pattern in model_1$Category
l2_matching_rows <- grep("L2_", model_1$Category)
l2_matching_rows <- l2_matching_rows[1]
l2_matching_rows

# Flatten the matching rows and remove duplicates (since multiple patterns can match the same row)
#matching_rows <- unique(unlist(matching_rows))
combined_matching_rows <- unique(c(unlist(matching_rows), l2_matching_rows))

# Extract rows from model_1 where Category matches the enrich_model patterns
model_1_matches <- model_1[combined_matching_rows, ]
model_1_matches$Category <- gsub("^L2.*", "other_Variants", model_1_matches$Category)
model_1_matches <- as.data.frame(model_1_matches)
print(model_1_matches)

# path_dir <- paste(result,"/","testing_label",sep = "")
# label <- fread(path_dir)
# print(label)

# label[, GeneWeaver_ID := gsub("\\..*", "", GeneWeaver_ID)]
# label <- as.data.frame(label)
# print(label)



csv_out <- paste(annot,"/HTML_model_1_3_output/model_1.csv",sep = "")
fwrite(model_1_matches,csv_out,sep=",")
csv_html <- paste("/apps/conda/project/envs/imlabtools/bin/csvtotable ",csv_out," ",annot,"/HTML_model_1_3_output/model_1.html",sep= "")
print(csv_html)
system(csv_html)

model1_out <- paste(annot,"/HTML_model_1_3_output/baseline_model_1.csv",sep = "")
model1_out
fwrite(model_1,model1_out,sep = ",")


####################### Model 3 ######################################
####################### Model 3 ######################################
enrich_model <- fread(paste(result,"/model_3_enr/enrich_model.txt",sep = ""),header = FALSE)
enrich_model <- as.data.frame(enrich_model)
(enrich_model); dim(enrich_model)


model_3 <- paste(result,"/model_3_enr/model_3_enrichment_out.results",sep = "")
model_3 <- fread(model_3)
model_3$p_fdr <- p.adjust(model_3$Enrichment_p, method = "fdr")
head(model_3); dim(model_3)

#fwrite(model_3,"/HTML_model_1_3_output/Baseline_Include_model_3.csv",sep = ",")

matching_rows <- sapply(enrich_model$V1, function(pattern) {
  grep(pattern, model_3$Category)
})


# Find rows with "L2_" pattern in model_1$Category
l2_matching_rows <- grep("L2_", model_3$Category)
l2_matching_rows <- l2_matching_rows[1]
l2_matching_rows

# Flatten the matching rows and remove duplicates (since multiple patterns can match the same row)
#matching_rows <- unique(unlist(matching_rows))
combined_matching_rows <- unique(c(unlist(matching_rows), l2_matching_rows))

# Extract rows from model_1 where Category matches the enrich_model patterns
model_3_matches <- model_3[combined_matching_rows, ]
model_3_matches$Category <- gsub("^L2.*", "other_Variants", model_3_matches$Category)
model_3_matches <- as.data.frame(model_3_matches)
print(model_3_matches)




# #csv_out <- paste(annot,"/enichment_annote.csv",sep = "")
# csv_out <- "/apps/www/project/ldsc/back_up/test/HTML_model_1_3_output/model_3.csv"
# fwrite(model_3_matches,csv_out,sep=",")
# #csv_html <- paste("/apps/conda/project/envs/imlabtools/bin/csvtotable ",annot,"/enichment_annote.csv"," ",annot,"/enichment_annote.html",sep= "")
# csv_html <- paste("/apps/conda/project/envs/imlabtools/bin/csvtotable ",csv_out," ","/apps/www/project/ldsc/back_up/test/HTML_model_1_3_output/","/model_3.html",sep= "")
# print(csv_html)
# system(csv_html)

csv_out <- paste(annot,"/HTML_model_1_3_output/model_3.csv",sep = "")
fwrite(model_3_matches,csv_out,sep=",")
csv_html <- paste("/apps/conda/project/envs/imlabtools/bin/csvtotable ",csv_out," ",annot,"/HTML_model_1_3_output/model_3.html",sep= "")
print(csv_html)
system(csv_html)

model3_out <- paste(annot,"/HTML_model_1_3_output/baseline_model_3.csv",sep = "")
fwrite(model_3,model3_out,sep = ",")


############ Model N ##########################
############ Model N ##########################

dir_pattern <- ".*Dir_other.*"
dirs <- list.dirs(result, recursive = TRUE, full.names = TRUE)
matching_dirs <- dirs[grep(dir_pattern, dirs)]
matching_dirs

enrichment_files_list <- list()

# Loop through the matching directories and find files with "enrichment_other" in their names
for (dir in matching_dirs) {
  # Find files matching the pattern "enrichment_other" in the directory
  files <- list.files(dir, pattern = "enrichment_other_out.results", full.names = TRUE)
  
  # Add the list of files to the result
  if (length(files) > 0) {
    enrichment_files_list[[dir]] <- files
  }
}

# Print the list of enrichment files
print(enrichment_files_list)


# Initialize a list to store the new data frames
dataframes_list <- list()
Full_dataframes_list <- list()

# Loop through the list of enrichment files
for (dir in names(enrichment_files_list)) {
  files <- enrichment_files_list[[dir]]
  
  for (file in files) {
    # Read the file using fread
    data <- fread(file)
	data <- as.data.frame(data)
	data$p_fdr <- p.adjust(data$Enrichment_p, method = "fdr")
    
    # Extract the first two rows
    first_two_rows <- data[1:2, ]
    
    # Store the resulting data frame in the list, using the file name as the key
    dataframes_list[[file]] <- first_two_rows
	Full_dataframes_list[[file]] <- data
  }
}

# Loop through the list of data frames
for (file in names(dataframes_list)) {
  # Access the data frame
  df <- dataframes_list[[file]]
  df_full <- Full_dataframes_list[[file]]
  
  # Replace pattern "L2" in all character columns
  char_cols <- names(df)[sapply(df, is.character)]  # Identify character column names
  for (col in char_cols) {
    df[[col]] <- gsub("L2", "other_Variants", df[[col]])  # Replace pattern in each column
  }

  char_cols <- names(df_full)[sapply(df_full, is.character)]  # Identify character column names
  for (col in char_cols) {
    df_full[[col]] <- gsub("L2", "other_Variants", df_full[[col]])  # Replace pattern in each column
  }
  
  # Update the modified data frame back into the list
  dataframes_list[[file]] <- df
  Full_dataframes_list[[file]] <- df_full
}


# Print the updated data frames
for (file in names(dataframes_list)) {

  cat("Processing file:", file, "\n\n")

  model_match <- dataframes_list[[file]]
  model_full  <- Full_dataframes_list[[file]]

  # Clean Category column
  model_match$Category <- gsub("_[0-9]+$", "", model_match$Category)
  model_full$Category  <- gsub("_[0-9]+$", "", model_full$Category)

  print(model_match)

  # Create a clean name from file path
  base_name <- basename(file)
  base_name <- tools::file_path_sans_ext(base_name)

  # Output CSV
  csv_out <- paste0(
    annot,
    "/HTML_model_N_output/M_",
    base_name,
    ".csv"
  )

  fwrite(model_match, csv_out, sep = ",")

  # Convert CSV to HTML
  csv_html <- paste(
    "/apps/conda/project/envs/imlabtools/bin/csvtotable",
    csv_out,
    paste0(
      annot,
      "/HTML_model_N_output/M_",
      base_name,
      ".html"
    )
  )

  system(csv_html)

  # Save full model output
  cell_out <- paste0(
    annot,
    "/HTML_model_N_output/baseline_Include_",
    base_name,
    ".csv"
  )

  fwrite(as.data.frame(model_full), cell_out, sep = ",")

  cat("Finished:", base_name, "\n\n")
}






# rm HTML_model*/*.csv HTML_model*/*.html
# mkdir HTML_model_1_3_output
# mkdir HTML_model_N_output
# result_dir=/apps/www/project/ldsc/result/r_505512/
# /apps/conda/project/envs/r_env/bin/Rscript /apps/www/project/ldsc/model_output.R $result_dir




#------------