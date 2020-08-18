# This function is for preprocessing the microglial morphology data output by 
# the MicrogliaMorphologyAnalysis.ijm ImageJ script
morphPreProcessing <- function(pixelSize,
                               morphologyWD,
                               TCSExclude = NULL,
                               animalIDs,
                               treatmentIDs,
                               useFrac = NULL) {
  
  exit = F
  if(is.null(pixelSize)) {
    exit = T
    print("Need to provide a pixelSize in um")
  }
  
  if(is.null(morphologyWD)) {
    exit = T
    print("Need to provide a directory (morphologyWD) for input files")
  }
  
  if(is.null(animalIDs)) {
    exit = T
    print("Need to provide a vector of animal IDs")
  } else {
    animalIDs = toupper(animalIDs)
  }
  
  if(is.null(treatmentIDs)) {
    exit = T
    print("Need to provide a vector of treatment IDs")
  } else {
    treatmentIDs = toupper(treatmentIDs)
  }
  
  if(exit == T) {
    return(NULL)
  }
  
  # List to store the pattern we'll search in our directory for each data type,
  # as well as the character that separates fields in the data, and the 
  # character that separates headers, also fileEncoding argument since on some
  # occassions we need to change it, and the column we'll refer to to assign
  # animal/timepoint info in forInfo
  storageList = 
    list("Cell Parameters" = 
           list("Pattern" = "Cell Parameters.csv", "Sep" = ",",
                "HeadSep" = ",", "fileEncoding" = "unknown",
                "forInfo" = "Location"),
         "Sholl Parameters" = 
           list("Pattern" = "[0-9] \\.csv","Sep" = ",","HeadSep" = ",",
                "fileEncoding" = "Latin-1","forInfo" = "Location"))
  
  # Specify the directories to search through, and the storageList for non-FracLac results
  dirToUse = list(morphologyWD)
  passList = list(storageList)
  
  # If we're using the fraclac outpu
  if(useFrac == T) {
    
    # List the files in the morphology WD input that have fracLac in the name
    lacDir = dir(path = morphologyWD, pattern = "fracLac", full.names = T, recursive = F, ignore.case = T)
    
    # Create a storeList-like object for fracLac
    fracList = list("Hull and Circularity" = 
                      list("Pattern" = "Hull and Circle Results.txt","Sep" = "\t",
                           "HeadSep" = "\t","fileEncoding" = "unknown","forInfo" = "ID"),
                    "FracLac" = 
                      list("Pattern" = "Scan Types.txt","Sep" = "\t","HeadSep" = "\t",
                           "fileEncoding" = "unknown","forInfo" = "ID"))
    
    # Put together the storageList and fracList, as well as the directories to search within
    storageList = c(storageList, fracList)
    dirToUse = c(morphologyWD, lacDir)
    passList = list(storageList[1:2], storageList[3:4])
    
  }
  
  
  # Loop through the first 3 then last 2 parts of storageList, changing where
  # we grab our data from for each
  comboList = Map(function(e, f) {
    
    # For each element in storageList, add a locations, files, and labels 
    # section which contains strings of the paths of all the files, data frames
    # for each file, and the animal and timepoint label of that file
    out = lapply(e, function(x, y) {
      
      x$Locations = list.files(path = y, pattern = x$Pattern, full.names = T, 
                               recursive = T, ignore.case = T);
      x$Locations[sapply(x$Locations, is.null)] <- NULL
      
      if(is.null(TCSExclude)==F) {
        # Exclude TCS values
        x$Locations = x$Locations[!str_detect(x$Locations, paste(TCSExclude, collapse = "|"))]
        x$Locations = x$Locations[is.na(x$Locations)==F]
      }
      
      x$Files = rbindlist(Map(function(x, y, z) {
        if(grepl("Scan", x)) {
          gotGaps = strsplit(readLines(file(x, encoding = "UTF-8")), "\t")
          closeAllConnections()
          asMatrix = do.call(rbind, gotGaps)
          temp = as.data.frame(asMatrix[-1,])
          names(temp) = asMatrix[1,]
          temp = as.data.table(temp)
        } else {
          temp = 
            fread(x, sep = y, na.strings = "NaN", encoding = z,header = T)
        }
        
        temp[, Location := x]
        return(temp)
      }, x$Locations, x$Sep, x$fileEncoding))
      
      return(x)}, f)
  }, passList, dirToUse)
  
  if(useFrac == T) {
    # Put the output together into a single list
    storageList = c(comboList[[1]], comboList[[2]])
  } else {
    storageList = comboList[[1]]
  }
  
  # mapStuff is a bunch of stuff we need to add onto each data type that its 
  # missing, this is either cell identifiers, or values for the TCS. These are
  # calculated using the file locations or IDs of the rows
  mapStuff = 
    list(
      "Sholl Parameters" = 
        list("TCS" = 
               with(storageList$`Sholl Parameters`, 
                    substring(Locations, regexpr("TCS", Locations)+3, 
                              regexpr("/Results", Locations)-1))))
  
  # A list of all the columns we want to remove from the associated data types,
  # these are columns that we won't be using in the analysis
  colsToRemove = 
    list("Sholl Parameters" = 
           c("Polyn. R^2", "Regression R^2 (Semi-log)",
             "Regression R^2 (Semi-log) [P10-P90]", "Regression R^2 (Log-log)", 
             "Regression R^2 (Log-log) [P10-P90]", "Unit", "Lower threshold", 
             "Upper threshold", "X center (px)", "Y center (px)",
             "Z center (slice)", "Starting radius", "Ending radius", "Radius step",
             "Samples/radius", "Enclosing radius cutoff", "I branches (user)"))
  
  if(useFrac == T) {
    storageList$`Hull and Circularity`$Files[, Location := NULL]
    storageList$`FracLac`$Files[, Location := NULL]
    # Change the names of the hull and circularity files so that we remove the
    # NA column name at the end and shift the names to the right by 1, relabelling
    # the first column as ID
    names(storageList$`Hull and Circularity`$Files)[1] = "Location"
    
    # Remove the last column in the fracLac file as its empty, then change the 
    # name of the first column to ID
    names(storageList$FracLac$Files)[1] = "Location"
    
    # For the ID value, get the characters to the left of the underscore
    storageList$FracLac$Files[, Location := sapply(strsplit(as.character(Location), "_"),function(x) x[1])]
    
    # Retain every 2nd row of the FracLac data (the data is in triplicate, where
    # the first and 3rd row are readings with formula for fractal dimensions
    # that we don't want to use)
    storageList$FracLac$Files = 
      storageList$FracLac$Files[rep(c(F,T,F), nrow(storageList$FracLac$Files)/3),]
    
    # Change the names for the fractal dimension and lacunarity measurements to be
    # readable
    names(storageList$FracLac$Files)[grep("^6. ", names(storageList$FracLac$Files))] = "FractalDimension"
    names(storageList$FracLac$Files)[grep("^16. ", names(storageList$FracLac$Files))] = "Lacunarity"
    
    toAdd = list("Hull and Circularity" = 
                   list("TCS" = 
                          with(storageList$`Hull and Circularity`$Files,
                               substring(unlist(Location),regexpr("^(TCS)[0-9]*", 
                                                                  unlist(Location)) +3, 
                                         attributes(regexpr("^(TCS)[0-9]*", 
                                                            unlist(Location)))$match.length)),
                        "CellName" = 
                          with(storageList$`Hull and Circularity`$Files,
                               substring(as.character(Location), regexpr("CANDIDATE", 
                                                                         toupper(as.character(Location))),
                                         regexpr("TIF", toupper(as.character(Location)))-1))),
                 "FracLac" = 
                   list("TCS" = 
                          with(storageList$FracLac$Files,
                               substring(unlist(Location),regexpr("^(TCS)[0-9]*", 
                                                                  unlist(Location)) +3, 
                                         attributes(regexpr("^(TCS)[0-9]*", 
                                                            unlist(Location)))$match.length)),
                        "CellName" =
                          with(storageList$FracLac$Files,
                               substring(as.character(Location), regexpr("CANDIDATE", toupper(as.character(Location))),
                                         regexpr("TIF", toupper(as.character(Location)))-1))))
    mapStuff = c(mapStuff,toAdd)
    
  }
  
  # Looping through the storageList section we need to edit, and then looping
  # through the things to edit for that section, we add on the sections and
  # rename the names in the data table to what we've added
  
  # For some reason setting columns with := not working so just cbind
  for(currMap in names(mapStuff)) {
    storageList[[currMap]]$Files = cbind(storageList[[currMap]]$Files, as.data.table(mapStuff[[currMap]]))
  }
  
  # Next we subset out cells we don't want to keep in our cell parameter data
  # by removing cells that weren't analysed in ImageJ because they didn't pass
  # quality control, or were taken on an imaging session where the objective
  # ini file was wrongly calibrated so the pixel size isn't what we have the
  # values for. For sholl parameters, we subset out cells where we know the
  # pixel size isn't 0.58 as we expect.
  storageList$`Cell Parameters`$Files = 
    storageList$`Cell Parameters`$Files[Analysed == 1,]
  storageList$`Sholl Parameters`$Files =
    storageList$`Sholl Parameters`$Files[`Radius step` == pixelSize, ]
  
  # Change the name of the image column to CellName in the sholl parameter
  # data since this makes it consistent with the other data forms, also the
  # Cell Name column in cell parameters
  setnames(storageList$`Sholl Parameters`$Files, old = "Image", new = "CellName")
  setnames(storageList$`Cell Parameters`$Files, old = "Cell Name", new = "CellName")
  
  wheresTif = grepl(".tif", storageList$`Cell Parameters`$Files$CellName)
  storageList$`Cell Parameters`$Files[wheresTif, CellName := sapply(strsplit(CellName, ".tif"), function(x) x[1])]
  storageList$`Cell Parameters`$Files[wheresTif==FALSE, CellName := gsub(" ", "", paste("Candidate mask for ", `Stack Position`, CellName), fixed = T)]
  
  # Add a uniqueID value to every data type, where we paste the animal, 
  # timepoint, cellname, and TCS together with no spaces so we have an 
  # identifier of every unique measurement that we can check across data types -
  # also note we make it all uppercase
  for(currType in names(storageList)) {
    storageList[[currType]]$Files[, c("Animal", "CellName") :=
                                    list(toupper(sapply(toupper(Location), function(x, y) y[str_detect(x, y)], animalIDs)),
                                         toupper(gsub(" ", "", CellName)))]
    checkAgainst = paste(treatmentIDs, "(?![0-9])", sep = "")
    storageList[[currType]]$Files[, Location := toupper(gsub(" ", "", Location, fixed = T))]
    for(currTreat in 1:length(treatmentIDs)) {
      storageList[[currType]]$Files[regexpr(checkAgainst[currTreat], Location, perl = T)>-1, Treatment := treatmentIDs[currTreat]] 
    }
    storageList[[currType]]$Files[, UniqueID := toupper(paste(Animal, Treatment, CellName, TCS, sep = ""))]
  }
  
  # Get out a list containing all the uniqueIDs for each data type before 
  # finding the intersection of all the uniqueID vectors
  uniqueIDList = lapply(storageList, function(x) {
    x$Files$UniqueID
  })
  Intersections = Reduce(intersect, uniqueIDList)
  
  rm("uniqueIDList")
  
  # Subset out the uniqueIDs that aren't present in all of the data types so
  # that we only end up with data where we have a complete set of measurements
  # for each cell
  for(currType in names(storageList)) {
    storageList[[currType]]$Files = storageList[[currType]]$Files[UniqueID %in% Intersections]
  }
  
  if(useFrac == T) {
    # A vector of the fracLac columns we want to keep
    fracToKeep = 
      c("Animal", "Treatment", "TCS", "CellName", "UniqueID", "FractalDimension", "Lacunarity")
    
    # A list of all the columns we want to remove from the associated data types,
    # these are columns that we won't be using in the analysis
    toRemove = 
      list("Hull and Circularity" = 
             c("MEAN FOREGROUND PIXELS", "TOTAL PIXELS", "Hull's Centre of Mass",
               "Width of Bounding Rectangle", "Height of Bounding Rectangle",
               "Circle's Centre", "Method Used to Calculate Circle"))
    
    # Add on the fracLac colstoRemove by selecting those that aren't in fractoKeep
    toRemove$FracLac = 
      names(storageList$FracLac$Files)[!(names(storageList$FracLac$Files) %in% fracToKeep)]
    
    colsToRemove = c(colsToRemove, toRemove)
    
    # Vector of measures in the hull and ciricularity data we want to convert from
    # pixels to um, and a vector of the numbers to multiple by respectively to do
    # that
    convToUm = 
      c("Area", "Perimeter", "Diameter of Bounding Circle", "Mean Radius", 
        "Maximum Span Across Hull", "Maximum Radius from Hull's Centre of Mass",
        "Maximum Radius from Circle's Centre", "Mean Radius from Circle's Centre")
    multiplyBy = rep(pixelSize, length(convToUm))
    multiplyBy[1] = pixelSize^2
    names(multiplyBy) = convToUm
    
    # For each column to convert, convert it
    for(currCol in convToUm) {
      storageList$`Hull and Circularity`$Files[[currCol]] = 
        as.numeric(unlist(storageList$`Hull and Circularity`$Files[[currCol]])) * multiplyBy[[currCol]]
    }
    
    # We now add "ConvexHull" to precede the following columns in the hull and 
    # circularity data since otherwise we would have duplicate column names with
    # the cell parameter data
    namesToChange = c("Area", "Perimeter", "Circularity")
    setnames(storageList$`Hull and Circularity`$Files, old = namesToChange, new = paste("ConvexHull", namesToChange, sep = ""))
  }
  
  for(currType in names(colsToRemove)) {
    temp = list()
    length(temp) = length(colsToRemove[[currType]])
    storageList[[currType]]$Files[, colsToRemove[[currType]] := temp]
  }
  
  # For all the data, remove spaces from the headers, and from the cellName
  # values to make them consistent between data types
  storageList = 
    lapply(storageList, function(x) { 
      names(x$Files) = gsub(" ", "", names(x$Files))
      x$Files$CellName = gsub(" ", "", x$Files$CellName)
      return(x) 
    })
  
  # Get out the data for the elements of storageList to merge together
  forMerge = lapply(storageList, function(x) {
    x$Files[, c("Animal", "Treatment", "CellName", "TCS", "UniqueID") :=
              list(as.character(unlist(Animal)), as.character(unlist(Treatment)),
                   as.character(unlist(CellName)), as.numeric(unlist(TCS)),
                   as.character(unlist(UniqueID)))]
    if("Location" %in% names(x$Files)) {
      x$Files[, Location := NULL]
    }
    return(x$Files)
  })
  
  # Merge everything except sholl profile together, create a unique name
  # but that could be repeated across TCS values, and assign each unique value
  # of that a number - then merge in the csvMerged info
  # mergeNames = names(storageList)[-which(names(storageList) == "Sholl Profile")]
  mergeNames = names(storageList)
  merged = Reduce(merge, forMerge[mergeNames])
  merged[, TCSName := paste(Treatment, Animal, CellName)]
  addNo = data.table("TCSName" = unique(merged$TCSName), "CellNo" = seq_along(unique(merged$TCSName)))
  merged = merge(merged, addNo, by = "TCSName")
  
  rm("addNo")
  
  merged = cbind("CellNo" = merged$CellNo, merged[, (which(names(merged) == "CellNo")) := NULL])
  if(useFrac == T) {
    merged$BranchingDensity = merged$SkelArea / merged$ConvexHullArea
  }
  
  # # Here we create a new data table where we merged in the sholl profile data,
  # # and store this as well as the non sholl profile merged table in a list
  # mergedProf =  merge(merged, forMerge$`Sholl Profile`, by = c("Animal", "Treatment", "CellName", "UniqueID", "TCS"))
  
  rm("forMerge")
  
  # storageList$merged = list("All" = mergedProf, "NoProf" = merged)
  storageList$merged = list("NoProf" = merged)
  
  # rm("mergedProf", "merged")
  rm("merged")
  
  # Create a list of columns to remove from the final merged DF
  mergeToRemove = c("TCSName", "CellName",  "Analysed", "StackPosition", "ExperimentName", "WrongObjective")
  
  # Remove the columns from merge to remove
  for(currOne in names(storageList$merged)) {
    for(currRemove in mergeToRemove) {
      if(currRemove %in% names(storageList$merged[[currOne]])) {
        storageList$merged[[currOne]][, (currRemove) := NULL]
      }
    }
  }
  
  startAt = which(names(storageList$merged$NoProf) == "UniqueID")+1
  for(currCol in names(storageList$merged$NoProf)[startAt:ncol(storageList$merged$NoProf)]) {
    storageList$merged$NoProf[, (currCol) := as.numeric(get(currCol))]
  }
  
  return(storageList$merged$NoProf)
  
}

