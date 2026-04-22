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

x_sum <- sum_name
x_sum <- basename(x_sum)
x_sum <- tools::file_path_sans_ext(basename(x_sum))
x_sum <- tools::file_path_sans_ext(basename(x_sum))

######### Estimating proportion of heritability by cell-type group ######################
######### Estimating proportion of heritability by cell-type group ######################

# Read in the files
cns <- fread(paste(annot,"/","sumstat_CNS.results",sep = ""))
head(cns); dim(cns)
ske <- fread(paste(annot,"/","sumstat_SkeletalMuscle.results",sep = ""))
Adr <- fread(paste(annot,"/","sumstat_Adrenal_Pancreas.results",sep = ""))
Connective_Bone <- fread(paste(annot,"/","sumstat_Connective_Bone.results",sep = ""))
GI <- fread(paste(annot,"/","sumstat_GI.results",sep = ""))
Hematopoietic <- fread(paste(annot,"/","sumstat_Hematopoietic.results",sep = ""))
Kidney <- fread(paste(annot,"/","sumstat_Kidney.results",sep = ""))
Liver <- fread(paste(annot,"/","sumstat_Liver.results",sep = ""))
Other <- fread(paste(annot,"/","sumstat_Other.results",sep = ""))
Cardiovascular <- fread(paste(annot,"/","sumstat_Cardiovascular.results",sep = ""))


# Combine datasets with updated category names
combined_data <- cns %>%
  filter(Category == "L2_0") %>%
  mutate(Category = "CNS", Cell_type = "CNS") %>%
  bind_rows(ske %>% 
              filter(Category == "L2_0") %>%
              mutate(Category = "SkeletalMuscle", Cell_type = "SkeletalMuscle")) %>%
  bind_rows(Adr %>% 
              filter(Category == "L2_0") %>%
              mutate(Category = "Adrenal_Pancreas", Cell_type = "Adrenal_Pancreas")) %>%
  bind_rows(Connective_Bone %>% 
              filter(Category == "L2_0") %>%
              mutate(Category = "Connective_Bone", Cell_type = "Connective_Bone"))	 %>%		  
  bind_rows(GI %>% 
              filter(Category == "L2_0") %>%
              mutate(Category = "GI", Cell_type = "GI")) %>%
  bind_rows(Hematopoietic %>% 
              filter(Category == "L2_0") %>%
              mutate(Category = "Hematopoietic", Cell_type = "Hematopoietic")) %>%
  bind_rows(Kidney %>% 
              filter(Category == "L2_0") %>%
              mutate(Category = "Kidney", Cell_type = "Kidney")) %>%
  bind_rows(Liver %>% 
              filter(Category == "L2_0") %>%
              mutate(Category = "Liver", Cell_type = "Liver"))	%>%	 	  
  bind_rows(Other %>% 
              filter(Category == "L2_0") %>%
              mutate(Category = "Other", Cell_type = "Other"))	%>%		  
  bind_rows(Cardiovascular %>% 
              filter(Category == "L2_0") %>%
              mutate(Category = "Cardiovascular", Cell_type = "Cardiovascular"))			  



combined_data <- as.data.frame(combined_data)
combined_data$p_adjusted <- p.adjust(combined_data$Enrichment_p, method = "BH")
combined_data$logp <- -log10(combined_data$Enrichment_p)
head(combined_data); dim(combined_data)


cell_type_out <- paste(annot,"/cell_type_out.csv",sep = "")
fwrite(combined_data,cell_type_out,sep=",")
cell_type_out_html <- paste("/apps/conda/project/envs/imlabtools/bin/csvtotable ",annot,"/cell_type_out.csv"," ",annot,"/cell_type_out.html",sep= "")
system(cell_type_out_html)


############# FDR < 0.05 #################################

alpha <- 0.05
m <- nrow(combined_data)
pvals <- combined_data$Enrichment_p

