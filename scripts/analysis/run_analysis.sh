#!/bin/bash
# run_analysis.sh - Main analysis script with dry-run support

set -e  # Exit on any error

# Parse command line arguments
DRY_RUN=false
JOB_DIR=""
GENEWEAVER_SCRIPT=""
GENEWEAVER_PGS_SCRIPT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --job-dir)
            JOB_DIR="$2"
            shift 2
            ;;
        --geneweaver-script)
            GENEWEAVER_SCRIPT="$2"
            shift 2
            ;;
        --geneweaver-pgs-script)
            GENEWEAVER_PGS_SCRIPT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$JOB_DIR" ]; then
    echo "ERROR: --job-dir parameter is required"
    exit 1
fi

# Set up paths
INPUT_DIR="$JOB_DIR/inputs"
WORKING_DIR="$JOB_DIR/working"
OUTPUT_DIR="$JOB_DIR/outputs"
LOG_FILE="$WORKING_DIR/analysis.log"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}


# =============================================================================
# Check if script files exist
# =============================================================================
log "=== CHECKING SCRIPT FILES ==="
if [ -f "$GENEWEAVER_SCRIPT" ]; then
    log "✓ GENEWEAVER_SCRIPT found: $GENEWEAVER_SCRIPT"
else
    log "✗ GENEWEAVER_SCRIPT NOT FOUND: $GENEWEAVER_SCRIPT"
    log "File exists check: [ -f \"$GENEWEAVER_SCRIPT\" ]"
    ls -la "$GENEWEAVER_SCRIPT" 2>/dev/null || log "File not found"
fi

if [ -f "$GENEWEAVER_PGS_SCRIPT" ]; then
    log "✓ GENEWEAVER_PGS_SCRIPT found: $GENEWEAVER_PGS_SCRIPT"
else
    log "✗ GENEWEAVER_PGS_SCRIPT NOT FOUND: $GENEWEAVER_PGS_SCRIPT"
    log "File exists check: [ -f \"$GENEWEAVER_PGS_SCRIPT\" ]"
    ls -la "$GENEWEAVER_PGS_SCRIPT" 2>/dev/null || log "File not found"
fi


# =============================================================================
# DEBUGGING: Log script paths at start
# =============================================================================
log "=== SCRIPT PATHS FROM COMMAND LINE ARGUMENTS ==="
log "GENEWEAVER_SCRIPT: $GENEWEAVER_SCRIPT"
log "GENEWEAVER_PGS_SCRIPT: $GENEWEAVER_PGS_SCRIPT"
log "JOB_DIR: $JOB_DIR"
log "DRY_RUN: $DRY_RUN"


# Add this function to update both status files - PUT IT BEFORE main()
update_job_status() {
    local job_dir="$1"
    local status="$2"
    local job_info_file="$job_dir/job_info.json"
    
    # Update status.txt
    echo "$status" > "$job_dir/status.txt"
    
    # Update job_info.json
    if [ -f "$job_info_file" ]; then
        # Use jq if available, or use a simple sed approach
        if command -v jq >/dev/null 2>&1; then
            jq --arg status "$status" '.status = $status' "$job_info_file" > "${job_info_file}.tmp" && mv "${job_info_file}.tmp" "$job_info_file"
        else
            # Fallback: use sed (less reliable but works for simple JSON)
            sed -i "s/\"status\":\"[^\"]*\"/\"status\":\"$status\"/" "$job_info_file"
        fi
    fi
    
    log "Updated job status to: $status"
}

# Function to validate file extension is .gz
validate_gzip_extension() {
    local file="$1"
    local file_type="$2"
    
    if [[ "$file" != *.gz ]]; then
        echo "ERROR: $file_type must be a .gz compressed file. Found: $file"
        return 1
    fi
    return 0
}