# Takes in the data.table output by morphPreProcessing(), a vector of which groups are the positive control groups in the
# data, and a list indicating what other conditions to specify for the positive control data
# Returns the positive control data
filter_by_training_data = function(inDat, posControlGroups, otherExclusions) {

  # Get out the positive control data, and if we have specified otherExclusions, get out the data that corresponds to this 
  procDat = inDat[Treatment %in% posControlGroups]
  if(is.null(otherExclusions) == F) {
    for(currCol in 1:length(otherExclusions$Col)) {
      if(otherExclusions$Col[currCol] %in% names(procDat)) {
        procDat = procDat[as.vector(procDat[, otherExclusions$Col[currCol], with = F] == otherExclusions$Cond[currCol])]
      }
    }
  }
  return(procDat)
}

# Takes the output of filter_by_training_data, and a vector of column names that label our data
# Returns a list including the data where all metrics are gathered into a single column (aggData),
# as well as data where each column is a metric (merged), and a vector of which label column names we have (toMove)
format_rocr_input = function(procDat, labCols) {
  
  # Gather the data across all measurements and label columns we're using
  aggData = 
    as.data.table(gather(procDat, Parameter, Value, (which(!(names(procDat) %in% labCols)))))
  aggData[, c("Parameter", "Value", "Treatment") := list(factor(Parameter, levels = unique(Parameter)), as.numeric(Value), as.factor(Treatment))]
  
  # Order our gathered data by parameter name
  aggData = 
    aggData[order(Parameter), c("CellNo","Animal","Treatment","TCS","Parameter","Value")]
  
  # Here we then spread the data but put our columns in alphabetical order
  merged = spread(aggData, Parameter, Value)
  merged = merged[order(merged$Treatment), ]
  toMove = 
    c("Animal", "Treatment", "CellNo", "TCS")
  
  return(list('aggData' = aggData,
              'merged' = merged,
              'toMove' = toMove))
  
}

