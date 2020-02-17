\name{infInd Function}
\alias{infInd}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{Function to run for full inflammation index construction and data preprocessing
%%  ~~function to do ... ~~
}
\description{This function sticks together the morphPreProcessing and constructInfInd
functions into a single call
%%  ~~ A concise (1-5 lines) description of what the function does. ~~
}
\usage{
Inflammation Index Pipeline
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{pixelSize}{Numeric value in um for the size of a pixel (assuming square pixels)}
  \item{morphologyWD}{String path pointing to the output directory from the microMorphologyAnalysis.ijm script}
  \item{TCSExclude}{String vector of TCS values to exclude from preprocessing in the form c("TCS200", "TCS300") etc., not essential}
  \item{animalIDs}{String vector of IDs for animals in the dataset, should match animal names on the images, essential}
  \item{treatmentIDs}{String vector of the treatments applied to the animals, should match names on the images}
  \item{useFrac}{Boolean describing whether to use fracLac analysis data from ImageJ}
  \item{LPSGroups}{Vector of treatments that identify non-LPS and LPS conditions (or simply non-inflammed and inflammed) so we can select measures that best descriminate between inflammed and non inflammed microglia e.g. c("Pre-LPS", "LPS")}
  \item{method}{String of what method to use to select best TCS and number of descriptors, either "p value" or "AUC" for either finding the smallest p value for the effect of LPS (tested using a linear mixed model) or AUC from a ROCAUC analysis}
  \item{otherExclusions}{A list in the form of list("Col" = "", "Cond" = "") where col indicates which column we want to use cond to exclude data from, not essential}
%%     ~~Describe \code{x} here~~
}
\details{For more detailed descriptions of the two functions involved, check their documentation
%%  ~~ If necessary, more details than the description above ~~
}
\value{Returns a list
\item{PCA Object}{A prcomp object containing the PCA run on the best TCS with the best number of descriptors where the weights for PC1 are those you apply to other data to derive the inflammation index}
\item{ProcData}{The data returned from the constructInfInd function}
\item{PreProcData}{The data output by the morphPreProcessing function}
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
\note{Requires the stringr, tidyr, data.table, ROCR, and nlme packages - but will check for their installations
and if not found will install them
%%  ~~further notes~~
}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\seealso{
%% ~~objects to See Also as \code{\link{help}}, ~~~
}
\examples{
dataOut = 
  infInd(pixelSize = 0.58, morphologyWD = getwd(),
          animalIDs = c("BG!L", "BG1R"), treatmentIDs = c("D1", "D2", "LPS"), 
          LPSGroups = c("D2", "LPS"), TCSExclude = NULL,
          method = "AUC", useFrac = T, 
          otherExclusions = list("Col" = "Diet", "Cond" = "Control"))
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ ~kwd1 }% use one of  RShowDoc("KEYWORDS")
\keyword{ ~kwd2 }% __ONLY ONE__ keyword per line
