# Inflammation Index R Package

-----

## Table of Contents

1.  [Installation and Dependencies](#installation-and-dependencies)
2.  [Use with the Microglia Morphology Analysis Fiji
    Plugin](#use-with-the-microglia-morphology-analysis-fiji-plugin)
    1.  [Step 1: Loading in Data (morphPreProcessing()
        function)](#step-1-loading-in-data-morphpreprocessing-function)
          - [Retrieving IDs from the Fiji Plugin Folder
            Structure](#retrieving-ids-from-the-fiji-plugin-folder-structure)
    2.  [Step 2: Constructing the Inflammation Index (constructInfInd()
        function)](#step-2-constructing-the-inflammation-index-constructinfind-function)
    3.  [Step 3: Apply the Inflammation Index to test data
        (applyInfInd())](#step-3-apply-the-inflammation-index-to-test-data-applyinfind)

-----

## Installation and Dependencies

-----

In R the InflammationIndex package can be installed first by installing
and loading devtools to enable installing packages directly from GitHub,
then installing the InflammationIndex package from GitHub

``` r
require(devtools)
```

    ## Loading required package: devtools

    ## Loading required package: usethis

``` r
install_github("BrainEnergyLab/Inflammation-Index/R Package")
```

    ## Downloading GitHub repo BrainEnergyLab/Inflammation-Index@HEAD

Then load in the package.

``` r
require(InflammationIndex)
```

    ## Loading required package: InflammationIndex

-----

## Use with the Microglia Morphology Analysis Fiji Plugin

-----

### Step 1: Loading in Data (morphPreProcessing() function)

After users have run the Microglia Morphology Analysis Fiji plugin ([see
here](https://github.com/BrainEnergyLab/Inflammation-Index/blob/master/Using%20the%20Microglia%20Morphology%20Analysis%20ImageJ%20Plugin.md)),
the ***morphPreProcessing()*** function can be used to read in and
collate all the morphological metrics extracted.This function requires
users to specify:

  - **pixelSize**: The pixel size in microns (assuming a square pixel)
  - **morphologyWD**: The file path to the ‘Output’ folder of the
    ‘working directory’ of the Fiji plugin passed as a string
  - **animalIDs**: A string vector where each element is the ID of an
    animal that users want to extract data for
  - **treatmentIDs**: A string vector where each element is the ID of
    the treatment applied that users want to extract data for

Optional inputs:

  - **TCSExclude**: a numeric vector of mask size values that users want
    to exclude from the data collation
      - Defaults to NULL (no values are excluded)
  - **useFrac**: a boolean that indicates whether the user wants to
    include data from FracLac in their collation
      - Defaults to False

The output of the function is a data.table where each row is a cell and
the columns indicate morphological metrics.

``` r
 # Pixel size in microns
pixelSize = 0.58

# Output directory of the MicroMorph.ijm script as a string
morphologyWD = "/Microglial Morphology/Output" 

# Vector of strings identifying the names of the animals images were captured 
# from and matching the names of the Animal level folders
animalIDs = c('HIPP5', 'HIPP6', 'HIPP7')

# Vector of strings identifying different treatments and matching the names 
# of the Treatment level folders
treatmentIDs = c('Pre-LPS', 'Post-LPS') 

# Optional:

# Boolean indicating whether to use the output of the FracLac plugin
useFrac = T

# String vector of mask sizes to exclude from the preprocessing function, can also take NULL
TCSExclude = NULL
# Alternatively:
# TCSExclude = c(400, 500, 600)
```

#### Retrieving IDs from the Fiji Plugin Folder Structure

To avoid having to manually input the animal and treatment IDs, users
can use the ***getAnimalAndTreatmentIDs()*** function to return a list,
the only input is:

  - **imageStorageDirectory**: the file path to the ‘image storage
    directory’ that users used with the Fiji plugin, passed as a string

The function returns a list with two elements:

  - **treatmentIDs**: a string vector of treatment IDs
  - **animalIDs**: a string vector of animal IDs

These can be passed directly to the treatmentIDs and animalIDs arguments
in morphPreProcessing().

Here we’re using the ‘Image Storage Directory’ in the example data found
at our [Fji example data
directory](https://drive.google.com/drive/folders/1t96nDcn9MJm0WcCDIAtmUL9dnJo-L4Ar?usp=sharing)

``` r
idList = InflammationIndex::getAnimalAndTreatmentIDs(imageStorageDirectory)
treatmentIDs = idList$treatmentIDs
animalIDs = idList$animalIDs

idList
```

    ## $treatmentIDs
    ## [1] "HFD21"
    ## 
    ## $animalIDs
    ## [1] "CE1L"

Here we’re using the ‘Working Directory/Output’ in the example data
found at our [Fji example data
directory](https://drive.google.com/drive/folders/17vDC6DvMFMrDnKlWLNMphE1dfXmUCAon?usp=sharing)

``` r
output = 
  morphPreProcessing(
    pixelSize = pixelSize, morphologyWD = morphologyWD, 
    animalIDs = animalIDs, treatmentIDs = treatmentIDs,
    useFrac = useFrac)
```

The columns in the output table:

  - **Animal**: animal ID
      - These values match the values in the animalIDs input
  - **Treatment**: treatment ID
      - These values match the values in the treatmentIDs input
  - **TCSValue**: The mask size value this row’s metrics relate to
  - **UniqueID**: is a unique identifier for each row (a combination of
    animal, treatment, mask size, and name of the mask file)
  - **CellNo**: (second to last column) is an identifier for each cell
    that is duplicated if a cell has measurements taken at multiple
    TCSValue levels.

All other columns are morphological metrics.

``` r
head(output)
```

    ##    Animal Treatment TCSValue
    ## 1:   CE1L     HFD21      200
    ## 2:   CE1L     HFD21      300
    ## 3:   CE1L     HFD21      400
    ## 4:   CE1L     HFD21      500
    ## 5:   CE1L     HFD21      600
    ## 6:   CE1L     HFD21      700
    ##                                                     UniqueID
    ## 1: ce1lhfd21200candidate mask for 10-20 x 17828 y 433108 tif
    ## 2: ce1lhfd21300candidate mask for 10-20 x 17828 y 433108 tif
    ## 3: ce1lhfd21400candidate mask for 10-20 x 17828 y 433108 tif
    ## 4: ce1lhfd21500candidate mask for 10-20 x 17828 y 433108 tif
    ## 5: ce1lhfd21600candidate mask for 10-20 x 17828 y 433108 tif
    ## 6: ce1lhfd21700candidate mask for 10-20 x 17828 y 433108 tif
    ##    CellParametersPerimeter CellSpread Eccentricity Roundness SomaSize MaskSize
    ## 1:                199.8199    20.4999       1.9711   0.06554  27.9212 208.2318
    ## 2:                337.5485    24.0163       2.1762   0.03985  27.9212 361.2940
    ## 3:                337.5485    24.0163       2.1762   0.03985  27.9212 361.2940
    ## 4:                337.5485    24.0163       2.1762   0.03985  27.9212 361.2940
    ## 5:                337.5485    24.0163       2.1762   0.03985  27.9212 361.2940
    ## 6:                337.5485    24.0163       2.1762   0.03985  27.9212 361.2940
    ##    #Branches #Junctions #End-pointvoxels #Junctionvoxels #Slabvoxels
    ## 1:        23         10               13              21         111
    ## 2:        35         15               20              41         191
    ## 3:        35         15               20              41         191
    ## 4:        35         15               20              41         191
    ## 5:        35         15               20              41         191
    ## 6:        35         15               20              41         191
    ##    AverageBranchLength #Triplepoints #Quadruplepoints MaximumBranchLength
    ## 1:              4.3832             8                1             19.7442
    ## 2:              5.0535            11                3             13.4753
    ## 3:              5.0535            11                3             13.4753
    ## 4:              5.0535            11                3             13.4753
    ## 5:              5.0535            11                3             13.4753
    ## 6:              5.0535            11                3             13.4753
    ##    LongestShortestPath SkelArea CriticalValue EnclosingRadius
    ## 1:             53.8850  48.7781            NA        22.50391
    ## 2:             73.4044  84.7729      2.277565        34.10392
    ## 3:             73.4044  84.7729      2.277565        34.10392
    ## 4:             73.4044  84.7729      2.277565        34.10392
    ## 5:             73.4044  84.7729      2.277565        34.10392
    ## 6:             73.4044  84.7729      2.277565        34.10392
    ##    MaximumNumberofIntersections Skewness(sampled)
    ## 1:                            6         0.1116328
    ## 2:                            7        -0.2103932
    ## 3:                            7        -0.2103932
    ## 4:                            7        -0.2103932
    ## 5:                            7        -0.2103932
    ## 6:                            7        -0.2103932
    ##    RegressionIntercept(Semi-log)[P10-P90] RegressionCoefficient(semi-log)
    ## 1:                              -2.079957                      -0.1933260
    ## 2:                              -1.913573                      -0.1819827
    ## 3:                              -1.913573                      -0.1819827
    ## 4:                              -1.913573                      -0.1819827
    ## 5:                              -1.913573                      -0.1819827
    ## 6:                              -1.913573                      -0.1819827
    ##    MeanValue RegressionIntercept(semi-log) RamificationIndex(fit)
    ## 1:        NA                     -2.306264                     NA
    ## 2:  3.720781                     -2.206013               6.595027
    ## 3:  3.720781                     -2.206013               6.595027
    ## 4:  3.720781                     -2.206013               6.595027
    ## 5:  3.720781                     -2.206013               6.595027
    ## 6:  3.720781                     -2.206013               6.595027
    ##    Kurtosis(sampled) PolynomialDegree IntersectingRadii CentroidRadius
    ## 1:         0.8201793               NA                34       12.93391
    ## 2:        -1.5171886               27                54       18.73391
    ## 3:        -1.5171886               27                54       18.73391
    ## 4:        -1.5171886               27                54       18.73391
    ## 5:        -1.5171886               27                54       18.73391
    ## 6:        -1.5171886               27                54       18.73391
    ##    RegressionCoefficient(Log-log)[P10-P90] MaxIntersectionRadius
    ## 1:                               -2.400080              4.523901
    ## 2:                               -3.008099             10.323904
    ## 3:                               -3.008099             10.323904
    ## 4:                               -3.008099             10.323904
    ## 5:                               -3.008099             10.323904
    ## 6:                               -3.008099             10.323904
    ##    PrimaryBranches MedianofIntersections
    ## 1:               1                   3.0
    ## 2:               1                   4.5
    ## 3:               1                   4.5
    ## 4:               1                   4.5
    ## 5:               1                   4.5
    ## 6:               1                   4.5
    ##    RegressionCoefficient(semi-log)[P10-P90] RegressionIntercept(Log-log)
    ## 1:                               -0.2107465                    0.2312613
    ## 2:                               -0.1957838                    1.3719607
    ## 3:                               -0.1957838                    1.3719607
    ## 4:                               -0.1957838                    1.3719607
    ## 5:                               -0.1957838                    1.3719607
    ## 6:                               -0.1957838                    1.3719607
    ##    RamificationIndex(sampled) RegressionIntercept(Log-log)[P10-P90]
    ## 1:                          6                              1.137956
    ## 2:                          7                              2.941819
    ## 3:                          7                              2.941819
    ## 4:                          7                              2.941819
    ## 5:                          7                              2.941819
    ## 6:                          7                              2.941819
    ##    RegressionCoefficient(Log-log) SumofIntersections Kurtosis(fit)
    ## 1:                      -2.065594                120            NA
    ## 2:                      -2.517894                201     -1.568975
    ## 3:                      -2.517894                201     -1.568975
    ## 4:                      -2.517894                201     -1.568975
    ## 5:                      -2.517894                201     -1.568975
    ## 6:                      -2.517894                201     -1.568975
    ##    CentroidValue CriticalRadius MeanofIntersections
    ## 1:      3.529412             NA            3.529412
    ## 2:      3.722222       28.33172            3.722222
    ## 3:      3.722222       28.33172            3.722222
    ## 4:      3.722222       28.33172            3.722222
    ## 5:      3.722222       28.33172            3.722222
    ## 6:      3.722222       28.33172            3.722222
    ##    Density=ForegroundPixels/HullArea SpanRatio(major/minoraxis)
    ## 1:                         0.1015928                     1.8055
    ## 2:                         0.1044186                     1.9135
    ## 3:                         0.1044186                     1.9135
    ## 4:                         0.1044186                     1.9135
    ## 5:                         0.1044186                     1.9135
    ## 6:                         0.1044186                     1.9135
    ##    MaximumSpanAcrossHull     Area HullandCircularityPerimeter Circularity
    ## 1:              42.66057  689.620                    110.1972      0.7136
    ## 2:              55.68302 1163.944                    141.1598      0.7340
    ## 3:              55.68302 1163.944                    141.1598      0.7340
    ## 4:              55.68302 1163.944                    141.1598      0.7340
    ## 5:              55.68302 1163.944                    141.1598      0.7340
    ## 6:              55.68302 1163.944                    141.1598      0.7340
    ##    MaximumRadiusfromHull'sCentreofMass Max/MinRadii CVforallRadii MeanRadius
    ## 1:                            23.93289       1.8507        0.1671   19.10648
    ## 2:                            33.89595       2.4700        0.2527   23.80326
    ## 3:                            33.89595       2.4700        0.2527   23.80326
    ## 4:                            33.89595       2.4700        0.2527   23.80326
    ## 5:                            33.89595       2.4700        0.2527   23.80326
    ## 6:                            33.89595       2.4700        0.2527   23.80326
    ##    DiameterofBoundingCircle MaximumRadiusfromCircle'sCentre
    ## 1:                 43.09156                        21.54578
    ## 2:                 56.34538                        28.17269
    ## 3:                 56.34538                        28.17269
    ## 4:                 56.34538                        28.17269
    ## 5:                 56.34538                        28.17269
    ## 6:                 56.34538                        28.17269
    ##    Max/MinRadiifromCircle'sCentre CVforallRadiifromCircle'sCentre
    ## 1:                         1.5944                          0.1237
    ## 2:                         1.4317                          0.1286
    ## 3:                         1.4317                          0.1286
    ## 4:                         1.4317                          0.1286
    ## 5:                         1.4317                          0.1286
    ## 6:                         1.4317                          0.1286
    ##    MeanRadiusfromCircle'sCentre FractalDimension Lacunarity CellNo
    ## 1:                     20.06284           1.3023     0.7276      1
    ## 2:                     25.46101           1.3991     0.6822      2
    ## 3:                     25.46101           1.3991     0.6822      3
    ## 4:                     25.46101           1.3991     0.6822      4
    ## 5:                     25.46101           1.3991     0.6822      5
    ## 6:                     25.46101           1.3991     0.6822      6
    ##    BranchingDensity
    ## 1:       0.07073185
    ## 2:       0.07283246
    ## 3:       0.07283246
    ## 4:       0.07283246
    ## 5:       0.07283246
    ## 6:       0.07283246

-----

### Step 2: Constructing the Inflammation Index (constructInfInd() function)

-----

Once users have an output from the morphPreProcessing() function, they
can use this to generate an Inflammation Index based on training
conditions using the constructInfInd() function. This function takes
three required arguments:

  - **procDat**: this is the filtered data.table output by the
    morphPreProcessing() function that is limited to your positive
    control / training conditions in the ‘Treatment’ column
      - This table should have two unique values in the ‘Treatment’
        column
      - This table should have multiple ‘TCSValue’ values as the
        function compares TCS value against one another to pick the
        value that provides the best morphological discrimination
        between training conditions
  - **method**: this is a string identifying which method users want to
    use to optimise the Inflammation Index
      - ‘p value’ uses the smallest p value
      - ‘AUC’ uses a ROC-AUC analysis

In addition there are two optional arguments:

  - **noDesc**: this is an integer vector of the number of ‘best’
    descriptors to compare to one another
      - Defaults to 5:15
  - **labCols**: this is a string vector containing the names of
    non-metric columns that defaults to the identifier columns provided
    by morphPreProcessing():
      - Defaults to c(Animal, Treatment, TCSValue, UniqueID, CellNo)

The function returns a single PCA object.

``` r
# A string vector indicating the treatment labels that ID our training data
LPSGroups = c('D56', 'LPS')

# The output of the morphPreProcessing() function filtered to only include our
# training data
inDat = output[, Treatment %in% LPSGroups]

# The method to use to refine the inflammation index,
# can also take the value 'AUC
method = 'p value' 
```

Here we’re going to run this function on the example morphPreProccessing
output table found
[here](https://drive.google.com/file/d/1dtgZZuBTPg-uJaWxZy8bOav8mSJs-msY/view?usp=sharing).
It’s worth noting that this data was collated with a legacy version of
the morphPreProcessing function and doesn’t have any FracLac data
included.

``` r
head(inDat)
```

    ##    TCSValue Animal Treatment                                          UniqueID
    ## 1:      200   C3PO       LPS C3POLPSCANDIDATEMASKFORSUBSTACK(21-30)X106Y417200
    ## 2:      200   CA1R       LPS CA1RLPSCANDIDATEMASKFORSUBSTACK(21-30)X118Y398200
    ## 3:      300   CA1R       LPS CA1RLPSCANDIDATEMASKFORSUBSTACK(21-30)X118Y398300
    ## 4:      400   CA1R       LPS CA1RLPSCANDIDATEMASKFORSUBSTACK(21-30)X118Y398400
    ## 5:      500   CA1R       LPS CA1RLPSCANDIDATEMASKFORSUBSTACK(21-30)X118Y398500
    ## 6:      600   CA1R       LPS CA1RLPSCANDIDATEMASKFORSUBSTACK(21-30)X118Y398600
    ##    Perimeter CellSpread Eccentricity Roundness SomaSize MaskSize #Branches
    ## 1:    84.636     10.902        2.584     0.208   38.686  118.413         5
    ## 2:   165.991     17.138        2.741     0.130   82.754  284.931        13
    ## 3:   165.991     17.138        2.741     0.130   82.754  284.931        13
    ## 4:   266.973     19.886        2.160     0.082   82.754  465.241        19
    ## 5:   266.973     19.886        2.160     0.082   82.754  465.241        19
    ## 6:   266.973     19.886        2.160     0.082   82.754  465.241        19
    ##    #Junctions #End-pointvoxels #Junctionvoxels #Slabvoxels AverageBranchLength
    ## 1:          2                4               4          57               8.577
    ## 2:          5                9              10         119               7.498
    ## 3:          5                9              10         119               7.498
    ## 4:          9               10              18         190               8.015
    ## 5:          9               10              18         190               8.015
    ## 6:          9               10              18         190               8.015
    ##    #Triplepoints #Quadruplepoints MaximumBranchLength LongestShortestPath
    ## 1:             2                0              19.562              30.524
    ## 2:             3                2              17.482              49.970
    ## 3:             3                2              17.482              49.970
    ## 4:             8                1              15.403              65.231
    ## 5:             8                1              15.403              65.231
    ## 6:             8                1              15.403              65.231
    ##    SkelArea Ibranches(inferred) Intersectingradii Suminters. Meaninters.
    ## 1:   21.866                   3                24         58        2.42
    ## 2:   46.423                   3                34        110        3.24
    ## 3:   46.423                   3                34        110        3.24
    ## 4:   73.335                   2                46        179        3.89
    ## 5:   73.335                   2                46        179        3.89
    ## 6:   73.335                   2                46        179        3.89
    ##    Medianinters. Skewness(sampled) Kurtosis(sampled) Maxinters.
    ## 1:             3             -0.40             -1.21          4
    ## 2:             3             -0.10             -0.99          6
    ## 3:             3             -0.10             -0.99          6
    ## 4:             3              0.45             -0.98          9
    ## 5:             3              0.45             -0.98          9
    ## 6:             3              0.45             -0.98          9
    ##    Maxinters.radius Ramificationindex(sampled) Centroidradius Centroidvalue
    ## 1:             8.15                       1.33         -10.57          2.45
    ## 2:            10.35                       2.00          14.48          3.30
    ## 3:            10.35                       2.00          14.48          3.30
    ## 4:            14.41                       4.50          17.57          4.31
    ## 5:            14.41                       4.50          17.57          4.31
    ## 6:            14.41                       4.50          17.57          4.31
    ##    Enclosingradius Criticalvalue Criticalradius Meanvalue
    ## 1:           16.85          3.46           8.84      2.43
    ## 2:           24.27          5.05          10.71      3.27
    ## 3:           24.27          5.05          10.71      3.27
    ## 4:           31.23          7.73          13.20      3.93
    ## 5:           31.23          7.73          13.20      3.93
    ## 6:           31.23          7.73          13.20      3.93
    ##    Ramificationindex(fit) Skewness(fit) Kurtosis(fit) Polyn.degree
    ## 1:                   1.15         -0.56         -1.38            6
    ## 2:                   1.68         -0.31         -1.11            7
    ## 3:                   1.68         -0.31         -1.11            7
    ## 4:                   3.87          0.37         -1.16            8
    ## 5:                   3.87          0.37         -1.16            8
    ## 6:                   3.87          0.37         -1.16            8
    ##    Regressioncoefficient(Semi-log) Regressionintercept(Semi-log)
    ## 1:                            0.32                         -1.53
    ## 2:                            0.22                         -2.02
    ## 3:                            0.22                         -2.02
    ## 4:                            0.19                         -2.13
    ## 5:                            0.19                         -2.13
    ## 6:                            0.19                         -2.13
    ##    Regressioncoefficient(Semi-log)[P10-P90]
    ## 1:                                     0.33
    ## 2:                                     0.22
    ## 3:                                     0.22
    ## 4:                                     0.20
    ## 5:                                     0.20
    ## 6:                                     0.20
    ##    Regressionintercept(Semi-log)[P10-P90] Regressioncoefficient(Log-log)
    ## 1:                                  -1.49                           2.82
    ## 2:                                  -2.07                           2.77
    ## 3:                                  -2.07                           2.77
    ## 4:                                  -1.87                           2.77
    ## 5:                                  -1.87                           2.77
    ## 6:                                  -1.87                           2.77
    ##    Regressionintercept(Log-log) Regressioncoefficient(Log-log)[P10-P90]
    ## 1:                         1.45                                    2.92
    ## 2:                         1.91                                    2.79
    ## 3:                         1.91                                    2.79
    ## 4:                         2.15                                    3.13
    ## 5:                         2.15                                    3.13
    ## 6:                         2.15                                    3.13
    ##    Regressionintercept(Log-log)[P10-P90] CellNo
    ## 1:                                  1.77   5987
    ## 2:                                  2.10   5988
    ## 3:                                  2.10   5988
    ## 4:                                  3.36   5988
    ## 5:                                  3.36   5988
    ## 6:                                  3.36   5988

The constructInfInd() function will print out the mask size, and number
of descriptors, that created the Inflammation Index that was most
sensitive to the differences in morphology between the positive control
conditions according to the method passed in the method argument. It
will print the value from the method argument.

``` r
infIndOut = 
  constructInfInd(procDat = inDat,
                  method = 'p value')
```

    ## [1] "Best TCS 400"
    ## [1] "Best No. Discriminators 5"
    ## [1] "p value 1.43679512731865e-10"

-----

### Step 3: Apply the Inflammation Index to test data (applyInfInd())

-----

Users can use the applyInfInd() function to generate an Inflammation
Index for novel data using the PCA object output by constructInfInd().
All this dataset needs to have is the same metrics that were available
in the training dataset. The value of the Inflammation Index for each
cell is added as the column ‘InfInd’.

``` r
daatWithInfIndex = applyInfInd(infIndOut, output)
head(daatWithInfIndex[, list(Animal, Treatment, TCSValue, CellNo, InfInd)])
```

    ##    Animal Treatment TCSValue CellNo    InfInd
    ## 1:   BT1R       D49      800   4083 6.2153555
    ## 2: HIPP17       D30      500      1 2.7330977
    ## 3:   CE1L   D2HOURS      500      2 0.6657795
    ## 4: WICKET       D14      800   4084 5.3204217
    ## 5:   BT1R        D3      800   4085 6.3594224
    ## 6:   BU2L        D1      500      3 4.4164059
