Inflammation Index R Package
================

## Step 1: Creating an Inflammation Index Based on Positive Control Conditions

In RStudio the InflammationIndex package can be installed first by
installing and loading devtools, then installing the InflammationIndex
package from GitHub

``` {r}
require(devtools)
install_github("BrainEnergyLab/Inflammation-Index")
require(InflammationIndex)
```

After users have run the MicroMorph.ijm script on their positive control
data, they should run the morphPreProcessing() function on this data.
Here they should specify the pixel size in microns (assuming a square
pixel), and the morphologyWD argument should be a string that is a path
to the output folder of the working directory of the ImageJ script.
AnimalIDs should be a string vector of the names of the Animal folders
in the image storage structure, and likewise for the TreatmentIDs
argument. These treatment IDs should be the two positive control
conditions (e.g. pre- and post-LPS) This function puts together all the
output of the Fiji script analysis into a single data table where each
row is a cell and each column is a morphological measure.

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

The output produced by the morphPreProcessing function has a row for
each cell, and each column represents a single morphological metric for
that
    cell.

``` r
head(output)
```

    ##    TCS Animal Treatment                                                UniqueID
    ## 1: 500 HIPP17       D30     HIPP17D30CANDIDATEMASKFORSUBSTACK(21-30)X100Y249500
    ## 2: 500   CE1L   D2HOURS   CE1LD2HOURSCANDIDATEMASKFORSUBSTACK(21-30)X100Y348500
    ## 3: 500   BU2L        D1         BU2LD1CANDIDATEMASKFORSUBSTACK(21-30)X100Y61500
    ## 4: 500   BG1L        D7        BG1LD7CANDIDATEMASKFORSUBSTACK(21-30)X101Y116500
    ## 5: 500 HIPP12   D4HOURS HIPP12D4HOURSCANDIDATEMASKFORSUBSTACK(21-30)X102Y134500
    ## 6: 500   BR1R       D-1       BR1RD-1CANDIDATEMASKFORSUBSTACK(21-30)X102Y192500
    ##    CellParametersPerimeter CellSpread Eccentricity Roundness SomaSize MaskSize
    ## 1:                 327.259     24.864        1.758     0.053   51.133  450.776
    ## 2:                 263.188     21.937        1.632     0.067   37.004  372.058
    ## 3:                 381.371     24.091        1.233     0.049   66.271  562.461
    ## 4:                 196.199     15.475        1.184     0.097   54.160  298.050
    ## 5:                 178.576     16.658        1.562     0.123   25.903  312.516
    ## 6:                 270.910     19.957        1.362     0.062   45.750  359.612
    ##    #Branches #Junctions #End-pointvoxels #Junctionvoxels #Slabvoxels
    ## 1:        32         15               17              31         214
    ## 2:        29         13               17              33         165
    ## 3:        42         19               22              37         261
    ## 4:        19          8               11              14         145
    ## 5:        17          8               10              18         112
    ## 6:        26         11               16              26         184
    ##    AverageBranchLength #Triplepoints #Quadruplepoints MaximumBranchLength
    ## 1:               5.555            13                2              20.424
    ## 2:               5.103            12                0              12.618
    ## 3:               5.225            15                3              18.062
    ## 4:               6.340             6                1              18.203
    ## 5:               5.689             8                0              16.703
    ## 6:               6.095             8                3              23.083
    ##    LongestShortestPath SkelArea Ibranches(inferred) Intersectingradii
    ## 1:              71.090   88.137                   2                45
    ## 2:              61.586   72.326                   1                46
    ## 3:              72.768  107.648                   1                45
    ## 4:              67.452   57.188                   1                29
    ## 5:              41.867   47.096                   1                32
    ## 6:              72.809   76.026                   2                41
    ##    Suminters. Meaninters. Medianinters. Skewness(sampled) Kurtosis(sampled)
    ## 1:        182        4.04           4.0              0.58             -0.10
    ## 2:        157        3.41           3.5              0.45             -0.40
    ## 3:        235        5.22           5.0              0.27             -0.99
    ## 4:        109        3.76           4.0              0.07             -0.79
    ## 5:        103        3.22           3.0              0.36             -1.26
    ## 6:        156        3.80           4.0              0.67              1.02
    ##    Maxinters. Maxinters.radius Ramificationindex(sampled) Centroidradius
    ## 1:         10            12.73                          5          18.51
    ## 2:          8            10.39                          8          20.45
    ## 3:         12            13.87                         12          15.93
    ## 4:          7             7.63                          7          12.88
    ## 5:          7             8.67                          7          10.29
    ## 6:          8             4.98                          4          20.71
    ##    Centroidvalue Enclosingradius Criticalvalue Criticalradius Meanvalue
    ## 1:          5.31           29.55          7.27          13.45      4.10
    ## 2:          4.78           29.53          5.62          10.04      3.47
    ## 3:          5.43           30.11         10.24          13.29      5.31
    ## 4:          4.11           20.39          6.59           7.42      3.85
    ## 5:          2.84           20.85          5.96           9.34      3.28
    ## 6:          5.25           27.02          7.24           5.49      3.86
    ##    Ramificationindex(fit) Skewness(fit) Kurtosis(fit) Polyn.degree
    ## 1:                   3.64          0.16         -1.20            7
    ## 2:                   5.62          0.05         -1.24            8
    ## 3:                  10.24          0.13         -1.30            7
    ## 4:                   6.59          0.37         -0.53            8
    ## 5:                   5.96          0.06         -1.61            8
    ## 6:                   3.62          0.18          0.57            7
    ##    Regressioncoefficient(Semi-log) Regressionintercept(Semi-log)
    ## 1:                            0.18                         -2.21
    ## 2:                            0.18                         -2.41
    ## 3:                            0.18                         -2.17
    ## 4:                            0.20                         -2.25
    ## 5:                            0.24                         -2.08
    ## 6:                            0.20                         -2.12
    ##    Regressioncoefficient(Semi-log)[P10-P90]
    ## 1:                                     0.18
    ## 2:                                     0.19
    ## 3:                                     0.19
    ## 4:                                     0.22
    ## 5:                                     0.26
    ## 6:                                     0.17
    ##    Regressionintercept(Semi-log)[P10-P90] Regressioncoefficient(Log-log)
    ## 1:                                  -2.14                           2.40
    ## 2:                                  -2.24                           2.27
    ## 3:                                  -1.77                           2.30
    ## 4:                                  -1.98                           2.11
    ## 5:                                  -1.73                           2.11
    ## 6:                                  -2.49                           2.48
    ##    Regressionintercept(Log-log) Regressioncoefficient(Log-log)[P10-P90]
    ## 1:                         1.14                                    2.60
    ## 2:                         0.67                                    2.64
    ## 3:                         1.04                                    2.73
    ## 4:                         0.35                                    2.46
    ## 5:                         0.02                                    2.47
    ## 6:                         1.34                                    2.38
    ##    Regressionintercept(Log-log)[P10-P90] Density=ForegroundPixels/HullArea
    ## 1:                                  1.91                            0.3795
    ## 2:                                  1.87                            0.3459
    ## 3:                                  2.55                            0.4249
    ## 4:                                  1.33                            0.4986
    ## 5:                                  1.14                            0.5921
    ## 6:                                  1.23                            0.3927
    ##    SpanRatio(major/minoraxis) MaximumSpanAcrossHull      Area
    ## 1:                     1.6004              52.92001 1187.8284
    ## 2:                     1.5544              48.58863 1075.4708
    ## 3:                     1.0666              48.81999 1323.7340
    ## 4:                     1.0969              30.82741  597.7828
    ## 5:                     1.2966              31.79438  527.8116
    ## 6:                     1.2183              41.50550  915.6808
    ##    HullandCircularityPerimeter Circularity MaximumRadiusfromHull'sCentreofMass
    ## 1:                   133.77253      0.8341                            28.08517
    ## 2:                   126.20481      0.8485                            26.72066
    ## 3:                   138.84643      0.8629                            24.98820
    ## 4:                    91.88679      0.8897                            17.00032
    ## 5:                    89.44766      0.8290                            17.04643
    ## 6:                   114.11674      0.8836                            22.75578
    ##    Max/MinRadii CVforallRadii MeanRadius DiameterofBoundingCircle
    ## 1:       1.7271        0.1870   22.61704                 52.92001
    ## 2:       1.4612        0.1307   21.49822                 48.58863
    ## 3:       1.3792        0.0704   23.13260                 48.86239
    ## 4:       1.6197        0.1141   15.05384                 32.44642
    ## 5:       1.8084        0.1520   15.11956                 32.68393
    ## 6:       1.4597        0.1167   18.81288                 41.66134
    ##    MaximumRadiusfromCircle'sCentre Max/MinRadiifromCircle'sCentre
    ## 1:                        26.46001                         2.2254
    ## 2:                        24.29434                         1.6274
    ## 3:                        24.43117                         1.3086
    ## 4:                        16.22318                         1.4536
    ## 5:                        16.34196                         1.5931
    ## 6:                        20.83064                         1.5347
    ##    CVforallRadiifromCircle'sCentre MeanRadiusfromCircle'sCentre
    ## 1:                          0.2407                     22.12306
    ## 2:                          0.1598                     21.79675
    ## 3:                          0.0684                     23.13371
    ## 4:                          0.1048                     15.00332
    ## 5:                          0.1222                     15.10042
    ## 6:                          0.0961                     19.26609
    ##    FractalDimension Lacunarity CellNo BranchingDensity
    ## 1:             1231       1039      1       0.07420011
    ## 2:              515       1698      2       0.06725055
    ## 3:             1480       1326      3       0.08132147
    ## 4:             1401        806      4       0.09566685
    ## 5:             1818        761      5       0.08922881
    ## 6:             1342        222      6       0.08302675

