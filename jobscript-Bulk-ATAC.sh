#!/bin/bash
#SBATCH --partition=batch
#SBATCH --job-name=ATAC
#SBATCH --ntasks=1
#SBATCH --mem=20G
#SBATCH --output=%j_%x.out
#SBATCH --error=%j_%x.err
#SBATCH --mail-user=emily.georgiades@imm.ox.ac.uk
#SBATCH --mail-type=end,fail


cd /t1-data/project/fgenomics/egeorgia/Data/Caz-artificial-locus/ATAC/WT-E14/analysis/

bash ./BulkATAC-analysis-pipeline.sh -f sample_name -d ../fastqs -g genome_build -n mm39-AL2R2chrX -p public_directory

