#######################################################################
##                                                                     ##
## Package: BatchMap                                                     ##
##                                                                     ##
## File: map.R                                                         ##
## Contains: map                                                       ##
##                                                                     ##
## Written by Gabriel Rodrigues Alves Margarido and Marcelo Mollinari  ##
## copyright (c) 2009, Gabriel R A Margarido                           ##
##                                                                     ##
## Modified by Bastian Schiffthaler                                    ##
##                                                                     ##
## First version: 02/27/2009                                           ##
## Last update: 07/03/2017                                             ##
## License: GNU General Public License version 2 (June, 1991) or later ##
##                                                                     ##
#######################################################################

## This function constructs the linkage map for a set of markers in a given order


##' Construct the linkage map for a sequence of markers
##'
##' Estimates the multipoint log-likelihood, linkage phases and recombination
##' frequencies for a sequence of markers in a given order.
##'
##' Markers are mapped in the order defined in the object \code{input.seq}. If
##' this object also contains a user-defined combination of linkage phases,
##' recombination frequencies and log-likelihood are estimated for that
##' particular case. Otherwise, the best linkage phase combination is also
##' estimated. The multipoint likelihood is calculated according to Wu et al.
##' (2002b)(Eqs. 7a to 11), assuming that the recombination fraction is the
##' same in both parents. Hidden Markov chain codes adapted from Broman et al.
##' (2008) were used.
##'
##' @param input.seq an object of class \code{sequence}.
##' @param tol tolerance for the C routine, i.e., the value used to evaluate
##' convergence.
##' @param verbosity Controls verbosity of phase. Currently can only be set to
##' "phase"
##' @param phase.cores Number of parallel cores used to estimate linkage phases.
##' Should not be higher than 4.
##' @return An object of class \code{sequence}, which is a list containing the
##' following components: \item{seq.num}{a \code{vector} containing the
##' (ordered) indices of markers in the sequence, according to the input file.}
##' \item{seq.phases}{a \code{vector} with the linkage phases between markers
##' in the sequence, in corresponding positions. \code{-1} means that there are
##' no defined linkage phases.} \item{seq.rf}{a \code{vector} with the
##' recombination frequencies between markers in the sequence. \code{-1} means
##' that there are no estimated recombination frequencies.}
##' \item{seq.like}{log-likelihood of the corresponding linkage map.}
##' \item{data.name}{name of the object of class \code{outcross} with the raw
##' data.} \item{twopt}{name of the object of class \code{rf.2pts} with the
##' 2-point analyses.}
##' @author Adapted from Karl Broman (package 'qtl') by Gabriel R A Margarido,
##' \email{gramarga@@usp.br} and Marcelo Mollinari, \email{mmollina@@gmail.com}
##' @seealso \code{\link[BatchMap]{make.seq}}
##' @references Broman, K. W., Wu, H., Churchill, G., Sen, S., Yandell, B.
##' (2008) \emph{qtl: Tools for analyzing QTL experiments} R package version
##' 1.09-43
##'
##' Jiang, C. and Zeng, Z.-B. (1997). Mapping quantitative trait loci with
##' dominant and missing markers in various crosses from two inbred lines.
##' \emph{Genetica} 101: 47-58.
##'
##' Lander, E. S., Green, P., Abrahamson, J., Barlow, A., Daly, M. J., Lincoln,
##' S. E. and Newburg, L. (1987) MAPMAKER: An interactive computer package for
##' constructing primary genetic linkage maps of experimental and natural
##' populations. \emph{Genomics} 1: 174-181.
##'
##' Wu, R., Ma, C.-X., Painter, I. and Zeng, Z.-B. (2002a) Simultaneous maximum
##' likelihood estimation of linkage and linkage phases in outcrossing species.
##' \emph{Theoretical Population Biology} 61: 349-363.
##'
##' Wu, R., Ma, C.-X., Wu, S. S. and Zeng, Z.-B. (2002b). Linkage mapping of
##' sex-specific differences. \emph{Genetical Research} 79: 85-96
##' @keywords utilities
##' @examples
##'
##'   data(example.out)
##'   twopt <- rf.2pts(example.out)
##'
##'   markers <- make.seq(twopt,c(30,12,3,14,2)) # correct phases
##'   map(markers)
##'
##'   markers <- make.seq(twopt,c(30,12,3,14,2),phase=c(4,1,4,3)) # incorrect phases
##'   map(markers)
##'
map <- function(input.seq,tol=10E-5, verbosity=FALSE, phase.cores = 1)
{
  ## checking for correct object
  if(!("sequence" %in% class(input.seq)))
    stop(deparse(substitute(input.seq))," is not an object of class 'sequence'")
  ##Gathering sequence information
  seq.num<-input.seq$seq.num
  seq.phases<-input.seq$seq.phases
  seq.rf<-input.seq$seq.rf
  seq.like<-input.seq$seq.like
  ##Checking for appropriate number of markers
  if(length(seq.num) < 2) stop("The sequence must have at least 2 markers")
  ##For F2, BC and rils

  if((seq.phases == -1) && (seq.rf == -1) && is.null(seq.like)) {
    ## if only the marker order is provided, without predefined linkage phases,
    ## a search for the best combination of phases is performed and recombination
    ## fractions are estimated
    if("phase" %in% verbosity)
    {
      message("Phasing marker ", input.seq$seq.num[1])
    }
    seq.phase <- numeric(length(seq.num)-1)
    results <- list(rep(NA,4),rep(-Inf,4))

    ## linkage map is started with the first two markers in the sequence
    ## gather two-point information for this pair
    phase.init <- vector("list",1)
    list.init <- phases(make.seq(get(input.seq$twopt,pos = -1),
                                 seq.num[1:2],
                                 twopt=input.seq$twopt))
    phase.init[[1]] <- list.init$phase.init[[1]]
    Ph.Init <- comb.ger(phase.init)
    phases <- mclapply(1:nrow(Ph.Init),
                       mc.cores = min(nrow(Ph.Init),phase.cores),
                       mc.allow.recursive = TRUE,
                       function(j) {
                         ## call to 'map' function with predefined linkage phase
                         map(make.seq(get(input.seq$twopt),
                                      seq.num[1:2],
                                      phase=Ph.Init[j],
                                      twopt=input.seq$twopt),
                             verbosity = verbosity)
                       })
    for(j in 1:nrow(Ph.Init))
    {
      results[[1]][j] <- phases[[j]]$seq.phases
      results[[2]][j] <- phases[[j]]$seq.like
    }
    seq.phase[1] <- results[[1]][which.max(results[[2]])] # best linkage phase is chosen

    if(length(seq.num) > 2) {
      ## for sequences with three or more markers, these are added sequentially
      for(mrk in 2:(length(seq.num)-1)) {
        if("phase" %in% verbosity)
        {
          message("Phasing marker ", input.seq$seq.num[mrk])
        }
        results <- list(rep(NA,4),rep(-Inf,4))
        ## gather two-point information
        phase.init <- vector("list",mrk)
        list.init <- phases(make.seq(get(input.seq$twopt),
                                     c(seq.num[mrk],seq.num[mrk+1]),
                                     twopt=input.seq$twopt))
        phase.init[[mrk]] <- list.init$phase.init[[1]]
        for(j in 1:(mrk-1)) phase.init[[j]] <- seq.phase[j]
        Ph.Init <- comb.ger(phase.init)
        phases <- mclapply(1:nrow(Ph.Init),
                           mc.cores = min(nrow(Ph.Init),phase.cores),
                           mc.allow.recursive = TRUE,
                           function(j) {
                             ## call to 'map' function with predefined linkage phases
                             map(make.seq(get(input.seq$twopt),
                                          seq.num[1:(mrk+1)],
                                          phase=Ph.Init[j,],
                                          twopt=input.seq$twopt),
                                 verbosity = verbosity)
                           })
        for(j in 1:nrow(Ph.Init))
        {
          results[[1]][j] <- phases[[j]]$seq.phases[mrk]
          results[[2]][j] <- phases[[j]]$seq.like
        }
        if(all(is.na(results[[2]])))
        {
          warning("Could not determine phase for marker ",
                  input.seq$seq.num[mrk])
        }
        seq.phase[mrk] <- results[[1]][which.max(results[[2]])] # best combination of phases is chosen
      }
    }
    ## one last call to map function, with the final map
    map(make.seq(get(input.seq$twopt),seq.num,phase=seq.phase,
                 twopt=input.seq$twopt), verbosity = verbosity)
  }
  else if(length(seq.rf) == 1){
    ## if the linkage phases are provided but the recombination fractions have
    ## not yet been estimated or need to be reestimated, this is done here
    ## gather two-point information
    rf.init <- get_vec_rf_out(input.seq, acum=FALSE)
    ## estimate parameters
    final.map <- est_map_hmm_out(geno=t(get(input.seq$data.name, pos=1)$geno[,seq.num]),
                                 type=get(input.seq$data.name, pos=1)$segr.type.num[seq.num],
                                 phase=seq.phases,
                                 rf.vec=rf.init,
                                 verbose=FALSE,
                                 tol=tol)
    return(structure(list(seq.num=seq.num, seq.phases=seq.phases, seq.rf=final.map$rf,
                          seq.like=final.map$loglike, data.name=input.seq$data.name,
                          twopt=input.seq$twopt), class = "sequence"))
  }
  # else
  # {
  #   final.map <- est_map_hmm_out(geno=t(get(input.seq$data.name, pos=1)$geno[,seq.num]),
  #                                type=get(input.seq$data.name, pos=1)$segr.type.num[seq.num],
  #                                phase=seq.phases,
  #                                rf.vec=seq.rf,
  #                                verbose=FALSE,
  #                                tol=tol)
  #   return(structure(list(seq.num=seq.num, seq.phases=seq.phases, seq.rf=final.map$rf,
  #                         seq.like=final.map$loglike, data.name=input.seq$data.name,
  #                         twopt=input.seq$twopt), class = "sequence"))
  # }
}

## end of file