# Takes the aggData output by format_rocr_input and the name of a metric
# Returns a data.table indicating the AUC value from an ROC-AUC analysis for the metric
get_ROC_values = function(aggData, currParam) {
  
  # For the current metric, calculate an ROC curve for it and return the AUC value
  forPref = 
    aggData[Parameter == currParam, ]
  pred = ROCR::prediction(aggData[Parameter == currParam, Value], aggData[Parameter == currParam, Treatment])
  perf = ROCR::performance(pred, "auc")
  forPlot =  ROCR::performance(pred,"tpr","fpr")
  AUC = perf@y.values[[1]]
  return(data.table(
    #"FPR" = unlist(forPlot@x.values), "TPR" = unlist(forPlot@y.values),
    "AUC" = AUC, "Parameter" = currParam))
  
  return(unique(rbindlist(ROCList)[, list(AUC, Parameter)]))
}

# Takes a vector of metric names
# Returns a list where we paste the string associated with sholl analysis percentile metrics
identify_variant_percentile_metrics = function(topParams) {
  check_list = list()
  for(currParam in topParams) {
    toCheck = paste(toupper(currParam), "[P10-P90]", sep = "")
    check_list[[currParam]] = toCheck
  }
  
  return(check_list)
}

# Takes vector of metric names
# Returns a list with the strings associated with the sholl analysis fit or sampled metrics
identify_variant_sholl_metrics = function(topParams) {
  check_list = list()
  for(currParam in topParams) {
    # If we have any measures based on the fit or sampled data, check to see if
    # there is a duplicate and pick the best one
    if(grepl("(FIT)", toupper(currParam)) || grepl("(SAMPLED)", toupper(currParam))) {
      withoutPs = strsplit(toupper(currParam), "\\(")[[1]][1]
      if(grepl("(FIT)", toupper(currParam))) {
        toCheck = paste(withoutPs, "(SAMPLED)", sep = "")
        check_list[[currParam]] = toCheck
      } else if (grepl("(SAMPLED)", toupper(currParam))) {
        toCheck = paste(withoutPs, "(FIT)", sep = "")
        check_list[[currParam]] = toCheck
      }
    }
  }
  
  return(check_list)
}

