/**
 * simple_upload.js
 * External JavaScript file for handling desktop gene set uploads (TEST VERSION)
 */

// Debug logging
console.log("simple_upload.js loaded successfully");

// Helper function to get element by ID
function _(el) {
    return document.getElementById(el);
}

// Get DOM elements
const geneFilesInput = _("gene_files");
const geneLabelsInput = _("gene_labels");
const sumstatInput = _("sumstat_right");
const gwasNInput = _("GWAS_N");
const windowSizeInput = _("window_size");
const targetBimInput = _("target_bim");
const uploadBtn = _("uploadBtn");
const messageDiv = _("message");

// Main form submission function
function submitForm() {
    console.log("submitForm() called"); // Debug
    
    // Get form values
    const geneFiles = geneFilesInput.files;
    const geneLabels = geneLabelsInput.value;
    const sumstat_right = sumstatInput.files[0];
    const GWAS_N = gwasNInput.value;
    const window_size = windowSizeInput.value;
    const target_bim = targetBimInput.files[0];

    console.log("Form values collected:");
    console.log("- Gene files:", geneFiles.length);
    console.log("- Gene labels:", geneLabels);
    console.log("- GWAS file:", sumstat_right ? sumstat_right.name : "none");
    console.log("- GWAS_N:", GWAS_N);
    console.log("- Window size:", window_size);

    // Basic validation
    if (!validateInputs(geneFiles, geneLabels, sumstat_right, GWAS_N, window_size)) {
        console.log("Validation failed");
        return false;
    }

    console.log("Validation passed");

    // Show loading message
    showLoadingMessage();

    // Create FormData
    const formData = new FormData();
    
    // Add gene files (multiple files)
    for (let i = 0; i < geneFiles.length; i++) {
        formData.append("gene_files[]", geneFiles[i]);
        console.log("Added gene file:", geneFiles[i].name);
    }
    
    // Add other form data
    formData.append("gene_labels", geneLabels);
    formData.append("sumstat_right", sumstat_right);
    formData.append("GWAS_N", GWAS_N);
    formData.append("window_size", window_size);
    
    // Add target_bim if provided
    if (target_bim) {
        formData.append("target_bim", target_bim);
        console.log("Added BIM file:", target_bim.name);
    }

    console.log("FormData created, submitting to PHP...");

    // Submit to PHP
    submitToPHP(formData);

    return false; // Prevent normal form submission
}

// Input validation function
function validateInputs(geneFiles, geneLabels, sumstat_right, GWAS_N, window_size) {
    console.log("Starting validation...");
    
    // Check required fields
    if (geneFiles.length === 0) {
        alert("Please upload at least one gene set file.");
        return false;
    }

    if (!geneLabels.trim()) {
        alert("Please enter gene set labels.");
        return false;
    }

    if (!sumstat_right) {
        alert("Please select a GWAS summary statistics file.");
        return false;
    }

    if (!GWAS_N.trim()) {
        alert("Please enter GWAS sample size.");
        return false;
    }

    if (!window_size.trim()) {
        alert("Please enter window size.");
        return false;
    }

    // Validate file extensions for gene files
    for (let i = 0; i < geneFiles.length; i++) {
        const fileName = geneFiles[i].name.toLowerCase();
        const validExtensions = ['.txt', '.csv', '.tsv'];
        const hasValidExtension = validExtensions.some(ext => fileName.endsWith(ext));
        
        if (!hasValidExtension) {
            alert("Gene set file '" + geneFiles[i].name + "' must be .txt, .csv, or .tsv format.");
            return false;
        }
    }

    // Validate GWAS file is .gz
    const gwasFileName = sumstat_right.name.toLowerCase();
    if (!gwasFileName.endsWith('.gz')) {
        alert("GWAS file must be a .gz compressed file.");
        return false;
    }

    // Validate GWAS sample size is numeric and greater than 0
    if (!/^\d+$/.test(GWAS_N)) {
        alert("Please enter only numeric values for the GWAS sample size. No letters, commas, or special characters allowed.");
        return false;
    } else if (parseInt(GWAS_N) < 1) {
        alert("Please enter a GWAS sample size greater than 0.");
        return false;
    }

    // Validate window size (same as shell script logic)
    if (!/^\d+$/.test(window_size)) {
        alert("Please enter only numeric values for the window size. No letters, commas, or special characters allowed.");
        return false;
    } else if (parseInt(window_size) < 100 || parseInt(window_size) > 100000) {
        alert("Please enter a value between 100 and 100,000 for the window size.");
        return false;
    }

    // Validate gene labels count matches number of files
    const geneLabelList = geneLabels.split(',').map(function(item) { return item.trim(); });
    const filteredLabels = geneLabelList.filter(function(item) { return item !== ''; });

    if (geneFiles.length !== filteredLabels.length) {
        alert("The number of gene set files (" + geneFiles.length + ") and gene set labels (" + filteredLabels.length + ") must match. Please correct the input.");
        return false;
    }

    // Limit number of files
    if (geneFiles.length > 10) {
        alert("Please upload a maximum of 10 gene set files.");
        return false;
    }

    console.log("All validations passed");
    return true;
}

