<?php
// simple_upload.php - Process desktop gene set uploads

// Include configuration and security files
require_once dirname(__DIR__, 2) . '/cfg/deploy.php';
require_once LIB_ROOT . '/security.php';

// Helper function to filter validation output
function filterValidationOutput($output) {
    $lines = explode("\n", $output);
    $cleanLines = [];
    
    foreach ($lines as $line) {
        // Keep only error messages and remove technical log messages
        if (strpos($line, 'ERROR:') !== false || 
            strpos($line, 'FAILED:') !== false ||
            strpos($line, 'Expected columns:') !== false ||
            strpos($line, 'Found columns:') !== false) {
            $cleanLines[] = $line;
        }
        // Also keep SUCCESS message if present
        elseif (strpos($line, 'SUCCESS:') !== false) {
            $cleanLines[] = $line;
        }
    }
    
    // If no specific errors found, return a generic message
    if (empty($cleanLines)) {
        return "File validation failed. Please check your file format and try again.";
    }
    
    return implode("\n", $cleanLines);
}

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    
    try {
        // Create job directory
        $jobNumber = generateSecureDirectoryName();
        $jobBasePath = UPLOAD_ROOT . $jobNumber . '/';
        $inputDir = $jobBasePath . JOB_INPUTS_DIR . '/';
        $workingDir = $jobBasePath . JOB_WORKING_DIR . '/';
        
        // Create directories with proper permissions
        mkdir($jobBasePath, 0775, true);
        mkdir($inputDir, 0775, true);
        mkdir($workingDir, 0775, true);
        chmod($jobBasePath, 0775);
        
        // ============================================
        // 1. Save uploaded gene set files
        // ============================================
        $geneFileNames = [];
        if (isset($_FILES['gene_files']) && is_array($_FILES['gene_files']['name'])) {
            $geneLabels = explode(',', sanitizeInput($_POST['gene_labels'], 'string'));
            $geneLabels = array_map('trim', $geneLabels);
            $geneLabels = array_filter($geneLabels);
            
            for ($i = 0; $i < count($_FILES['gene_files']['name']); $i++) {
                if ($_FILES['gene_files']['error'][$i] === UPLOAD_ERR_OK) {
                    // Sanitize filename
                    $originalName = $_FILES['gene_files']['name'][$i];
                    $safeName = preg_replace('/[^a-zA-Z0-9._-]/', '_', $originalName);
                    
                    // Use label if available, otherwise use sanitized filename
                    $label = isset($geneLabels[$i]) ? $geneLabels[$i] : 'geneset_' . ($i + 1);
                    $safeLabel = preg_replace('/[^a-zA-Z0-9_-]/', '_', $label);
                    
                    // Save file with label-based name
                    $geneFile = $inputDir . $safeLabel . '.txt';
                    
                    if (move_uploaded_file($_FILES['gene_files']['tmp_name'][$i], $geneFile)) {
                        $geneFileNames[] = $safeLabel;
                    } else {
                        throw new Exception("Could not save gene set file: " . $originalName);
                    }
                }
            }
        }
        
        if (empty($geneFileNames)) {
            throw new Exception("No gene set files were successfully uploaded.");
        }
        
        // ============================================
        // 2. Save GWAS file
        // ============================================
        if (!isset($_FILES['sumstat_right']) || $_FILES['sumstat_right']['error'] !== UPLOAD_ERR_OK) {
            throw new Exception("GWAS file upload failed");
        }
        
        $gwasFile = $inputDir . 'uploaded_sumstat.' . pathinfo($_FILES['sumstat_right']['name'], PATHINFO_EXTENSION);
        if (!move_uploaded_file($_FILES['sumstat_right']['tmp_name'], $gwasFile)) {
            throw new Exception("Could not save GWAS file");
        }
        
        // ============================================
        // 3. Save optional BIM file
        // ============================================
        if (isset($_FILES['target_bim']) && $_FILES['target_bim']['error'] == UPLOAD_ERR_OK) {
            $bimFile = $inputDir . 'uploaded_bim.' . pathinfo($_FILES['target_bim']['name'], PATHINFO_EXTENSION);
            move_uploaded_file($_FILES['target_bim']['tmp_name'], $bimFile);
        }
        
        // ============================================
        // 4. Create job info file
        // ============================================
        $passcode = generateSecurePasscode();
        
        // Sanitize inputs
        $unsafe_GWAS_N = $_POST['GWAS_N'];
        $unsafe_window_size = $_POST['window_size'];
        
        $cleaned_GWAS_N = sanitizeInput($unsafe_GWAS_N, 'numeric');
        $cleaned_window_size = sanitizeInput($unsafe_window_size, 'numeric');
        
        $jobData = [
            'job_number' => $jobNumber,
            'passcode' => $passcode,
            'gene_files' => $geneFileNames,  // List of gene set labels/names
            'gene_labels' => sanitizeInput($_POST['gene_labels'], 'string'),
            'GWAS_N' => $cleaned_GWAS_N,
            'window_size' => $cleaned_window_size,
            'submitted_at' => date('Y-m-d H:i:s'),
            'status' => 'validating',
            'upload_type' => 'desktop'  // To distinguish from GeneWeaver uploads
        ];
        
        // Save job info
        file_put_contents($jobBasePath . 'job_info.json', json_encode($jobData));
        updateJobStatus($jobBasePath, 'validating');
        
        // ============================================
        // 5. Run DRY-RUN validation using ANALYSIS_SCRIPT_DESKTOP
        // ============================================
/*         $dryRunCommand = "bash " . escapeshellarg(ANALYSIS_SCRIPT_DESKTOP) . 
                        " --dry-run --job-dir " . escapeshellarg($jobBasePath) . 
                        " 2>&1";

        $dryRunOutput = shell_exec($dryRunCommand);
        $dryRunSuccess = (strpos($dryRunOutput, 'SUCCESS: All validations passed') !== false); */
		
        $dryRunCommand = sprintf(
            'bash %s --dry-run --job-dir %s --desktop-basic-script %s --desktop-pgs-script %s 2>&1',
            escapeshellarg(ANALYSIS_SCRIPT_DESKTOP),
            escapeshellarg($jobBasePath),
            escapeshellarg(ANALYSIS_SCRIPT_DESKTOP_update),
            escapeshellarg(ANALYSIS_PGS_SCRIPT_DESKTOP_update)
        );

        error_log("Desktop upload - Dry-run command: " . $dryRunCommand); // Debug logging

        $dryRunOutput = shell_exec($dryRunCommand);
        $dryRunSuccess = (strpos($dryRunOutput, 'SUCCESS: All validations passed') !== false);

        if (!$dryRunSuccess) {
            // Clean up and show error
            deleteDirectory($jobBasePath);
            
            $cleanError = filterValidationOutput($dryRunOutput);
            
            echo '<div class="message error">';
            echo '<h3>❌ Validation Failed</h3>';
            echo '<p>Please check your input files:</p>';
            echo '<div style="background: white; padding: 10px; border-radius: 4px; font-family: monospace; white-space: pre-wrap;">';
            echo htmlspecialchars($cleanError);
            echo '</div>';
            echo '<p><a href="../desktop_upload.html">Try Again</a></p>';
            echo '</div>';
            exit;
        }
        
        // ============================================
        // 6. Start real analysis using ANALYSIS_SCRIPT_DESKTOP
        // ============================================
        $jobData['status'] = 'running';
        file_put_contents($jobBasePath . 'job_info.json', json_encode($jobData));
        updateJobStatus($jobBasePath, 'running');
        
        // Start analysis in background
        $realCommand = sprintf(
            'bash %s --job-dir %s --desktop-basic-script %s --desktop-pgs-script %s > %s 2>&1 &',
            escapeshellarg(ANALYSIS_SCRIPT_DESKTOP),
            escapeshellarg($jobBasePath),
            escapeshellarg(ANALYSIS_SCRIPT_DESKTOP_update),
            escapeshellarg(ANALYSIS_PGS_SCRIPT_DESKTOP_update),
            escapeshellarg($workingDir . 'analysis.log')
        );
        
        error_log("Desktop upload - Real command: " . $realCommand); // Debug logging
        
        exec($realCommand);
        
        // ============================================
        // 7. Success message
        // ============================================
        $displayJobNumber = str_replace('r_', '', $jobNumber);
        
        echo '<div class="message success">';
        echo '<h3>✅ Job Submitted Successfully!</h3>';
        echo '<p><strong>Job Number:</strong> ' . htmlspecialchars($displayJobNumber) . '</p>';
        echo '<p><strong>Passcode:</strong> ' . htmlspecialchars($passcode) . '</p>';
        echo '<p><strong>Gene Sets Uploaded:</strong> ' . count($geneFileNames) . ' files</p>';
        echo '<br>';
        echo '<p>✅ <strong>File validation passed!</strong> Your analysis has started.</p>';
        echo '<p>Use the "Check Job Status" tab to monitor progress.</p>';
        echo '</div>';
        
    } catch (Exception $e) {
        // Clean up on any error
        if (isset($jobBasePath) && is_dir($jobBasePath)) {
            deleteDirectory($jobBasePath);
        }
        
        echo '<div class="message error">';
        echo '<h3>❌ Submission Failed</h3>';
        echo '<p>' . htmlspecialchars($e->getMessage()) . '</p>';
        echo '</div>';
    }
} else {
    // Invalid request method
    echo '<div class="message error">';
    echo '<h3>❌ Invalid Request</h3>';
    echo '<p>Please use the upload form to submit your data.</p>';
    echo '</div>';
}
?>
