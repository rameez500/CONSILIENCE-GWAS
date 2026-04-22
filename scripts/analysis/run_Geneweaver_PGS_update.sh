#!/bin/bash
# /apps/www-dev/support/script/analysis/run_Geneweaver_PGS.sh

# Initialize variables
sum_stat=""
target_bim=""
result_dir=""
N=""
windowSize=""
file_png=""
file_png2=""
geneLabel=""
uploadeddir_str=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -sum_stat)
      sum_stat="$2"
      shift
      shift
      ;;
    -target_bim)
      target_bim="$2"
      shift
      shift
      ;;	  
    -result_dir)
      result_dir="$2"
      shift
      shift
      ;;
    -N)
      N="$2"
      shift
      shift
      ;;
    -windowSize)
      windowSize="$2"
      shift
      shift
      ;;
    -file_png)
      file_png="$2"
      shift
      shift
      ;;
    -file_png2)
      file_png2="$2"
      shift
      shift
      ;;
    -geneLabel)
      geneLabel="$2"
      shift
      shift
      ;;
    -geneID)
      uploadeddir_str="$2"
      shift
      shift
      ;;		  
    *)
      echo "Invalid option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "$sum_stat" ] || [ -z "$result_dir" ] || [ -z "$N" ] || [ -z "$windowSize" ]; then
    echo "ERROR: Missing required parameters"
    echo "Usage: $0 -sum_stat <file> -result_dir <dir> -N <sample_size> -windowSize <size>"
    exit 1
fi

echo "=== Starting GeneWeaver PGS Analysis ==="
echo "Summary statistics: $sum_stat"
echo "Target BIM: $target_bim"
echo "Result directory: $result_dir"
echo "Sample size: $N"
echo "Window size: $windowSize"
echo "Gene IDs: $uploadeddir_str"

# Create result directory if it doesn't exist
mkdir -p "$result_dir"

# Convert gene IDs string to array
IFS=',' read -r -a uploadeddir_array <<< "$uploadeddir_str"

echo "Number of Gene IDs: ${#uploadeddir_array[@]}"
echo "Gene IDs: ${uploadeddir_array[*]}"

# Process gene labels if provided
if [ -n "$geneLabel" ] && [ -f "$geneLabel" ]; then
    echo "Processing gene labels from: $geneLabel"
    /apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/dat_label.R "$geneLabel" "$result_dir"
else
    echo "No gene label file provided or file not found"
fi

# Extract base name from sumstat file
sumpath_with_extension=$(basename "$sum_stat")
sum_name="${sumpath_with_extension%.*}"
sum_name="${sum_name%.*}"
sum_name="${sum_name%.*}"
echo "GWAS file base name: $sum_name"

# Process each Gene ID
echo "Processing Gene IDs..."
for gene_id in "${uploadeddir_array[@]}"; do
    echo "Processing GeneID: $gene_id"
    
    /apps/conda/project/envs/py3_10/bin/python \
        /apps/www-dev/support/script/python/GeneWeaver_pipeline.py \
        --GeneID "$gene_id" \
        --dir_out "$result_dir"
        
    if [ $? -ne 0 ]; then
        echo "WARNING: Failed to process GeneID: $gene_id"
    fi
done

# Generate output files list
echo "Generated output files:"
find "$result_dir" -name "*.txt" -o -name "*.csv" -o -name "*.png" | while read -r file; do
    echo "  - $file"
done

# Run the final analysis script
echo "Running final analysis..."
/apps/conda/project/envs/py39/bin/python \
    /apps/www-dev/support/script/python/gwas_vis.py \
    --sum_file "$sum_stat" \
    --N "$N" \
    --file_png "$file_png" \
    --filegene "$file_png2"

PYTHON_EXIT_CODE=$?

if [ $PYTHON_EXIT_CODE -ne 0 ]; then
    echo "ERROR: Final analysis script failed with exit code: $PYTHON_EXIT_CODE"
    exit $PYTHON_EXIT_CODE
fi

# =========================================================================
# REST OF YOUR ORIGINAL PGS SCRIPT
# =========================================================================

echo "=== Starting Advanced PGS Analysis ==="

# Discover files dynamically instead of constructing paths - FIXED
full_paths_with_ext=()