# i = seq(along=pvals)
# k <- max( which( sort(pvals) < i/m*alpha) )
# cutoff <- sort(pvals)[k]
# P <- -log10(cutoff)



############## Bonferroni-corrected significance ####################### 

p_bon <- -log10(alpha/m)
p_bon

# ggplot(data = combined_data, aes(x = Category, y = -log10(Enrichment_p))) +
  # geom_point(aes(color = Category, size = -log10(Enrichment_p))) + 
  # geom_hline(yintercept = p_bon, linetype = "dashed", color = "black", size = 1) + 
  # xlab("Cell Type") +  # X-axis title text
  # ylab("-log10P") +
  # ggtitle(x_sum) +
  # scale_color_discrete(name = "") +
  # scale_size_continuous(range = c(3, 6)) +  # Adjust size as needed
  # guides(size = "none") +  # Hide size legend
  # theme_minimal() +
  # theme(
    # axis.text.x = element_blank(),   # Remove x-axis tick labels
    # legend.text = element_text(size = 14),  # Increase font size of legend text
    # panel.background = element_rect(fill = "white"),  # Set white background for the plot area
    # plot.background = element_rect(fill = "white"),	
	
	# plot.title = element_text(
	# hjust = 0,             # Align title to the left
	# face = "italic",       # Use italic for a more stylish look
	# size = 16,             # Slightly smaller size
	# color = "#444444"      # Subtle dark gray color
	# )	# Set white background for the entire plot
  # ) + 
  # guides(color = guide_legend(override.aes = list(shape = 15, size = 5)))  # Rectangle shape in legend 

# out_dir <- paste(annot,"/","sumstat_cell_group.png",sep = "")
# #out_dir <- paste("/apps/www/project/ldsc/back_up/test","/","sumstat_cell_group.png",sep = "")
# ggsave(out_dir, width = 8, height = 5, units = "in",dpi = 600) 


# ============ PLOT (NO AUTO-PRINT!) ============
p <- ggplot(combined_data, aes(x = reorder(Category, -logp), y = logp)) +
  
  # Points
  geom_point(aes(color = Category, size = -log10(Enrichment_p))) +
  
  # Bonferroni line
  geom_hline(yintercept = p_bon, linetype = "dashed", color = "black", size = 1) + 
  
  # Axis labels
  xlab("Cell Type") +
  ylab(expression(bold(-log[10](P)))) +   # Bold y-axis label
  
  # Title (blank or add custom later)
  ggtitle("") +
  
  # Color legend
  scale_color_discrete(name = "") +
  
  # Point size scaling
  scale_size_continuous(range = c(4, 8)) +
  guides(size = "none") +   # Hide size legend
  
  # Clean minimal theme
  theme_minimal(base_size = 16) +   # Bigger base font
  theme(
    axis.text.x = element_blank(),      # No x labels
    axis.title.x = element_text(size = 18, face = "bold"),   # Bold x title
    axis.title.y = element_text(size = 18, face = "bold"),   # Bold y title
    axis.text.y = element_text(size = 14, face = "bold"),    # Clean bold y labels
    
    legend.text = element_text(size = 16, face = "bold"),     # Better legend text
    legend.key.size = unit(1.1, "cm"),
    
    panel.background = element_rect(fill = "white"),
    plot.background  = element_rect(fill = "white"),
    
    plot.title = element_text(
      hjust = 0,
      face = "italic",
      size = 18,
      color = "#444444"
    )
  ) +
  
  # Rectangle symbol in legend
  guides(
    color = guide_legend(
      override.aes = list(shape = 15, size = 6)
    )
  )


out_dir <- paste(annot,"/","sumstat_cell_group.png",sep = "")
#out_dir <- paste("/apps/www/project/ldsc/back_up/test","/","sumstat_cell_group.png",sep = "")
#ggsave(out_dir, width = 8, height = 5, units = "in",dpi = 600) 
print(out_dir)
ggsave(filename = out_dir, plot = p, width = 12, height = 7, dpi = 300, bg = "white")

