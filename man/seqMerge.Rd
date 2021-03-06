\name{seqMerge}
\alias{seqMerge}
\title{Merge Multiple Sequence GDS Files}
\description{
    Merges multiple sequence GDS files.
}
\usage{
seqMerge(gds.fn, out.fn, storage.option=seqStorage.Option(), verbose=TRUE)
}
\arguments{
    \item{gds.fn}{the file names of multiple GDS files}
    \item{out.fn}{the output file name}
    \item{storage.option}{specify the storage and compression options,
        by default \code{\link{seqStorage.Option}}}
    \item{verbose}{if \code{TRUE}, show information}
}
\value{
    None.
}
\details{
    The current implementation of \code{seqMerge} extracts and merges the
genotypic data only without any annotation. Users can specify multiple VCF
files in \code{\link{seqVCF2GDS}} to export a single GDS file.
}

\author{Xiuwen Zheng}
\seealso{
    \code{\link{seqVCF2GDS}}
}

\keyword{gds}
\keyword{sequencing}
\keyword{genetics}
