## Rscript to compute BED file from VCF file (SV with manta or indels) ##

args <- commandArgs(TRUE)
parseArgs <- function(x) {
  res = strsplit(sub("^--", "", x), "=")
  if(length(unlist(res))==1) res[[1]][2]=""
  return(res)
}

argsL <- as.list(do.call("cbind", parseArgs(args))[c(F,T)])
names(argsL) <- as.list(do.call("cbind", parseArgs(args))[c(T,F)])
args <- argsL;rm(argsL)

if(! is.null(args$help)) {
  cat("
      Mandatory arguments:
      --VCF                        - Input VCF to compute the BED file
      --caller                     - Manta or indel caller
      --output_bed                 - Output bed file
      
      --help \n\n")
  q(save="no")
}


if(is.null(args$VCF)) {stop("Option --VCF should be provided")} else{VCF=args$VCF}
if(is.null(args$caller)) {stop("Option --caller should be provided")} else{caller=args$caller}
if(is.null(args$output_bed)) {stop("Option --output_bed should be provided")} else{output_bed=args$output_bed}

sv_len = as.numeric(system(paste("bcftools query -f '%SVLEN\n' ", VCF, sep=""), intern = T))
sv_len[which(is.na(sv_len))] = 1
sv_chr = system(paste("bcftools query -f '%CHROM\n' ", VCF, sep=""), intern = T)
sv_pos = as.numeric(system(paste("bcftools query -f '%POS\n' ", VCF, sep=""), intern = T))

dat = data.frame(CHR = sv_chr, START = sv_pos - abs(sv_len), END = sv_pos + abs(sv_len))
dat[which(dat$START < 0), "START"] = 1
dat = dat[which(sv_len < 10000), ] # do not consider very very large events for now

write.table(dat, file=output_bed, quote = FALSE, col.names = FALSE, row.names = FALSE, sep = "\t")