# Takes a vector of metric names
# Returns a list with the strings attached to check for variants of the hull and circularity morphometric measures
identify_variant_hcl_metrics = function(topParams){
  check_list = list()
  count = 1
  for(currParam in topParams) {
    # If we have measures that are based on the circle centre, check if there is
    # the same measure based on the centre of mass, if so, remove the one with
    # the lowest AUC
    if(grepl(paste(currParam, "fromHull'sCentreofMass", sep = ""), (topParams)) || grepl(paste(currParam, "fromCircle'sCentre", sep = ""), (topParams))) {
      toCheck = c(currParam, paste(currParam, "fromHull'sCentreofMass", sep = ""), paste(currParam, "fromCircle'sCentre", sep = ""))
      check_list[[count]] = toCheck
      count = count + 1
    }
    
    if(grepl("fromHull'sCentreofMass", currParam) || grepl("fromCircle'sCentre", currParam)) {
      without = strsplit(toupper(currParam), "FROM")[[1]][1]
      toCheck = c(currParam, paste(without, "fromHull'sCentreofMass", sep = ""), paste(without, "fromCircle'sCentre", sep = ""))
      check_list[[count]] = toCheck
      count = count + 1
    }
    
    without = strsplit(toupper(currParam), "FROM")[[1]][1]
    if(grepl(paste(without, toupper("fromHull'sCentreofMass"), sep = ""), toupper(topParams)) || grepl(paste(without, toupper("fromCircle'sCentre"), sep = ""), toupper(topParams))) {
      toCheck = c(currParam, paste(currParam, "fromHull'sCentreofMass", sep = ""), paste(currParam, "fromCircle'sCentre", sep = ""))
      check_list[[count]] = toCheck
      count = count + 1
    }
    
  }
  return(check_list)
}