# CRITICAL: Prevent R from auto-opening Rplots.pdf
invisible(p)
invisible(gc())  # clean up






###################### Road Map ##################################
###################### Road Map ##################################
###################### Road Map ##################################

Roadmap <- fread(paste(annot,"/","Roadmap.cell_type_results.txt",sep = ""))
Roadmap <- as.data.frame(Roadmap)
Roadmap$p_adjusted <- p.adjust(Roadmap$Coefficient_P_value, method = "BH")
Roadmap$logp <- -log10(Roadmap$Coefficient_P_value)
Roadmap <- Roadmap[order(Roadmap$Coefficient_P_value),]
head(Roadmap); dim(Roadmap)

Roadmap_out <- paste(annot,"/Roadmap_out.csv",sep = "")
fwrite(Roadmap,Roadmap_out,sep=",")
Roadmap_out_html <- paste("/apps/conda/project/envs/imlabtools/bin/csvtotable ",annot,"/Roadmap_out.csv"," ",annot,"/Roadmap_out.html",sep= "")
system(Roadmap_out_html)


############# FDR < 0.05 #################################

alpha <- 0.05
m <- nrow(Roadmap)
pvals <- Roadmap$Coefficient_P_value

i = seq(along=pvals)
k <- max( which( sort(pvals) < i/m*alpha) )
cutoff <- sort(pvals)[k]
P <- -log10(cutoff)



############## Bonferroni-corrected significance ####################### 

p_bon <- -log10(alpha/m)
p_bon

Roadmap <- Roadmap %>% 
  mutate(Name = reorder(Name, Coefficient_P_value))  # Reorder by ascending Enrichment


# Assuming 'Roadmap' data is already loaded and has the required columns
p <- ggplot(data = Roadmap[1:25, ], aes(x = reorder(Name, -log10(Coefficient_P_value)), 
                                   y = -log10(Coefficient_P_value))) +
  # Points with color based on crossing p_bon value
  geom_point(aes(color = ifelse(-log10(Coefficient_P_value) > p_bon, "Significant", "Not Significant")), 
             size = 4, alpha = 0.8) +
  # Add horizontal significance lines
  geom_hline(yintercept = p_bon, linetype = "dashed", color = "black", size = 1) + 
  geom_hline(yintercept = P, linetype = "dashed", color = "grey", size = 1) + 
  coord_flip() +  # Flip axes for horizontal orientation
  # Axis labels and title
  xlab("") + 
  ylab("-log10 P-value") +
  ggtitle(x_sum) +
  # Manual color scale for points
  scale_color_manual(values = c("Significant" = "red", "Not Significant" = "blue"), guide = "none") +
  # Minimal theme with bold labels
  theme_minimal(base_size = 14) +
  theme(
    axis.text.y = element_text(size = 12, face = "bold", color = "#333333"),  # Make names bold and dark
    axis.title.x = element_text(size = 14, face = "bold", color = "#333333"),  # Bold x-axis title
    axis.title.y = element_text(size = 14, face = "bold", color = "#333333"),  # Bold y-axis title
    legend.text = element_text(size = 10),  # Legend text size
    panel.background = element_rect(fill = "white"),  # White panel background
    plot.background = element_rect(fill = "white"),  # White background
    
	plot.title = element_text(
	hjust = 0,             # Align title to the left
	face = "italic",       # Use italic for a more stylish look
	size = 14,             # Slightly smaller size
	color = "#444444"      # Subtle dark gray color
	)	# Set white background for the entire plot
	
  ) +
  # Add attractive labels with better formatting
  theme(
    axis.text.y = element_text(
      size = 10, 
      face = "bold", 
      color = "#333333", 
      angle = 0,  # Keep labels horizontal for readability
      margin = margin(t = 5, r = 10, b = 5, l = 10)  # Adjust spacing around labels
    )
  )