Following this, users should run the constructInfInd() function, where
the inDat argument is set to the output of the morphPreProcessing()
function, LPSGroups is a string vector (length of 2) of the TreatmentIDs
that identify the positive control and control groups for the experiment
(same as the treatmentIDs just fed into morphPreProcessing). Method is
the method used to identify the mask sizes that are best at
discrminating the positive control groups (can use the smallest p value
of comparisons, or the area under the curve of a receiver-operating
characteristic (ROC) analysis). The function loops through each mask
size value present, and first uses an ROC analysis to rank the
morphological measures that are best at discriminating between
inflammed/non-inflammed cells. Then, the function builds a composite
index composed of the best discriminators at each mask size, and using
the method specified to pick which mask size, and number of features
included in the composite, provides the best discrimination between the
positive control conditions. This building of a composite measure is
based on work by Heindl et al. (2018):
<https://doi.org/10.3389/fncel.2018.00106>.

``` r
inDat = output # The output of the morphPreProcessing() function
LPSGroups = c('Pre-LPS', 'Post-LPS') # Vector of strings of the positive control conditions
method = 'p value' # The method to use to refine the inflammation index, can also take the value 'AUC
noDesc = 1:15 # A vector of integers where we compare inflammation indices made up of the N best descriptors and compare them
  # E.g. when noDesc = c(1,2,3) we compare the inflammation indices made up of the 1 best discriminators, to one made of the 2 best discriminators, to one made of the 3 best discrminators.
```

