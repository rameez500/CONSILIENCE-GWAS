
# CONSILIENCE-GWAS

**Web-based Parsed Heritability & Polygenic Score Analysis Using Heterogeneous Functional Genomics Data**

This is the server-side repository for CONSILIENCE-GWAS, an online web application to perform partitioned heritability enrichment analysis and polygenic score (PGS) derivation using heterogeneous functional genomics data. The application is available at [https://consilience.bgalab.emory.edu/](https://consilience.bgalab.emory.edu/).

## Version Information

| Component | Version |
|-----------|---------|
| **CONSILIENCE-GWAS** | v1.0 |
| **Apache** | 2.4.58 |
| **PHP** | 8.3.6 |
| **Ubuntu** | 22.04+ |

## Technology Stack

![Apache](https://img.shields.io/badge/Apache-2.4.58-D22128?logo=apache&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-8.3.6-777BB4?logo=php&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-E95420?logo=ubuntu&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-5.1-4EAA25?logo=gnubash&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.9+-3776AB?logo=python&logoColor=white)
![R](https://img.shields.io/badge/R-4.2+-276DC3?logo=r&logoColor=white)


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

ENSMUSG00000026842 \
ENSMUSG00000026003 \
ENSMUSG00000029545 \


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