out_dir <- paste(annot,"/","sumstat_Roadmap.png",sep = "")
#out_dir <- paste("/apps/www/project/ldsc/back_up/test","/","sumstat_Roadmap.png",sep = "")
#ggsave(out_dir, width = 14, height = 12, units = "in",dpi = 600) 

print(out_dir)
ggsave(filename = out_dir, plot = p, width = 12, height = 7, dpi = 300, bg = "white")

# CRITICAL: Prevent R from auto-opening Rplots.pdf
invisible(p)
invisible(gc())  # clean up



###################### Cahoy ##################################
###################### Cahoy ##################################
###################### Cahoy ##################################


Cahoy <- fread(paste(annot,"/","Cahoy.cell_type_results.txt",sep = ""))
Cahoy <- as.data.frame(Cahoy)
Cahoy$p_adjusted <- p.adjust(Cahoy$Coefficient_P_value, method = "BH")
Cahoy$logp <- -log10(Cahoy$Coefficient_P_value)
head(Cahoy); dim(Cahoy)

Cahoy_out <- paste(annot,"/Cahoy_out.csv",sep = "")
fwrite(Cahoy,Cahoy_out,sep=",")
Cahoy_out_html <- paste("/apps/conda/project/envs/imlabtools/bin/csvtotable ",annot,"/Cahoy_out.csv"," ",annot,"/Cahoy_out.html",sep= "")
system(Cahoy_out_html)


alpha <- 0.05
m <- nrow(Cahoy)


# ############## Bonferroni-corrected significance ####################### 

p_bon <- -log10(alpha/m)
p_bon

p <- ggplot(data = Cahoy, aes(x = Name, y = -log10(Coefficient_P_value))) +
  geom_point(aes(color = Name, size = -log10(Coefficient_P_value))) + 
  geom_hline(yintercept = p_bon, linetype = "dashed", color = "black", size = 1) + 
  xlab("Cell Type") +  # X-axis title text
  ylab("-log10P") +
  ggtitle(x_sum) +
  scale_color_discrete(name = "") +
  scale_size_continuous(range = c(3, 6)) +  # Adjust size as needed
  guides(size = "none") +  # Hide size legend
  theme_minimal() +
  theme(
    axis.text.x = element_blank(),   # Remove x-axis tick labels
    legend.text = element_text(size = 14),  # Increase font size of legend text
    panel.background = element_rect(fill = "white"),  # Set white background for the plot area
    plot.background = element_rect(fill = "white"),   # Set white background for the entire plot
	
	plot.title = element_text(
	hjust = 0,             # Align title to the left
	face = "italic",       # Use italic for a more stylish look
	size = 16,             # Slightly smaller size
	color = "#444444"      # Subtle dark gray color
	)	# Set white background for the entire plot
  ) +
  guides(color = guide_legend(override.aes = list(shape = 15, size = 5)))  # Rectangle shape in legend

out_dir <- paste(annot,"/","sumstat_Cahoy.png",sep = "")
#out_dir <- paste("/apps/www/project/ldsc/back_up/test","/","sumstat_Cahoy.png",sep = "")
#ggsave(out_dir, width = 8, height = 5, units = "in",dpi = 600) 

print(out_dir)
ggsave(filename = out_dir, plot = p, width = 12, height = 7, dpi = 300, bg = "white")

# CRITICAL: Prevent R from auto-opening Rplots.pdf
invisible(p)
invisible(gc())  # clean up



###################### GTEx ##################################
###################### GTEx ##################################
###################### GTEx ##################################

GTEx <- fread(paste(annot,"/","GTEx.cell_type_results.txt",sep = ""))
GTEx <- as.data.frame(GTEx)
GTEx$p_adjusted <- p.adjust(GTEx$Coefficient_P_value, method = "BH")
GTEx$logp <- -log10(GTEx$Coefficient_P_value)
GTEx <- GTEx[order(GTEx$Coefficient_P_value),]
head(GTEx); dim(GTEx)

