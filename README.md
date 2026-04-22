
# CONSILIENCE-GWAS

**Web-based Parsed Heritability & Polygenic Score Analysis Using Heterogeneous Functional Genomics Data**

This is the server-side repository for CONSILIENCE-GWAS, an online web application to perform partitioned heritability enrichment analysis and polygenic score (PGS) derivation using heterogeneous functional genomics data. The application is available at [https://consilience.bgalab.emory.edu/](https://consilience.bgalab.emory.edu/).

## Features

- **Tissue/Cell-Specific Enrichment**: Investigate partitioned heritability across diverse functional categories
- **Cross-Species Analysis**: Integrate gene sets from model organisms (mouse, rat) with human GWAS data
- **Polygenic Score Calculation**: Compute PGS using PRS-CS with optional target BIM file upload
- **Multiple Input Options**: Support for GeneWeaver IDs or custom gene set files
- **Comprehensive Visualization**: Manhattan plots, enrichment plots, and interactive result browsing
- **Cell-Type Group Analysis**: Pre-configured analyses for CNS, Cardiovascular, Liver, Immune, and other cell types
- **External Data Integration**: GTEx, Cahoy (mouse brain), ImmGen (immune cells), and Roadmap Epigenomics

## Citation

When using CONSILIENCE-GWAS, please cite the following:

> Syed R, Benca-Bachman CE, Huggett SB, McGeary JE, Bubier JA, Fisher H, Berger A, Baker E, Chesler EJ, Lind PA, Palmer RHC. CONSILIENCE-GWAS: A Web Resource for Parsed Heritability & Polygenic Score Analysis of Human GWAS Using Heterogeneous Functional Genomics Data. *medRxiv*. 2025. doi: [10.1101/2025.10.24.25338727](https://www.medrxiv.org/content/10.1101/2025.10.24.25338727v1)

## Input Format

### GWAS Summary Statistics
File must be compressed as `.gz` with exactly 8 tab-separated columns:

| Column | Description | Example |
|--------|-------------|---------|
| SNP_ID | Variant identifier (rs number) | rs11130222 |
| CHR | Chromosome number (1-22) | 3 |
| POS | Genomic position | 49901060 |
| A1 | Effect allele | A |
| A2 | Other allele | T |
| Beta | Effect size | 0.026 |
| SE | Standard error | 0.003 |
| Pval | P-value | 4.581e-25 |

### Gene Set Files
Plain text file (`.txt`) with one Ensembl ID per line:

ENSMUSG00000026842
ENSMUSG00000026003
ENSMUSG00000029545



## Technology Stack

- **Backend**: PHP 7.4+ with custom framework
- **Analysis Pipeline**: Bash scripts orchestrating Python and R modules
- **LD Score Regression**: LDSC (Bulik-Sullivan et al. 2015)
- **Polygenic Scoring**: PRS-CS
- **Statistical Computing**: R (various packages), Python (NumPy, Pandas)
- **Conda Environments**: Isolated environments for R, Python, and LDSC

## Repository Structure

```
consilience-gwas/
├── web/                    # Frontend HTML/CSS/JS
├── api/                    # PHP endpoints for job submission
├── scripts/                # Analysis scripts
│   ├── analysis/           # Bash orchestrators
│   ├── python/             # Python modules
│   ├── r/                  # R scripts
│   └── ldsc/               # LDSC integration
├── config/                 # Configuration templates
└── data/                   # Reference data (download separately)
```




## License