# Function to validate GWAS file columns exactly match
validate_gwas_columns() {
    local sample_file="$1"
    
    # Expected columns in exact order
    local required_columns=("SNP_ID" "CHR" "POS" "A1" "A2" "Beta" "SE" "Pval")
    
    # Read header line
    local header_line=$(head -1 "$sample_file")
    
    # Convert header to array
    IFS=$'\t' read -ra header_columns <<< "$header_line"
    
    # Check column count matches
    if [ ${#header_columns[@]} -ne ${#required_columns[@]} ]; then
        echo "ERROR: GWAS file has ${#header_columns[@]} columns, but expected ${#required_columns[@]} columns."
        echo "Found columns: ${header_columns[*]}"
        echo "Expected columns: ${required_columns[*]}"
        return 1
    fi
    
    # Check each column name matches exactly
    for i in "${!required_columns[@]}"; do
        if [ "${header_columns[$i]}" != "${required_columns[$i]}" ]; then
            echo "ERROR: Column $((i+1)) mismatch. Expected: '${required_columns[$i]}', Found: '${header_columns[$i]}'"
            echo "All found columns: ${header_columns[*]}"
            echo "All expected columns: ${required_columns[*]}"
            return 1
        fi
    done
    
    return 0
}

# Function to validate BIM file format
validate_bim_file() {
    local bim_file="$1"
    local working_dir="$2"
    
    log "Validating BIM file: $bim_file"
    
    # Check if file is gzipped
    if [[ "$bim_file" == *.gz ]]; then
        if ! gunzip -c "$bim_file" > "$working_dir/bim_decompressed.txt" 2>/dev/null; then
            echo "ERROR: Failed to decompress BIM file - may be corrupted"
            return 1
        fi
        local decompressed_file="$working_dir/bim_decompressed.txt"
    else
        cp "$bim_file" "$working_dir/bim_decompressed.txt"
        local decompressed_file="$working_dir/bim_decompressed.txt"
    fi
    
    # Read and validate each line
    local line_number=0
    while IFS= read -r line; do
        ((line_number++))
        
        # Skip empty lines
        [ -z "$line" ] && continue
        
        # Split line by tabs
        IFS=$'\t' read -ra columns <<< "$line"
        
        # Check if there are exactly 6 columns
        if [ ${#columns[@]} -ne 6 ]; then
            echo "ERROR: Line $line_number in BIM file does not have exactly 6 columns. Found: ${#columns[@]}"
            echo "Line content: $line"
            return 1
        fi
        
        local chr="${columns[0]}"      # Column 1: chromosome
        local rsid="${columns[1]}"     # Column 2: rsID
        local pos="${columns[2]}"      # Column 3: position
        local coord="${columns[3]}"    # Column 4: coordinate
        local a1="${columns[4]}"       # Column 5: allele 1
        local a2="${columns[5]}"       # Column 6: allele 2
        
        # Validate chromosome (1-22)
        if ! [[ "$chr" =~ ^[0-9]+$ ]] || [ "$chr" -lt 1 ] || [ "$chr" -gt 22 ]; then
            echo "ERROR: Line $line_number: Column 1 (CHR) should be an integer between 1-22. Found: '$chr'"
            return 1
        fi
        
        # Validate rsID pattern (rs followed by numbers)
        if ! [[ "$rsid" =~ ^rs[0-9]+$ ]]; then
            echo "ERROR: Line $line_number: Column 2 (RSID) should follow pattern 'rs' followed by numbers. Found: '$rsid'"
            return 1
        fi
        
        # Validate position (numeric)
        if ! [[ "$pos" =~ ^[0-9]+$ ]]; then
            echo "ERROR: Line $line_number: Column 3 (POS) should be numeric. Found: '$pos'"
            return 1
        fi
        
        # Validate coordinate (numeric)
        if ! [[ "$coord" =~ ^[0-9]+$ ]]; then
            echo "ERROR: Line $line_number: Column 4 (COORD) should be numeric. Found: '$coord'"
            return 1
        fi
        
        # Validate allele 1 (A,G,C,T)
        if ! [[ "$a1" =~ ^[AGCT]$ ]]; then
            echo "ERROR: Line $line_number: Column 5 (A1) should be A, G, C, or T. Found: '$a1'"
            return 1
        fi
        
        # Validate allele 2 (A,G,C,T)
        if ! [[ "$a2" =~ ^[AGCT]$ ]]; then
            echo "ERROR: Line $line_number: Column 6 (A2) should be A, G, C, or T. Found: '$a2'"
            return 1
        fi
        
    done < "$decompressed_file"
    
    # Clean up temporary file
    rm -f "$decompressed_file"
    
    log "BIM file validation passed for $line_number lines"
    return 0
}

# FIXED: Main validation function with proper BIM file checking
validate_inputs() {
    log "=== STARTING VALIDATION ==="
    
    # Check if job directory structure exists
    if [ ! -d "$INPUT_DIR" ]; then
        echo "ERROR: Input directory not found: $INPUT_DIR"
        return 1
    fi
    
    # Find and validate GWAS file
    GWAS_FILES=($INPUT_DIR/uploaded_sumstat.*)
    if [ ${#GWAS_FILES[@]} -eq 0 ]; then
        echo "ERROR: No GWAS file found in $INPUT_DIR"
        return 1
    fi
    
    GWAS_FILE="${GWAS_FILES[0]}"
    log "Found GWAS file: $GWAS_FILE"
    
    # Validate GWAS file is gzipped
    if ! validate_gzip_extension "$GWAS_FILE" "GWAS file"; then
        return 1
    fi
    
    # Decompress GWAS file for validation
    log "Decompressing GWAS file for validation..."
    if ! gunzip -c "$GWAS_FILE" > "$WORKING_DIR/gwas_decompressed.txt" 2>/dev/null; then
        echo "ERROR: Failed to decompress GWAS file - may be corrupted"
        return 1
    fi
    
    # Validate GWAS file columns
    log "Validating GWAS file columns..."
    if ! validate_gwas_columns "$WORKING_DIR/gwas_decompressed.txt"; then
        rm -f "$WORKING_DIR/gwas_decompressed.txt"
        return 1
    fi
    
    # Clean up temporary GWAS file
    rm -f "$WORKING_DIR/gwas_decompressed.txt"
    
    # FIXED: Proper BIM file detection using nullglob and checking actual files
    shopt -s nullglob
    BIM_FILES=($INPUT_DIR/uploaded_bim.*)
    shopt -u nullglob
    
    # Check if any actual BIM files exist
    if [ ${#BIM_FILES[@]} -gt 0 ]; then
        BIM_FILE="${BIM_FILES[0]}"
        log "Found BIM file: $BIM_FILE"
        
        # Validate BIM file is gzipped
        if ! validate_gzip_extension "$BIM_FILE" "BIM file"; then
            return 1
        fi
        
        # Validate BIM file format
        if ! validate_bim_file "$BIM_FILE" "$WORKING_DIR"; then
            return 1
        fi
    else
        log "No BIM file provided, skipping BIM validation"
    fi
    
    log "=== VALIDATION PASSED ==="
    return 0
}

# FIXED: Main analysis function with proper BIM file checking
run_analysis() {
    log "=== STARTING ANALYSIS ==="
    
    # Read job parameters
    JOB_INFO_FILE="$JOB_DIR/job_info.json"
    if [ ! -f "$JOB_INFO_FILE" ]; then
        echo "ERROR: Job info file not found: $JOB_INFO_FILE"
        return 1
    fi
    
    # Extract parameters
    if command -v jq >/dev/null 2>&1; then
        log "Using jq to extract parameters"
        GWAS_N=$(jq -r '.GWAS_N' "$JOB_INFO_FILE")
        WINDOW_SIZE=$(jq -r '.window_size' "$JOB_INFO_FILE")
        GENEWEAVER_IDS=$(jq -r '.geneweaver' "$JOB_INFO_FILE")
    elif command -v python3 >/dev/null 2>&1; then
        log "Using python to extract parameters"
        GWAS_N=$(python3 -c "import json; print(json.load(open('$JOB_INFO_FILE'))['GWAS_N'])")
        WINDOW_SIZE=$(python3 -c "import json; print(json.load(open('$JOB_INFO_FILE'))['window_size'])")
        GENEWEAVER_IDS=$(python3 -c "import json; print(json.load(open('$JOB_INFO_FILE'))['geneweaver'])")
    else
        log "Using grep to extract parameters"
        GWAS_N=$(grep -o '"GWAS_N":"[^"]*' "$JOB_INFO_FILE" | sed 's/"GWAS_N":"//')
        WINDOW_SIZE=$(grep -o '"window_size":"[^"]*' "$JOB_INFO_FILE" | sed 's/"window_size":"//')
        GENEWEAVER_IDS=$(grep -o '"geneweaver":"[^"]*' "$JOB_INFO_FILE" | sed 's/"geneweaver":"//')
    fi
    
    # Debug: Log the extracted values
    log "Extracted parameters - GWAS_N: '$GWAS_N', window_size: '$WINDOW_SIZE', genesets: '$GENEWEAVER_IDS'"
    
    # Validate parameters are not empty
    if [ -z "$GWAS_N" ] || [ -z "$WINDOW_SIZE" ] || [ -z "$GENEWEAVER_IDS" ]; then
        log "ERROR: One or more required parameters are empty"
        log "GWAS_N: '$GWAS_N', window_size: '$WINDOW_SIZE', genesets: '$GENEWEAVER_IDS'"
        return 1
    fi
    
    log "Analysis parameters: GWAS_N=$GWAS_N, window_size=$WINDOW_SIZE, genesets=$GENEWEAVER_IDS"
    
    # Find input files
    GWAS_FILES=($INPUT_DIR/uploaded_sumstat.*)
    GWAS_FILE="${GWAS_FILES[0]}"
    
    # FIXED: Proper BIM file detection using nullglob
    shopt -s nullglob
    BIM_FILES=($INPUT_DIR/uploaded_bim.*)
    shopt -u nullglob
    
    # =========================================================================
    # STEP 1: Choose which GeneWeaver script to run based on BIM file presence
    # =========================================================================
    
    # Set up common paths
    FILE_PNG="$OUTPUT_DIR/manhattan_plot.png"
    FILE_PNG2="$OUTPUT_DIR/enrichment_plot.png"
    GENE_LABEL_FILE="$WORKING_DIR/gene_labels.json"
    
    # Create gene labels JSON file from job info
    if command -v jq >/dev/null 2>&1; then
        jq '{geneweaver: .geneweaver, geneweaver_label: .geneweaver_label}' "$JOB_INFO_FILE" > "$GENE_LABEL_FILE"
    else
        echo "{\"geneweaver\":\"$GENEWEAVER_IDS\",\"geneweaver_label\":\"$(grep -o '"geneweaver_label":"[^"]*' "$JOB_INFO_FILE" | sed 's/"geneweaver_label":"//')\"}" > "$GENE_LABEL_FILE"
    fi
    
    # FIXED: Check if BIM file exists to decide which script to run
    if [ ${#BIM_FILES[@]} -gt 0 ]; then
        BIM_FILE="${BIM_FILES[0]}"
        log "BIM file detected: $BIM_FILE - Running PGS analysis"
        
        # Use the PGS script (with BIM file support)
        
        if [ -n "$GENEWEAVER_PGS_SCRIPT" ] && [ -f "$GENEWEAVER_PGS_SCRIPT" ]; then
			WEAVER_SCRIPT="$GENEWEAVER_PGS_SCRIPT"
			log "Executing PGS script: $WEAVER_SCRIPT"
            
            # Debug: Log the exact command
            log "Command: $WEAVER_SCRIPT -sum_stat \"$GWAS_FILE\" -target_bim \"$BIM_FILE\" -result_dir \"$WORKING_DIR\" -N \"$GWAS_N\" -windowSize \"$WINDOW_SIZE\" -file_png \"$FILE_PNG\" -file_png2 \"$FILE_PNG2\" -geneLabel \"$GENE_LABEL_FILE\" -geneID \"$GENEWEAVER_IDS\""
            
            "$WEAVER_SCRIPT" \
                -sum_stat "$GWAS_FILE" \
                -target_bim "$BIM_FILE" \
                -result_dir "$WORKING_DIR" \
                -N "$GWAS_N" \
                -windowSize "$WINDOW_SIZE" \
                -file_png "$FILE_PNG" \
                -file_png2 "$FILE_PNG2" \
                -geneLabel "$GENE_LABEL_FILE" \
                -geneID "$GENEWEAVER_IDS"
                
            WEAVER_EXIT_CODE=$?
        else
            log "ERROR: PGS script not found at $WEAVER_SCRIPT"
            return 1
        fi
    else
        log "No BIM file provided - Running basic GeneWeaver analysis"
        
        # Use the basic script (no BIM file)
        
        if [ -n "$GENEWEAVER_SCRIPT" ] && [ -f "$GENEWEAVER_SCRIPT" ]; then
			WEAVER_SCRIPT="$GENEWEAVER_SCRIPT"
			log "Executing basic script: $WEAVER_SCRIPT"
            
            # Debug: Log the exact command
            log "Command: $WEAVER_SCRIPT -sum_stat \"$GWAS_FILE\" -result_dir \"$WORKING_DIR\" -N \"$GWAS_N\" -windowSize \"$WINDOW_SIZE\" -file_png \"$FILE_PNG\" -file_png2 \"$FILE_PNG2\" -geneLabel \"$GENE_LABEL_FILE\" -geneID \"$GENEWEAVER_IDS\""
            
            "$WEAVER_SCRIPT" \
                -sum_stat "$GWAS_FILE" \
                -result_dir "$WORKING_DIR" \
                -N "$GWAS_N" \
                -windowSize "$WINDOW_SIZE" \
                -file_png "$FILE_PNG" \
                -file_png2 "$FILE_PNG2" \
                -geneLabel "$GENE_LABEL_FILE" \
                -geneID "$GENEWEAVER_IDS"
                
            WEAVER_EXIT_CODE=$?
        else
            log "WARNING: GeneWeaver script not found at $WEAVER_SCRIPT"
            log "Using placeholder analysis instead..."
            
            # Your placeholder analysis here
            sleep 2
            
            log "Processing GeneWeaver IDs..."
            IFS=',' read -ra GENE_IDS <<< "$GENEWEAVER_IDS"
            for gene_id in "${GENE_IDS[@]}"; do
                log "Processing GeneWeaver ID: $gene_id"
            done
            
            log "Running analysis with window size: $WINDOW_SIZE"
            sleep 3
            
            # Create dummy output files
            log "Creating output files..."
            echo "Manhattan Plot Data" > "$FILE_PNG"
            echo "Gene,Enrichment,PValue" > "$OUTPUT_DIR/enrichment_results.csv"
            echo "Top_SNP,Chromosome,Position,P_Value" > "$OUTPUT_DIR/top_snps.csv"
            echo "Analysis completed successfully" > "$OUTPUT_DIR/analysis_report.txt"
            
            WEAVER_EXIT_CODE=0
        fi
    fi
    
    # Check exit code
    if [ $WEAVER_EXIT_CODE -ne 0 ]; then
        log "ERROR: GeneWeaver analysis failed with exit code: $WEAVER_EXIT_CODE"
        return 1
    else
        log "GeneWeaver analysis completed successfully"
    fi
    
    log "=== ANALYSIS COMPLETED SUCCESSFULLY ==="
    return 0
}

# Main execution flow
main() {
    log "Job directory: $JOB_DIR"
    
    # Create working and output directories if they don't exist
    mkdir -p "$WORKING_DIR" "$OUTPUT_DIR"
    
    if [ "$DRY_RUN" = true ]; then
        log "=== DRY RUN MODE ==="
        if validate_inputs; then
            echo "SUCCESS: All validations passed"
            exit 0
        else
            echo "FAILED: Validation errors detected"
            exit 1
        fi
    else
        log "=== FULL ANALYSIS MODE ==="
        # Update status to running - USE THE FUNCTION FOR BOTH FILES
        update_job_status "$JOB_DIR" "running"
        
        # Run validation first (fail fast in real run too)
        if ! validate_inputs; then
            update_job_status "$JOB_DIR" "failed"
            log "ERROR: Validation failed at analysis start"
            exit 1
        fi
        
        # Run the actual analysis
        if run_analysis; then
            update_job_status "$JOB_DIR" "complete"
            log "Analysis completed successfully"
            exit 0
        else
            update_job_status "$JOB_DIR" "failed"
            log "Analysis failed"
            exit 1
        fi
    fi
}

# Run main function
main "$@"

# ## sed -i 's/\r$//' /apps/www-dev/support/script/analysis/run_analysis.sh
