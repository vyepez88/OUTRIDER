#' 
#' Filter expression
#' 
#' To filter out non expressed genes this method uses the FPKM values to 
#' get a comparable value over genes. To calcute the FPKM values the user 
#' needs to provide a GTF file or the basepair parameter as described in 
#' \code{\link[DESeq2]{fpkm}}.
#' 
#' @rdname filterExpression
#' @param x An OutriderDataSet object
#' @param filterGenes If TRUE, the default, the object is subseted.
#' @param minCounts Filter for required read counts per gene
#' @param gtfFile A txDb object or a GTF/GFF file to be used as annotation
#' @param fpkmCutoff The threshold for filtering based on the FPKM value
#' @param savefpkm If TRUE the FPKM values are saved as assay
#' @param ... Additional arguments passed to \code{computeGeneLength}
#' @return An OutriderDataSet containing the \code{passedFilter} column, which
#'             indicates if the given gene passed the filtering threshold. If
#'             \code{filterGenes} is TRUE the object is already subsetted.
#' 
#' @examples 
#' ods <- makeExampleOutriderDataSet(dataset="GTExSkinSmall")
#' annotationFile <- system.file("extdata", 
#'     "gencode.v19.genes.small.gtf.gz", package="OUTRIDER")
#' ods <- filterExpression(ods, annotationFile, filterGenes=FALSE)
#' 
#' mcols(ods)['passedFilter']
#' fpkm(ods)[1:10,1:10]
#' dim(ods)
#' 
#' ods <- ods[mcols(ods)[['passedFilter']]]
#' dim(ods)
#' 
#' @export
setGeneric("filterExpression", 
        function(x, ...) standardGeneric("filterExpression"))

filterExpression.OUTRIDER <- function(x, gtfFile, fpkmCutoff=1, 
                    filterGenes=TRUE, savefpkm=FALSE, minCounts=FALSE, ...){
    x <- filterMinCounts(x, filterGenes=filterGenes)
    if(minCounts == TRUE){
        return(x)
    }
    if(!missing(gtfFile)){
        x <- computeGeneLength(x, gtfFile=gtfFile, ...)
    }
    filterExp(x, fpkmCutoff=fpkmCutoff, filterGenes=filterGenes, 
            savefpkm=savefpkm)
}

#' @rdname filterExpression
#' @export
setMethod("filterExpression", "OutriderDataSet", filterExpression.OUTRIDER)

filterExp <- function(ods, fpkmCutoff=1, filterGenes=filterGenes, 
                    savefpkm=savefpkm){
    fpkm <- fpkm(ods)
    if(savefpkm){
        assays(ods)[['fpkm']]<-fpkm
    }
    passed <- rowQuantiles(fpkm, probs=c(0.95)) > fpkmCutoff

    mcols(ods)['passedFilter'] <- passed
    validObject(ods)
    
    if(filterGenes==TRUE){
        ods <- ods[passed == TRUE]
    }
    message(paste0(sum(!passed), ifelse(filterGenes, 
            " genes are filtered out. ", " genes did not passed the filter. "), 
            "This is ", signif(sum(!passed)/length(passed)*100, 3), 
            "% of the genes."))
    return(ods)
}

#' 
#' Extracting the gene length from annotations
#' 
#' Computes the length for each gene based on the given GTF file or annotation.
#' Here the length of a gene is defind by the total number of bases covered
#' by exons.
#' 
#' @param ods An OutriderDataSet for which the gene length should be computed.
#' @param gtfFile Can be a GTF file or an txDb object with annotation.
#' @param format The format parameter from \code{makeTxDbFromGFF}
#' @param mapping If set, it is used to map gene names between the GFT and the
#'             ods object. This should be a 2 column data.frame: 
#'             1. column GTF names and 2. column ods names.
#' @param ... further arguments to \code{makeTxDbFromGFF}
#' 
#' @return An OutriderDataSet containing a \code{basepairs} column with the 
#'             calculated gene length. Accessable through 
#'             \code{mcols(ods)['baisepairs']}
#' 
#' @examples 
#' 
#' ods <- makeExampleOutriderDataSet(dataset="GTExSkinSmall")
#' annotationFile <- system.file("extdata", "gencode.v19.genes.small.gtf.gz",
#'         package="OUTRIDER")
#' ods <- computeGeneLength(ods, annotationFile)
#' 
#' mcols(ods)['basepairs']
#' fpkm(ods)[1:10,1:10]
#' 
#' @export
computeGeneLength <- function(ods, gtfFile, format='gtf', mapping=NULL, ...){
    checkOutriderDataSet(ods)
    
    if(!is(gtfFile, "TxDb")){
        #created txdb object
        txdb <- makeTxDbFromGFF(gtfFile, format=format, ...)
    } else {
        txdb <- gtfFile
    }
    
    # collect the exons per gene id
    exons_list_per_gene <- exonsBy(txdb,by="gene")
    
    # for each gene, reduce all the exons to a set of non overlapping exons,
    # calculate their lengths (widths) and sum then
    widths <- width(reduce(exons_list_per_gene))
    totalexonlength <- vapply(widths, sum, numeric(1))
    if(!is.null(mapping)){
        if(is.data.table(mapping)){
            mapping <- as.data.frame(mapping)
        }
        if(is.data.frame(mapping)){
            tmpmapping <- mapping[,2]
            names(tmpmapping) <- mapping[,1]
            mapping <- tmpmapping
        }
        names(totalexonlength) <- mapping[names(totalexonlength)]
    }
    mcols(ods)['basepairs'] <- totalexonlength[rownames(ods)]
    
    # checking for NAs in basepair annotation
    if(any(is.na(mcols(ods)['basepairs']))){
        missingNames <- rownames(ods)[is.na(mcols(ods)['basepairs'])]
        warning(paste0("Some genes (n=", length(missingNames), 
                ") are not found in the annotation. Setting 'basepairs' == 1. ",
                "The first 6 names are:\n", 
                paste(missingNames[seq_len(min(6, length(missingNames)))],
                        collapse=", ")))
        mcols(ods[is.na(mcols(ods)['basepairs'])[,1]])['basepairs'] <- 1
    }
    
    validObject(ods)
    return(ods)
}


#' 
#' Calculate FPM and FPKM values
#' 
#' This is the fpm and fpkm function from DESeq2. For more details see: 
#' \code{\link[DESeq2]{fpkm}} and \code{\link[DESeq2]{fpm}}
#' 
#' @name fpkm
#' @rdname fpkm
#' @aliases fpkm fpm
#' @seealso \code{\link[DESeq2]{fpkm}} \code{\link[DESeq2]{fpm}}
#' 
#' @inheritParams DESeq2::fpm
#' @inheritParams DESeq2::fpkm
#' 
#' @examples 
#' ods <- makeExampleOutriderDataSet()
#' mcols(ods)['basepairs'] <- round(rnorm(nrow(ods), 1000, 500))
#' 
#' mcols(ods)['basepairs']
#' fpkm(ods)[1:10,1:10]
#' fpm(ods)[1:10,1:10]
#' 
#' @export fpkm
#' @export fpm
NULL

#'
#' Filter zero counts
#' 
#' @noRd
filterMinCounts <- function(x, filterGenes=FALSE){
    passed <- !checkCountRequirements(x, test=TRUE)
    mcols(x)['passedFilter'] <- passed
    
    message(paste0(sum(!passed), " genes did not passed the filter due to ", 
            "zero counts. This is ", signif(sum(!passed)/length(passed)*100, 3),
            "% of the genes."))
    
    if(isTRUE(filterGenes)){
        x <- x[passed,]
    }
    return(x)
}