GTEx_out <- paste(annot,"/GTEx_out.csv",sep = "")
fwrite(GTEx,GTEx_out,sep=",")
GTEx_out_html <- paste("/apps/conda/project/envs/imlabtools/bin/csvtotable ",annot,"/GTEx_out.csv"," ",annot,"/GTEx_out.html",sep= "")
system(GTEx_out_html)


############# FDR < 0.05 #################################

alpha <- 0.05
m <- nrow(GTEx)
pvals <- GTEx$Coefficient_P_value

i = seq(along=pvals)
k <- max( which( sort(pvals) < i/m*alpha) )
cutoff <- sort(pvals)[k]
P <- -log10(cutoff)


############## Bonferroni-corrected significance ####################### 

p_bon <- -log10(alpha/m)
p_bon

GTEx <- GTEx %>% 
  mutate(Name = reorder(Name, Coefficient_P_value))  # Reorder by ascending Enrichment


# Assuming 'Roadmap' data is already loaded and has the required columns
p <- ggplot(data = GTEx[1:25, ], aes(x = reorder(Name, -log10(Coefficient_P_value)), 
                                   y = -log10(Coefficient_P_value))) +
  # Points with color based on crossing p_bon value
  geom_point(aes(color = ifelse(-log10(Coefficient_P_value) > p_bon, "Significant", "Not Significant")), 
             size = 4, alpha = 0.8) +
  # Add horizontal significance lines
  geom_hline(yintercept = p_bon, linetype = "dashed", color = "black", size = 1) + 
  geom_hline(yintercept = P, linetype = "dashed", color = "grey", size = 1) + 
  coord_flip() +  # Flip axes for horizontal orientation
  # Axis labels and title
  xlab("") + 
  ylab("-log10 P-value") +
  ggtitle(x_sum) +
  # Manual color scale for points
  scale_color_manual(values = c("Significant" = "red", "Not Significant" = "blue"), guide = "none") +
  # Minimal theme with bold labels
  theme_minimal(base_size = 14) +
  theme(
    axis.text.y = element_text(size = 12, face = "bold", color = "#333333"),  # Make names bold and dark
    axis.title.x = element_text(size = 14, face = "bold", color = "#333333"),  # Bold x-axis title
    axis.title.y = element_text(size = 14, face = "bold", color = "#333333"),  # Bold y-axis title
    legend.text = element_text(size = 10),  # Legend text size
    panel.background = element_rect(fill = "white"),  # White panel background
    plot.background = element_rect(fill = "white"),  # White background
    
	plot.title = element_text(
	hjust = 0,             # Align title to the left
	face = "italic",       # Use italic for a more stylish look
	size = 16,             # Slightly smaller size
	color = "#444444"      # Subtle dark gray color
	)	# Set white background for the entire plot
	
  ) +
  # Add attractive labels with better formatting
  theme(
    axis.text.y = element_text(
      size = 10, 
      face = "bold", 
      color = "#333333", 
      angle = 0,  # Keep labels horizontal for readability
      margin = margin(t = 5, r = 10, b = 5, l = 10)  # Adjust spacing around labels
    )
  )
  
out_dir <- paste(annot,"/","sumstat_GTEx.png",sep = "")
#out_dir <- paste("/apps/www/project/ldsc/back_up/test","/","sumstat_GTEx.png",sep = "")
#ggsave(out_dir, width = 12, height = 8, units = "in",dpi = 600) 

print(out_dir)
ggsave(filename = out_dir, plot = p, width = 12, height = 7, dpi = 300, bg = "white")

# CRITICAL: Prevent R from auto-opening Rplots.pdf
invisible(p)
invisible(gc())  # clean up



###################### Mouse immune ##################################
###################### Mouse immune ##################################
###################### Mouse immune ##################################

