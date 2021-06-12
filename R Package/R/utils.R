#' InflammationIndex: A package for analysing microglial morphology
#' 
#' The InflammationIndex package contains functions used alongside the Microglia Morphology Analysis Fiji plugin
#' 
#' @docType package
#' @name InflammationIndex
#' @import ROCR
#' @import tidyr
#' @import stringr
#' @import dplyr
#' @importFrom stats anova complete.cases prcomp predict var
#' @importFrom utils tail
#' @importFrom data.table := rbindlist fread as.data.table copy data.table setnames
#' @importFrom nlme lme lmeControl

NULL

usethis::use_package('data.table')
usethis::use_package('ROCR')
usethis::use_package('tidyr')
usethis::use_package('nlme')
usethis::use_package('stringr')
usethis::use_package('dplyr')
#usethis::use_testthat()