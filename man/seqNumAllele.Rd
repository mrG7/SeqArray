\name{seqNumAllele}
\alias{seqNumAllele}
\title{Number of alleles}
\description{
    Returns the numbers of alleles for each site.
}
\usage{
seqNumAllele(gdsfile, parallel=getOption("seqarray.parallel", FALSE))
}
\arguments{
    \item{gdsfile}{a \code{\link{SeqVarGDSClass}} object}
    \item{parallel}{\code{FALSE} (serial processing), \code{TRUE} (parallel
        processing) or other value; \code{parallel} is passed to the argument
        \code{cl} in \code{\link{seqParallel}}, see \code{\link{seqParallel}}
        for more details.}
}
\value{
    The numbers of alleles for each site.
}

\author{Xiuwen Zheng}
\seealso{
    \code{\link{seqAlleleFreq}}, \code{\link{seqMissing}},
    \code{\link{seqParallel}}
}

\examples{
# the GDS file
(gds.fn <- seqExampleFileName("gds"))

# display
f <- seqOpen(gds.fn)

table(seqNumAllele(f))

# close the GDS file
seqClose(f)
}

\keyword{gds}
\keyword{sequencing}
\keyword{genetics}
