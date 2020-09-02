Inflammation Index R Package
================

# Inflammation Index Package in R

## Step 1: Creating an Inflammation Index Based on Positive Control Conditions

In RStudio the InflammationIndex package can be installed first by
installing and loading devtools, then installing the InflammationIndex
package from GitHub

``` r
require(devtools)
install_github("BrainEnergyLab/Inflammation-Index")
require(InflammationIndex)
```

Now users should run the morphPreProcessing() function on the positive
control data. Here they should specify the pixel size in microns
(assuming a square pixel), and the morphologyWD argument should be a
string that is a path to the output folder of the working directory of
the ImageJ script. AnimalIDs should be a string vector of the names of
the Animal folders in the image storage structure, and likewise for the
TreatmentIDs argument. These treatment IDs should be the two positive
control conditions (e.g. pre- and post-LPS) This function puts together
all the output of the Fiji script analysis into a single data table
where each row is a cell and each column is a morphological measure.

``` r
pixelSize = 0.58 # Pixel size in microns
morphologyWD = "/Microglial Morphology/Output" # Output directory of the MicroMorph.ijm script as a string
animalIDs = c('HIPP5', 'HIPP6', 'HIPP7') # Vector of strings identifying the names of the animals images were captured from and matching the names of the Animal level folders
treatmentIDs = c('Pre-LPS', 'Post-LPS') # Vector of strings identifying different treatments / timepoints and matching the names of the Treatment level folders
useFrac = T # Boolean indicating whether to use the output of the FracLac plugin
TCSExclude = NULL # String vector of mask sizes to exclude from the preprocessing function, can also take NULL
```

``` r
output = 
  morphPreProcessing(
    pixelSize = pixelSize, morphologyWD = morphologyWD, 
    animalIDs = animalIDs, treatmentIDs = treatmentIDs,
    useFrac = useFrac)
```

``` r
output
```

## R Markdown

This is an R Markdown document. Markdown is a simple formatting syntax
for authoring HTML, PDF, and MS Word documents. For more details on
using R Markdown see <http://rmarkdown.rstudio.com>.

When you click the **Knit** button a document will be generated that
includes both content as well as the output of any embedded R code
chunks within the document. You can embed an R code chunk like this:

``` r
summary(cars)
```

    ##      speed           dist       
    ##  Min.   : 4.0   Min.   :  2.00  
    ##  1st Qu.:12.0   1st Qu.: 26.00  
    ##  Median :15.0   Median : 36.00  
    ##  Mean   :15.4   Mean   : 42.98  
    ##  3rd Qu.:19.0   3rd Qu.: 56.00  
    ##  Max.   :25.0   Max.   :120.00

## Including Plots

You can also embed plots, for
example:

![](Using-the-R-InflammationIndex-Package_files/figure-gfm/pressure-1.png)<!-- -->

Note that the `echo = FALSE` parameter was added to the code chunk to
prevent printing of the R code that generated the plot.
