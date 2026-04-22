library(data.table)
library(ggplot2)
library(tidyverse)
library(scales)


# Retrieve command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Count the number of arguments
arg_count <- length(args)

# Print the number of arguments
cat("Number of arguments passed:", arg_count, "\n")
annot <- args[1]
sum_name <- args[2]
#out_dir_res <- args[2]

directory <- annot
#files <- list.files(directory, pattern = "\\.results$", full.names = TRUE)
files <- list.files(directory, pattern = "enrichment_out.*\\.results$", full.names = TRUE)


# Initialize an empty list to store the data frames
annot_list <- list()
# Loop through each file and read it
for (file_l in files) {
  # Read the file (assuming it's tab-separated, adjust if necessary)
  annot_data <- fread(file_l, header = TRUE, sep = "\t")
  # Optionally, add a column to track the source file for debugging
  annot_data$source_file <- basename(file_l)
  base_name <- tools::file_path_sans_ext(basename(file_l))
  annot_Full_data <- as.data.frame(annot_data)
  annot_Full_data <- annot_Full_data[,1:10]
  annot_Full_data$p_fdr <- p.adjust(annot_Full_data$Enrichment_p, method = "fdr")
  annot_data <- as.data.frame(annot_Full_data[1,])
  #annot_data[, Category_renamed := ifelse(Category == annot_data[1,1], base_name, Category)]
  annot_data$Category[annot_data$Category == annot_data[1,1]] <- base_name
  
  # Append the data to the list
  annot_list[[length(annot_list) + 1]] <- annot_data
  
  cell_out <- paste(annot,"/","Baseline_Include_",base_name,".csv",sep = "")
  fwrite(annot_Full_data,cell_out,sep=",")
}

combined_annot_data <- do.call(rbind, annot_list)
combined_annot_data <- as.data.frame(combined_annot_data)
# Remove "enrichment_out" and replace "_" with a space
combined_annot_data$Category <- gsub("enrichment_out", "", combined_annot_data$Category)  # Remove "enrichment_out"
combined_annot_data$Category <- gsub("_", " ", combined_annot_data$Category)             # Replace "_" with a space
combined_annot_data$Category <- trimws(combined_annot_data$Category)    
head(combined_annot_data); dim(combined_annot_data)


df_enrich <- combined_annot_data %>%
  mutate(Coefficient_p_values = 1 - pnorm(`Coefficient_z-score`)) 	

df_enrich <- df_enrich %>%
  mutate(Coefficient_p_values_log = -log(Coefficient_p_values))
  

############## Change the label #############################


# path_dir <- paste(annot,"/","testing_label",sep = "")
# label <- fread(path_dir)
# print(label)
# label[, GeneWeaver_ID := gsub("\\..*", "", GeneWeaver_ID)]
# label <- as.data.frame(label)
# print(label)

path_dir <- paste(annot,"/../","workingtesting_label",sep = "")
dt <- fread(path_dir, header = TRUE)

# Extract values
ids <- unlist(strsplit(dt$Label[dt$GeneWeaver_ID == "geneweaver"], ","))
labels <- unlist(strsplit(dt$Label[dt$GeneWeaver_ID == "geneweaver_label"], ","))

# Combine into long format
label <- data.table(
  GeneWeaver_ID = ids,
  Label = labels
)
label <- as.data.frame(label)
print(label)


df_enrich$Category <- as.character(df_enrich$Category)
# Perform a left join to map the labels
df_enrich <- merge(
  df_enrich, 
  label, 
  by.x = "Category", 
  by.y = "GeneWeaver_ID", 
  all.x = TRUE
)

df_enrich$Category <- ifelse(
  is.na(df_enrich$Label),
  df_enrich$Category,
  df_enrich$Label
)


# Drop the Label column if it's no longer needed
df_enrich$Label <- NULL

# Print the updated dataframe
print(df_enrich)


############################################################

########################## Function definition  ###########################################
########################## Function definition  ###########################################
########################## Function definition  ###########################################


