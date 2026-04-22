# Load necessary libraries
library(jsonlite)
library(data.table)

# Read the file path from the arguments
args <- commandArgs(trailingOnly = TRUE)
input_file <- args[1]
annot <- args[2]

# Read the JSON file into R
data <- fromJSON(input_file)

# Convert the list to a data frame
df <- data.frame(GeneWeaver_ID = names(data), Label = unlist(data, use.names = FALSE))

out_dir <- paste(annot,"testing_label",sep = "")
fwrite(df,out_dir,sep = "\t")

# Display the data frame
print(df)
