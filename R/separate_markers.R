# Separate a column (markers) into CHROM LOCUS and POS
# generate markers meta

#' @name separate_markers
#' @title Separate markers column into chrom, locus and pos

#' @description Radiator uses unique marker names by combining
#' \code{CHROM}, \code{LOCUS}, \code{POS} columns, with double underscore
#' separators, into \code{MARKERS = CHROM__LOCUS__POS}.
#'
#'
#' Used internally in \href{https://github.com/thierrygosselin/radiator}{radiator}
#' and might be of interest for users who need to get back to the original metadata the
#' function provides an easy way to do it.

#' @param data An object with a column named \code{MARKERS}.
#' If \code{CHROM}, \code{LOCUS}, \code{POS} are already present, the function
#' returns the dataset untouched.
#' The data can be whitelists and blacklists of markers or tidy datasets or
#' radiator GDS object.

#' @param sep (optional, character) Separator used to identify the different
#' field in the \code{MARKERS} column.
#'
#' When the \code{MARKERS} column doesn't have separator and the function is used
#' to generate markers metadata column:
#' \code{"CHROM", "LOCUS", "POS", "REF", "ALT"}, use \code{sep = NULL}.
#' Default: \code{sep = "__"}.
#'
#' @param markers.meta.lists.only (logical, optional)
#' Allows to keep only the markers metadata:
#' \code{"VARIANT_ID", "MARKERS", "CHROM", "LOCUS", "POS"}, useful for whitelist
#' or blacklist.
#' Default: \code{markers.meta.lists.only = FALSE}

#' @param markers.meta.all.only (logica, optionall)
#' Allows to keep all available markers metadata:
#' \code{"VARIANT_ID", "MARKERS", "CHROM", "LOCUS", "POS", "COL", "REF", "ALT"},
#' useful inside radiator.
#' Default: \code{markers.meta.all.only = FALSE}

#' @param generate.markers.metadata (logical, optional)
#' Generate missing markers metadata when missing.
#' \code{"CHROM", "LOCUS", "POS"}.
#' Default: \code{generate.markers.metadata = TRUE}
#'
#' @param generate.ref.alt (logical, optional) Generate missing REF/ALT alleles
#' with: REF = A and ALT = C (for biallelic datasets, only).
#' It is turned off automatically
#' when argument \code{markers.meta.lists.only = TRUE} and
#' on automatically when argument \code{markers.meta.all.only = TRUE}
#' Default: \code{generate.ref.alt = FALSE}

#' @param biallelic (logical) Speed up the function execution by entering
#' if the dataset is biallelic or not. Used internally for verification, before
#' generating REF/ALT info.
#' By default, the function calls \code{\link{detect_biallelic_markers}}.
#' The argument is required if \code{data} is a tidy dataset and not just
#' a whitelist/blacklist.
#' Default: \code{biallelic = NULL}
#' @inheritParams tidy_genomic_data

#' @return The same data in the global environment, with 3 new columns:
#' \code{CHROM}, \code{LOCUS}, \code{POS}. Additionnal columns may be genrated,
#' see arguments documentation.
#' @rdname separate_markers

#' @examples
#' \dontrun{
#' whitelist <- radiator::separate_markers(data = whitelist.markers)
#' tidy.data <- radiator::separate_markers(data = bluefintuna.data)
#' }
#' @export

#' @seealso \code{\link{detect_biallelic_markers}} and \code{\link{generate_markers_metadata}}

#' @author Thierry Gosselin \email{thierrygosselin@@icloud.com}

separate_markers <- function(
  data,
  sep = "__",
  markers.meta.lists.only = FALSE,
  markers.meta.all.only = FALSE,
  generate.markers.metadata = TRUE,
  generate.ref.alt = FALSE,
  biallelic = NULL,
  parallel.core = parallel::detectCores() - 1,
  verbose = TRUE
) {
  # data.bk <- data
  # sep <- "__"

  # check if markers column is present
  if (!tibble::has_name(data, "MARKERS")) {
    rlang::abort("The data require a column named MARKERS")
  }

  n.markers <- length(unique(data$MARKERS))
  unique.markers <- nrow(data) == n.markers

  if (unique.markers && generate.ref.alt && is.null(biallelic)) {
    rlang::abort("biallelic TRUE/FALSE required")
  }

  if (markers.meta.lists.only) {
    want <- c("VARIANT_ID", "MARKERS", "CHROM", "LOCUS", "POS")
    suppressWarnings(data %<>% dplyr::select(dplyr::one_of(want)) %>%
                       dplyr::distinct(MARKERS, .keep_all = TRUE))
    generate.ref.alt <- FALSE
    generate.markers.metadata <- TRUE
  }

  if (markers.meta.all.only) {
    want <- c("VARIANT_ID", "MARKERS", "CHROM", "LOCUS", "POS", "COL", "REF", "ALT")
    suppressWarnings(data %<>% dplyr::select(dplyr::one_of(want)) %>%
                       dplyr::distinct(MARKERS, .keep_all = TRUE))
    generate.markers.metadata <- generate.ref.alt <- TRUE
  }

  if (!is.null(sep)) {
    rad.sep <- unique(
      stringi::stri_detect_fixed(
        str = sample(x = unique(data$MARKERS), size = min(200, length(data$MARKERS))),
        pattern = sep))

    if (length(rad.sep) != 1) rlang::abort("More than 1 separator was detected")
    if (!rad.sep) {
      message("The separator specified is not valid")
    } else {
      if (FALSE %in% unique(c("CHROM", "LOCUS", "POS") %in% colnames(data))) {
        rad.sep <- TRUE
      } else {
        rad.sep <- FALSE
      }

      if (rad.sep) {
        # Note to myself: this section could be parallelized when whole dataset are required
        want <- c("CHROM", "LOCUS", "POS")

        if (unique.markers) {
          data <- suppressWarnings(
            data %>%
              dplyr::select(-dplyr::one_of(want)) %>%
              tidyr::separate(data = ., col = "MARKERS",
                              into = want, sep = sep, remove = FALSE))
        } else {# for datasets
          temp <- suppressWarnings(tidyr::separate(
            data = dplyr::distinct(data, MARKERS),
            col = "MARKERS",
            into = want,
            sep = sep,
            remove = FALSE))

          suppressWarnings(data %<>% dplyr::select(-dplyr::one_of(want)))
          data %<>% dplyr::left_join(temp, by = intersect(colnames(data),
                                                          colnames(temp)))
          temp <- NULL
        }
      }
    }
  }# End of splitting markers column

  # Generate missing markers meta ----------------------------------------------
  if (generate.markers.metadata) {
    data <- generate_markers_metadata(
      data = data,
      generate.markers.metadata = generate.markers.metadata,
      generate.ref.alt = generate.ref.alt,
      biallelic = biallelic,
      parallel.core = parallel.core, verbose = verbose)
  }
  return(data)
}#End separate_markers