``` r
infIndOut = 
  constructInfInd(inDat = inDat,
                  LPSGroups = LPSGroups,
                  method = method,
                  noDesc = 1:15)
```

    ## [1] "Best TCS 500"
    ## [1] "Best No. Discriminators 2"
    ## [1] "p value 5.89534643324896e-10"

When run, the constructInfInd function prints to the console the mask
size best at discrminating inflammation. This mask size should be noted.
The object returns is a PCA object, that can be applied to novel data
using the apply\_inf\_ind() function.

## Step 2: Running MicroMorph.ijm on Experimental Data

Using the mask size printed by the constructInfInd, users should run the
MicroMorph.ijm script on the dataset they want to apply the constructed
Inflammation Index to. In the ‘Generate masks for cells’ step users can
accomplish this by setting the upper and lower limits of the mask sizes
to the optimal mask size.

## Step 3: Running InflammationIndex on Experimental Data

Once the MicroMorph.ijm output has been generated for the experimental
data, users must run the morphPreProcessing function on this
data

``` r
non_positive_treatments = c('EXP_CONDITION_1', 'EXP_CONDITION_2')
```

``` r
# Run the morphPreProcessing() function this time on experimental data - as specified in the treatmentIDs argument in this case
output_exp_data = 
  morphPreProcessing(
    pixelSize = pixelSize, morphologyWD = morphologyWD, 
    animalIDs = animalIDs, treatmentIDs = non_positive_treatments,
    useFrac = useFrac)
```

Following this, users use the apply\_inf\_ind() function to apply to
inflammation index generated earlier. This outputs a data table that is
the same as the output\_exp\_data data table but with an extra column
added that is the inflammation index calculated for each cell. This
inflammation index metric can then be used to analyse whether the
experimental conditions have an effect on microglial morphology.

