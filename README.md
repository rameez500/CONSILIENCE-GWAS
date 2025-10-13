# CONSILIENCE-GWAS Web Platform

🌐 **Live Application**: [https://consilience.bgalab.emory.edu](https://consilience.bgalab.emory.edu)

A web-based platform for cross-species functional enrichment analysis and polygenic scoring that integrates human GWAS with model organism data.

## 🚀 Quick Access

No installation required! Use our web interface:

**Main Application**: [https://consilience.bgalab.emory.edu](https://consilience.bgalab.emory.edu)

## ✨ Features

- **Cross-Species Enrichment Analysis**: Integrate gene sets from model organisms with human GWAS
- **Tissue/Cell-Type Specificity**: Stratified LD Score Regression for functional annotations
- **Polygenic Score Calculation**: Gene-set specific PGS using PRS-CS
- **GeneWeaver Integration**: Direct API access to curated cross-species gene sets
- **Interactive Visualizations**: High-resolution enrichment plots and results display

## 🛠️ For Developers & Researchers

This repository contains the source code for the CONSILIENCE-GWAS web platform.

### Architecture Overview


**Key Components:**
- `frontend/`: User interface files
- `backend/php/`: PHP request handlers
- `backend/scripts/`: Shell script orchestrators
- `backend/r_scripts/`: R statistical analysis
- `python_scripts/`: Python data processing

### Core Analysis Pipeline

1. **User Input**: GWAS summary statistics + GeneWeaver gene sets
2. **Processing**: `process_Gen_update.php` orchestrates analysis
3. **Enrichment**: R scripts perform LDSC and statistical analysis
4. **PGS Calculation**: PRS-CS implementation for polygenic scores
5. **Visualization**: Interactive results display

### Key Scripts

- `cell_geneWea_PGS.sh` - Main pipeline for enrichment + PGS
- `cell_geneWea.sh` - Enrichment analysis only
- `GeneWeaver_pipeline.py` - Cross-species gene set processing
- `PGS_prscs.R` - Polygenic score calculation

## 📊 Example Usage

Visit the web application and:
1. Upload GWAS summary statistics
2. Select GeneWeaver gene sets or upload custom sets
3. Choose analysis type (enrichment, PGS, or both)
4. View interactive results and download reports

## 🐛 Support & Issues

Found a bug or have questions?
- 📧 **Email**: your-email@emory.edu
- 🐛 **GitHub Issues**: [Open an Issue](https://github.com/yourusername/consilience-gwas-web/issues)

## 📄 Citation

If you use CONSILIENCE-GWAS in your research, please cite:

> [Your publication reference here]

## 🔧 Server Requirements

- **Web Server**: Apache 2.4+
- **PHP**: 8.0+
- **R**: 4.0+ with key packages
- **Python**: 3.8+
- **Linux Environment**

## 📜 License

MIT License - see [LICENSE](LICENSE) for details.

