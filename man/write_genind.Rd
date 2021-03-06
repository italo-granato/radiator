% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/write_genind.R
\name{write_genind}
\alias{write_genind}
\title{Write a genind object from a tidy data frame}
\usage{
write_genind(data, write = FALSE, verbose = FALSE)
}
\arguments{
\item{data}{A tidy data frame object in the global environment or
a tidy data frame in wide or long format in the working directory.
\emph{How to get a tidy data frame ?}
Look into \pkg{radiator} \code{\link{tidy_genomic_data}}.}

\item{write}{(logical, optional) To write in the working directory the genind
object. The file is written with \code{radiator_genind_DATE@TIME.RData} and
can be open with load or readRDS.
Default: \code{write = FALSE}.}

\item{verbose}{(optional, logical) When \code{verbose = TRUE}
the function is a little more chatty during execution.
Default: \code{verbose = TRUE}.}
}
\description{
Write a genind object from a tidy data frame.
Used internally in \href{https://github.com/thierrygosselin/radiator}{radiator}
and \href{https://github.com/thierrygosselin/assigner}{assigner}
and might be of interest for users.
}
\references{
Jombart T (2008) adegenet: a R package for the multivariate
analysis of genetic markers. Bioinformatics, 24, 1403-1405.

Jombart T, Ahmed I (2011) adegenet 1.3-1:
new tools for the analysis of genome-wide SNP data.
Bioinformatics, 27, 3070-3071.
}
\author{
Thierry Gosselin \email{thierrygosselin@icloud.com}
}