# Takes a vector of metrics
# Acts as a wrapper function that gets lists of metric names to check (i.e. the possible variants the metrics vector input)
# Returns all these lists joined together
identify_all_variants_to_check = function(topParams) {
  
  check_variant_perc = identify_variant_percentile_metrics(topParams)
  
  check_variant_sholl = identify_variant_sholl_metrics(topParams)
  
  check_variant_hcl = identify_variant_hcl_metrics(topParams)
  
  total_check_list = c(check_variant_perc, check_variant_sholl, check_variant_hcl)
  
  return(total_check_list)
  
}

# Takes a data.table output by get_ROC_values (where we need to have the parameters that are in the topParams input), 
# a list output by identify_all_variants_to_check (or its constituent functions), and a vector of metrics
# Returns a vector of metrics where the worst performing variant of any metrics present in two forms in the input vector
# is removed
remove_worst_duplicate_metric = function(paramByAuc, toCheck, topParams){
  if(sum(grepl(paste(toupper(toCheck), collapse = '|'), toupper(topParams)))>0) {
    getRid = 
      paramByAuc[toupper(Parameter) %in% toupper(toCheck), Parameter][which.min(paramByAuc[toupper(Parameter) %in% toupper(toCheck), AUC])]
    topParams = topParams[!(topParams %in% getRid)]
  }
  return(topParams)
}

