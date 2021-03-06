#! /usr/bin/env nextflow

//vim: syntax=groovy -*- mode: groovy;-*-

// Copyright (C) 2022 IRB Barcelona

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.


log.info ""
log.info "-------------------------------------------------------------------------"
log.info "  SimulateLowCovSeq: nextflow pipeline to simulate low coverage seq data "
log.info "          and run a calling with strelka2, based on existing BAM files   "
log.info "-------------------------------------------------------------------------"
log.info "Copyright (C) IRB Barcelona"
log.info "This program comes with ABSOLUTELY NO WARRANTY; for details see LICENSE"
log.info "This is free software, and you are welcome to redistribute it"
log.info "under certain conditions; see LICENSE for details."
log.info "-------------------------------------------------------------------------"
log.info ""

params.help = null

if (params.help) {
    log.info ''
    log.info '--------------------------------------------------'
    log.info '  USAGE              '
    log.info '--------------------------------------------------'
    log.info ''
    log.info 'Usage: '
    log.info 'nextflow run main.nf --input_file list_SV_SNV.txt --distance 1'
    log.info ''
    log.info 'Mandatory arguments:'
    log.info '    --input_file                   FOLDER         Input file containing 2 columns: cluster (e.g. path to SV VCF) and target (e.g. SNV VCF).'
    log.info '    --cluster_type                 STRING         Type of variant to make the clusters (SV or indels).'
    log.info ''
    log.info 'Optional arguments:'
    log.info '    --distance                     INTEGER        Distance to consider a cluster (default = 2Kb).'
    log.info '    --output_folder                FOLDER         Output folder (default: cluster_sig_output).'
    log.info 'Flags:'
    log.info '    --help                                        Display this message'
    log.info ''
    exit 0
}

params.input_file = null
params.cluster_type = null
params.distance = 2
params.output_folder = "cluster_sig_output"

pairs_list = Channel.fromPath( params.input_file ).splitCsv(header: true, sep: '\t', strip: true)
                   .map{ row -> [ row.sample, file(row.cluster), file(row.target) ] }.view()


process compute_bed_clusters {

       publishDir params.output_folder+"/BED/", mode: 'copy', pattern: '*merged.bed'

       tag {sample}

       input:
       set val(sample), file(cluster), file(target) from pairs_list

       output:
       set val(sample), file(cluster), file(target), file("*merged.bed") into clu_tar_bed

       shell:
       '''
       bcftools view -f 'PASS' !{cluster} -Oz > cluster_pass.vcf.gz
       if [[ !{params.cluster_type} == "SV" ]] ; then 
        echo "We consider a VCF of clusters from Manta SV calling"
        Rscript  !{baseDir}/bin/vcf_to_bed.R --VCF=cluster_pass.vcf.gz --caller=manta --output_bed=cluster.bed
       fi
       cat cluster.bed | sort -k1,1 -k2,2n | bedtools merge -i stdin | awk '{print $1"\t"$2"\t"$3}' > !{sample}_cluster_merged.bed
       '''
  }

process compute_extract_targets {

       publishDir params.output_folder+"/VCF/", mode: 'move', pattern: '*_cluster_*.vcf.gz'
       publishDir params.output_folder+"/VCF/", mode: 'move', pattern: '*_uncluster_*.vcf.gz'

       tag {sample}

       input:
       set val(sample), file(cluster), file(target), file(bed) from clu_tar_bed

       output:
       file("*_cluster_*.vcf.gz") into clus
       file("*_uncluster_*.vcf.gz") into unclus

       shell:
       '''
       tabix -p vcf !{target}
       bcftools view -f PASS --regions-file !{bed} !{target} -Oz > !{sample}_cluster_PASS_mutations.vcf.gz # variants overlapping the bed file
       bedtools intersect -v -a !{target} -b !{bed} -wa > tmp
       bcftools view -h !{target} > header
       cat header tmp | bgzip -c | bcftools view -f PASS -Oz > !{sample}_uncluster_PASS_mutations.vcf.gz # variants non-overlapping the bed file
       '''
  }
