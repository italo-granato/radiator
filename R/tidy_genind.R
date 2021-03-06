#' @name tidy_genind
#' @title Tidy a genind object to a tidy dataframe
#' @description Tidy genind object from
#' \href{https://github.com/thibautjombart/adegenet}{adegenet} to a tidy dataframe.
#' Used internally in \href{https://github.com/thierrygosselin/radiator}{radiator}
#' and might be of interest for users.

#' @param data A genind object in the global environment.

#' @param keep.allele.names Allows to keep allele names for the tidy dataset.
#' Requires the alleles to be numeric. To have this argument in
#' \pkg{radiator} \code{\link{tidy_genomic_data}} or
#' \pkg{radiator} \code{\link{genomic_converter}}
#' use it at the end. \code{...} in those function looks for it.
#' Default: \code{keep.allele.names = FALSE}.

#' @param tidy (logical) Generate a tidy dataset.
#' Default: \code{tidy = TRUE}.


#' @param gds (optional, logical) To write a radiator gds object.
#' Currently, for biallelic datasets only.
#' Default: \code{gds = TRUE}.

#' @param write (optional, logical) To write in the working directory the tidy
#' data. The file is written with \code{radiator_genind_DATE@TIME.rad}.
#' Default: \code{write = FALSE}.

#' @inheritParams radiator_common_arguments


#' @export
#' @rdname tidy_genind

#' @importFrom dplyr select distinct n_distinct group_by ungroup rename arrange tally filter if_else mutate summarise left_join inner_join right_join anti_join semi_join full_join
#' @importFrom stringi stri_replace_all_fixed stri_replace_all_regex stri_join
# @importFrom adegenet indNames
#' @importFrom tibble rownames_to_column data_frame
#' @importFrom tidyr gather unite

#' @references Jombart T (2008) adegenet: a R package for the multivariate
#' analysis of genetic markers. Bioinformatics, 24, 1403-1405.
#' @references Jombart T, Ahmed I (2011) adegenet 1.3-1:
#' new tools for the analysis of genome-wide SNP data.
#' Bioinformatics, 27, 3070-3071.


#' @author Thierry Gosselin \email{thierrygosselin@@icloud.com}