# Takes a vector of metrics, and a data.table output by get_ROC_values
# Acts as a wrapper around iedntify_all_variants_to_check so we can get all the variants names to check
# Then removes the worst performing variants
# Returns a vector of metric names with the worst performing metrics removed
remove_worst_performing_variants = function(topParams, paramByAuc) {
  
  # Identify all the variant metrics in topParams
  total_check_list = identify_all_variants_to_check(topParams)
  
  # For each metric present in two variants, remove the lowest performing variant re: AUC value
  for(curr_element in 1:length(total_check_list)){
    topParams = remove_worst_duplicate_metric(paramByAuc, total_check_list[[curr_element]], topParams)
  }
  
  return(topParams)
  
} 

# Takes the output of format_rocr_input and the output of remove_worst_performing_variants
# Returns a data.table with the columns specified in topParams and the label columns
# specified in forInfIndex
# Excludes columns that have 0 variance
format_top_metric_data = function(format_list, topParams) {
  
  # Put together our metric columns that are in topParams with identifying
  # and remove any rows with NAs
  forInfIndex = format_list$merged[, c(format_list$toMove, topParams), with = F]
  forInfIndex = forInfIndex[complete.cases(forInfIndex)]
  
  # Cbind our identifying columns with our metric columns that have been converted to numeric (just to make sure they are)
  forInfIndex = 
    cbind(forInfIndex[, (format_list$toMove), with = F], forInfIndex[, sapply(.SD, function(x) as.numeric(x)), .SDcols = topParams])
  
  # Remove any columns where variance is 0 - identify these columns then set their values to NULL
  zeroVar = topParams[which(forInfIndex[, sapply(.SD, function(x) var(scale(as.numeric(x)), na.rm = T)), .SDcols = topParams] == 0)]
  if(length(zeroVar)!= 0) {
    temp = list()
    length(temp) = length(zeroVar)
    forInfIndex[, (zeroVar) := temp]
  }
  
  # If we now have no columns, warn the user
  if(ncol(forInfIndex)==4) {
    print("None of the best performing metrics were retained")
    return(NULL)
  } else {
    return(forInfIndex)
  }
  
}

