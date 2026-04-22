/**
 * Geneweaver_upload.js
 * External JavaScript file for handling file uploads
 */

// Helper function to get element by ID
function _(el) {
    return document.getElementById(el);
}

// Main form submission function
function submitForm() {
    // Get form values - matching PHP variable names
    var geneweaver = _("geneweaver").value;
    var geneweaver_label = _("geneweaver_label").value;
    var sumstat_right = _("sumstat_right").files[0];  // This matches PHP $_FILES['sumstat_right']
    var GWAS_N = _("GWAS_N").value;
    var window_size = _("window_size").value;
    var target_bim = _("target_bim").files[0];  // This matches PHP $_FILES['target_bim']

    // Basic validation
    if (!validateInputs(geneweaver, geneweaver_label, sumstat_right, GWAS_N, window_size)) {
        return false;
    }

    // Show loading message
    showLoadingMessage();

    // Create FormData - names must match PHP expected names
    var formData = new FormData();
    formData.append("geneweaver", geneweaver);
    formData.append("geneweaver_label", geneweaver_label);
    formData.append("sumstat_right", sumstat_right);  // Matches $_FILES['sumstat_right']
    formData.append("GWAS_N", GWAS_N);
    formData.append("window_size", window_size);
    
    // Add target_bim if provided
    if (target_bim) {
        formData.append("target_bim", target_bim);  // Matches $_FILES['target_bim']
    }

    // Submit to PHP
    submitToPHP(formData);

    return false; // Prevent normal form submission
}

// Input validation function
function validateInputs(geneweaver, geneweaver_label, sumstat_right, GWAS_N, window_size) {
    // Check required fields
    if (!geneweaver.trim()) {
        alert("Please enter GeneWeaver IDs.");
        return false;
    }

    if (!geneweaver_label.trim()) {
        alert("Please enter GeneWeaver labels.");
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

    // Validate GeneWeaver IDs and labels count match
    var geneweaver_list = geneweaver.split(',').map(function(item) { return item.trim(); });
    var geneweaverLabelList = geneweaver_label.split(',').map(function(item) { return item.trim(); });
    
    // Remove empty strings from arrays
    geneweaver_list = geneweaver_list.filter(function(item) { return item !== ''; });
    geneweaverLabelList = geneweaverLabelList.filter(function(item) { return item !== ''; });
    
    console.log("GeneWeaver list:", geneweaver_list);
    console.log("GeneWeaver label list:", geneweaverLabelList);

    if (geneweaver_list.length < 1) {
        alert("Please include at least one GeneSet ID.");
        return false;
    }
    
    if (geneweaver_list.length !== geneweaverLabelList.length) {
        alert("The number of GeneWeaver IDs and GeneWeaver labels must match. Please correct the input.");
        return false;
    }

    return true;
}

// Show loading message
function showLoadingMessage() {
    _("responseContainer").innerHTML = 
        '<div class="message loading">⏳ Submitting your job... Please wait.</div>';
}

// Submit form data to PHP
function submitToPHP(formData) {
    var xhr = new XMLHttpRequest();
    xhr.open('POST', 'api/submit_work_from_web.php', true);
    
    xhr.onload = function() {
        if (this.status === 200) {
            _("responseContainer").innerHTML = this.responseText;
        } else {
            showError("Server error: " + this.status);
        }
    };
    
    xhr.onerror = function() {
        showError("Network error. Please check your connection.");
    };
    
    xhr.ontimeout = function() {
        showError("Request timeout. Please try again.");
    };
    
    xhr.send(formData);
}

// Show error message
function showError(message) {
    _("responseContainer").innerHTML = 
        '<div class="message" style="background: #f8d7da; border: 1px solid #f5c6cb;">❌ ' + message + '</div>';
}

// Optional: Progress handler for file upload
function setupProgressHandler() {
    var xhr = new XMLHttpRequest();
    
    xhr.upload.addEventListener("progress", function(e) {
        if (e.lengthComputable) {
            var percent = (e.loaded / e.total) * 100;
            _("responseContainer").innerHTML = 
                '<div class="message loading">📤 Uploading: ' + Math.round(percent) + '%</div>';
        }
    }, false);
    
    return xhr;
}
