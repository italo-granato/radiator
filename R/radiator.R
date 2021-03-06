# radiator common arguments
#' @name radiator_common_arguments
#' @title radiator common arguments
#' @description radiator common arguments
#' @rdname radiator_common_arguments
#' @export
#' @keywords internal

#' @param interactive.filter (optional, logical) Do you want the filtering session to
#' be interactive. Figures of distribution are shown before asking for filtering
#' thresholds.
#' Default: \code{interactive.filter = TRUE}.

#' @param data (4 options) A file or object generated by radiator:
#' \itemize{
#' \item tidy data
#' \item Genomic Data Structure (GDS)
#' }
#'
#' \emph{How to get GDS and tidy data ?}
#' Look into \code{\link{tidy_genomic_data}},
#' \code{\link{write_seqarray}} or
#' \code{\link{tidy_vcf}}.


#' @param verbose (optional, logical) When \code{verbose = TRUE}
#' the function is a little more chatty during execution.
#' Default: \code{verbose = TRUE}.

#' @param parallel.core (optional) The number of core used for parallel
#' execution during import.
#' Default: \code{parallel.core = parallel::detectCores() - 1}.

#' @param random.seed (integer, optional) For reproducibility, set an integer
#' that will be used inside the function that requires randomness. With default,
#' a random number is generated and printed in the appropriate output.
#' Default: \code{random.seed = NULL}.



#' @param ... (optional) Advance mode that allows to pass further arguments
#' for fine-tuning the function. Also used for legacy arguments (see details or
#' special section)


# @inheritParams radiator_common_arguments

#' @importFrom dplyr group_by select rename filter mutate summarise distinct n_distinct arrange left_join semi_join anti_join inner_join full_join tally bind_rows
#' @importFrom parallel detectCores
#' @importFrom stringi stri_replace_all_fixed stri_join stri_sub stri_replace_na stri_pad_left
#' @importFrom purrr discard
#' @importFrom readr read_tsv write_tsv
#' @importFrom tibble as_data_frame data_frame
#' @importFrom tidyr spread gather unite separate
#' @importFrom stats IQR


radiator_common_arguments <- function (
  data,
  parallel.core = parallel::detectCores() - 1,
  verbose = TRUE,
  random.seed = NULL,
  ...) {
  data = NULL
  parallel.core <- NULL
  verbose <- NULL
  random.seed <- NULL
}