# Takes the output of format_top_metric_data, the vector of metrics output by remove_worst_performing_Variants,
# and the output of format_rocr_input
# Returns a PCA run on the forInfIndex data, and a copy of forInfIndex with the first PC appended as a final column
get_training_pca = function(forInfIndex, topParams, format_list) {
  
  # Run a PCA on the data and then get labels for each row
  PCA = prcomp(forInfIndex[, (topParams), with = F], center = T, scale = T)
  allDat = cbind(forInfIndex[, (format_list$toMove), with = F], PCA$x[,"PC1"])
  setnames(allDat, old = "V2", new = "PC1")
  
  return(list('PCA' = PCA,
              'allDat' = allDat))
  
}

# Takes the allDat object output by get_training_pca, runs a LMM on it to calculate the p values of the positive control conditions
# Returns the model and the p value
get_training_pval = function(allDat){
  
  lmMod = 
    lme(PC1 ~ Treatment, random = ~1|Animal,
        data = allDat, control = lmeControl(msMaxIter = 100, opt = 'optim'))
  
  pval = as.data.table(anova(lmMod))[2, "p-value"]
  
  return(list('model' = lmMod,
              'pval' = pval$'p-value'))
  
}

# Takes the allDat object output by get_training_pca, calculates the AUC of an ROC analysis using the positive control conditions
# Returns the AUC values
get_training_auc = function(allDat){
  
  pred = ROCR::prediction(allDat[, PC1], allDat[, Treatment])
  perf = ROCR::performance(pred, "auc")
  forPlot =  ROCR::performance(pred,"tpr","fpr")
  AUC = perf@y.values[[1]]
  
  return(AUC)
  
}

# Takes the output of get_ROC_values, the number of best preidctors to use, the output of format_rocr_input,
# and a string of 'p value' or AUC to specify which to use to identify the best inflamation index
# Creates an inflammation index using the howMany best metrics and evaluated using the string in method
# Returns a data.table including the best metrics used, the p value / AUC of the inflammation index for this
# positive control condition
get_inf_ind_metrics = function(paramByAuc, howMany, format_list, method) {
  
  # Get the top parameters by AUC
  topParams = paramByAuc[AUC %in% tail(sort(AUC),howMany), Parameter]    
  
  topParams = as.vector(remove_worst_performing_variants(topParams, paramByAuc))
  
  # Format a data.table of the best performing metrics
  forInfIndex = format_top_metric_data(format_list, topParams)
  
  # If we return actual formmated data
  if(is.null(forInfIndex) == F) {
    
    # Get our initial inflammation index and calculate pvalue and AUC value for comparison between training conditions
    pca_out = get_training_pca(forInfIndex, topParams, format_list)
    
    if(method == 'p value') {
      lmMod = get_training_pval(pca_out$allDat)
      AUC = NA
    } else {
      lmMod = list('pval' = NA)
      AUC = get_training_auc(pca_out$allDat)
      
    }
    
    # Else set our pval, AUC, and PCA values to NULL as the formatted data was empty
  } else {
    
    AUC = NA
    lmMod = list('pval' = NA)
    pca_out = list('PCA' = NA)
    
  }  
  
  tableOut = 
    data.table("Parameters" = topParams, "Vals" = howMany, 
               'p-value' = lmMod$pval,"AUC" = AUC)
  
  return(list('PCAOut' = pca_out$PCA,
              'tableOut' = tableOut))
}