#' @name generate_markers_metadata
#' @title Generate markers metadata

#' @description Generate markers metadata: \code{CHROM, LOCUS, POS, REF, ALT}
#' when missing from tidy datasets.

#' @inheritParams separate_markers
#' @inheritParams tidy_genomic_data

#' @return Depending on argument's value, the same data is returned
#' in the global environment, with potential these additional columns:
#' \code{CHROM, LOCUS, POS, REF, ALT}.
#' @rdname generate_markers_metadata

#' @examples
#' \dontrun{
#' tidy.data <- radiator::generate_markers_metadata(data = bluefintuna.data)
#' }
#' @export
#' @seealso \code{\link{detect_biallelic_markers}} and \code{\link{separate_markers}}


#' @author Thierry Gosselin \email{thierrygosselin@@icloud.com}
generate_markers_metadata <- function(
  data,
  generate.markers.metadata = TRUE,
  generate.ref.alt = FALSE,
  biallelic = NULL,
  parallel.core = parallel::detectCores() - 1,
  verbose = TRUE
) {
  if (!generate.markers.metadata && generate.ref.alt) {
    if (verbose) message("generate.markers.metadata: switched to TRUE automatically")
    generate.markers.metadata <- TRUE
  }

  if (generate.markers.metadata) {
    n.markers <- length(unique(data$MARKERS))

    unique.markers <- nrow(data) == n.markers


    if (unique.markers && generate.ref.alt && is.null(biallelic)) {
      rlang::abort("biallelic TRUE/FALSE required")
    }

    want <- c("VARIANT_ID", "MARKERS", "CHROM", "LOCUS", "POS", "COL", "REF",
              "ALT", "CALL_RATE", "AVG_COUNT_REF", "AVG_COUNT_SNP", "REP_AVG", "SEQUENCE")
    if (!unique.markers) {
      suppressWarnings(
        markers.meta <- data %>%
          dplyr::select(dplyr::one_of(want)) %>%
          dplyr::distinct(MARKERS, .keep_all = TRUE))
    } else {
      markers.meta <- suppressWarnings(dplyr::select(data, dplyr::one_of(want)))
      data <- NULL
    }

    if (!tibble::has_name(markers.meta, "CHROM")) {
      markers.meta %<>% dplyr::mutate(CHROM = rep("CHROM_1", n.markers))
      if (verbose) message("CHROM info missing: 'CHROM_1' integer was added to dataset")
    }

    # Generate LOCUS info if not present
    if (!tibble::has_name(markers.meta, "LOCUS")) {
      markers.meta %<>% dplyr::mutate(LOCUS = seq(1, n.markers, by = 1))
      if (verbose) message("LOCUS info missing: unique integers were added to dataset")
    }

    if (!tibble::has_name(markers.meta, "POS")) {
      markers.meta %<>% dplyr::mutate(CHROM = rep(1L, n.markers))
      if (verbose) message("POS info missing: dataset filled with MARKERS column")
    }

    # Generate REF/ALT allele if not in dataset
    if (generate.ref.alt) {
      if (tibble::has_name(markers.meta, "REF")) generate.ref.alt <- FALSE
      if (is.null(biallelic)) {
        biallelic <- radiator::detect_biallelic_markers(data = data, verbose = FALSE, parallel.core = parallel.core)
      }
      if (!biallelic) generate.ref.alt <- FALSE
    }

    if (generate.ref.alt) {
      markers.meta %<>% dplyr::mutate(REF = "A", ALT = "C")
      if (verbose) message("REF and ALT allele info missing: setting REF = A and ALT = C")
    }

    if (!unique.markers) {
      data %<>% dplyr::left_join(markers.meta, by = intersect(colnames(data),
                                                              colnames(markers.meta)))
    } else {
      data <- markers.meta
    }
    markers.meta <- NULL
  }
  return(data)
}#End generate_markers_metadata
