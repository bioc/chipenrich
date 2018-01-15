#' Running Hybrid test, either from scratch or using two results files
#'
#' Hybrid test is designed for people unsure of which test between ChIP-Enrich
#' and Poly-Enrich to use, so it takes information of both and gives adjusted
#' P-values. For more about ChIP- and Poly-Enrich, consult their corresponding
#' documentation.
#'
#' @section Hybrid p-values:
#' Given n tests that test for the same hypothesis, same Type I error rate, and
#' converted to p-values: \code{p_1, ..., p_n}, the Hybrid p-value is computed as:
#' \code{n*min(p_1, ..., p_n)}. This hybrid test will have at most the same
#' Type I error as any individual test, and if any of the tests have 100% power as
#' sample size goes to infinity, then so will the hybrid test.
#'
#' @section Function inputs:
#' Every input in hybridenrich is the same as in chipenrich and polyenrich. Inputs
#' unique to chipenrich are: num_peak_threshold; and inputs unique to polyenrich are:
#' weighting. Currently the test only supports running chipenrich and polyenrich, but
#' future plans will allow you to run any number of different support tests.
#'
#' @param peaks Either a file path or a \code{data.frame} of peaks in BED-like
#' format. If a file path, the following formats are fully supported via their
#' file extensions: .bed, .broadPeak, .narrowPeak, .gff3, .gff2, .gff, and .bedGraph
#' or .bdg. BED3 through BED6 files are supported under the .bed extension. Files
#' without these extensions are supported under the conditions that the first 3
#' columns correspond to 'chr', 'start', and 'end' and that there is either no
#' header column, or it is commented out. If a \code{data.frame} A BEDX+Y style
#' \code{data.frame}. See \code{GenomicRanges::makeGRangesFromDataFrame} for
#' acceptable column names.
#' @param out_name Prefix string to use for naming output files. This should not
#' contain any characters that would be illegal for the system being used (Unix,
#' Windows, etc.) The default value is "chipenrich", and a file "chipenrich_results.tab"
#' is produced. If \code{qc_plots} is set, then a file "chipenrich_qcplots.pdf"
#' is produced containing a number of quality control plots. If \code{out_name}
#' is set to NULL, no files are written, and results then must be retrieved from
#' the list returned by \code{chipenrich}.
#' @param out_path Directory to which results files will be written out. Defaults
#' to the current working directory as returned by \code{\link{getwd}}.
#' @param genome One of the \code{supported_genomes()}.
#' @param genesets A character vector of geneset databases to be tested for
#' enrichment. See \code{supported_genesets()}. Alternately, a file path to a
#' a tab-delimited text file with header and first column being the geneset ID
#' or name, and the second column being Entrez Gene IDs. For an example custom
#' gene set file, see the vignette.
#' @param locusdef One of: 'nearest_tss', 'nearest_gene', 'exon', 'intron', '1kb',
#' '1kb_outside', '1kb_outside_upstream', '5kb', '5kb_outside', '5kb_outside_upstream',
#' '10kb', '10kb_outside', '10kb_outside_upstream'. For a description of each,
#' see the vignette or \code{\link{supported_locusdefs}}. Alternately, a file path for
#' a custom locus definition. NOTE: Must be for a \code{supported_genome()}, and
#' must have columns 'chr', 'start', 'end', and 'gene_id' or 'geneid'. For an
#' example custom locus definition file, see the vignette.
#' @param methods A character string array specifying the method to use for enrichment
#' testing. Currently actually unused as the methods are forced to be one chipenrich
#' and one polyenrich.
#' @param weighting A character string specifying the weighting method. Method name will
#' automatically be "polyenrich_weighted" if given weight options. Current options are:
#' 'signalValue', 'logsignalValue', and 'multiAssign'.
#' @param mappability One of \code{NULL}, a file path to a custom mappability file,
#' or an \code{integer} for a valid read length given by \code{supported_read_lengths}.
#' If a file, it should contain a header with two column named 'gene_id' and 'mappa'.
#' Gene IDs should be Entrez IDs, and mappability values should range from 0 and 1.
#' For an example custom mappability file, see the vignette. Default value is NULL.
#' @param qc_plots A logical variable that enables the automatic generation of
#' plots for quality control.
#' @param min_geneset_size Sets the minimum number of genes a gene set may have
#' to be considered for enrichment testing.
#' @param max_geneset_size Sets the maximum number of genes a gene set may have
#' to be considered for enrichment testing.
#' @param num_peak_threshold Sets the threshold for how many peaks a gene must
#' have to be considered as having a peak. Defaults to 1. Only relevant for
#' Fisher's exact test and ChIP-Enrich methods.
#' @param randomization One of \code{NULL}, 'complete', 'bylength', or 'bylocation'.
#' See the Randomizations section below.
#' @param n_cores The number of cores to use for enrichment testing. We recommend
#' using only up to the maximum number of \emph{physical} cores present, as
#' virtual cores do not significantly decrease runtime. Default number of cores
#' is set to 1. NOTE: Windows does not support multicore enrichment.
#'
#' @section Joining two results files:
#' Combines two existing results files and returns one results file with hybrid
#' p-values and FDR included. Current allowed inputs are objects from any of
#' the supplied enrichment tests or a dataframe with at least the following columns:
#' \code{P.value, Geneset.ID}. Optional columns include: \code{Status}. Currently
#' we only allow for joining two results files, but future plans will allow you to join
#' any number of results files.
#'
#' @return A data.frame containing:
#' \item{results }{
#' A data frame of the results from performing the gene set enrichment test on
#' each geneset that was requested (all genesets are merged into one final data
#' frame.) The columns are:
#'
#' \describe{
#'   \item{Geneset.ID}{ is the identifier for a given gene set from the selected database.  For example, GO:0000003. }
#'   \item{P.Value.x}{ is the probability of observing the degree of enrichment of the gene set given the null hypothesis
#'                     that peaks are not associated with any gene sets, for the first test..}
#'   \item{P.Value.y}{ is the same as above except for the second test.}
#'   \item{P.Value.Hybrid}{ The calculated Hybrid p-value from the two tests}
#'   \item{FDR.Hybrid}{ is the false discovery rate proposed by Bejamini \& Hochberg for adjusting the p-value to control for family-wise error rate.}
#'
#' }}
#'
#' @export
#' @include chipenrich.R polyenrich.R

