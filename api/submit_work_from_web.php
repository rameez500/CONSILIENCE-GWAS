<?php
// submit_work_from_web.php - The "hand-off" that Thomas mentioned
// require_once '/apps/www-dev/project/cfg/deploy.php';
// require_once '/apps/www-dev/project/lib/security.php';


require_once dirname(__DIR__, 2) . '/cfg/deploy.php';  // Go up 2 levels
require_once LIB_ROOT . '/security.php';  // Use constant from deploy.php


// Add this helper function to filter output
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
	
	// If no specific errors found, return a generic message with limited technical info
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
        
		/* FIX: create job directory with 0775 */
		mkdir($jobBasePath, 0775, true);
		
        mkdir($inputDir, 0775, true);
        mkdir($workingDir, 0775, true);

		/* Ensure correct permissions explicitly (optional but recommended) */
		chmod($jobBasePath, 0775);
        
        // Save uploaded files
        if (!isset($_FILES['sumstat_right']) || $_FILES['sumstat_right']['error'] !== UPLOAD_ERR_OK) {
            throw new Exception("GWAS file upload failed");
        }
        
        $gwasFile = $inputDir . 'uploaded_sumstat.' . pathinfo($_FILES['sumstat_right']['name'], PATHINFO_EXTENSION);
        if (!move_uploaded_file($_FILES['sumstat_right']['tmp_name'], $gwasFile)) {
            throw new Exception("Could not save GWAS file");
        }
        
        if (isset($_FILES['target_bim']) && $_FILES['target_bim']['error'] == UPLOAD_ERR_OK) {
            $bimFile = $inputDir . 'uploaded_bim.' . pathinfo($_FILES['target_bim']['name'], PATHINFO_EXTENSION);
            move_uploaded_file($_FILES['target_bim']['tmp_name'], $bimFile);
        }
        
        // ✅ FIX: CREATE JOB_INFO.JSON FIRST (before dry-run)
        $passcode = generateSecurePasscode();
        
/*         $jobData = [
            'job_number' => $jobNumber,
            'passcode' => $passcode,
            'geneweaver' => $_POST['geneweaver'],
            'geneweaver_label' => $_POST['geneweaver_label'],
            'GWAS_N' => $_POST['GWAS_N'],
            'window_size' => $_POST['window_size'],
            'submitted_at' => date('Y-m-d H:i:s'),
            'status' => 'validating'  // Initial status
        ]; */

		$unsafe_geneweaver = $_POST['geneweaver'];
		$unsafe_geneweaver_label = $_POST['geneweaver_label'];
		$unsafe_GWAS_N = $_POST['GWAS_N'];
		$unsafe_window_size = $_POST['window_size'];

		// Sanitize using functions from security.php
		$cleaned_geneweaver = sanitizeInput($unsafe_geneweaver, 'gene_id');
		$cleaned_geneweaver_label = sanitizeInput($unsafe_geneweaver_label, 'string');
		$cleaned_GWAS_N = sanitizeInput($unsafe_GWAS_N, 'numeric');
		$cleaned_window_size = sanitizeInput($unsafe_window_size, 'numeric');

		$jobData = [
			'job_number' => $jobNumber,
			'passcode' => $passcode,
			'geneweaver' => $cleaned_geneweaver,
			'geneweaver_label' => $cleaned_geneweaver_label,
			'GWAS_N' => $cleaned_GWAS_N,
			'window_size' => $cleaned_window_size,
			'submitted_at' => date('Y-m-d H:i:s'),
			'status' => 'validating'
		];
       
        // ✅ CREATE BOTH FILES WITH CONSISTENT STATUS
        file_put_contents($jobBasePath . 'job_info.json', json_encode($jobData));
        updateJobStatus($jobBasePath, 'validating');  // ADD THIS LINE
        
		// STEP 1: Run DRY-RUN validation (Fail Fast)
        $dryRunCommand = sprintf(
            'bash %s --dry-run --job-dir %s --geneweaver-script %s --geneweaver-pgs-script %s 2>&1',
            escapeshellarg(ANALYSIS_SCRIPT),
            escapeshellarg($jobBasePath),
            escapeshellarg(GENEWEAVER_SCRIPT),
            escapeshellarg(GENEWEAVER_PGS_SCRIPT)
        );

        error_log("Dry-run command: " . $dryRunCommand); // Debug logging

		$dryRunOutput = shell_exec($dryRunCommand);
		$dryRunSuccess = (strpos($dryRunOutput, 'SUCCESS: All validations passed') !== false);

		if (!$dryRunSuccess) {
			// Clean up and show error immediately
			deleteDirectory($jobBasePath);
			
			// FILTER OUT TECHNICAL LOG MESSAGES - only show actual errors
			$cleanError = filterValidationOutput($dryRunOutput);
			
			echo '<div class="message error">';
			echo '<h3>❌ Validation Failed</h3>';
			echo '<p>Please check your input files:</p>';
			echo '<div style="background: white; padding: 10px; border-radius: 4px; font-family: monospace; white-space: pre-wrap;">';
			echo htmlspecialchars($cleanError);
			echo '</div>';
			//echo '<p><a href="https://test.consilience.bgalab.emory.edu/test_Geneweaver_upload.html">Try Again</a></p>';
			//echo '<p><a href="' . SITE_BASE_URL . '"/test_Geneweaver_upload.html">Try Again</a></p>';
			echo '<p><a href="../Geneweaver_upload.html">Try Again</a></p>';
			echo '</div>';
			exit;
		}


        
        // STEP 2: Validation passed - update status and start real job
        // ✅ UPDATE BOTH FILES TO 'running' STATUS
        $jobData['status'] = 'running';
        file_put_contents($jobBasePath . 'job_info.json', json_encode($jobData));
        updateJobStatus($jobBasePath, 'running');  // ADD THIS LINE
        
        // Start real analysis in background
        $realCommand = sprintf(
            'bash %s --job-dir %s --geneweaver-script %s --geneweaver-pgs-script %s > %s 2>&1 &',
            escapeshellarg(ANALYSIS_SCRIPT),
            escapeshellarg($jobBasePath),
            escapeshellarg(GENEWEAVER_SCRIPT),
            escapeshellarg(GENEWEAVER_PGS_SCRIPT),
            escapeshellarg($workingDir . 'analysis.log')
        );
        
        error_log("Real command: " . $realCommand); // Debug logging
        
        exec($realCommand);
        
        // Success message
        $displayJobNumber = str_replace('r_', '', $jobNumber);
        
		//echo '<div class="message success" style="background: #d4f4d4; color: #0d4526;">';
		echo '<div class="message success">';
		echo '<h3>✅ Job Submitted Successfully!</h3>';
		echo '<p><strong>Job Number:</strong> ' . htmlspecialchars($displayJobNumber) . '</p>';
		echo '<p><strong>Passcode:</strong> ' . htmlspecialchars($passcode) . '</p>';
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
}
?>
