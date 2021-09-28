#!/bin/bash

# Specify parameters:
usage() { echo -e "
+-------------------------------------------------------+
|                   ATAC-seq Analysis                   |
|          Fastq -> bigwigs for ATAC-seq data           |
|       Modified from Ravza's bulk ATAC analysis        |
|              Emily Georgiades, Sep 2021               |
+-------------------------------------------------------+
Notes: sample name should be consistent with fastq naming.\n
Use following flags:" && grep " .)\ #" $0; exit 0; }
[ $# -eq 0 ] && usage
while getopts ":f:d:r:g:n:p:" arg; do
  case $arg in
    f) # Specify sample name (e.g. clone_celltype_condition_rep).
	SAMPLE=${OPTARG};;
    d) # Specify directory containing gun-zipped fastqs.
       DATA=${OPTARG};;
    g) # Specify genome build (mm39, mm39-R2 or hg38).
	GENOME=${OPTARG};;
    n) # Specify bowtie2 prefix (i.e. xxx.1.bt2)
	BT2PREFIX=${OPTARG};;
    p) # Give path to public directory where bigwigs will be saved (not including /datashare/).
	public_dir=${OPTARG};;
    h) # Display help.
      usage
      exit 0
      ;;
  esac
done

start="$(date)"

# Print all output to log file:
exec > >(tee "$PWD/output-${SAMPLE}.log") 2>&1

echo ""
echo "+--------------------------------------------------------------+"
echo "|                        ATAC-seq Analysis                     |"
echo "|                 Run started:  "$start"                       |"
echo "+--------------------------------------------------------------+"
echo ""

echo "This script is for ATAC-seq data analysis including performing alignment with bowtie2, conversion files to another format and bam coverage"
echo ""
echo "You are in" $PWD
echo ""
echo "The reference genome to be used for bowtie2 is $GENOME"

# Determine which bt2 directory to use:
if [ $GENOME == "mm39" ]; then
   BT2DIR="/stopgap/databank/igenomes/Mus_musculus/UCSC/mm39/Sequence/Bowtie2Index"
elif [ $GENOME == "mm39-R2" ]; then 
   BT2DIR="/stopgap/fgenomics/egeorgia/custom-genome/Bowtie2Index"
elif [ $GENOME == "hg38" ]; then
   BT2DIR="/stopgap/databank/igenomes/Homo_sapiens/UCSC/hg38/Sequence/Bowtie2Index"
else
  echo "Incorrect genome entered, choose either mm39, mm39-R2 or hg38."
fi
echo ""

echo "--------------------Analysis is processing----------------------------"
echo ""
echo ""
echo "Necessary tools has been loading..."
module load bowtie2 samtools deeptools
echo ""

# Step 1: Align single ot paired end reads using Bowtie2
echo "Performing bowtie2 ..."
if ! bowtie2 -q -N 1 -X 2000 -p 8 -x ${BT2DIR}/${BT2PREFIX} -1 ${DATA}/${SAMPLE}_R1.fastq.gz -2 ${DATA}/${SAMPLE}_R2.fastq.gz -S ${SAMPLE}.sam ; then
    echo "Bowtie returned an error"
    exit 1
fi

# Step 2: Sam to Bam conversion
echo ""
echo "Converting the SAM file to a BAM file ..."
if ! samtools view -b -o ${SAMPLE}.bam ${SAMPLE}.sam ; then
    echo Samtools returned a view error
    exit 1
fi

# Some intermediate QC steps...
echo ""
echo "QC#1: How many alignments are there in this region?: "
samtools view ${SAMPLE}.bam | wc -l
echo ""
echo "QC#2: Counting the number of reads which are paired and mapped in proper pair: "
samtools view -c -f 3 ${SAMPLE}.bam
echo ""
echo "QC#3: Filtering the number of reads which are paired and mapped in proper pair: "
if ! samtools view -b -h -f 3 ${SAMPLE}.bam > ${SAMPLE}_properpairs.bam ; then
    echo Samtools returned an error
    exit 1
fi
echo ""
echo "QC#4: Reads with mapping quality less than 30 are removed"
if ! samtools view -bShuF 4 -f 2 -q 30 ${SAMPLE}_properpairs.bam > ${SAMPLE}_properpairs_q30.bam ; then
    echo "samtools filtering returned an error"
    exit 1
    fi

# Step 3: sort bamfile by genomic coordinate
echo ""
echo "Sorting the bam file ..."
if ! samtools sort -o ${SAMPLE}_properpairs_q30_sorted.bam ${SAMPLE}_properpairs_q30.bam ; then
    echo Samtools returned a sorting error
    exit 1
fi

# Step 4: remove duplicates
echo ""
echo "Remove potential PCR duplicates: if multiple read pairs have identical external coordinates, only retain the pair with highest mapping quality."
if ! samtools rmdup ${SAMPLE}_properpairs_q30_sorted.bam ${SAMPLE}_properpairs_q30_sorted_rmdup.bam ; then
    echo samtools rmdup returned an error
    exit 1
fi

# Step 5: index bam
echo ""
echo "Indexing the bam file ..."
if ! samtools index ${SAMPLE}_properpairs_q30_sorted_rmdup.bam ; then
    echo Samtools returned an index error
    exit 1
fi

# Calculating summary statistics...
echo ""
echo "Calculating and printing statistics to stdout ..."
samtools flagstat ${SAMPLE}_properpairs_q30_sorted_rmdup.bam > ${SAMPLE}.properpairs.rmdup.flagstat.txt

echo ""
echo "Continuing with sorted and indexed bam file i.e. alignment_sorted_mapped.bam"


# echo ""
# echo "Deleting intermediate files..."
# rm -rf ${SAMPLE}.sam ${OUTPUT_PREFIX}_properpairs.bam ${OUTPUT_PREFIX}_properpairs_q30.bam ${OUTPUT_PREFIX}_properpairs_q30_sorted.bam

# Creating a bigwig using DeepTools
echo "Creating bigwig"
bamCoverage -b ${SAMPLE}_properpairs_q30_sorted_rmdup.bam -o ${SAMPLE}.bw -bs 1 --extendReads

# Copying bigwigs to datashare folder to view on ucsc genome browser
cp ${SAMPLE}.bw /datashare/${public_dir}
echo ""
echo "Copy + paste link into UCSC genome browser:"
echo "bigDataUrl=http://sara.molbiol.ox.ac.uk/public/${public_dir}/${SAMPLE}.bw"
echo ""

end="$(date)"
echo ""
echo "Run complete:" "$end"