``` r
data_with_inf_index = apply_inf_ind(infIndOut, output_exp_data)
head(data_with_inf_index)
```

    ##    TCS Animal Treatment                                                UniqueID
    ## 1: 500 HIPP17       D30     HIPP17D30CANDIDATEMASKFORSUBSTACK(21-30)X100Y249500
    ## 2: 500   CE1L   D2HOURS   CE1LD2HOURSCANDIDATEMASKFORSUBSTACK(21-30)X100Y348500
    ## 3: 500   BU2L        D1         BU2LD1CANDIDATEMASKFORSUBSTACK(21-30)X100Y61500
    ## 4: 500   BG1L        D7        BG1LD7CANDIDATEMASKFORSUBSTACK(21-30)X101Y116500
    ## 5: 500 HIPP12   D4HOURS HIPP12D4HOURSCANDIDATEMASKFORSUBSTACK(21-30)X102Y134500
    ## 6: 500   BR1R       D-1       BR1RD-1CANDIDATEMASKFORSUBSTACK(21-30)X102Y192500
    ##    CellParametersPerimeter CellSpread Eccentricity Roundness SomaSize MaskSize
    ## 1:                 327.259     24.864        1.758     0.053   51.133  450.776
    ## 2:                 263.188     21.937        1.632     0.067   37.004  372.058
    ## 3:                 381.371     24.091        1.233     0.049   66.271  562.461
    ## 4:                 196.199     15.475        1.184     0.097   54.160  298.050
    ## 5:                 178.576     16.658        1.562     0.123   25.903  312.516
    ## 6:                 270.910     19.957        1.362     0.062   45.750  359.612
    ##    #Branches #Junctions #End-pointvoxels #Junctionvoxels #Slabvoxels
    ## 1:        32         15               17              31         214
    ## 2:        29         13               17              33         165
    ## 3:        42         19               22              37         261
    ## 4:        19          8               11              14         145
    ## 5:        17          8               10              18         112
    ## 6:        26         11               16              26         184
    ##    AverageBranchLength #Triplepoints #Quadruplepoints MaximumBranchLength
    ## 1:               5.555            13                2              20.424
    ## 2:               5.103            12                0              12.618
    ## 3:               5.225            15                3              18.062
    ## 4:               6.340             6                1              18.203
    ## 5:               5.689             8                0              16.703
    ## 6:               6.095             8                3              23.083
    ##    LongestShortestPath SkelArea Ibranches(inferred) Intersectingradii
    ## 1:              71.090   88.137                   2                45
    ## 2:              61.586   72.326                   1                46
    ## 3:              72.768  107.648                   1                45
    ## 4:              67.452   57.188                   1                29
    ## 5:              41.867   47.096                   1                32
    ## 6:              72.809   76.026                   2                41
    ##    Suminters. Meaninters. Medianinters. Skewness(sampled) Kurtosis(sampled)
    ## 1:        182        4.04           4.0              0.58             -0.10
    ## 2:        157        3.41           3.5              0.45             -0.40
    ## 3:        235        5.22           5.0              0.27             -0.99
    ## 4:        109        3.76           4.0              0.07             -0.79
    ## 5:        103        3.22           3.0              0.36             -1.26
    ## 6:        156        3.80           4.0              0.67              1.02
    ##    Maxinters. Maxinters.radius Ramificationindex(sampled) Centroidradius
    ## 1:         10            12.73                          5          18.51
    ## 2:          8            10.39                          8          20.45
    ## 3:         12            13.87                         12          15.93
    ## 4:          7             7.63                          7          12.88
    ## 5:          7             8.67                          7          10.29
    ## 6:          8             4.98                          4          20.71
    ##    Centroidvalue Enclosingradius Criticalvalue Criticalradius Meanvalue
    ## 1:          5.31           29.55          7.27          13.45      4.10
    ## 2:          4.78           29.53          5.62          10.04      3.47
    ## 3:          5.43           30.11         10.24          13.29      5.31
    ## 4:          4.11           20.39          6.59           7.42      3.85
    ## 5:          2.84           20.85          5.96           9.34      3.28
    ## 6:          5.25           27.02          7.24           5.49      3.86
    ##    Ramificationindex(fit) Skewness(fit) Kurtosis(fit) Polyn.degree
    ## 1:                   3.64          0.16         -1.20            7
    ## 2:                   5.62          0.05         -1.24            8
    ## 3:                  10.24          0.13         -1.30            7
    ## 4:                   6.59          0.37         -0.53            8
    ## 5:                   5.96          0.06         -1.61            8
    ## 6:                   3.62          0.18          0.57            7
    ##    Regressioncoefficient(Semi-log) Regressionintercept(Semi-log)
    ## 1:                            0.18                         -2.21
    ## 2:                            0.18                         -2.41
    ## 3:                            0.18                         -2.17
    ## 4:                            0.20                         -2.25
    ## 5:                            0.24                         -2.08
    ## 6:                            0.20                         -2.12
    ##    Regressioncoefficient(Semi-log)[P10-P90]
    ## 1:                                     0.18
    ## 2:                                     0.19
    ## 3:                                     0.19
    ## 4:                                     0.22
    ## 5:                                     0.26
    ## 6:                                     0.17
    ##    Regressionintercept(Semi-log)[P10-P90] Regressioncoefficient(Log-log)
    ## 1:                                  -2.14                           2.40
    ## 2:                                  -2.24                           2.27
    ## 3:                                  -1.77                           2.30
    ## 4:                                  -1.98                           2.11
    ## 5:                                  -1.73                           2.11
    ## 6:                                  -2.49                           2.48
    ##    Regressionintercept(Log-log) Regressioncoefficient(Log-log)[P10-P90]
    ## 1:                         1.14                                    2.60
    ## 2:                         0.67                                    2.64
    ## 3:                         1.04                                    2.73
    ## 4:                         0.35                                    2.46
    ## 5:                         0.02                                    2.47
    ## 6:                         1.34                                    2.38
    ##    Regressionintercept(Log-log)[P10-P90] Density=ForegroundPixels/HullArea
    ## 1:                                  1.91                            0.3795
    ## 2:                                  1.87                            0.3459
    ## 3:                                  2.55                            0.4249
    ## 4:                                  1.33                            0.4986
    ## 5:                                  1.14                            0.5921
    ## 6:                                  1.23                            0.3927
    ##    SpanRatio(major/minoraxis) MaximumSpanAcrossHull      Area
    ## 1:                     1.6004              52.92001 1187.8284
    ## 2:                     1.5544              48.58863 1075.4708
    ## 3:                     1.0666              48.81999 1323.7340
    ## 4:                     1.0969              30.82741  597.7828
    ## 5:                     1.2966              31.79438  527.8116
    ## 6:                     1.2183              41.50550  915.6808
    ##    HullandCircularityPerimeter Circularity MaximumRadiusfromHull'sCentreofMass
    ## 1:                   133.77253      0.8341                            28.08517
    ## 2:                   126.20481      0.8485                            26.72066
    ## 3:                   138.84643      0.8629                            24.98820
    ## 4:                    91.88679      0.8897                            17.00032
    ## 5:                    89.44766      0.8290                            17.04643
    ## 6:                   114.11674      0.8836                            22.75578
    ##    Max/MinRadii CVforallRadii MeanRadius DiameterofBoundingCircle
    ## 1:       1.7271        0.1870   22.61704                 52.92001
    ## 2:       1.4612        0.1307   21.49822                 48.58863
    ## 3:       1.3792        0.0704   23.13260                 48.86239
    ## 4:       1.6197        0.1141   15.05384                 32.44642
    ## 5:       1.8084        0.1520   15.11956                 32.68393
    ## 6:       1.4597        0.1167   18.81288                 41.66134
    ##    MaximumRadiusfromCircle'sCentre Max/MinRadiifromCircle'sCentre
    ## 1:                        26.46001                         2.2254
    ## 2:                        24.29434                         1.6274
    ## 3:                        24.43117                         1.3086
    ## 4:                        16.22318                         1.4536
    ## 5:                        16.34196                         1.5931
    ## 6:                        20.83064                         1.5347
    ##    CVforallRadiifromCircle'sCentre MeanRadiusfromCircle'sCentre
    ## 1:                          0.2407                     22.12306
    ## 2:                          0.1598                     21.79675
    ## 3:                          0.0684                     23.13371
    ## 4:                          0.1048                     15.00332
    ## 5:                          0.1222                     15.10042
    ## 6:                          0.0961                     19.26609
    ##    FractalDimension Lacunarity CellNo BranchingDensity      InfInd
    ## 1:             1231       1039      1       0.07420011  0.02277333
    ## 2:              515       1698      2       0.06725055  1.50402880
    ## 3:             1480       1326      3       0.08132147 -1.01412498
    ## 4:             1401        806      4       0.09566685  0.73192524
    ## 5:             1818        761      5       0.08922881  0.06343808
    ## 6:             1342        222      6       0.08302675  0.43285031
