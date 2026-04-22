#!/bin/bash
# run_desktop_update.sh - Basic analysis for desktop gene sets (updated to work directly with gene files)

# Initialize variables
sum_stat=""
result_dir=""
N=""
windowSize=""
file_png=""
file_png2=""
geneLabel=""
geneID=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -sum_stat)
      sum_stat="$2"
      shift 2
      ;;
    -result_dir)
      result_dir="$2"
      shift 2
      ;;
    -N)
      N="$2"
      shift 2
      ;;
    -windowSize)
      windowSize="$2"
      shift 2
      ;;
    -file_png)
      file_png="$2"
      shift 2
      ;;
    -file_png2)
      file_png2="$2"
      shift 2
      ;;
    -geneLabel)
      geneLabel="$2"
      shift 2
      ;;
    -geneID)
      geneID="$2"
      shift 2
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

echo "=== Starting Desktop Gene Set Analysis ==="
echo "Summary statistics: $sum_stat"
echo "Result directory: $result_dir"
echo "Sample size: $N"
echo "Window size: $windowSize"
echo "Gene IDs: $geneID"

# Create result directory if it doesn't exist
mkdir -p "$result_dir"

# Convert gene IDs string to array
IFS=',' read -r -a gene_array <<< "$geneID"

echo "Number of Gene Sets: ${#gene_array[@]}"
echo "Gene Sets: ${gene_array[*]}"

# Copy all gene set files from inputs directory to working directory
INPUT_DIR="$result_dir/../inputs"

if [ ! -d "$INPUT_DIR" ]; then
    echo "ERROR: Input directory not found: $INPUT_DIR"
    exit 1
fi

echo "Copying gene set files from $INPUT_DIR to $result_dir..."
# Copy all .txt gene files from inputs to working directory
find "$INPUT_DIR" -name "*.txt" -type f | while read gene_file; do
    filename=$(basename "$gene_file")
    # Skip GWAS decompressed file if present
    if [[ "$filename" != "gwas_decompressed.txt" ]]; then
        cp "$gene_file" "$result_dir/"
        echo "  Copied: $filename"
    fi
done

echo "Looking for gene set files in: $result_dir"

# Find and collect all gene files from working directory
gene_files_found=()
full_paths_with_ext=()
for gene_set in "${gene_array[@]}"; do
    echo "Searching for gene set: $gene_set"
    
    # Try multiple possible file locations and names
    GENE_FILE=""
    
    # First try: exact match in working directory
    if [ -f "$result_dir/${gene_set}.txt" ]; then
        GENE_FILE="$result_dir/${gene_set}.txt"
    # Second try: look for any file containing the gene set name
    elif [ $(find "$result_dir" -name "*${gene_set}*.txt" -type f | wc -l) -gt 0 ]; then
        GENE_FILE=$(find "$result_dir" -name "*${gene_set}*.txt" -type f | head -1)
    fi
    
    if [ -f "$GENE_FILE" ]; then
        echo "✓ Found gene file: $GENE_FILE"
        
        # Count genes in file
        GENE_COUNT=$(grep -c '^[^[:space:]]' "$GENE_FILE" 2>/dev/null || wc -l < "$GENE_FILE")
        echo "  Gene count: $GENE_COUNT"
        
        # Check if file has content
        if [ $GENE_COUNT -eq 0 ]; then
            echo "  WARNING: Gene file is empty"
        else
            # Display first few genes as sample
            echo "  Sample genes:"
            head -5 "$GENE_FILE" | while read gene; do
                echo "    - $gene"
            done
            if [ $GENE_COUNT -gt 5 ]; then
                echo "    ... and $(($GENE_COUNT - 5)) more"
            fi
        fi
        
        gene_files_found+=("$GENE_FILE")
        full_paths_with_ext+=("$GENE_FILE")
    else
        echo "✗ WARNING: Gene file not found for: $gene_set"
        echo "  Searched in: $result_dir"
        echo "  Tried patterns: ${gene_set}.txt, *${gene_set}*.txt"
        echo "  Available files:"
        ls -la "$result_dir/"*.txt 2>/dev/null | head -10 || echo "    No .txt files found"
    fi
done