hybridenrich <- function(	peaks,
						out_name = "hybridenrich",
						out_path = getwd(),
						genome = supported_genomes(),
						genesets = c(
							'GOBP',
							'GOCC',
							'GOMF'),
						locusdef = "nearest_tss",
						methods = c('chipenrich','polyenrich'),
						weighting = NULL,
						mappability = NULL,
						qc_plots = TRUE,
						min_geneset_size = 15,
						max_geneset_size = 2000,
						num_peak_threshold = 1,
						randomization = NULL,
						n_cores = 1
) {
    if (!is.null(out_name)) {
        out_chip = sprintf("%s_chip",out_name)
        out_poly = sprintf("%s_poly",out_name)
    } else {
        out_chip = NULL
        out_poly = NULL
    }
    
    #Check if methods number isn't 2. Will support more than 2 later.
    #Also not really relevant as you're forced to use chip and poly anyway.
    if (length(methods) != 2) {
        stop("Hybrid test currently only supports exactly two methods!")
    }
    
	results1 = chipenrich(
        peaks = peaks,
        out_name = out_chip,
        out_path = out_path,
        genome = genome,
        genesets = genesets,
        locusdef = locusdef,
        method = "chipenrich",
        mappability = mappability,
        qc_plots = qc_plots,
        min_geneset_size = min_geneset_size,
        max_geneset_size = max_geneset_size,
        num_peak_threshold = num_peak_threshold,
        randomization = randomization,
        n_cores = n_cores)
        
        
    if (is.null(weighting)) {
        polymeth = "polyenrich"
    } else {
        polymeth = "polyenrich_weighted"
    }
    results2 = polyenrich(
        peaks = peaks,
        out_name = out_poly,
        out_path = out_path,
        genome = genome,
        genesets = genesets,
        locusdef = locusdef,
        method = polymeth,
        weighting = weighting,
        mappability = mappability,
        qc_plots = qc_plots,
        min_geneset_size = min_geneset_size,
        max_geneset_size = max_geneset_size,
        randomization = randomization,
        n_cores = n_cores)
        
    hybrid = hybrid.join(results1,results2)
    
    return(hybrid)
}



#User gives results objects (object or just results), and appends hybrid results
hybrid.join <- function(test1, test2) {
	#Check if they inputed the test object or just the results file, checked by seeing
    # if object has a $results part
    if ("results" %in% names(test1)) {
        #If entire object, extract the results section
        results1 = test1$results
    } else if ("P.value" %in% names(test1)) {
        results1 = test1
    } else {
        stop("First object is not a valid output or does not have P.value column")
    }
	
    if ("results" %in% names(test2)) {
        #If entire object, extract the results section
        results2 = test2$results
    } else if ("P.value" %in% names(test2)) {
        results2 = test2
    } else {
        stop("Second object is not a valid output or does not have P.value column")
    }
    
    #Check for Geneset.ID column
    if (!("Geneset.ID" %in% names(results1))) {
        stop("First object does not have Geneset.ID column")
    }
    if (!("Geneset.ID" %in% names(results2))) {
        stop("Second object does not have Geneset.ID column")
    }
    
    
    

    
    #Separate tree if the data does not have Status column
    if ("Status" %in% names(results1) & "Status" %in% names(results2)) {
        #Extract p-value and status of both tests
        Pvals1 = results1[,c("Geneset.ID","P.value","Status")]
        Pvals2 = results2[,c("Geneset.ID","P.value","Status")]
    
    } else {
        #Extract p-value only
        Pvals1 = results1[,c("Geneset.ID","P.value")]
        Pvals2 = results2[,c("Geneset.ID","P.value")]

    }

    #Merge by Geneset.ID
    PvalsH = merge(Pvals1, Pvals2, by="Geneset.ID")
    #If 0 remain, stop.
    if (nrow(PvalsH) == 0) {
        stop("No common genesets in the two datasets!")
    }
    message(sprintf("Total of %s common Geneset.IDs", nrow(PvalsH)))


    PvalsH$P.value.Hybrid = 2*pmin(PvalsH$P.value.x, PvalsH$P.value.y)
	
	#Run B-H to adjust for FDR for hybrid p-values
    PvalsH$FDR.Hybrid = stats::p.adjust(PvalsH$P.value.Hybrid, method = "BH")
    
    
    #Include enrich/depleted status if available and combine
    if ("Status" %in% names(results1) & "Status" %in% names(results2)) {
        PvalsH$Status.Hybrid = ifelse(PvalsH$Status.x == PvalsH$Status.y, PvalsH$Status.x, "Inconsistent")
        #Combine both results files together and append hybrid p-value and FDR
        resultsH = merge(results1[,-which(colnames(results1) %in% c("P.value","Status"))], PvalsH, by = "Geneset.ID")
    } else {
        resultsH = merge(results1[,-which(colnames(results1) %in% c("P.value"))], PvalsH, by = "Geneset.ID")
    }
    
    
    #Reorder columns?????
	
	#Output final results
	return(resultsH)
	
}