immune <- fread(paste(annot,"/","ImmGen.cell_type_results.txt",sep = ""))
immune <- as.data.frame(immune)
immune$p_adjusted <- p.adjust(immune$Coefficient_P_value, method = "BH")
immune$logp <- -log10(immune$Coefficient_P_value)
immune <- immune[order(immune$Coefficient_P_value),]
head(immune); dim(immune)

immune_out <- paste(annot,"/immune_out.csv",sep = "")
fwrite(immune,immune_out,sep=",")
immune_out_html <- paste("/apps/conda/project/envs/imlabtools/bin/csvtotable ",annot,"/immune_out.csv"," ",annot,"/immune_out.html",sep= "")
system(immune_out_html)


alpha <- 0.05
m <- nrow(immune)

############## Bonferroni-corrected significance ####################### 

p_bon <- -log10(alpha/m)
p_bon

immune <- immune %>% 
  mutate(Name = reorder(Name, Coefficient_P_value))  # Reorder by ascending Enrichment


# Assuming 'Roadmap' data is already loaded and has the required columns
p <- ggplot(data = immune[1:25, ], aes(x = reorder(Name, -log10(Coefficient_P_value)), 
                                y = -log10(Coefficient_P_value))) +
  # Points with color based on crossing p_bon value
  geom_point(aes(color = ifelse(-log10(Coefficient_P_value) > p_bon, "Significant", "Not Significant")), 
             size = 4, alpha = 0.8) +
  # Add horizontal significance lines
  geom_hline(yintercept = p_bon, linetype = "dashed", color = "black", size = 1) + 
  coord_flip() +  # Flip axes for horizontal orientation
  # Axis labels and title
  xlab("") + 
  ylab("-log10 P-value") +
  ggtitle(x_sum) +
  # Manual color scale for points
  scale_color_manual(values = c("Significant" = "red", "Not Significant" = "blue"), guide = "none") +
  # Minimal theme with bold labels
  theme_minimal(base_size = 14) +
  theme(
    axis.text.y = element_text(size = 12, face = "bold", color = "#333333"),  # Make names bold and dark
    axis.title.x = element_text(size = 14, face = "bold", color = "#333333"),  # Bold x-axis title
    axis.title.y = element_text(size = 14, face = "bold", color = "#333333"),  # Bold y-axis title
    legend.text = element_text(size = 10),  # Legend text size
    panel.background = element_rect(fill = "white"),  # White panel background
    plot.background = element_rect(fill = "white"),  # White background
    
	plot.title = element_text(
	hjust = 0,             # Align title to the left
	face = "italic",       # Use italic for a more stylish look
	size = 16,             # Slightly smaller size
	color = "#444444"      # Subtle dark gray color
	)	# Set white background for the entire plot
	
  ) +
  # Add attractive labels with better formatting
  theme(
    axis.text.y = element_text(
      size = 10, 
      face = "bold", 
      color = "#333333", 
      angle = 0,  # Keep labels horizontal for readability
      margin = margin(t = 5, r = 10, b = 5, l = 10)  # Adjust spacing around labels
    )
  )

out_dir <- paste(annot,"/","sumstat_immune.png",sep = "")
#out_dir <- paste("/apps/www/project/ldsc/back_up/test","/","sumstat_immune.png",sep = "")
#ggsave(out_dir, width = 10, height = 10, units = "in",dpi = 600) 


print(out_dir)
ggsave(filename = out_dir, plot = p, width = 12, height = 7, dpi = 300, bg = "white")

# CRITICAL: Prevent R from auto-opening Rplots.pdf
invisible(p)
invisible(gc())  # clean up




######################## html ################################
######################## html ################################
######################## html ################################


# /apps/conda/project/envs/r_env/bin/Rscript /apps/www/project/ldsc/cell_specific_V2.R "/apps/www/project/ldsc/result/r_452123" "/apps/www/project/ldsc/result/r_452123/EA2_results_V2.txt.gz"




##--------------------