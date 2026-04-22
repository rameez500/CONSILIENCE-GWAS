import argparse
import sys
import gwaslab as gl
#sys.path.insert(0,"/apps/www/project/ldsc/tool/gwaslab")

# Set up argument parser
parser = argparse.ArgumentParser(description="Run the data pipeline.")
parser.add_argument('--sum_file', type=str, required=True, help='Path to the sum file.')
parser.add_argument('--N', type=str, required=True, help='Path to the sum file.')
parser.add_argument('--file_png', type=str, help='Additional argument 1.')
parser.add_argument('--filegene', type=str, help='Additional argument 2.')
args = parser.parse_args()


mysumstats = gl.Sumstats(args.sum_file,
             snpid="SNP_ID",
             chrom="CHR",
             pos="POS",
             ea="A1",
             nea="A2",
             beta="Beta",
             se="SE",
             p="Pval",
             n=float(args.N),
             sep="\t")


#mysumstats.plot_mqq(skip=2, cut=20, mode="m", anno=True, sig_level_lead=5e-8,save=args.file_png, saveargs={"dpi":400,"facecolor":"white"})
mysumstats.plot_mqq(skip=2, cut=20, sig_level_lead=5e-8,save=args.file_png, saveargs={"dpi":400,"facecolor":"white"})

mysumstats.basic_check()
# mysumstats.data
# mysumstats.get_lead(anno=True,sig_level=1e-08,build="19")
mysumstats.plot_mqq(mode="mqq",
                    cut=20,
                    skip=2,
		            build="19",
                    anno="GENENAME",
                    sig_level_lead=5e-8,
		            sig_level=5e-8,
                    marker_size=(5,5),
                    figargs={"figsize":(15,5),"dpi":300},
                    save=args.filegene, 
                    saveargs={"dpi":400,"facecolor":"white"})

###
