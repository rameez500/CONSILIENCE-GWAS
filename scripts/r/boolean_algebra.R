library(data.table)
library(VennDiagram)
library(dplyr)
library(tidyr)


args <- commandArgs(trailingOnly = TRUE)
# Count the number of arguments
arg_count <- length(args)

#uploadeddir_files <- args[1:length(args)]
uploadeddir_files <- commandArgs(trailingOnly = TRUE)
print(uploadeddir_files)

dataframe_list <- list()
for (file_list in uploadeddir_files) {

	variable_name <- tools::file_path_sans_ext(basename(file_list))
	gene <- fread(file_list,header=FALSE)
	gene <- gene[gene$V1 != "-",]
	
	assign(variable_name, gene)
	
	# Add the dataframe to the list
	dataframe_list[[variable_name]] <- gene
	
}

print(names(dataframe_list))
print(length(dataframe_list))


# Loop through each dataframe in the list
for (name in names(dataframe_list)) {
  cat("\n--- Head of dataframe:", name, "---\n")
  print(head(dataframe_list[[name]]))
  print(dim(dataframe_list[[name]]))
}


gene_sets_vector <- lapply(dataframe_list, function(df) df$V1)


######################## Unions ###############################
######################## Unions ###############################

output_dir <- "union"
# Extract the directory path
directory_path <- dirname(uploadeddir_files[1])
#print(directory_path)

out_path <- paste(directory_path,"/",output_dir,sep = "")
#print("pathway")
#print(out_path)

if (!dir.exists(out_path)) {
  dir.create(out_path)
}


union_genes <- Reduce(union, gene_sets_vector)
union_df <- data.frame(Gene = union_genes)
print("Union of all gene sets:")
print(head(union_df))
print(dim(union_df))


# Check if the length of names(dataframe_list) is >= 3
if (length(names(dataframe_list)) >= 2) {
  # Construct the file name
  file_name <- paste0(out_path, "/", "All_UnionGenes.txt")
  # Write the union_df$Gene to the file
  write.table(union_df$Gene, file = file_name, row.names = FALSE, col.names = FALSE, quote = FALSE)
}


# Get all pairwise combinations of gene set names
# set_names <- names(gene_sets_vector)
# pairwise_combinations <- combn(set_names, 2, simplify = FALSE)

# # Compute union for each pair
# pairwise_unions <- lapply(pairwise_combinations, function(pair) {
  # union_genes <- union(gene_sets_vector[[pair[1]]], gene_sets_vector[[pair[2]]])
  # data.frame(Sets = paste(pair, collapse = "_U_"), Union_Genes = paste(union_genes, collapse = ", "))
# })

#pairwise_unions[[1]]$Sets
#pairwise_unions[[1]]$Union_Genes

# Combine results into a single dataframe
# union_df <- do.call(rbind, pairwise_unions)
# print("Union of each pair of gene sets:")
# print(head(union_df))


# Split Union_Genes into separate rows (convert comma-separated genes into individual values)

# union_long <- union_df %>%
  # separate_rows(Union_Genes, sep = ", ") %>%
  # mutate(Union_Genes = trimws(Union_Genes)) # Remove any extra whitespace

# unique_sets <- unique(union_long$Sets)

# model_union <- paste(unique_sets, collapse = " + ")
# print(model_union)
# # Save the string as one row in the file
# file_name <- paste0(out_path, "/", "model_union.txt")
# writeLines(model_union, con = file_name)


# Check if the length of names(dataframe_list) is >= 3
# if (length(names(dataframe_list)) >= 3) {
  # # Add "+ All_Unions" to the model
  # model_union <- paste(paste(unique_sets, collapse = " + "), "+ All_Unions")
  
  # # Save the updated model_union to the file
  # file_name <- paste0(out_path, "/", "model_union.txt")
  # writeLines(model_union, con = file_name)
  
# } else {
  # # Leave model_union as it is and save it
  # model_union <- paste(unique_sets, collapse = " + ")
  # file_name <- paste0(out_path, "/", "model_union.txt")
  # writeLines(model_union, con = file_name)
# }



# for (set_name in unique_sets) {
  # # Filter rows for the current set
  # genes <- union_long[union_long$Sets == set_name, "Union_Genes"]
  # print(head(genes))
  
  # # Create a filename based on the set name
  # #file_name <- paste0(gsub(" & ", "_", set_name), "_UnionGenes.txt")
  # file_name <- paste0(out_path, "/", gsub(" and ", "_", set_name), "_UnionGenes.txt")
  # print(file_name)
  
  # # Write the genes to a file
  # write.table(genes, file = file_name, row.names = FALSE, col.names = FALSE, quote = FALSE)
# }



################### intersection ######################
################## intersection ######################


output_dir <- "intersection"
# Extract the directory path
directory_path <- dirname(uploadeddir_files[1])
print(directory_path)

out_path <- paste(directory_path,"/",output_dir,sep = "")
#print(out_path)

if (!dir.exists(out_path)) {
  dir.create(out_path)
}


intersect_genes <- Reduce(intersect, gene_sets_vector)
intersect_df <- data.frame(Gene = intersect_genes)
print("intersect of all gene sets:")
print(head(intersect_df))
print(dim(intersect_df))



if (length(names(dataframe_list)) >= 3) {
  # Check if intersect_df$Gene has at least 2 entries
  if (length(intersect_df$Gene) >= 2) {
    # Construct the file name
    file_name <- paste0(out_path, "/", "All_IntersectionGenes.txt")
    # Write the intersect_df$Gene to the file
    write.table(intersect_df$Gene, file = file_name, row.names = FALSE, col.names = FALSE, quote = FALSE)
  }
}




