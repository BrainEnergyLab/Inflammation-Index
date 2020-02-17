\name{constructInfInd Function}
\alias{constructInfInd}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{Function to Build the Inflammation Index from Output of morphPreProcessing
%%  ~~function to do ... ~~
}
\description{Takes the output of the morphPreProcessing function and selects the best
TCS size and number of descriptors to use to build a single composite value that is most
sensitive to the effects of LPS on microglial morphology. Loops through and checks all TCS values
in the data, and checks for the best combination of 1 through 15 of the best descriptors
to use.
%%  ~~ A concise (1-5 lines) description of what the function does. ~~
}
\usage{
Constructing the Inflammation Index
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{inDat}{Output from the morphPreProcessing function, data.table where each column is a measure, each row
  is a cell, and there are identifiers for Animal and Treatment}
  \item{LPSGroups}{Vector of treatments that identify non-LPS and LPS conditions (or simply non-inflammed and inflammed) so we can select measures that best descriminate between inflammed and non inflammed microglia e.g. c("Pre-LPS", "LPS")}
  \item{method}{String of what method to use to select best TCS and number of descriptors, either "p value" or "AUC" for either finding the smallest p value for the effect of LPS (tested using a linear mixed model) or AUC from a ROCAUC analysis}
  \item{otherExclusions}{A list in the form of list("Col" = "", "Cond" = "") where col indicates which column we want to use cond to exclude data from, not essential}
%%     ~~Describe \code{x} here~~
}
\details{
%%  ~~ If necessary, more details than the description above ~~
}
\value{Returns a list
\item{PCA Object}{A prcomp object containing the PCA run on the best TCS with the best number of descriptors where the weights for PC1 are those you apply to other data to derive the inflammation index}
\item{Data}{The input data returned as a data.table but having removed non-optimal TCS value and adding the inflammation index value on as the final column}
%%  ~Describe the value returned
%%  If it is a LIST, use
%%  \item{comp1 }{Description of 'comp1'}
%%  \item{comp2 }{Description of 'comp2'}
%% ...
}
\references{
%% ~put references to the literature/web site here ~
}
\author{Devin Clarke
%%  ~~who you are~~
}
\note{Requires the data.table, ROCR, and nlme packages, but will check for their installation
and install them if necessary
%%  ~~further notes~~
}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\seealso{
%% ~~objects to See Also as \code{\link{help}}, ~~~
}
\examples{
PCOut = 
  constructInfInd(morphPreProcessingOutput, 
    LPSGroups = c("D56", "LPS"), 
    method = "p value", 
    otherExclusions = list("Col" = "Diet", "Cond" = "Control"))
}

% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ ~kwd1 }% use one of  RShowDoc("KEYWORDS")
\keyword{ ~kwd2 }% __ONLY ONE__ keyword per line