# Run on the output of the morphPreProcessing function, we look through TCS values and
# find the best TCS and combination of descriptors to distinguish between LPS and nonLPS
# using "method"
constructInfIndTest <- function(inDat, LPSGroups, method, otherExclusions = NULL,
                                noDesc = 1:2) {
  # INPUTS
  # inDat = data.table containing the output from morphPreProcessing
  # LPSGroups = vector of strings identifying the treatment values that specify our positive control conditions
  # Method is a string of 'p value' or 'AUC' specifying how to choose our best discriminators
  # otherExclusions is a list with element 'column' that gives the column name to look in and 'cond' that gives the condition in
  #   that column to limit our data to for training purposes (besides just LPSGroups)
  
  exit = F
  
  if(is.null(inDat)) {
    exit = T
    print("Data not provided")
  }
  
  if(is.null(LPSGroups)) {
    exit = T
    print("Need to provide a vector of which treatment IDs identify pre and post inflammatory activation")
  }
  
  if(is.null(method)) {
    exit = T
    print("Need to provide a string of which method to use to optimise the inflammation index selection")
  }
  
  if(!(method %in% c("p value", "AUC"))) {
    exit = T
    print("Format of provided method doesn't match 'p value' or 'AUC'")
  }
  
  if(exit == T) {
    return(NULL)
  }
  
  if(is.null(otherExclusions)) {
    labCols = 
      c("Animal", "CellNo", "TCS", "Treatment", "UniqueID")
  } else {
    labCols = c(c("Animal", "CellNo", "TCS", "Treatment", "UniqueID"), otherExclusions$Col)
  }
  
  tableOut = list()
  PCAOut = list()
  addIndex = 1
  
  # Get out our training data
  procDat = filter_by_training_data(inDat, LPSGroups, otherExclusions)
  
  # For each TCS value we have in our training data
  for(currTCS in unique(procDat$TCS)) {
    
    PCAOut[[currTCS]] = list()
    
    # Get out gathered data for this TCS value
    format_list = format_rocr_input(procDat[TCS == currTCS], labCols)
    
    # Get out AUC values for every metric in our gathered data
    ROC_list = lapply(unique(format_list$aggData$Parameter), function(x, aggData) {
      get_ROC_values(aggData, currParam = x)
    }, format_list$aggData)
    
    paramByAuc = rbindlist(ROC_list)
    
    # Loop through whether we're using the 1st, 1st+2nd, 1st+2nd+3rd etc. best discriminators
    for(howMany in noDesc) {
      
      # Get the PCA of our inflammation index, and a table of evaluation metrics
      inf_ind_metrics = get_inf_ind_metrics(paramByAuc, howMany, format_list, method)
      
      # Return our inflammation index PCA and pval and AUC values
      PCAOut[[currTCS]][[howMany]] = inf_ind_metrics$PCAOut
      
      tableOut[[addIndex]] = inf_ind_metrics$tableOut
      tableOut[[addIndex]][, TCS := currTCS]
      
      addIndex = addIndex+1
      
    }
    
  }
  
  forComp = unique(rbindlist(tableOut)[, list(Vals, TCS, `p-value`, AUC)])
  
  # Print thee TCS, no. discriminators that had the best discrmination between psotive control condtions
  if(method == "p value") {
    print(paste("Best TCS", forComp[which.min(forComp$`p-value`), TCS]))
    print(paste("Best No. Discriminators", forComp[which.min(forComp$`p-value`), Vals]))
    print(paste("p value", min(forComp$`p-value`)))
    toUse = PCAOut[[forComp[which.min(forComp$`p-value`), TCS]]][[forComp[which.min(forComp$`p-value`), Vals]]]
    TCSToUse = forComp[which.min(forComp$`p-value`), TCS]
  } else if (method == "AUC") {
    print(paste("Best TCS", forComp[which.max(forComp$AUC), TCS]))
    print(paste("Best No. Discriminators", forComp[which.max(forComp$AUC), Vals]))
    print(paste("AUC", max(forComp$AUC)))
    toUse = PCAOut[[forComp[which.max(forComp$AUC), TCS]]][[forComp[which.max(forComp$AUC), Vals]]]
    TCSToUse = forComp[which.max(forComp$AUC), TCS]
  }
  
  # Apply our final inflammation index to our input data
  dataToReturn = inDat[TCS == TCSToUse]
  dataToReturn[, InfInd := predict(toUse, newdata = dataToReturn)[,1]]
  
  # Return the input data with the final index applied, as well as the PCA this is based on
  backList = list("PCA Object" = toUse,
                  "Data" = dataToReturn)
  
}


# Functino wraps the preprocessing and constructInfInd functions in one
infInd <- 
  function(pixelSize, morphologyWD, TCSExclude = NULL, 
           animalIDs, treatmentIDs, LPSGroups, method,
           useFrac = NULL, otherExclusions = NULL) {
    
    # If there is a fraclac directory specify useFrac as T
    if(is.null(useFrac)) {
      if(length(dir(path = morphologyWD, pattern = "fracLac", full.names = T, recursive = F, ignore.case = T)>0)) {
        useFrac = T
      }
    }
    
    ################################################################################
    ########################### Get Morphology Data ################################
    ################################################################################
    
    # Get our formatted data
    output = 
      morphPreProcessing(
        pixelSize = pixelSize, morphologyWD = morphologyWD, 
        TCSExclude = TCSExclude, animalIDs = animalIDs, treatmentIDs = treatmentIDs,
        useFrac = useFrac)
    
    # Construct our inflammation index and apply it
    PCOut = 
      constructInfInd(output, LPSGroups = LPSGroups, method = method, 
                      otherExclusions = otherExclusions)
    
    # Return our data
    returnList = list("PreProcData" = output,
                      "PCA Object" = PCOut$`PCA Object`,
                      "ProcData" = PCOut$Data)
    
    return(returnList)
    
  }