// Show loading message
function showLoadingMessage() {
    console.log("Showing loading message");
    messageDiv.innerHTML = 
        '<div class="message loading">⏳ Submitting your job... Please wait.</div>';
    messageDiv.style.display = 'block';
}

// Submit form data to PHP
function submitToPHP(formData) {
    console.log("submitToPHP() called");
    
    const xhr = new XMLHttpRequest();
    const url = 'api/deskop_upload_process.php';
    console.log("Making AJAX request to:", url);
    
    xhr.open('POST', url, true);
    
    xhr.onload = function() {
        console.log("AJAX response received. Status:", this.status);
        console.log("Response text (first 500 chars):", this.responseText.substring(0, 500));
        
        if (this.status === 200) {
            console.log("Response success, updating container");
            messageDiv.innerHTML = this.responseText;
            messageDiv.style.display = 'block';
        } else {
            console.error("Server error:", this.status);
            showError("Server error: " + this.status);
        }
    };
    
    xhr.onerror = function() {
        console.error("AJAX network error occurred");
        showError("Network error. Please check your connection.");
    };
    
    xhr.ontimeout = function() {
        console.error("AJAX timeout");
        showError("Request timeout. Please try again.");
    };
    
    // Track upload progress
    xhr.upload.onprogress = function(e) {
        if (e.lengthComputable) {
            const percentComplete = Math.round((e.loaded / e.total) * 100);
            console.log("Upload progress: " + percentComplete + "%");
        }
    };
    
    // Log when request is sent
    xhr.onreadystatechange = function() {
        console.log("ReadyState:", xhr.readyState);
    };
    
    try {
        xhr.send(formData);
        console.log("AJAX request sent successfully");
    } catch (error) {
        console.error("Error sending AJAX request:", error);
        showError("Error submitting form: " + error.message);
    }
}

// Show error message
function showError(message) {
    console.error("Showing error:", message);
    messageDiv.innerHTML = 
        '<div class="message error">❌ ' + message + '</div>';
    messageDiv.style.display = 'block';
}

// Display uploaded file information
function displayFileInfo() {
    const geneFiles = geneFilesInput.files;
    let fileInfo = document.getElementById('fileInfo');
    
    if (!fileInfo) {
        fileInfo = document.createElement('div');
        fileInfo.id = 'fileInfo';
        fileInfo.className = 'file-upload-info';
        geneFilesInput.parentNode.appendChild(fileInfo);
    }
    
    if (geneFiles.length > 0) {
        let html = '<strong>Selected files (' + geneFiles.length + '):</strong><ul style="margin: 10px 0 0 20px;">';
        for (let i = 0; i < geneFiles.length; i++) {
            html += '<li>' + geneFiles[i].name + ' (' + (geneFiles[i].size / 1024).toFixed(1) + ' KB)</li>';
        }
        html += '</ul>';
        fileInfo.innerHTML = html;
    } else {
        fileInfo.innerHTML = '<em>No files selected</em>';
    }
}

// Test function to check if everything works
function testFormSubmission() {
    console.log("=== TESTING FORM SUBMISSION ===");
    
    // Simulate form data
    const testFormData = new FormData();
    testFormData.append('test', 'test_value');
    
    const xhr = new XMLHttpRequest();
    xhr.open('POST', 'api/deskop_upload_process.php', true);
    
    xhr.onload = function() {
        console.log("Test response:", this.responseText.substring(0, 200));
    };
    
    xhr.send(testFormData);
}

// Initialize when page loads
window.addEventListener('DOMContentLoaded', function() {
    console.log("DOM fully loaded");
    
    // Setup event listeners
    if (geneFilesInput) {
        geneFilesInput.addEventListener('change', displayFileInfo);
    }
    
    if (uploadBtn) {
        uploadBtn.addEventListener('click', function(event) {
            event.preventDefault();
            console.log("Upload button clicked directly");
            submitForm();
        });
    }
    
    // Test if we can get form elements
    try {
        console.log("gene_files element found:", geneFilesInput !== null);
        console.log("uploadBtn element found:", uploadBtn !== null);
    } catch(e) {
        console.error("Error accessing form elements:", e);
    }
});

// Initialize file info display on window load
window.onload = function() {
    console.log("Window fully loaded");
    
    // Also add form submit handler
    const form = document.getElementById('uploadForm');
    if (form) {
        form.addEventListener('submit', function(event) {
            console.log("Form submit event triggered");
            event.preventDefault();
            event.stopPropagation();
            return false;
        });
    }
    
    // Run test
    testFormSubmission();
};