# Get all pairwise combinations of gene set names
set_names <- names(gene_sets_vector)
pairwise_combinations <- combn(set_names, 2, simplify = FALSE)

# Compute intersection for each pair
pairwise_intersections <- lapply(pairwise_combinations, function(pair) {
  intersect_genes <- intersect(gene_sets_vector[[pair[1]]], gene_sets_vector[[pair[2]]])
  data.frame(Sets = paste(pair, collapse = "_and_"),
             Intersection_Genes = paste(intersect_genes, collapse = ", "))
})

# Combine results into a single dataframe
intersection_df <- do.call(rbind, pairwise_intersections)
print("Intersection of each pair of gene sets:")
#print(head(intersection_df))

# Split Intersection_Genes into separate rows (convert comma-separated genes into individual values)
intersection_long <- intersection_df %>%
  separate_rows(Intersection_Genes, sep = ", ") %>%
  mutate(Intersection_Genes = trimws(Intersection_Genes)) # Remove extra whitespace

# Generate a model-like string for intersections
unique_sets_intersection <- unique(intersection_long$Sets)
print("unique_sets_intersection")
print(head(unique_sets_intersection))

# model_intersection <- paste(unique_sets_intersection, collapse = " + ")
# print("Model of intersections:")
# print(model_intersection)
# # Save the string as one row in the file
# file_name <- paste0(out_path, "/", "model_Intersection.txt")
# writeLines(model_intersection, con = file_name)


if (length(names(dataframe_list)) >= 3) {
  # Add "+ All_Unions" to the model
  model_intersection <- paste(paste(unique_sets_intersection, collapse = " + "), "+ All_Intersection")
  
  # Save the updated model_union to the file
  file_name <- paste0(out_path, "/", "model_Intersection.txt")
  writeLines(model_intersection, con = file_name)
  
} else {
  # Leave model_union as it is and save it
	model_intersection <- paste(unique_sets_intersection, collapse = " + ")
	print("Model of intersections:")
	print(model_intersection)
	# Save the string as one row in the file
	file_name <- paste0(out_path, "/", "model_Intersection.txt")
	writeLines(model_intersection, con = file_name)
}




# Save intersection genes for each pairwise combination
for (set_name in unique_sets_intersection) {
  # Filter rows for the current set
  genes <- intersection_long[intersection_long$Sets == set_name, "Intersection_Genes"]
  print(head(genes))
  
  # Check if genes has at least 2 entries
  if (nrow(genes) > 1) {
    # Create a filename based on the set name
    #file_name <- paste0(gsub(" & ", "_", set_name), "_IntersectionGenes.txt")
	file_name <- paste0(out_path, "/", gsub(" and ", "_", set_name), "_IntersectionGenes.txt")

    print(file_name)
    
    # Write the genes to a file
    write.table(genes, file = file_name, row.names = FALSE, col.names = FALSE, quote = FALSE)
  } else {
    # Print a message if there are not enough genes
    message(paste("Skipping", set_name, "- not enough genes (less than 2)"))
  }
}



################################ Unique ######################################
############################### Unique ##################################

output_dir <- "Unique"
# Extract the directory path
directory_path <- dirname(uploadeddir_files[1])
#print(directory_path)

out_path <- paste(directory_path,"/",output_dir,sep = "")
#print(out_path)

if (!dir.exists(out_path)) {
  dir.create(out_path)
}



# Initialize an empty list to store unique genes for each set
unique_genes_list <- list()

# Compute unique genes for each gene set
for (set_name in names(gene_sets_vector)) {
  # Combine all other gene sets into one
  other_genes <- unlist(gene_sets_vector[names(gene_sets_vector) != set_name])
  
  # Find unique genes in the current set
  unique_genes <- setdiff(gene_sets_vector[[set_name]], other_genes)
  
  # Save to the unique genes list
  unique_genes_list[[set_name]] <- unique_genes
}

# Convert unique genes to a dataframe
unique_genes_df <- do.call(rbind, lapply(names(unique_genes_list), function(name) {
  data.frame(Set = name, Unique_Genes = paste(unique_genes_list[[name]], collapse = ", "))
}))
#print("Unique genes for each gene set:")
#print(head(unique_genes_df))

# Split unique genes into separate rows for better visibility
unique_long <- unique_genes_df %>%
  separate_rows(Unique_Genes, sep = ", ") %>%
  mutate(Unique_Genes = trimws(Unique_Genes)) # Remove extra whitespace

# Save unique genes to files for each gene set
for (set_name in names(unique_genes_list)) {
  # Check if there is at least 1 gene in the list
  if (length(unique_genes_list[[set_name]]) > 0) {
    # Create a filename
    #file_name <- paste0(set_name, "_UniqueGenes.txt")
	file_name <- paste0(out_path, "/", set_name, "_UniqueGenes.txt")

    print(paste("Saving file:", file_name))
    
    # Write the unique genes to a file
    write.table(unique_genes_list[[set_name]], file = file_name, row.names = FALSE, col.names = FALSE, quote = FALSE)
  } else {
    # Print a message if no genes to save
    print(paste("Skipping", set_name, "- no genes to save"))
  }
}


unique_sets <- names(unique_genes_list)
model_unique <- paste(unique_sets, collapse = " + ")
print("Model of unique gene sets:")
print(model_unique)

# Save the unique gene model as a single row in a file
file_name <- paste0(out_path, "/", "model_Unique.txt")
writeLines(model_unique, con = file_name)
print(paste("Model saved to file:", file_name))



#-----------------