for gene_id in "${uploadeddir_array[@]}"; do
    # Look for the actual file that was created
    found_file=$(find "$result_dir" -name "${gene_id}.txt" -type f | head -1)
    
    if [ -n "$found_file" ] && [ -f "$found_file" ]; then
        echo "✓ Found file: $found_file"
        full_paths_with_ext+=("$found_file")
    else
        echo "✗ File not found for GeneID: $gene_id"
        # Try alternative patterns
        alt_file=$(find "$result_dir" -name "*${gene_id}*" -name "*.txt" -type f | head -1)
        if [ -n "$alt_file" ] && [ -f "$alt_file" ]; then
            echo "✓ Found alternative file: $alt_file"
            full_paths_with_ext+=("$alt_file")
        else
            echo "ERROR: No file found for GeneID: $gene_id"
            exit 1
        fi
    fi
done

echo "Discovered files:"
printf "%s\n" "${full_paths_with_ext[@]}"

# Check if we have any files to process
if [ ${#full_paths_with_ext[@]} -eq 0 ]; then
    echo "ERROR: No gene set files found. Cannot proceed with advanced analysis."
    exit 1
fi

# Boolean algebra and model processing
echo "Running boolean algebra with ${#full_paths_with_ext[@]} files..."
/apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/boolean_algebra.R "${full_paths_with_ext[@]}"

echo "Running model processing with ${#full_paths_with_ext[@]} files..."
/apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/model_processing.R "${full_paths_with_ext[@]}"



# Process Unions - FIXED: Check if directory exists first
if [ -d "${result_dir}/union" ]; then
    union_array=($(find "${result_dir}/union" -type f -name '*UnionGenes*.txt'))
    echo "Union files found:"
    for file in "${union_array[@]}"; do
        echo "$file"
    done
    if [ ${#union_array[@]} -gt 0 ]; then
        /apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/model_processing.R "${union_array[@]}"
    fi
else
    echo "No union directory found"
fi


# Process Intersections - FIXED: Check if directory exists first  
if [ -d "${result_dir}/intersection" ]; then
    intersect_array=($(find "${result_dir}/intersection" -type f -name '*IntersectionGenes*.txt'))
    echo "Intersection files found:"
    for file in "${intersect_array[@]}"; do
        echo "$file"
    done
    if [ ${#intersect_array[@]} -gt 0 ]; then
        /apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/model_processing.R "${intersect_array[@]}"
    fi
else
    echo "No intersection directory found"
fi


# Process Unique - FIXED: Check if directory exists first
if [ -d "${result_dir}/Unique" ]; then
    unique_array=($(find "${result_dir}/Unique" -type f -name '*UniqueGenes*.txt'))
    echo "Unique files found:"
    for file in "${unique_array[@]}"; do
        echo "$file"
    done
    if [ ${#unique_array[@]} -gt 0 ]; then
        /apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/model_processing.R "${unique_array[@]}"
    fi
else
    echo "No Unique directory found"
fi


## Munge summary statistics
/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/munge_sumstats.py \
--sumstats "$sum_stat" \
--merge-alleles /apps/www-dev/support/data/ref/w_hm3.snplist \
--N "$N" --snp SNP_ID --p Pval --a1 A1 --a2 A2  \
--chunksize 50000 \
--out "$result_dir/$sum_name"

# Create annotations for each gene set
last_index=$((${#full_paths_with_ext[@]} - 1))

for index in $(seq 0 $last_index); do
    bed_file="${full_paths_with_ext[$index]}"
    base_name="${uploadeddir_array[$index]}"

    for i in {1..22}; do
		/apps/www-dev/support/script/analysis/run_make_annot.sh \
        --gene-set-file "$bed_file" \
        --gene-coord-file /apps/www-dev/support/data/ENSG_coord.txt \
        --windowsize "$windowSize" \
        --bimfile /apps/www-dev/support/data/ref/1000G_EUR_Phase3_plink/1000G.EUR.QC.${i}.bim \
        --annot-file "$result_dir/${base_name}.${i}.annot.gz" &
    done
done
wait
echo "All annotation jobs finished."

# Calculate LD scores
for index in $(seq 0 $last_index); do
    base_name="${uploadeddir_array[$index]}"
    
    for i in {1..22}; do
        /apps/conda/project/envs/ldsc/bin/python \
        /apps/www-dev/support/script/ldsc/ldsc.py \
        --l2 \
        --bfile /apps/www-dev/support/data/ref/1000G_EUR_Phase3_plink/1000G.EUR.QC.${i} \
        --ld-wind-cm 1 \
        --annot "$result_dir/${base_name}.${i}.annot.gz" \
        --thin-annot \
        --out "$result_dir/${base_name}.${i}" \
        --print-snps /apps/www-dev/support/data/ref/listHM3.txt &
    done
done
wait
echo "All LD score calculation jobs finished."

# Process union annotations
base_names_union=()
for file in "${union_array[@]}"; do
    base_name=$(basename "$file")
    base_name="${base_name%.*}"
    base_name="${base_name%.*}"
    base_names_union+=("$base_name")
done

last_index_union=$((${#union_array[@]} - 1))
for index in $(seq 0 $last_index_union); do
    bed_file="${union_array[$index]}"
    base_name="${base_names_union[$index]}"

    for i in {1..22}; do
		/apps/www-dev/support/script/analysis/run_make_annot.sh \
        --gene-set-file "$bed_file" \
        --gene-coord-file /apps/www-dev/support/data/ENSG_coord.txt \
        --windowsize "$windowSize" \
        --bimfile /apps/www-dev/support/data/ref/1000G_EUR_Phase3_plink/1000G.EUR.QC.${i}.bim \
        --annot-file "$result_dir/union/${base_name}.${i}.annot.gz" &
    done
done
wait

for index in $(seq 0 $last_index_union); do
    base_name="${base_names_union[$index]}"
    
    for i in {1..22}; do
        /apps/conda/project/envs/ldsc/bin/python \
        /apps/www-dev/support/script/ldsc/ldsc.py \
        --l2 \
        --bfile /apps/www-dev/support/data/ref/1000G_EUR_Phase3_plink/1000G.EUR.QC.${i} \
        --ld-wind-cm 1 \
        --annot "$result_dir/union/${base_name}.${i}.annot.gz" \
        --thin-annot \
        --out "$result_dir/union/${base_name}.${i}" \
        --print-snps /apps/www-dev/support/data/ref/listHM3.txt &
    done
done
wait

# Process intersection annotations
base_names_intersect=()
for file in "${intersect_array[@]}"; do
    base_name=$(basename "$file")
    base_name="${base_name%.*}"
    base_name="${base_name%.*}"
    base_names_intersect+=("$base_name")
done

last_index_intersect=$((${#intersect_array[@]} - 1))
for index in $(seq 0 $last_index_intersect); do
    bed_file="${intersect_array[$index]}"
    base_name="${base_names_intersect[$index]}"
    
    for i in {1..22}; do
		/apps/www-dev/support/script/analysis/run_make_annot.sh \
        --gene-set-file "$bed_file" \
        --gene-coord-file /apps/www-dev/support/data/ENSG_coord.txt \
        --windowsize "$windowSize" \
        --bimfile /apps/www-dev/support/data/ref/1000G_EUR_Phase3_plink/1000G.EUR.QC.${i}.bim \
        --annot-file "$result_dir/intersection/${base_name}.${i}.annot.gz" &
    done
done
wait

for index in $(seq 0 $last_index_intersect); do
    base_name="${base_names_intersect[$index]}"
    
    for i in {1..22}; do
        /apps/conda/project/envs/ldsc/bin/python \
        /apps/www-dev/support/script/ldsc/ldsc.py \
        --l2 \
        --bfile /apps/www-dev/support/data/ref/1000G_EUR_Phase3_plink/1000G.EUR.QC.${i} \
        --ld-wind-cm 1 \
        --annot "$result_dir/intersection/${base_name}.${i}.annot.gz" \
        --thin-annot \
        --out "$result_dir/intersection/${base_name}.${i}" \
        --print-snps /apps/www-dev/support/data/ref/listHM3.txt &
    done
done
wait

# Process unique annotations
base_names_unique=()
for file in "${unique_array[@]}"; do
    base_name=$(basename "$file")
    base_name="${base_name%.*}"
    base_name="${base_name%.*}"
    base_names_unique+=("$base_name")
done

last_index_unique=$((${#unique_array[@]} - 1))
for index in $(seq 0 $last_index_unique); do
    bed_file="${unique_array[$index]}"
    base_name="${base_names_unique[$index]}"
    
    for i in {1..22}; do
		/apps/www-dev/support/script/analysis/run_make_annot.sh \
        --gene-set-file "$bed_file" \
        --gene-coord-file /apps/www-dev/support/data/ENSG_coord.txt \
        --windowsize "$windowSize" \
        --bimfile /apps/www-dev/support/data/ref/1000G_EUR_Phase3_plink/1000G.EUR.QC.${i}.bim \
        --annot-file "$result_dir/Unique/${base_name}.${i}.annot.gz" &
    done
done
wait

for index in $(seq 0 $last_index_unique); do
    base_name="${base_names_unique[$index]}"
    
    for i in {1..22}; do
        /apps/conda/project/envs/ldsc/bin/python \
        /apps/www-dev/support/script/ldsc/ldsc.py \
        --l2 \
        --bfile /apps/www-dev/support/data/ref/1000G_EUR_Phase3_plink/1000G.EUR.QC.${i} \
        --ld-wind-cm 1 \
        --annot "$result_dir/Unique/${base_name}.${i}.annot.gz" \
        --thin-annot \
        --out "$result_dir/Unique/${base_name}.${i}" \
        --print-snps /apps/www-dev/support/data/ref/listHM3.txt &
    done
done
wait

# Rename cell files
/apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/cell_rename.R "$result_dir" "${uploadeddir_array[@]}"
/apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/cell_rename.R "$result_dir/union" "${base_names_union[@]}"
/apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/cell_rename.R "$result_dir/intersection" "${base_names_intersect[@]}"
/apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/cell_rename.R "$result_dir/Unique" "${base_names_unique[@]}"

# Other LD scores
for i in {1..22}; do
    /apps/conda/project/envs/ldsc/bin/python \
    /apps/www-dev/support/script/ldsc/ldsc.py \
    --l2 \
    --bfile /apps/www-dev/support/data/ref/1000G_EUR_Phase3_plink/1000G.EUR.QC.${i} \
    --ld-wind-cm 1 \
    --annot "$result_dir/other.${i}.annot.gz" \
    --thin-annot \
    --out "$result_dir/other.${i}" \
    --print-snps /apps/www-dev/support/data/ref/listHM3.txt &
done
wait

# Enrichment analysis without Joint Model
for index in $(seq 0 $last_index); do
    base_name="${uploadeddir_array[$index]}"
	
	/apps/conda/project/envs/ldsc/bin/python \
	/apps/www-dev/support/script/ldsc/ldsc.py \
	--h2 "$result_dir/$sum_name.sumstats.gz" \
	--ref-ld-chr "$result_dir/${base_name}.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD." \
	--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
	--overlap-annot \
	--print-coefficients \
	--frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
	--out "$result_dir/${base_name}_enrichment_out"
done

# Other enrichment
/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2 "$result_dir/$sum_name.sumstats.gz" \
--ref-ld-chr "$result_dir/other.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD." \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--overlap-annot \
--print-coefficients \
--frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
--out "$result_dir/other_enrichment_out"

# ############## with Joint Model ################################
# ############## with Joint Model ################################


#################### Model 1 #######################################

mkdir $result_dir/model_1_enr


/apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/other_variants.R $result_dir

for i in {1..22}; do
    /apps/conda/project/envs/ldsc/bin/python \
    /apps/www-dev/support/script/ldsc/ldsc.py \
    --l2 \
    --bfile /apps/www-dev/support/data/ref/1000G_EUR_Phase3_plink/1000G.EUR.QC.${i} \
    --ld-wind-cm 1 \
    --annot $result_dir/model_1_enr/other.${i}.annot.gz \
    --thin-annot \
    --out $result_dir/model_1_enr/other.${i} \
    --print-snps /apps/www-dev/support/data/ref/listHM3.txt &
done

# Wait for all background jobs to finish
wait
echo "All 'model_1_enr' LD score calculation jobs finished."



#result_dir=/apps/www/project/ldsc/result/r_989216
uni_dir=$result_dir/Unique
int_dir=$result_dir/intersection

# Extract unique prefixes and split them into an array
unique_prefixes=$(ls $uni_dir  / | grep -oP '^\d+_UniqueGenes' | sort -u)
#intersection_prefixes=$(ls $int_dir/ | grep -oP '^\d+_and_\d+_IntersectionGenes' | sort -u)
intersection_prefixes=$(ls $int_dir/ | grep -oP '^\d+_and_\d+_IntersectionGenes|^All_IntersectionGenes' | sort -u)



# Initialize uni_paths
uni_paths=""

# Loop through each prefix
for prefix in $unique_prefixes; do
    if [[ -n "$uni_paths" ]]; then
        uni_paths+=".,"
    fi
    uni_paths+="$uni_dir/$prefix"
done

# Print the result
echo "$uni_paths"


# Initialize int_dir
int_paths=""
# Loop through each prefix
for prefix in $intersection_prefixes; do
    if [[ -n "$int_paths" ]]; then
        int_paths+=".,"
    fi
    int_paths+="$int_dir/$prefix"
done

# Print the result
echo "$int_paths"

other_model1=$result_dir/model_1_enr/other

model1=$uni_paths.,$int_paths.,$other_model1
echo $model1


# /apps/conda/project/envs/ldsc/bin/python \
# /apps/www-dev/support/script/ldsc/ldsc.py \
# --h2 /apps/www/project/ldsc/result/r_783363/EA2_results_V2.sumstats.gz \
# --ref-ld-chr /apps/www/project/ldsc/result/r_989216/Unique/399061_UniqueGenes.,/apps/www/project/ldsc/result/r_989216/Unique/399058_UniqueGenes.,/apps/www/project/ldsc/result/r_989216/intersection/399058_and_399061_IntersectionGenes.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
# --w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
# --overlap-annot \
# --print-coefficients \
# --frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
# --out model_1_enrichment_out


/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2 $result_dir/$sum_name.sumstats.gz \
--ref-ld-chr $model1.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--overlap-annot \
--print-coefficients \
--frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
--out $result_dir/model_1_enr/model_1_enrichment_out



grep -- '--ref-ld-chr' $result_dir/model_1_enr/model_1_enrichment_out.log | \
sed -n 's/.*--ref-ld-chr \(.*\)/\1/p' | \
tr ',' '\n' | \
sed "s#${result_dir}/##g" | \
sed 's#.*/##' | \
sed 's/\\$//' | \
sed 's/\.$//' | \
grep -v 'baselineLD' > $result_dir/model_1_enr/enrich_model.txt


#echo "model = $(cat enrich_model.txt | tr '\n' ' ' | sed 's/ $//' | sed 's/ / + /g')" > new_model.txt
echo "model = $(cat $result_dir/model_1_enr/enrich_model.txt | tr '\n' ' ' | sed 's/ $//' | sed 's/ / + /g')" > $result_dir/model_1_enr/new_model.txt



# ################ Model N  ##############################

# mkdir $result_dir/model_N_enr

# echo "All base_names:"
# for name in "${uploadeddir_array[@]}"; do
    # echo "$name"
# done


# dir_other_list=$(find ${result_dir} -type d -name "*_Dir_other")

# echo "Iterating through the directories:"
# for dir in "${dir_other_list[@]}"; do
    # echo "$dir"
# done


# Find directories and store the basenames in a new list
dir_other_list=$(find ${result_dir} -maxdepth 1 -type d -name "*_Dir_other")
basename_other_list=()

for dir in $dir_other_list; do
    basename_other_list+=("$(basename "$dir")")
done

# Print the new list
echo "Basename list:"
printf "%s\n" "${basename_other_list[@]}"

core_list=()
for name in "${basename_other_list[@]}"; do
    core_list+=("${name%_Dir_other}")  # Remove "_Dir_other" using parameter expansion
done

echo "Core list:"
printf "%s\n" "${core_list[@]}"



#last_index=$((${#basename_other_list[@]}))
last_index=$((${#basename_other_list[@]} - 1))
echo $last_index


for index in $(seq 0 $last_index); do
    dir_name="${basename_other_list[$index]}"
    echo $dir_name
    
    # Loop through chromosomes 1 to 22
    for i in {1..22}; do
        /apps/conda/project/envs/ldsc/bin/python \
        /apps/www-dev/support/script/ldsc/ldsc.py \
        --l2 \
        --bfile /apps/www-dev/support/data/ref/1000G_EUR_Phase3_plink/1000G.EUR.QC.${i} \
        --ld-wind-cm 1 \
        --annot $result_dir/$dir_name/other.${i}.annot.gz \
        --thin-annot \
        --out $result_dir/$dir_name/other.${i} \
        --print-snps /apps/www-dev/support/data/ref/listHM3.txt &
    done
done

# Wait for all background jobs to finish
wait
echo "All 'other' LD score calculation jobs finished."


for index in $(seq 0 $last_index); do
    base_name="${core_list[$index]}"
	dir_name="${basename_other_list[$index]}"
	echo $base_name
	echo $dir_name
	
	/apps/conda/project/envs/ldsc/bin/python \
	/apps/www-dev/support/script/ldsc/ldsc.py \
	--h2 $result_dir/$sum_name.sumstats.gz \
	--ref-ld-chr $result_dir/${base_name}.,$result_dir/${dir_name}/other.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
	--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
	--overlap-annot \
	--print-coefficients \
	--frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
	--out $result_dir/${dir_name}/${base_name}_enrichment_other_out
done





# for index in $(seq 0 $last_index); do
    # base_name="${base_names[$index]}"
	
	# /apps/conda/project/envs/ldsc/bin/python \
	# /apps/www-dev/support/script/ldsc/ldsc.py \
	# --h2 $result_dir/$sum_name.sumstats.gz \
	# --ref-ld-chr $result_dir/${base_name}.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
	# --w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
	# --overlap-annot \
	# --print-coefficients \
	# --frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
	# --out $result_dir/model_N_enr/${base_name}_enrichment_out
	
# done




################ Model 3  ##############################


for i in {1..22}; do
    /apps/conda/project/envs/ldsc/bin/python \
    /apps/www-dev/support/script/ldsc/ldsc.py \
    --l2 \
    --bfile /apps/www-dev/support/data/ref/1000G_EUR_Phase3_plink/1000G.EUR.QC.${i} \
    --ld-wind-cm 1 \
    --annot $result_dir/union/other.${i}.annot.gz \
    --thin-annot \
    --out $result_dir/union/other.${i} \
    --print-snps /apps/www-dev/support/data/ref/listHM3.txt &
done

# Wait for all background jobs to finish
wait
echo "All 'union other' LD score calculation jobs finished."



#result_dir=/apps/www/project/ldsc/result/r_989216
union_dir=$result_dir/union


# Extract unique prefixes and split them into an array
#union_prefixes=$(ls $union_dir/ | grep -oP '^\d+_U_\d+_UnionGenes' | sort -u)
union_prefixes=$(ls $union_dir/ | grep -oP '^\d+_U_\d+_UnionGenes|^All_UnionGenes' | sort -u)

# Initialize union_paths
union_paths=""

# Loop through each prefix
for prefix in $union_prefixes; do
    if [[ -n "$union_paths" ]]; then
        union_paths+=".,"
    fi
    union_paths+="$union_dir/$prefix"
done

# Print the result
echo "$union_paths"

other_model3=$result_dir/union/other
model3=$union_paths.,$other_model3
echo $model3


mkdir $result_dir/model_3_enr

/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2 $result_dir/$sum_name.sumstats.gz \
--ref-ld-chr $model3.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--overlap-annot \
--print-coefficients \
--frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
--out $result_dir/model_3_enr/model_3_enrichment_out



# grep -- '--ref-ld-chr' $result_dir/model_3_enr/model_3_enrichment_out.log | \
# sed -n 's/.*--ref-ld-chr \(.*\)/\1/p' | \
# sed "s#${result}##g" | \
# tr ',' '\n' | \
# sed 's#.*/##' | \
# sed 's/\\$//' | \
# sed 's/\.$//' | \
# sed '/baselineLD/d' > $result_dir/model_3_enr/enrich_model.txt


grep -- '--ref-ld-chr' $result_dir/model_3_enr/model_3_enrichment_out.log | \
sed -n 's/.*--ref-ld-chr \(.*\)/\1/p' | \
tr ',' '\n' | \
sed "s#${result_dir}/##g" | \
sed 's#.*/##' | \
sed 's/\\$//' | \
sed 's/\.$//' | \
grep -v 'baselineLD' > $result_dir/model_3_enr/enrich_model.txt

#echo "model = $(cat enrich_model.txt | tr '\n' ' ' | sed 's/ $//' | sed 's/ / + /g')" > new_model.txt
echo "model = $(cat $result_dir/model_3_enr/enrich_model.txt | tr '\n' ' ' | sed 's/ $//' | sed 's/ / + /g')" > $result_dir/model_3_enr/new_model.txt




######################################################################################################
######################################################################################################


/apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/cell_vis_3_V2.R $result_dir $sum_stat
# /apps/conda/project/envs/r_env/bin/Rscript cell_vis_3.R   $result_dir $gene_name1 $gene_name2

mkdir $result_dir/HTML_model_1_3_output
mkdir $result_dir/HTML_model_N_output

/apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/model_output.R $result_dir


cp $result_dir/model_1_enr/new_model.txt $result_dir/model_1_enr/model1_updated.txt
# Loop through the labels and replace in the file
while read -r id label; do
  sed -i "s/$id/$label/g" $result_dir/model_1_enr/model1_updated.txt
done < $result_dir/testing_label


# /apps/conda/project/envs/r_env/bin/Rscript cell_specific_V2.R  $result_dir $sum_stat



mkdir $result_dir/PGS_prs_cs

/apps/conda/project/envs/r_env/bin/Rscript \
/apps/www-dev/support/script/r/PGS_prscs.R \
$sum_stat \
$N \
$result_dir \
${uploadeddir_array[@]}

# Decompress BIM file if provided
if [ -n "$target_bim" ] && [ -f "$target_bim" ]; then
    echo "Decompressing target BIM file..."
    gunzip -c "$target_bim" > "$result_dir/PGS_prs_cs/Target_upload.bim"
else
    # Check for bim.gz files in result directory
    count=$(ls "$result_dir"/*.bim.gz 2>/dev/null | wc -l)
    if [ "$count" -eq 1 ]; then
        echo "Found one .bim.gz file — decompressing..."
        gunzip -c "$result_dir"/*.bim.gz > "$result_dir/PGS_prs_cs/Target_upload.bim"
    elif [ "$count" -eq 0 ]; then
        echo "❌ No .bim.gz file found in $result_dir"
    else
        echo "⚠️ More than one .bim.gz file found in $result_dir"
        ls "$result_dir"/*.bim.gz
    fi
fi



for f in $result_dir/PGS_prs_cs/sum_stat*_PGS.txt; do
    base=$(basename "$f" .txt)
	echo "Starting job for $base ..."
    nohup /apps/conda/project/envs/py39/bin/python \
        /apps/www-dev/support/script/prs_cs/Tool/PRScs/PRScs.py \
        --ref_dir=/apps/www-dev/support/script/prs_cs/ldblk_1kg_eur \
        --bim_prefix=$result_dir/PGS_prs_cs/Target_upload \
        --sst_file="$f" \
        --n_gwas=$N \
        --out_dir=$result_dir/PGS_prs_cs/${base}_prscs \
        > $result_dir/PGS_prs_cs/${base}.log 2>&1 &
done

# Wait for all background jobs to finish
wait
echo "All 'PGS' calculation jobs finished."


for f in $result_dir/PGS_prs_cs/sum_stat*_PGS.txt; do
    base=$(basename "$f" .txt)
    
    # create an output file for the combined chromosomes
    out_file="$result_dir/PGS_prs_cs/${base}_all_chr.txt"
    
    echo "Combining chromosomes for $base ..."
    
    # use cat to combine chr 1-22 files
    cat $result_dir/PGS_prs_cs/${base}_prscs_pst_eff_a1_b0.5_phiauto_chr{1..22}.txt > "$out_file"
    
    echo "Saved combined file to $out_file"
done




#####################################################################################################
#####################################################################################################


######### Estimating proportion of heritability by cell-type group ######################
######### Estimating proportion of heritability by cell-type group ######################
######### Estimating proportion of heritability by cell-type group ######################

######## Adrenal_Pancreas
/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2 $result_dir/$sum_name.sumstats.gz \
--ref-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_cell_type_groups/cell_type_group.1.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--overlap-annot \
--print-coefficients \
--frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
--out $result_dir/sumstat_Adrenal_Pancreas &
		
		
######## Cardiovascular
/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2 $result_dir/$sum_name.sumstats.gz \
--ref-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_cell_type_groups/cell_type_group.2.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--overlap-annot \
--print-coefficients \
--frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
--out $result_dir/sumstat_Cardiovascular &


######## CNS
/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2 $result_dir/$sum_name.sumstats.gz \
--ref-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_cell_type_groups/cell_type_group.3.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--overlap-annot \
--print-coefficients \
--frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
--out $result_dir/sumstat_CNS &


######## Connective_Bone
/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2 $result_dir/$sum_name.sumstats.gz \
--ref-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_cell_type_groups/cell_type_group.4.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--overlap-annot \
--print-coefficients \
--frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
--out $result_dir/sumstat_Connective_Bone &


######## GI
/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2 $result_dir/$sum_name.sumstats.gz \
--ref-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_cell_type_groups/cell_type_group.5.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--overlap-annot \
--print-coefficients \
--frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
--out $result_dir/sumstat_GI &

######## Hematopoietic
/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2 $result_dir/$sum_name.sumstats.gz \
--ref-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_cell_type_groups/cell_type_group.6.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--overlap-annot \
--print-coefficients \
--frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
--out $result_dir/sumstat_Hematopoietic &


######## Kidney
/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2 $result_dir/$sum_name.sumstats.gz \
--ref-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_cell_type_groups/cell_type_group.7.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--overlap-annot \
--print-coefficients \
--frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
--out $result_dir/sumstat_Kidney &

######## Liver
/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2 $result_dir/$sum_name.sumstats.gz \
--ref-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_cell_type_groups/cell_type_group.8.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--overlap-annot \
--print-coefficients \
--frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
--out $result_dir/sumstat_Liver &


######## Other
/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2 $result_dir/$sum_name.sumstats.gz \
--ref-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_cell_type_groups/cell_type_group.9.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--overlap-annot \
--print-coefficients \
--frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
--out $result_dir/sumstat_Other &


######## SkeletalMuscle
/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2 $result_dir/$sum_name.sumstats.gz \
--ref-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_cell_type_groups/cell_type_group.10.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--overlap-annot \
--print-coefficients \
--frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
--out $result_dir/sumstat_SkeletalMuscle &



#########################
#########################
#########################

############# Mouse brain cell type partitioning heritability enrichment for DPW GWAS using Cahoy gene expression data

/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2-cts $result_dir/$sum_name.sumstats.gz \
--ref-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--ref-ld-chr-cts /apps/www-dev/support/data/ref/Cahoy.ldcts \
--out $result_dir/Cahoy &



############# Tissue or cell type partitioning heritability enrichment for DPW GWAS using GTEx gene expression data

/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2-cts $result_dir/$sum_name.sumstats.gz \
--ref-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--ref-ld-chr-cts /apps/www-dev/support/data/ref/LDSC_SEG_ldscores/biorx/GTEx.ldcts \
--out $result_dir/GTEx &



############# Mouse immune cell type partitioning heritability enrichment for AUDIT-C GWAS using ImmGen gene expression data

/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2-cts $result_dir/$sum_name.sumstats.gz \
--ref-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--ref-ld-chr-cts /apps/www-dev/support/data/ref/ImmGen.ldcts \
--out $result_dir/ImmGen &


############# Epigenetic partitioning heritability enrichment for AUDIT-C GWAS using Roadmap data

/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2-cts $result_dir/$sum_name.sumstats.gz \
--ref-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD. \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--ref-ld-chr-cts /apps/www-dev/support/data/ref/LDSC_SEG_ldscores/biorx/Roadmap.ldcts \
--out $result_dir/Roadmap &


wait
echo "All heritability enrichment analyses finished."


/apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/cell_specific_V2.R  $result_dir $sum_stat






# # sed -i 's/\r//' /apps/www/project/ldsc/script/cell_geneWea.sh
# # sed -i 's/\r$//' /apps/www/project/ldsc/script/cell_geneWea.sh

## sed -i 's/\r$//' /apps/www-dev/project/ldsc-dev/analysis/run_Geneweaver_PGS.sh
## chmod 775 /apps/www-dev/support/script/analysis/run_Geneweaver_PGS_update.sh
## sed -i 's/\r$//' /apps/www-dev/support/script/analysis/run_Geneweaver_PGS_update.sh

echo "=== GeneWeaver PGS Analysis Completed Successfully ==="