Enrichment <- function(df_enrich, out_dir_enrich,sum_name) {
  # Reorder categories based on Enrichment values
  df_enrich <- df_enrich %>% 
    mutate(Category = reorder(Category, Enrichment))  # Reorder by ascending Enrichment
  
  y_max <- max(df_enrich$Enrichment + df_enrich$Enrichment_std_error)
  y_min <- min(df_enrich$Enrichment - df_enrich$Enrichment_std_error)
  
  ggplot(df_enrich, aes(x = Category, y = Enrichment)) + 
    # Points with color determined by significance
    geom_point(aes(color = p_fdr < (0.05)), size = 4, alpha = 0.8) +
    # Error bars with more dashed lines
    geom_errorbar(
      aes(ymin = Enrichment - 1.96 * Enrichment_std_error, 
          ymax = Enrichment + 1.96 * Enrichment_std_error), 
      width = 0.2,  # Narrower error bars
      linetype = "longdash",  # More frequent dashes
      color = "black", 
      size = 0.6  # Thinner error bars
    ) +
    coord_flip() +  # Flip axes for horizontal orientation
    labs(
      title = "",
      x = "", 
      y = "Enrichment"
    ) +
    theme_minimal(base_size = 14) +  # Minimal theme with larger base font
    theme(
      plot.title = element_text(hjust = 0, face = "italic", size = 15, color = "#444444"),  # Left-aligned, italic, subtle dark gray
      axis.title.x = element_text(size = 14, face = "bold", color = "#333333"),  # Bold x-axis title
      axis.title.y = element_text(size = 14, face = "bold", color = "#333333"),  # Bold y-axis title
      axis.text.x = element_text(size = 12, color = "#666666"),  # x-axis labels
      axis.text.y = element_text(size = 12, color = "#666666"),  # y-axis labels
      plot.background = element_rect(fill = "#f5f5f5", color = NA),  # Light background
      panel.background = element_rect(fill = "#ffffff", color = NA),  # White panel background
      panel.grid.major = element_line(color = "#dcdcdc"),  # Light gray grid lines
      panel.grid.minor = element_blank(),  # No minor grid lines
      axis.line = element_line(color = "#333333", size = 0.5),  # Dark gray axis line
      axis.ticks = element_line(color = "#333333", size = 0.5)  # Dark gray axis ticks
    ) +
    expand_limits(y = c(y_min - 1, y_max + 1)) +
    scale_y_continuous(
      breaks = breaks_extended(n = 5),  # Adjust breaks
      labels = label_number(accuracy = 0.01, big.mark = "")  # Round numbers
    ) +
    scale_color_manual(values = c("TRUE" = "red", "FALSE" = "#69b3a2"), guide = "none")  # Red for significant, green otherwise
  
  ggsave(out_dir_enrich, width = 8, height = 5, units = "in", dpi = 600)
  
  # Return the result
  return(out_dir_enrich)
}


x <- sum_name
x <- basename(x)
x <- tools::file_path_sans_ext(basename(x))
x <- tools::file_path_sans_ext(basename(x))


out_dir_enrich <- paste(annot,"/","vis_enichment_enrich.png",sep = "")
#out_dir_enrich <- paste("/apps/www/project/ldsc/back_up/test","/","vis_enichment_enrich.png",sep = "")
enrich <- Enrichment(df_enrich,out_dir_enrich,x)


# save out the table
csv_out <- paste(annot,"/enichment_annote.csv",sep = "")
fwrite(df_enrich,csv_out,sep=",")
csv_html <- paste("/apps/conda/project/envs/imlabtools/bin/csvtotable ",annot,"/enichment_annote.csv"," ",annot,"/enichment_annote.html",sep= "")
system(csv_html)


##############################################################
##############################################################
##############################################################

# /apps/conda/project/envs/r_env/bin/Rscript cell_vis_3_V2.R $result_dir

# /apps/conda/project/envs/r_env/bin/Rscript /apps/www/project/ldsc/cell_vis_3_V2.R "/apps/www/project/ldsc/result/r_452123" "/apps/www/project/ldsc/result/r_452123/EA2_results_V2.txt.gz"

# /apps/conda/project/envs/r_env/bin/Rscript /apps/www/project/ldsc/cell_vis_3_V2.R "/apps/www/project/ldsc/result/r_874965" "/apps/www/project/ldsc/result/r_874965/EA2_results_V2.txt.gz"


# $sum_stat <- /apps/www/project/ldsc/result/r_452123/EA2_results_V2.txt.gz

# x <- "/apps/www/project/ldsc/result/r_452123/EA2_results_V2.txt.gz"
# x <- basename(x)
# x <- tools::file_path_sans_ext(basename(x))
# x <- tools::file_path_sans_ext(basename(x))