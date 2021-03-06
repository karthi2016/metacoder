% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/taxmap--utilities.R
\name{subtaxa}
\alias{subtaxa}
\title{Get all subtaxa of a taxon}
\usage{
subtaxa(obj, subset = NULL, recursive = TRUE, simplify = FALSE,
  include_input = FALSE, index = FALSE)
}
\arguments{
\item{obj}{(\code{taxmap}) The \code{taxmap} object containing taxon information to be
queried.}

\item{subset}{(\code{character}) \code{taxon_ids} or indexes of \code{taxon_data} for which
supertaxa will be returned. Default: All taxa in \code{obj} will be used.}

\item{recursive}{(\code{logical}) If \code{FALSE}, only return the subtaxa one level bwlow the 
target taxa. If \code{TRUE}, return all the subtaxa of every subtaxa, etc.}

\item{simplify}{(\code{logical}) If \code{TRUE}, then combine all the results into a single 
vector of unique values.}

\item{include_input}{(\code{logical}) If \code{TRUE}, the input taxa are included in the output}

\item{index}{(\code{logical}) If \code{TRUE}, return the indexes of supertaxa in 
\code{taxon_data} instead of \code{taxon_ids}}
}
\value{
If \code{simplify = FALSE}, then a list of vectors are returned corresponding to the
  \code{target} argument. If \code{simplify = TRUE}, then the unique values are returned in a
  single vector.
}
\description{
Return the taxon IDs or \code{taxon_data} indexes of all subtaxa in an object of type \code{taxmap}
}
\examples{
\dontrun{
subtaxa(contaminants, subset = 1:10)}

}
\seealso{
Other taxmap taxonomy functions: \code{\link{obs}},
  \code{\link{roots}}, \code{\link{supertaxa}}
}

