SeqVarGDSClass <- function(gdsobj, ...) {
    new("SeqVarGDSClass", gdsobj, ...)
}

setMethod("granges",
          "SeqVarGDSClass",
          function(x, ...) {
            variant.id <- seqGetData(x, "variant.id")
            chromosome <- seqGetData(x, "chromosome")
            position <- seqGetData(x, "position")
            reflen <- elementLengths(ref(x))
            reflen[reflen < 1] <- 1
            gr <- GRanges(seqnames=chromosome,
                          ranges=IRanges(start=position,
                            end=(position + reflen - 1)),
                          ...)
            names(gr) <- variant.id
            gr
          })


.refAllele <- function(x) {
  endRef <- regexpr(",", x, fixed=TRUE) - 1
  noAlt <- endRef < 0
  if (any(noAlt)) {
    endRef[noAlt] <- nchar(x[noAlt])
  }
  substr(x, 1, endRef)
}

.altAllele <- function(x) {
  begAlt <- regexpr(",", x, fixed=TRUE) + 1
  noAlt <- begAlt == 0
  if (any(noAlt)) {
    begAlt[noAlt] <- nchar(x[noAlt]) + 1
  }
  substr(x, begAlt, nchar(x))
}

setMethod("ref",
          "SeqVarGDSClass",
          function(x) {
            DNAStringSet(.refAllele(seqGetData(x, "allele")))
          })

setMethod("alt",
          "SeqVarGDSClass",
          function(x) {
            alt <- .altAllele(seqGetData(x, "allele"))
            ## want strsplit to return "" instead of character(0) for alt=""
            alt[alt == ""] <- ","
            do.call(DNAStringSetList, strsplit(alt, ",", fixed=TRUE))
          })

setMethod("qual",
          "SeqVarGDSClass",
          function(x) {
            qual <- seqGetData(x, "annotation/qual")
            qual[is.na(qual)] <- NA # change NaN to NA
            qual
          })

setMethod("filt",
          "SeqVarGDSClass",
          function(x) {
            as.character(seqGetData(x, "annotation/filter"))
          })


setMethod("asVCF",
          "SeqVarGDSClass",
          function(x, info=NULL, geno=NULL) {
            seqsum <- seqSummary(x, check="none", verbose=FALSE)
            if (!is.null(info)) {
              validInfo <- seqsum$info$var.name
              infoDiff <- setdiff(info, c(validInfo, NA))
              if (length(infoDiff) > 0) {
                warning(paste("info fields not present:", infoDiff))
                info <- intersect(info, validInfo)
              }
            }
            if (!is.null(geno)) {
              validGeno <- c("GT", seqsum$format$var.name)
              genoDiff <- setdiff(geno, c(validGeno, NA))
              if (length(genoDiff) > 0) {
                warning(paste("geno fields not present:", genoDiff))
                geno <- intersect(geno, validGeno)
              }
            }
            VCF(rowRanges=.rowRanges(x),
                colData=.colData(x),
                exptData=SimpleList(header=.header(x)),
                fixed=.fixed(x),
                info=.info(x, info),
                geno=.geno(x, geno))
          })

.rowRanges <- function(gdsobj) {
  granges(gdsobj,
          ID=seqGetData(gdsobj, "annotation/id"),
          REF=ref(gdsobj),
          ALT=alt(gdsobj),
          QUAL=qual(gdsobj),
          FILTER=filt(gdsobj))
}

.colData <- function(gdsobj) {
  sample.id <- seqGetData(gdsobj, "sample.id")
  DataFrame(Samples=seq_along(sample.id), row.names=sample.id)
}

.header <- function(gdsobj) {
  sample.id <- seqGetData(gdsobj, "sample.id")

  ## info
  seqsum <- seqSummary(gdsobj, check="none", verbose=FALSE)
  infoHd <- seqsum$info
  names(infoHd)[2:4] <- c("Number", "Type", "Description")
  infoHd <- DataFrame(infoHd[,2:4], row.names=infoHd[,1])

  ## geno
  genoHd <- seqsum$format
  names(genoHd)[2:4] <- c("Number", "Type", "Description")
  genoHd <- DataFrame(genoHd[,2:4], row.names=genoHd[,1])
  gt <- DataFrame(Number="1", Type="String", Description="Genotype",
                  row.names="GT")
  genoHd <- rbind(gt, genoHd)

  ## meta
  des <- get.attr.gdsn(index.gdsn(gdsobj, "description"))
  ff <- des$vcf.fileformat
  meta <- DataFrame(Value=ff, row.names="fileformat")
  n <- index.gdsn(gdsobj, "description/vcf.header", silent=TRUE)
  if (!is.null(n)) {
    des <- read.gdsn(n)
    meta <- rbind(meta, DataFrame(Value=des[,2], row.names=des[,1]))
  }

  hdr <- DataFrameList(META=meta, INFO=infoHd, FORMAT=genoHd)

  ## fixed
  n <- index.gdsn(gdsobj, "description/vcf.alt", silent=TRUE)
  if (!is.null(n)) {
    des <- read.gdsn(n)
    hdr[["ALT"]] <- DataFrame(Description=des[,2], row.names=des[,1])
  }
  n <- index.gdsn(gdsobj, "description/vcf.filter", silent=TRUE)
  if (!is.null(n)) {
    des <- read.gdsn(n)
    hdr[["FILTER"]] <- DataFrame(Description=des[,2], row.names=des[,1])
  }

  VCFHeader(samples=sample.id, header=hdr)
}

