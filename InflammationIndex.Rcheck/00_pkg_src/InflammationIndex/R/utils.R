#' InflammationIndex: A package for analysing microglial morphology
#' 
#' The InflammationIndex package contains functions used alongside the Microglia Morphology Analysis Fiji plugin
#' 
#' @docType package
#' @name InflammationIndex
#' @import data.table
#' @import ROCR
#' @importFrom stats anova complete.cases prcomp predict var
#' @importFrom utils tail
NULL

usethis::use_package('data.table')
usethis::use_package('ROCR')
#usethis::use_testthat()