tidy_genind <- function(
  data,
  keep.allele.names = FALSE,
  tidy = TRUE,
  gds = TRUE,
  write = FALSE,
  verbose = FALSE
) {

  # Checking for missing and/or default arguments ------------------------------
  if (missing(data)) stop("data argument required")
  if (class(data)[1] != "genind") stop("Input is not a genind object")
  if (verbose) message("genind info:")
  strata <- tibble::tibble(INDIVIDUALS = rownames(data@tab))
  if (is.null(data@pop)) {
    if (verbose) message("    strata: no")
    if (verbose) message("    'pop' will be added")
    strata %<>% dplyr::mutate(STRATA = "pop")
  } else {
    if (verbose) message("    strata: yes")
    strata$STRATA = data@pop
  }

  biallelic <- max(unique(data@loc.n.all)) == 2
  if (!biallelic) gds <- FALSE

  if (gds) {
    # prepare genind
    alt.alleles <- tibble::tibble(MARKERS_ALLELES = colnames(data@tab), COUNT = colSums(x = data@tab, na.rm = TRUE)) %>%
      dplyr::mutate(
        MARKERS = stringi::stri_extract_first_regex(str = colnames(data@tab), pattern = "^[^.]+"),
        ALLELES = stringi::stri_extract_last_regex(str = colnames(data@tab), pattern = "(?<=\\.).*")
      ) %>%
      dplyr::group_by(MARKERS) %>%
      dplyr::mutate(REF = dplyr::if_else(COUNT == min(COUNT, na.rm = TRUE), "ALT", "REF")) %>%
      dplyr::ungroup(.) %>%
      dplyr::select(MARKERS_ALLELES, REF) %>%
      dplyr::filter(REF == "ALT") %>%
      dplyr::select(MARKERS_ALLELES) %$% MARKERS_ALLELES

    geno <- tibble::as_tibble(t(data@tab), rownames = "MARKERS") %>%
      dplyr::filter(MARKERS %in% alt.alleles) %>%
      dplyr::mutate(
        MARKERS = stringi::stri_extract_first_regex(str = MARKERS, pattern = "^[^.]+"),
        VARIANT_ID = as.integer(factor(MARKERS))) %>%
      dplyr::arrange(VARIANT_ID)

    alt.alleles <- NULL
    markers.meta <- dplyr::select(geno, VARIANT_ID, MARKERS)
    suppressWarnings(
      geno %<>%
        dplyr::select(-MARKERS) %>%
        tibble::column_to_rownames(df = ., var = "VARIANT_ID")
    )

    gds.filename <- radiator_gds(
      genotypes.df = geno,
      strata = strata,
      biallelic = TRUE,
      markers.meta = markers.meta,
      filename = NULL,
      verbose = verbose
    )
    if (verbose) message("Written: GDS filename: ", gds.filename)

  }# End gds genind

  if (tidy) {
    if (write) {
      filename.temp <- generate_filename(extension = "rad")
      filename.short <- filename.temp$filename.short
      filename.genind <- filename.temp$filename
    }

    A2 <- TRUE %in% unique(stringi::stri_detect_fixed(str = sample(colnames(data@tab), 100), pattern = ".A2"))

    if (biallelic && A2) {
      # changed adegenet::indNames to rownames(data@tab) to lower dependencies
      data <- tibble::as_data_frame(data@tab) %>%
        tibble::add_column(.data = ., INDIVIDUALS = rownames(data@tab), .before = 1) %>%
        tibble::add_column(.data = ., POP_ID = data@pop) %>%
        dplyr::select(POP_ID, INDIVIDUALS, dplyr::ends_with(match = ".A2")) %>%
        # tidyr::gather(data = ., key = MARKERS, value = GT_BIN, -c(POP_ID, INDIVIDUALS)) %>%
        data.table::as.data.table(.) %>%
        data.table::melt.data.table(
          data = .,
          id.vars = c("INDIVIDUALS", "POP_ID"),
          variable.name = "MARKERS",
          value.name = "GT_BIN"
        ) %>%
        tibble::as_data_frame(.) %>%
        dplyr::mutate(
          MARKERS = stringi::stri_replace_all_fixed(
            str = MARKERS, pattern = ".A2", replacement = "", vectorize_all = FALSE),
          GT_VCF = dplyr::if_else(GT_BIN == 0, "0/0",
                                  dplyr::if_else(GT_BIN == 1, "0/1", "1/1"), missing = "./."),
          GT = dplyr::if_else(GT_BIN == 0, "001001", dplyr::if_else(GT_BIN == 1, "001002", "002002") , missing = "000000")
        )
    } else {

      if (keep.allele.names) {
        message("Alleles names are kept if all numeric and padded with 0 if length < 3")
        data <- tibble::as_data_frame(data@tab) %>%
          tibble::add_column(.data = ., INDIVIDUALS = rownames(data@tab), .before = 1) %>%
          tibble::add_column(.data = ., POP_ID = data@pop) %>%
          # tidyr::gather(data = ., key = MARKERS_ALLELES, value = COUNT, -c(POP_ID, INDIVIDUALS)) %>%
          data.table::as.data.table(.) %>%
          data.table::melt.data.table(
            data = .,
            id.vars = c("INDIVIDUALS", "POP_ID"),
            variable.name = "MARKERS_ALLELES",
            value.name = "COUNT"
          ) %>%
          tibble::as_data_frame(.) %>%
          dplyr::filter(COUNT > 0 | is.na(COUNT)) %>%
          tidyr::separate(data = ., col = MARKERS_ALLELES, into = c("MARKERS", "ALLELES"), sep = "\\.")

        check.alleles <- unique(stringi::stri_detect_regex(str = unique(data$ALLELES), pattern = "[0-9]"))
        check.alleles <- length(check.alleles) == 1 && check.alleles

        if (check.alleles) {
          data <- data %>%
            dplyr::mutate(
              ALLELES = stringi::stri_pad_left(str = ALLELES, pad = "0", width = 3)
            )
        } else {
          data <- data %>%
            dplyr::mutate(
              ALLELES = as.numeric(factor(ALLELES)),
              ALLELES = stringi::stri_pad_left(str = ALLELES, pad = "0", width = 3)
            )
        }

      } else {
        message("Alleles names for each markers will be converted to factors and padded with 0")
        data <- tibble::as_data_frame(data@tab) %>%
          tibble::add_column(.data = ., INDIVIDUALS = rownames(data@tab), .before = 1) %>%
          tibble::add_column(.data = ., POP_ID = data@pop) %>%
          # tidyr::gather(data = ., key = MARKERS_ALLELES, value = COUNT, -c(POP_ID, INDIVIDUALS)) %>%
          data.table::as.data.table(.) %>%
          data.table::melt.data.table(
            data = .,
            id.vars = c("INDIVIDUALS", "POP_ID"),
            variable.name = "MARKERS_ALLELES",
            value.name = "COUNT"
          ) %>%
          tibble::as_data_frame(.) %>%
          dplyr::filter(COUNT > 0 | is.na(COUNT)) %>%
          tidyr::separate(data = ., col = MARKERS_ALLELES, into = c("MARKERS", "ALLELES"), sep = "\\.") %>%
          dplyr::mutate(
            ALLELES = as.numeric(factor(ALLELES)),
            ALLELES = stringi::stri_pad_left(str = ALLELES, pad = "0", width = 3)
          )
      }


      # #If the genind was coded with allele 0, this will generate missing data with this code
      # allele.zero <- TRUE %in% stringi::stri_detect_regex(str = unique(data3$ALLELES), pattern = "^0$")
      # if (allele.zero) stop("alleles in this multiallelic genind were coded as 0 and won't work with this script")

      #Isolate missing genotype
      missing.hom <- dplyr::filter(data, is.na(COUNT)) %>%
        dplyr::distinct(POP_ID, INDIVIDUALS, MARKERS) %>%
        dplyr::mutate(GT = rep("000000", n())) %>%
        dplyr::ungroup(.)

      #Isolate all Homozygote genotypes and combine with the missings
      missing.hom <- dplyr::filter(data, COUNT == 2) %>%
        dplyr::group_by(POP_ID, INDIVIDUALS, MARKERS) %>%
        dplyr::summarise(GT = stringi::stri_join(ALLELES, ALLELES, sep = "")) %>%
        dplyr::ungroup(.) %>%
        dplyr::bind_rows(missing.hom)

      #Isolate all Het genotypes and combine
      data <- dplyr::filter(data, COUNT != 2) %>%#this will also remove the missing
        dplyr::group_by(POP_ID, INDIVIDUALS, MARKERS) %>%
        dplyr::summarise(GT = stringi::stri_join(ALLELES, collapse = "")) %>%
        dplyr::ungroup(.) %>%
        dplyr::bind_rows(missing.hom)
      missing.hom <- NULL
    }#End for multi-allelic

    if (write) {
      radiator::write_rad(data = data, path = filename.genind)
      if (verbose) message("File written: ", filename.short)
    }
  }# End tidy genind

  return(data)
} # End tidy_genind
