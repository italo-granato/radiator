#' @name private_haplotypes
#' @title private haplotypes
#' @description Minor Allele Frequency filter.
#' @param data A tidy genomic dataframe
#' Used internally in \href{https://github.com/thierrygosselin/radiator}{radiator}
#' and might be of interest for users.
#' \emph{How to get a tidy data frame ?}
#' Look into \pkg{radiator} \code{\link{tidy_genomic_data}}.

#' @param strata (optional) A strata file or object in the global environment.
#' The strata is a tab-separated data frame with 2 columns: \code{INDIVIDUALS} and
#' \code{STRATA}. If used, the strata will replace the current STRATA or POP_ID in the
#' dataset. Use this argument if you want to find private haplotypes on another
#' hierarchical level, other than POP_ID.

#' @inheritParams tidy_genomic_data


#' @rdname private_haplotypes
#' @export
#' @return A list with private haplotypes per markers and strata and a summary of
#' overall number of private haplotypes per strata.
#' @author Thierry Gosselin \email{thierrygosselin@@icloud.com}
#' @importFrom tibble has_name
#' @importFrom stringi stri_join stri_replace_all_fixed stri_sub
#' @importFrom dplyr select distinct group_by ungroup rename arrange tally filter if_else mutate summarise left_join inner_join right_join anti_join semi_join full_join funs summarise_at bind_rows
#' @importFrom tidyr complete gather unite spread nesting


private_haplotypes <- function(data, strata = NULL, verbose = TRUE) {
  if (verbose) cat("#######################################################################\n")
  if (verbose) cat("##################### radiator::private_haplotypes ####################\n")
  if (verbose) cat("#######################################################################\n")
  timing <- proc.time()
  opt.change <- getOption("width")
  options(width = 70)
  res <- list()

  if (missing(data)) rlang::abort("Input file missing")

  if (!is.null(strata)) {
    if (is.vector(strata)) {
      strata <- readr::read_tsv(file = strata,  col_types = readr::cols(.default = readr::col_character()))
    }

    colnames(strata) <- stringi::stri_replace_all_fixed(
      str = colnames(strata),
      pattern = "POP_ID",
      replacement = "STRATA",
      vectorize_all = FALSE)

    # Remove potential whitespace in pop_id
    strata$STRATA <- radiator::clean_pop_names(strata$STRATA)

    # clean ids
    strata$INDIVIDUALS <- radiator::clean_ind_names(strata$INDIVIDUALS)

    data <- suppressWarnings(
      dplyr::ungroup(data) %>%
        dplyr::select(-dplyr::one_of(c("POP_ID", "STRATA"))) %>%
        dplyr::left_join(strata, by = "INDIVIDUALS")
    )
  } else {
    colnames(data) <- stringi::stri_replace_all_fixed(
      str = colnames(data),
      pattern = "POP_ID",
      replacement = "STRATA",
      vectorize_all = FALSE)
  }

  if (!tibble::has_name(data, "HAPLOTYPES")) {
    data <- dplyr::ungroup(data) %>%
      dplyr::filter(GT_VCF_NUC != "./.") %>%
      dplyr::distinct(MARKERS, STRATA, GT_VCF_NUC) %>%
      separate_gt(x = ., sep = "/", gt = "GT_VCF_NUC", exclude = c("MARKERS", "STRATA")) %>%
      dplyr::select(-ALLELE_GROUP) %>%
      dplyr::distinct(MARKERS, STRATA, HAPLOTYPES)
  } else {
    data <- dplyr::filter(data, MAF_LOCAL > 0)
  }



  res$private.haplotypes <- dplyr::distinct(data, MARKERS, STRATA, HAPLOTYPES) %>%
    dplyr::group_by(MARKERS, HAPLOTYPES) %>%
    dplyr::tally(.) %>%
    dplyr::ungroup(.) %>%
    dplyr::filter(n == 1) %>%
    dplyr::select(-n) %>%
    dplyr::left_join(data, by = c("MARKERS", "HAPLOTYPES")) %>%
    dplyr::select(MARKERS, STRATA, HAPLOTYPES) %>%
    readr::write_tsv(x = ., path = "private.haplotypes.tsv")

  res$private.haplotypes.summary <- res$private.haplotypes %>%
    dplyr::group_by(STRATA) %>%
    dplyr::tally(.) %>%
    dplyr::ungroup(.) %>%
    tibble::add_row(.data = ., STRATA = "OVERALL", n = sum(.$n)) %>%
    dplyr::mutate(PRIVATE_HAPLOTYPES = stringi::stri_join(STRATA, " = ", n)) %>%
    readr::write_tsv(x = ., path = "private.haplotypes.summary.tsv")

  message("Number of private haplotypes = ", nrow(res$private.haplotypes))
  message("Strata with the highest number of private haplotypes = ", res$private.haplotypes.summary$STRATA[res$private.haplotypes.summary$n == max(res$private.haplotypes.summary$n)])
  message("Number of private haplotype(s) per strata:\n", stringi::stri_join(res$private.haplotypes.summary$PRIVATE_HAPLOTYPES, collapse = "\n"))
  if (verbose) message("\nComputation time: ", round((proc.time() - timing)[[3]]), " sec")
  if (verbose) cat("############################## completed ##############################\n")
  options(width = opt.change)
  return(res)
}#End private_haplotypes