# Check if any gene files were found
if [ ${#gene_files_found[@]} -eq 0 ]; then
    echo "ERROR: No gene set files could be found for processing"
    echo "Available files in $result_dir:"
    ls -la "$result_dir/" || echo "Cannot list directory"
    exit 1
fi

echo ""
echo "✓ Found ${#gene_files_found[@]} gene set files for processing"

# =========================================================================
# Boolean Algebra and Model Processing - Save results to working directory
# =========================================================================
echo ""
echo "=== Running Boolean Algebra and Model Processing ==="

# Boolean algebra and model processing
echo "Running boolean algebra with ${#full_paths_with_ext[@]} files..."
if [ -f "/apps/conda/project/envs/r_env/bin/Rscript" ] && [ -f "/apps/www-dev/support/script/r/boolean_algebra.R" ]; then
    /apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/boolean_algebra.R "${full_paths_with_ext[@]}"
    if [ $? -eq 0 ]; then
        echo "✓ Boolean algebra completed successfully"
    else
        echo "WARNING: Boolean algebra script failed, continuing..."
    fi
else
    echo "WARNING: Rscript or boolean_algebra.R not found, skipping boolean algebra"
fi

echo "Running model processing with ${#full_paths_with_ext[@]} files..."
if [ -f "/apps/conda/project/envs/r_env/bin/Rscript" ] && [ -f "/apps/www-dev/support/script/r/model_processing.R" ]; then
    /apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/model_processing.R "${full_paths_with_ext[@]}"
    if [ $? -eq 0 ]; then
        echo "✓ Model processing completed successfully"
    else
        echo "WARNING: Model processing script failed, continuing..."
    fi
else
    echo "WARNING: Rscript or model_processing.R not found, skipping model processing"
fi

# Generate Manhattan plot using the visualization script
echo "Generating Manhattan plot..."
if [ -f "/apps/conda/project/envs/py39/bin/python" ] && [ -f "/apps/www-dev/support/script/python/gwas_vis.py" ]; then
    /apps/conda/project/envs/py39/bin/python \
        /apps/www-dev/support/script/python/gwas_vis.py \
        --sum_file "$sum_stat" \
        --N "$N" \
        --file_png "$file_png" \
        --filegene "$file_png2"
    
    if [ $? -eq 0 ]; then
        echo "✓ Manhattan plot generated successfully"
    else
        echo "WARNING: Manhattan plot generation failed, continuing with analysis..."
    fi
else
    echo "WARNING: Python or gwas_vis.py not found, skipping Manhattan plot"
fi

# Check and process set operations from result_dir (where R scripts save results)
echo "Checking for set operation results in: $result_dir"

# Process Unions from result_dir
echo "Processing Unions..."
if [ -d "${result_dir}/union" ]; then
    union_array=($(find "${result_dir}/union" -type f -name '*UnionGenes*.txt'))
    echo "Union files found in result_dir: ${#union_array[@]}"
    for file in "${union_array[@]}"; do
        echo "  - $file"
    done
    if [ ${#union_array[@]} -gt 0 ]; then
        if [ -f "/apps/conda/project/envs/r_env/bin/Rscript" ] && [ -f "/apps/www-dev/support/script/r/model_processing.R" ]; then
            /apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/model_processing.R "${union_array[@]}"
            if [ $? -eq 0 ]; then
                echo "✓ Union model processing completed"
            else
                echo "WARNING: Union model processing failed"
            fi
        fi
        # Add union files to the processing list
        for union_file in "${union_array[@]}"; do
            full_paths_with_ext+=("$union_file")
            gene_files_found+=("$union_file")
        done
    fi
else
    echo "No union directory found in result_dir"
fi

# Process Intersections from result_dir
echo "Processing Intersections..."
if [ -d "${result_dir}/intersection" ]; then
    intersect_array=($(find "${result_dir}/intersection" -type f -name '*IntersectionGenes*.txt'))
    echo "Intersection files found in result_dir: ${#intersect_array[@]}"
    for file in "${intersect_array[@]}"; do
        echo "  - $file"
    done
    if [ ${#intersect_array[@]} -gt 0 ]; then
        if [ -f "/apps/conda/project/envs/r_env/bin/Rscript" ] && [ -f "/apps/www-dev/support/script/r/model_processing.R" ]; then
            /apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/model_processing.R "${intersect_array[@]}"
            if [ $? -eq 0 ]; then
                echo "✓ Intersection model processing completed"
            else
                echo "WARNING: Intersection model processing failed"
            fi
        fi
        # Add intersection files to the processing list
        for intersect_file in "${intersect_array[@]}"; do
            full_paths_with_ext+=("$intersect_file")
            gene_files_found+=("$intersect_file")
        done
    fi
else
    echo "No intersection directory found in result_dir"
fi

# Process Unique from result_dir
echo "Processing Unique..."
if [ -d "${result_dir}/Unique" ]; then
    unique_array=($(find "${result_dir}/Unique" -type f -name '*UniqueGenes*.txt'))
    echo "Unique files found in result_dir: ${#unique_array[@]}"
    for file in "${unique_array[@]}"; do
        echo "  - $file"
    done
    if [ ${#unique_array[@]} -gt 0 ]; then
        if [ -f "/apps/conda/project/envs/r_env/bin/Rscript" ] && [ -f "/apps/www-dev/support/script/r/model_processing.R" ]; then
            /apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/model_processing.R "${unique_array[@]}"
            if [ $? -eq 0 ]; then
                echo "✓ Unique model processing completed"
            else
                echo "WARNING: Unique model processing failed"
            fi
        fi
        # Add unique files to the processing list
        for unique_file in "${unique_array[@]}"; do
            full_paths_with_ext+=("$unique_file")
            gene_files_found+=("$unique_file")
        done
    fi
else
    echo "No Unique directory found in result_dir"
fi

echo ""
echo "=== Creating Annotations ==="
echo "Total files to process for annotations: ${#gene_files_found[@]}"

# Process each gene set file for annotations
processed_count=0
for i in "${!gene_files_found[@]}"; do
    gene_file="${gene_files_found[$i]}"
    gene_name=""
    
    # Extract gene name from filename
    if [ $i -lt ${#gene_array[@]} ]; then
        gene_name="${gene_array[$i]}"
    else
        # For union/intersection/unique files, use base filename
        base_name=$(basename "$gene_file" .txt)
        gene_name="${base_name}"
    fi
    
    echo ""
    echo "Processing for annotations: $gene_name"
    echo "  File: $gene_file"
    
    # Count genes in file
    GENE_COUNT=$(grep -c '^[^[:space:]]' "$gene_file" 2>/dev/null || wc -l < "$gene_file")
    echo "  Gene count: $GENE_COUNT"
    
    if [ $GENE_COUNT -lt 2 ]; then
        echo "  WARNING: Skipping annotation - file has less than 2 genes"
        continue
    fi
    
    # Create annotations for each chromosome
    echo "  Creating annotations for chromosomes 1-22..."
    annotation_jobs=0
    for chrom in {1..22}; do
        /apps/www-dev/support/script/analysis/run_make_annot.sh \
            --gene-set-file "$gene_file" \
            --gene-coord-file /apps/www-dev/support/data/ENSG_coord.txt \
            --windowsize "$windowSize" \
            --bimfile /apps/www-dev/support/data/ref/1000G_EUR_Phase3_plink/1000G.EUR.QC.${chrom}.bim \
            --annot-file "$result_dir/${gene_name}.${chrom}.annot.gz" &
        
        annotation_jobs=$((annotation_jobs + 1))
        if [ $annotation_jobs -ge 4 ]; then
            wait
            annotation_jobs=0
        fi
    done
    wait
    
    processed_count=$((processed_count + 1))
    echo "  ✓ Annotations created for $gene_name"
done

echo ""
echo "✓ All annotation jobs finished. Processed $processed_count gene sets."

# =========================================================================
# Reorganize annotation files to appropriate directories
# =========================================================================
echo ""
echo "=== Reorganizing Annotation Files ==="

# Move Union annotation files to union directory
echo "Moving Union annotation files..."
if [ -d "${result_dir}/union" ]; then
    mkdir -p "${result_dir}/union"
    find "$result_dir" -name "*UnionGenes*.annot.gz" -type f | while read file; do
        mv "$file" "${result_dir}/union/"
        echo "  Moved: $(basename $file) to union/"
    done
fi

# Move Intersection annotation files to intersection directory
echo "Moving Intersection annotation files..."
if [ -d "${result_dir}/intersection" ]; then
    mkdir -p "${result_dir}/intersection"
    find "$result_dir" -name "*IntersectionGenes*.annot.gz" -type f | while read file; do
        mv "$file" "${result_dir}/intersection/"
        echo "  Moved: $(basename $file) to intersection/"
    done
fi

# Move Unique annotation files to Unique directory
echo "Moving Unique annotation files..."
if [ -d "${result_dir}/Unique" ]; then
    mkdir -p "${result_dir}/Unique"
    find "$result_dir" -name "*UniqueGenes*.annot.gz" -type f | while read file; do
        mv "$file" "${result_dir}/Unique/"
        echo "  Moved: $(basename $file) to Unique/"
    done
fi

# =========================================================================
# Munge Summary Statistics
# =========================================================================
echo ""
echo "=== Munging Summary Statistics ==="

# Extract base name from sumstat file
sumpath_with_extension=$(basename "$sum_stat")
sum_name="${sumpath_with_extension%.*}"

echo "Munging summary statistics for: $sum_name"
if [ -f "/apps/conda/project/envs/ldsc/bin/python" ] && [ -f "/apps/www-dev/support/script/ldsc/munge_sumstats.py" ]; then
    /apps/conda/project/envs/ldsc/bin/python \
        /apps/www-dev/support/script/ldsc/munge_sumstats.py \
        --sumstats "$sum_stat" \
        --merge-alleles /apps/www-dev/support/data/ref/w_hm3.snplist \
        --N "$N" --snp SNP_ID --p Pval --a1 A1 --a2 A2 \
        --chunksize 50000 \
        --out "$result_dir/$sum_name"
    
    if [ $? -eq 0 ]; then
        echo "✓ Summary statistics munging completed successfully"
    else
        echo "WARNING: Summary statistics munging failed"
    fi
else
    echo "WARNING: Python or munge_sumstats.py not found, skipping summary statistics munging"
fi

# =========================================================================
# Calculate LD Scores
# =========================================================================
echo ""
echo "=== Calculating LD Scores ==="

# Get original gene sets
uploadeddir_array=("${gene_array[@]}")
last_index=$((${#uploadeddir_array[@]} - 1))

# Calculate LD scores for original gene sets
echo "Calculating LD scores for ${#uploadeddir_array[@]} original gene sets..."
for index in $(seq 0 $last_index); do
    base_name="${uploadeddir_array[$index]}"
    
    echo "  Processing: $base_name"
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
echo "✓ Original gene set LD score calculations finished."

# Calculate LD scores for union gene sets
echo "Calculating LD scores for union gene sets..."
if [ -d "${result_dir}/union" ]; then
    union_files=($(find "${result_dir}/union" -name "*.annot.gz" -type f))
    base_names_union=()
    
    # Extract unique base names from union files
    for file in "${union_files[@]}"; do
        filename=$(basename "$file")
        base_name=$(echo "$filename" | cut -d'.' -f1)
        if [[ ! " ${base_names_union[@]} " =~ " ${base_name} " ]]; then
            base_names_union+=("$base_name")
        fi
    done
    
    last_index_union=$((${#base_names_union[@]} - 1))
    
    for index in $(seq 0 $last_index_union); do
        base_name="${base_names_union[$index]}"
        
        echo "  Processing: $base_name (union)"
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
    echo "✓ Union gene set LD score calculations finished."
fi

# Calculate LD scores for intersection gene sets
echo "Calculating LD scores for intersection gene sets..."
if [ -d "${result_dir}/intersection" ]; then
    intersect_files=($(find "${result_dir}/intersection" -name "*.annot.gz" -type f))
    base_names_intersect=()
    
    # Extract unique base names from intersection files
    for file in "${intersect_files[@]}"; do
        filename=$(basename "$file")
        base_name=$(echo "$filename" | cut -d'.' -f1)
        if [[ ! " ${base_names_intersect[@]} " =~ " ${base_name} " ]]; then
            base_names_intersect+=("$base_name")
        fi
    done
    
    last_index_intersect=$((${#base_names_intersect[@]} - 1))
    
    for index in $(seq 0 $last_index_intersect); do
        base_name="${base_names_intersect[$index]}"
        
        echo "  Processing: $base_name (intersection)"
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
    echo "✓ Intersection gene set LD score calculations finished."
fi

# Calculate LD scores for unique gene sets
echo "Calculating LD scores for unique gene sets..."
if [ -d "${result_dir}/Unique" ]; then
    unique_files=($(find "${result_dir}/Unique" -name "*.annot.gz" -type f))
    base_names_unique=()
    
    # Extract unique base names from unique files
    for file in "${unique_files[@]}"; do
        filename=$(basename "$file")
        base_name=$(echo "$filename" | cut -d'.' -f1)
        if [[ ! " ${base_names_unique[@]} " =~ " ${base_name} " ]]; then
            base_names_unique+=("$base_name")
        fi
    done
    
    last_index_unique=$((${#base_names_unique[@]} - 1))
    
    for index in $(seq 0 $last_index_unique); do
        base_name="${base_names_unique[$index]}"
        
        echo "  Processing: $base_name (unique)"
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
    echo "✓ Unique gene set LD score calculations finished."
fi

echo "All LD score calculation jobs finished."

# =========================================================================
# Run cell_rename.R for all categories
# =========================================================================
echo ""
echo "=== Running cell_rename.R for Annotation Processing ==="

# Run cell_rename.R for original gene sets
if [ ${#uploadeddir_array[@]} -gt 0 ] && [ -f "/apps/conda/project/envs/r_env/bin/Rscript" ] && [ -f "/apps/www-dev/support/script/r/cell_rename.R" ]; then
    echo "Running cell_rename.R for original gene sets..."
    /apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/cell_rename.R "$result_dir" "${uploadeddir_array[@]}"
    if [ $? -eq 0 ]; then
        echo "✓ cell_rename.R completed for original gene sets"
    else
        echo "WARNING: cell_rename.R failed for original gene sets"
    fi
fi

# Run cell_rename.R for union gene sets
if [ ${#base_names_union[@]} -gt 0 ] && [ -f "/apps/conda/project/envs/r_env/bin/Rscript" ] && [ -f "/apps/www-dev/support/script/r/cell_rename.R" ]; then
    echo "Running cell_rename.R for union gene sets..."
    /apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/cell_rename.R "$result_dir/union" "${base_names_union[@]}"
    if [ $? -eq 0 ]; then
        echo "✓ cell_rename.R completed for union gene sets"
    else
        echo "WARNING: cell_rename.R failed for union gene sets"
    fi
fi

# Run cell_rename.R for intersection gene sets
if [ ${#base_names_intersect[@]} -gt 0 ] && [ -f "/apps/conda/project/envs/r_env/bin/Rscript" ] && [ -f "/apps/www-dev/support/script/r/cell_rename.R" ]; then
    echo "Running cell_rename.R for intersection gene sets..."
    /apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/cell_rename.R "$result_dir/intersection" "${base_names_intersect[@]}"
    if [ $? -eq 0 ]; then
        echo "✓ cell_rename.R completed for intersection gene sets"
    else
        echo "WARNING: cell_rename.R failed for intersection gene sets"
    fi
fi

# Run cell_rename.R for unique gene sets
if [ ${#base_names_unique[@]} -gt 0 ] && [ -f "/apps/conda/project/envs/r_env/bin/Rscript" ] && [ -f "/apps/www-dev/support/script/r/cell_rename.R" ]; then
    echo "Running cell_rename.R for unique gene sets..."
    /apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/cell_rename.R "$result_dir/Unique" "${base_names_unique[@]}"
    if [ $? -eq 0 ]; then
        echo "✓ cell_rename.R completed for unique gene sets"
    else
        echo "WARNING: cell_rename.R failed for unique gene sets"
    fi
fi

# =========================================================================
# Calculate "Other" LD Scores (background regions)
# =========================================================================
echo ""
echo "=== Calculating 'Other' LD Scores ==="

# Calculate LD scores for main "other" annotations
echo "Calculating LD scores for main 'other' annotations..."
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
echo "✓ Main 'other' LD score calculations finished."

# Calculate LD scores for "_Dir_other" directories (created by cell_rename.R)
echo "Calculating LD scores for '_Dir_other' directories..."

# Find directories and store the basenames in a new list
dir_other_list=$(find "${result_dir}" -maxdepth 1 -type d -name "*_Dir_other")
basename_other_list=()

for dir in $dir_other_list; do
    basename_other_list+=("$(basename "$dir")")
done

if [ ${#basename_other_list[@]} -gt 0 ]; then
    echo "Found ${#basename_other_list[@]} '_Dir_other' directories"
    last_index_dir_other=$((${#basename_other_list[@]} - 1))
    
    for index in $(seq 0 $last_index_dir_other); do
        dir_name="${basename_other_list[$index]}"
        echo "  Processing: $dir_name"
        
        for i in {1..22}; do
            /apps/conda/project/envs/ldsc/bin/python \
            /apps/www-dev/support/script/ldsc/ldsc.py \
            --l2 \
            --bfile /apps/www-dev/support/data/ref/1000G_EUR_Phase3_plink/1000G.EUR.QC.${i} \
            --ld-wind-cm 1 \
            --annot "$result_dir/$dir_name/other.${i}.annot.gz" \
            --thin-annot \
            --out "$result_dir/$dir_name/other.${i}" \
            --print-snps /apps/www-dev/support/data/ref/listHM3.txt &
        done
    done
    wait
    echo "✓ '_Dir_other' LD score calculations finished."
else
    echo "No '_Dir_other' directories found"
fi

# =========================================================================
# Run Enrichment Analysis - Without Joint Model
# =========================================================================
echo ""
echo "=== Running Enrichment Analysis (Without Joint Model) ==="

# Individual enrichment analysis for each original gene set
echo "Running individual enrichment analysis for each original gene set..."
for index in $(seq 0 $last_index); do
    base_name="${uploadeddir_array[$index]}"
    echo "  Processing: $base_name"
    
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

# Other enrichment analysis
echo "Running 'other' enrichment analysis..."
/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2 "$result_dir/$sum_name.sumstats.gz" \
--ref-ld-chr "$result_dir/other.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD." \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--overlap-annot \
--print-coefficients \
--frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
--out "$result_dir/other_enrichment_out"

echo "✓ Individual enrichment analyses finished."

# =========================================================================
# Run Enrichment Analysis - With Joint Models
# =========================================================================
echo ""
echo "=== Running Enrichment Analysis (With Joint Models) ==="

# =========================================================================
# Model 1: Unique + Intersection + Other (modified)
# =========================================================================
echo "Setting up Model 1 (Unique + Intersection + Other)..."
mkdir -p "$result_dir/model_1_enr"

# Run other_variants.R to prepare model 1
if [ -f "/apps/conda/project/envs/r_env/bin/Rscript" ] && [ -f "/apps/www-dev/support/script/r/other_variants.R" ]; then
    echo "Running other_variants.R for Model 1..."
    /apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/other_variants.R "$result_dir"
    if [ $? -eq 0 ]; then
        echo "✓ other_variants.R completed for Model 1"
    else
        echo "WARNING: other_variants.R failed for Model 1"
    fi
fi

# Calculate LD scores for model_1_enr other annotations
echo "Calculating LD scores for Model 1 'other' annotations..."
for i in {1..22}; do
    /apps/conda/project/envs/ldsc/bin/python \
    /apps/www-dev/support/script/ldsc/ldsc.py \
    --l2 \
    --bfile /apps/www-dev/support/data/ref/1000G_EUR_Phase3_plink/1000G.EUR.QC.${i} \
    --ld-wind-cm 1 \
    --annot "$result_dir/model_1_enr/other.${i}.annot.gz" \
    --thin-annot \
    --out "$result_dir/model_1_enr/other.${i}" \
    --print-snps /apps/www-dev/support/data/ref/listHM3.txt &
done
wait
echo "✓ Model 1 'other' LD score calculations finished."

# Build model 1 paths
uni_dir="$result_dir/Unique"
int_dir="$result_dir/intersection"

# Extract unique prefixes for Unique and Intersection
if [ -d "$uni_dir" ]; then
    unique_prefixes=$(ls "$uni_dir/" 2>/dev/null | grep -oP '^.*UniqueGenes' | sort -u)
else
    unique_prefixes=""
fi

if [ -d "$int_dir" ]; then
    intersection_prefixes=$(ls "$int_dir/" 2>/dev/null | grep -oP '^.*IntersectionGenes|^All_IntersectionGenes' | sort -u)
else
    intersection_prefixes=""
fi

# Build paths for Unique sets
uni_paths=""
for prefix in $unique_prefixes; do
    if [[ -n "$uni_paths" ]]; then
        uni_paths+=".,"
    fi
    uni_paths+="$uni_dir/$prefix"
done

# Build paths for Intersection sets
int_paths=""
for prefix in $intersection_prefixes; do
    if [[ -n "$int_paths" ]]; then
        int_paths+=".,"
    fi
    int_paths+="$int_dir/$prefix"
done

other_model1="$result_dir/model_1_enr/other"

# Combine paths for Model 1
if [[ -n "$uni_paths" && -n "$int_paths" ]]; then
    model1="$uni_paths.,$int_paths.,$other_model1"
elif [[ -n "$uni_paths" ]]; then
    model1="$uni_paths.,$other_model1"
elif [[ -n "$int_paths" ]]; then
    model1="$int_paths.,$other_model1"
else
    model1="$other_model1"
fi

echo "Model 1 paths: $model1"

# Run Model 1 enrichment analysis
echo "Running Model 1 enrichment analysis..."
/apps/conda/project/envs/ldsc/bin/python \
/apps/www-dev/support/script/ldsc/ldsc.py \
--h2 "$result_dir/$sum_name.sumstats.gz" \
--ref-ld-chr "$model1.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD." \
--w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
--overlap-annot \
--print-coefficients \
--frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
--out "$result_dir/model_1_enr/model_1_enrichment_out"

# Extract model components
grep -- '--ref-ld-chr' "$result_dir/model_1_enr/model_1_enrichment_out.log" | \
sed -n 's/.*--ref-ld-chr \(.*\)/\1/p' | \
tr ',' '\n' | \
sed "s#${result_dir}/##g" | \
sed 's#.*/##' | \
sed 's/\\$//' | \
sed 's/\.$//' | \
grep -v 'baselineLD' > "$result_dir/model_1_enr/enrich_model.txt"

echo "model = $(cat $result_dir/model_1_enr/enrich_model.txt | tr '\n' ' ' | sed 's/ $//' | sed 's/ / + /g')" > "$result_dir/model_1_enr/new_model.txt"

echo "✓ Model 1 enrichment analysis finished."

# =========================================================================
# Individual Gene Set + Other Enrichment
# =========================================================================
echo "Running individual gene set + other enrichment analyses..."

# Extract core list from basename_other_list
core_list=()
for name in "${basename_other_list[@]}"; do
    core_list+=("${name%_Dir_other}")
done

# Run enrichment for each gene set with its corresponding "other"
if [ ${#basename_other_list[@]} -gt 0 ]; then
    last_index_core=$((${#basename_other_list[@]} - 1))
    
    for index in $(seq 0 $last_index_core); do
        base_name="${core_list[$index]}"
        dir_name="${basename_other_list[$index]}"
        echo "  Processing: $base_name with $dir_name"
        
        /apps/conda/project/envs/ldsc/bin/python \
        /apps/www-dev/support/script/ldsc/ldsc.py \
        --h2 "$result_dir/$sum_name.sumstats.gz" \
        --ref-ld-chr "$result_dir/${base_name}.,$result_dir/${dir_name}/other.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD." \
        --w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
        --overlap-annot \
        --print-coefficients \
        --frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
        --out "$result_dir/${dir_name}/${base_name}_enrichment_other_out"
    done
    echo "✓ Individual gene set + other enrichment analyses finished."
fi

# =========================================================================
# Model 3: Union + Other
# =========================================================================
echo "Setting up Model 3 (Union + Other)..."

# Calculate LD scores for union other annotations
echo "Calculating LD scores for union 'other' annotations..."
if [ -d "${result_dir}/union" ] && [ -f "${result_dir}/union/other.1.annot.gz" ]; then
    for i in {1..22}; do
        /apps/conda/project/envs/ldsc/bin/python \
        /apps/www-dev/support/script/ldsc/ldsc.py \
        --l2 \
        --bfile /apps/www-dev/support/data/ref/1000G_EUR_Phase3_plink/1000G.EUR.QC.${i} \
        --ld-wind-cm 1 \
        --annot "$result_dir/union/other.${i}.annot.gz" \
        --thin-annot \
        --out "$result_dir/union/other.${i}" \
        --print-snps /apps/www-dev/support/data/ref/listHM3.txt &
    done
    wait
    echo "✓ Union 'other' LD score calculations finished."
else
    echo "WARNING: Union 'other' annotations not found, skipping Model 3"
fi

# Build Model 3
mkdir -p "$result_dir/model_3_enr"
union_dir="$result_dir/union"

if [ -d "$union_dir" ]; then
    union_prefixes=$(ls "$union_dir/" 2>/dev/null | grep -oP '^.*UnionGenes|^All_UnionGenes' | sort -u)
    
    # Build paths for Union sets
    union_paths=""
    for prefix in $union_prefixes; do
        if [[ -n "$union_paths" ]]; then
            union_paths+=".,"
        fi
        union_paths+="$union_dir/$prefix"
    done
    
    other_model3="$result_dir/union/other"
    
    # Combine paths for Model 3
    if [[ -n "$union_paths" ]]; then
        model3="$union_paths.,$other_model3"
    else
        model3="$other_model3"
    fi
    
    echo "Model 3 paths: $model3"
    
    # Run Model 3 enrichment analysis
    echo "Running Model 3 enrichment analysis..."
    /apps/conda/project/envs/ldsc/bin/python \
    /apps/www-dev/support/script/ldsc/ldsc.py \
    --h2 "$result_dir/$sum_name.sumstats.gz" \
    --ref-ld-chr "$model3.,/apps/www-dev/support/data/ref/1000G_Phase3_baselineLD_v2.2_ldscores/baselineLD." \
    --w-ld-chr /apps/www-dev/support/data/ref/1000G_Phase3_weights_hm3_no_MHC/weights.hm3_noMHC. \
    --overlap-annot \
    --print-coefficients \
    --frqfile-chr /apps/www-dev/support/data/ref/1000G_Phase3_frq/1000G.EUR.QC. \
    --out "$result_dir/model_3_enr/model_3_enrichment_out"
    
    # Extract model components
    grep -- '--ref-ld-chr' "$result_dir/model_3_enr/model_3_enrichment_out.log" | \
    sed -n 's/.*--ref-ld-chr \(.*\)/\1/p' | \
    tr ',' '\n' | \
    sed "s#${result_dir}/##g" | \
    sed 's#.*/##' | \
    sed 's/\\$//' | \
    sed 's/\.$//' | \
    grep -v 'baselineLD' > "$result_dir/model_3_enr/enrich_model.txt"
    
    echo "model = $(cat $result_dir/model_3_enr/enrich_model.txt | tr '\n' ' ' | sed 's/ $//' | sed 's/ / + /g')" > "$result_dir/model_3_enr/new_model.txt"
    
    echo "✓ Model 3 enrichment analysis finished."
fi



######################################################################################################
######################################################################################################


/apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/cell_vis_3_V2_desktop.R $result_dir $sum_stat
# /apps/conda/project/envs/r_env/bin/Rscript cell_vis_3.R   $result_dir $gene_name1 $gene_name2

mkdir $result_dir/HTML_model_1_3_output
mkdir $result_dir/HTML_model_N_output

/apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/model_output_desktop.R $result_dir



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

/apps/conda/project/envs/r_env/bin/Rscript /apps/www-dev/support/script/r/cell_specific_V2.R  $result_dir $sum_stat


# =========================================================================
# Create Summary
# =========================================================================
echo ""
echo "=== Creating Analysis Summary ==="

# Create summary of processed files
SUMMARY_FILE="$result_dir/desktop_analysis_summary.txt"
echo "Desktop Gene Set Analysis Summary" > "$SUMMARY_FILE"
echo "=================================" >> "$SUMMARY_FILE"
echo "Job Directory: $(basename $(dirname $result_dir))" >> "$SUMMARY_FILE"
echo "GWAS File: $sum_stat" >> "$SUMMARY_FILE"
echo "Sample Size: $N" >> "$SUMMARY_FILE"
echo "Window Size: $windowSize" >> "$SUMMARY_FILE"
echo "Original Gene Sets: ${#gene_array[@]}" >> "$SUMMARY_FILE"
echo "Total Files Processed: ${#gene_files_found[@]}" >> "$SUMMARY_FILE"
echo "Annotation Files Created: $processed_count" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "Gene Set Sources:" >> "$SUMMARY_FILE"
echo "  - Input files copied from: $INPUT_DIR" >> "$SUMMARY_FILE"
echo "  - All processing and outputs in: $result_dir" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "Annotation File Organization:" >> "$SUMMARY_FILE"
echo "  - Original gene sets: $result_dir/" >> "$SUMMARY_FILE"
echo "  - Union gene sets: $result_dir/union/" >> "$SUMMARY_FILE"
echo "  - Intersection gene sets: $result_dir/intersection/" >> "$SUMMARY_FILE"
echo "  - Unique gene sets: $result_dir/Unique/" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "Generated Files:" >> "$SUMMARY_FILE"
echo "  - Munged summary statistics: ${sum_name}.sumstats.gz" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# Enrichment Analysis Results
echo "Enrichment Analysis Results:" >> "$SUMMARY_FILE"
echo "  - Individual analyses:" >> "$SUMMARY_FILE"
for index in $(seq 0 $last_index); do
    base_name="${uploadeddir_array[$index]}"
    echo "    * ${base_name}_enrichment_out" >> "$SUMMARY_FILE"
done
echo "  - Other enrichment: other_enrichment_out" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# Joint Model Results
echo "Joint Model Analyses:" >> "$SUMMARY_FILE"
echo "  - Model 1 (Unique + Intersection + Other): model_1_enr/model_1_enrichment_out" >> "$SUMMARY_FILE"
if [ ${#basename_other_list[@]} -gt 0 ]; then
    echo "  - Gene set + Other analyses:" >> "$SUMMARY_FILE"
    for index in $(seq 0 $last_index_core); do
        base_name="${core_list[$index]}"
        dir_name="${basename_other_list[$index]}"
        echo "    * ${dir_name}/${base_name}_enrichment_other_out" >> "$SUMMARY_FILE"
    done
fi
if [ -d "$result_dir/model_3_enr" ]; then
    echo "  - Model 3 (Union + Other): model_3_enr/model_3_enrichment_out" >> "$SUMMARY_FILE"
fi
echo "" >> "$SUMMARY_FILE"

echo "Analysis completed: $(date)" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "All enrichment analyses completed successfully!" >> "$SUMMARY_FILE"

echo "✓ Analysis summary saved to: $SUMMARY_FILE"

echo ""
echo "=== Desktop Gene Set Analysis Completed Successfully ==="
echo ""
echo "Summary:"
echo "  - Copied gene sets to: $result_dir"
echo "  - Processed ${#gene_files_found[@]} total files (original + derived)"
echo "  - Created annotations for $processed_count gene sets"
echo "  - Generated Manhattan plot: $file_png"
echo "  - Munged summary statistics: ${sum_name}.sumstats.gz"
echo "  - Calculated LD scores for all gene sets"
echo "  - Processed LD score files with cell_rename.R for all categories"
echo "  - Ran enrichment analyses:"
echo "    * Individual gene set analyses"
echo "    * 'Other' background analysis"
echo "    * Model 1: Unique + Intersection + Other"
echo "    * Gene set + Other paired analyses"
echo "    * Model 3: Union + Other"
echo "  - Generated set operations: union, intersection, unique"
echo "  - Reorganized files into appropriate directories"
echo "  - Detailed summary: $SUMMARY_FILE"
echo ""
echo "All analyses completed successfully!"

exit 0
