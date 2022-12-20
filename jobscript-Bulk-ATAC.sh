#!/bin/bash
#SBATCH --partition=batch
#SBATCH --job-name=ATAC
#SBATCH --ntasks=1
#SBATCH --mem=20G
#SBATCH --output=%j_%x.out
#SBATCH --error=%j_%x.err
#SBATCH --mail-user=email@address
#SBATCH --mail-type=end,fail


cd <path-to-wd>
bash ./BulkATAC-analysis-pipeline.sh -f sample_name -d ../fastqs -g genome_build -n mm39-AL2R2chrX -p public_directory