.fixed <- function(gdsobj) {
  DataFrame(REF=ref(gdsobj),
            ALT=alt(gdsobj),
            QUAL=qual(gdsobj),
            FILTER=filt(gdsobj))
}

.variableLengthToList <- function(x) {
  xl <- list()
  j <- 1
  for (i in 1:length(x$length)) {
    len <- x$length[i]
    if (len > 0) {
      xl[[i]] <- x$data[j:(j+len-1)]
      j <- j+len
    } else {
      xl[[i]] <- NA
    }
  }
  xl
}

.toAtomicList <- function(x, type) {
  switch(type,
         Character=CharacterList(x),
         String=CharacterList(x),
         Integer=IntegerList(x),
         Float=NumericList(x))
}

.info <- function(gdsobj, info=NULL) {
  des <- seqSummary(gdsobj, check="none", verbose=FALSE)$info
  if (!is.null(info)) {
    des <- des[des$var.name %in% info,]
  }
  infoDf <- DataFrame(row.names=seqGetData(gdsobj, "variant.id"))
  if (nrow(des) > 0) {
    for (i in 1:nrow(des)) {
      x <- seqGetData(gdsobj, paste("annotation/info/", des$var.name[i], sep=""))
      ## deal with variable length fields
      if (!is.null(names(x))) {
        xl <- .variableLengthToList(x)
        ## each element should have length number of alt alleles, even for NAs
        if (des$number[i] == "A") {
          nAlt <- elementLengths(alt(gdsobj))
          addNA <- which(nAlt > 1 & is.na(xl))
          for (ind in addNA) {
            xl[[ind]] <- rep(NA, nAlt[ind])
          }
        }
        x <- .toAtomicList(xl, des$type[i])
      } else if (!is.null(dim(x))) {
        ## x is a matrix with nrow="Number"
        xl <- list()
        for (j in 1:ncol(x)) {
          xl[[j]] <- x[,j]
        }
        x <- .toAtomicList(xl, des$type[i])
      }
      x[is.na(x)] <- NA # change NaN to NA
      x[x %in% ""] <- NA
      infoDf[[des$var.name[i]]] <- x
    }
  }
  infoDf
}

.variableLengthToMatrix <- function(x) {
  xl <- list()
  i <- 1
  for (j in 1:length(x)) {
    for (k in 1:nrow(x[[j]])) {
      xl[[i]] <- x[[j]][k,]
      i <- i + 1
    }
  }
  matrix(xl, nrow=nrow(x[[1]]), ncol=length(x))
}

.geno <- function(gdsobj, geno=NULL) {
  ## genotype
  sample.id <- seqGetData(gdsobj, "sample.id")
  variant.id <- seqGetData(gdsobj, "variant.id")

  if (is.null(geno) || "GT" %in% geno) {
    gt <- seqApply(gdsobj, c(geno="genotype", phase="phase"),
                   function(x) {sep=ifelse(x$phase, "|", "/")
                                paste(x$geno[1,], sep, x$geno[2,], sep="")})
    gt <- matrix(unlist(gt), ncol=length(gt),
                 dimnames=list(sample.id, variant.id))
    gt[gt == "NA/NA"] <- "."
    gt <- t(gt)

    genoSl <- SimpleList(GT=gt)
  } else {
    genoSl <- SimpleList()
  }

  ## all other fields
  des <- seqSummary(gdsobj, check="none", verbose=FALSE)$format
  if (!is.null(geno)) {
    des <- des[des$var.name %in% geno,]
  }
  if (nrow(des) > 0) {
    for (i in 1:nrow(des)) {
      var.name <- paste("annotation/format/", des$var.name[i], sep="")
      number <- suppressWarnings(as.integer(des$number[i]))
      if (!is.na(number) && number > 1) {
        x <- seqApply(gdsobj, var.name, function(x) {x})
        xm <- array(dim=c(length(variant.id), length(sample.id), number),
                    dimnames=list(variant.id, sample.id, NULL))
        for (j in 1:length(x)) {
          if (is.null(x[[j]])) {
            xm[j,,] <- NA
          } else {
            xm[j,,] <- t(x[[j]][,,1])
          }
        }
        x <- xm
      } else {
        x <- seqGetData(gdsobj, var.name)
        if (!is.null(names(x))) {
          if (all(x$length == 1) && !is.na(number) && number == 1) {
            x <- x$data
          } else {
            x <- seqApply(gdsobj, var.name, function(x) {x})
            x <- .variableLengthToMatrix(x)
          }
        }
        dimnames(x) <- list(sample.id, variant.id)
        x <- t(x)
      }
      genoSl[[des$var.name[i]]] <- x
    }
  }
  genoSl
}
