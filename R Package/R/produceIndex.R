#' Format morphPreProcessing Output for ROC-AUC Analysis
#' 
#' @param inputData A data.table output by morphPreProcessing
#' @param labCols A string vector of the ID columns (i.e. non-metric columns) in inputData
#' @return A data.table that is a version of inputData where each metric has its own row
formatROCRInput = function(inputData, labCols) {
  
  procDat = copy(inputData)

  # Gather the data across all measurements and label columns we're using
  aggData = 
    as.data.table(gather(procDat, Parameter, Value, (which(!(names(procDat) %in% labCols)))))
  
  # Turn our Parameter values into factors, format Value and Treatment columns appropriately
  aggData[, c("Parameter", "Value", "Treatment") := list(factor(Parameter, levels = unique(Parameter)), as.numeric(Value), as.factor(Treatment))]
  
  # Order our gathered data by parameter name
  aggData = 
    aggData[order(Parameter), c(labCols, 'Parameter', 'Value'), with = F]  
  
  return(aggData)

}

#' Run an ROC Analysis on a metric using Treatment conditions
#' 
#' @param aggData A data.table object output by formatROCRInput
#' @param currParam A string identifying the metric to perform the ROC analysis on (a unique value in aggData$Parameter)
#' @return A data.table containing the AUC from the ROC analysis
getROCValues = function(aggData, currParam) {

  # Get data corresponding to the metric of interest
  forPref = 
    copy(aggData[Parameter == currParam, ])
  
  # Calculate the AUC of an ROC plot for this parameter against the treatment values
  pred = ROCR::prediction(forPref[, Value], forPref[, Treatment])
  perf = ROCR::performance(pred, "auc")
  forPlot =  ROCR::performance(pred,"tpr","fpr")
  AUC = perf@y.values[[1]]
  outData = data.table("AUC" = AUC)
  
  # Return a data.table object containing values from our ROC analysis
  return(outData)
    #"FPR" = unlist(forPlot@x.values), "TPR" = unlist(forPlot@y.values),

}

#' Takes a string vector of all the metrics we're analysing and returns a string vector of the
#' sholl percentile metrics that have [P10-P90] variants
#' 
#' @param allMetrics A string vector of metrics
#' @return A string vector where each element is a sholl percentile metric that has a variant, and the name of the element
#' is its variant
shollPercentileVariants = function(allMetrics) {
  
  # Get the variants for our metrics based on sholl data percentiles
  rawPercMetrics = allMetrics[grepl('\\[P10-P90\\]', toupper(allMetrics))]
  variantPercMetrics = as.vector(sapply(rawPercMetrics, function(x) {
    substring(x, 0, gregexpr('\\[P10-P90\\]', x)[[1]][1]-1)
  }))
  names(variantPercMetrics) = rawPercMetrics
  
  return(variantPercMetrics)
  
}

#' Takes a string vector of all the metrics we're analysing and returns a string vector of the
#' sholl percentile metrics that have (fit)
#' 
#' @param allMetrics A string vector of metrics
#' @return A string vector where each element is a sholl sampled metric that has a variant, and the name of the element
#' is its variant
shollSampledVariants = function(allMetrics) {
  
  # Get the variants for our metrics based on sampled sholl data
  rawShollMetrics = allMetrics[grepl('fit', tolower(allMetrics))]

  variantShollMetrics = as.vector(sapply(rawShollMetrics, function(x) {
    paste(substring(x, 0, gregexpr('\\(fit', x)[[1]][1]-1), '(sampled)', sep = '')
  }))
  names(variantShollMetrics) = rawShollMetrics
  
  return(variantShollMetrics)
  
}

#' Return a string vector of our HC metrics and all their possible variants
#' 
#' @param allMetrics A string vector of all possible metrics
#' @return A string vector of all our HC metrics and their variants
hcCentreVariants = function(allMetrics) {
  
  # Get all our Hc metrics with 'from' in the name
  rawHCMetrics = allMetrics[grepl("from", tolower(allMetrics))]
  
  # Get the names of these without the 'from' ending
  rawHCMetricsTrunc = as.vector(sapply(rawHCMetrics, function(x) {
    substring(x, 0, gregexpr('from', x)[[1]][1]-1)
  }))
  
  # Stick on 'fromCircle'sCentre'
  hcCircCentre = as.vector(sapply(rawHCMetricsTrunc, function(x) {
    paste(x, "fromCircle'sCentre", sep = '')
  }))
  
  # Stick on 'fromHull'sCentreofMass'
  hcBoundingCirc = as.vector(sapply(rawHCMetricsTrunc, function(x) {
    paste(x, "fromHull'sCentreofMass", sep = '')
  }))
  
  # Name the elements with the other type
  names(hcCircCentre) = hcBoundingCirc
  names(hcBoundingCirc) = hcCircCentre
  
  # Stick them all together and send
  return(c(hcCircCentre, hcBoundingCirc))
  
}

#' Takes a vector of metrics and returns a vector where each element contains the name of that metrics variant
#' 
#' @param allMetrics A string vector of metrics
#' @return A string vector where the name of each element is a metric, and the value of each element is the name of the 
#' variant form of that metric
identifyMetricVariants = function(allMetrics) {

  # Get the variants for our metrics based on sholl data percentiles
  percVariants = shollPercentileVariants(allMetrics)
  
	# Get the variants for our metrics based on sampled sholl data
  sampleVariants = shollSampledVariants(allMetrics)
	
	# Get the variants for our metrics based on the centre of the hull and circularity circle
  centreVariants = hcCentreVariants(allMetrics)
  
	# Return all these vectors as a single vector
	allMetricVariants = unlist(c(percVariants, sampleVariants, centreVariants))

	return(allMetricVariants)

}

#' Remove the worst performing variants from a string vector of metrics
#' 
#' @param topParams A string vector of metrics in paramByAuc
#' @param paramByAuc A data.table of the ROC-AUC value for all metrics
#' @return A string vector that is a cleaned version of topParams
removeWorstPerformingVariants = function(topParams, paramByAuc) {

  # Identify all the variant metrics in topParams
  allMetricVariants = identifyMetricVariants(as.vector(unique(paramByAuc$Parameter)))
  
  # Get a vector of the topParams metrics that are in the allMetricVariants vector
  checkMetrics = intersect(topParams, names(allMetricVariants))
  topMetricVariants = allMetricVariants[names(allMetricVariants) %in% checkMetrics]
  
  # If we have an intersection, remove the worst performing variant from topParams
  cleanParams = copy(topParams)
  if(length(topMetricVariants) != 0) {
    for(currElement in 1:length(topMetricVariants)) {
      aucTable = paramByAuc[Parameter %in% c(names(topMetricVariants)[currElement], topMetricVariants[currElement])]
      paramToRemove = aucTable[which.min(aucTable$AUC), ]$Parameter
      cleanParams = cleanParams[cleanParams != paramToRemove]
    }
  }
  
  # Return a vector of topPArams with worst performing variants removed
  return(cleanParams)

} 

#' Filter our data to limit to the top performing parameters that have non-zero variance
#' 
#' @param aggData A data.table output by formatROCRInput
#' @param topParams A string vector of metrics/parameters to retain
#' @param labCols A string vector of ID columns
#' @return A data.table that is a filtered version of aggData
filterTopMetrics = function(aggData, topParams, labCols) {

  # Get out our top metrics and label columns
  forInfIndex = copy(aggData[Parameter %in% topParams, c(labCols, 'Parameter', 'Value'), with = F])
  forInfIndex[, Value := as.numeric(Value)]
  
  # Identify parameters with zero variants and remove these from our data
  zeroVarianceParameters = forInfIndex[, var(scale(Value), na.rm = T), by = Parameter][V1 == 0]$Parameter
  forInfIndex[!Parameter %in% zeroVarianceParameters]

  # If we now have no columns, warn the user
  if(nrow(forInfIndex)==0) {
    print("None of the best performing metrics were retained")
    return(NULL)
	} else {
	  return(forInfIndex)
	}

}

#' Run a PCA and append PC1 as a Column
#' 
#' @param forInfIndex A data.table output by filterTopMetrics
#' @return A list with two elements: PCA is the PCA object output by running a PCA on our data;
#' allDat is the wide format of our input data with PC1 appended as a column
runPCA = function(forInfIndex) { 
  
  # Restructure our data to wide format and remove ID columns
  forPCARaw = as.data.table(spread(forInfIndex, Parameter, Value))
  metricCols = as.vector(unique(forInfIndex$Parameter))
  forPCA = forPCARaw[, (metricCols), with = F]

  # Run a PCA on the data and then add our PC1 value to our input table
  PCA = prcomp(forPCA, center = T, scale = T)
  allDat = cbind(forPCARaw, PCA$x[,"PC1"])
  setnames(allDat, old = "V2", new = "PC1")

  return(list('PCA' = PCA,
  	'allDat' = allDat))

}

#' Calculate the p value of our Treatment effect on PC1
#' 
#' @param allDat A data.table object output by runPCA$allDat
#' @return A list with two elements: model being the linear mixed model object we ran; pval being the p value of the effect of Treatment
#' in the model
getPC1PValue = function(allDat){
  
  # Build a linear mixed model for the effect of Treatment on our PC1 value using Animal as a group identifier
	lmMod = 
	lme(PC1 ~ Treatment, random = ~1|Animal,
		data = allDat, control = lmeControl(msMaxIter = 100, opt = 'optim'))
  
	# Get our p value
	pval = as.data.table(anova(lmMod))[2, "p-value"]

	# Return our model and p value
	return(list('model' = lmMod,
		'pval' = pval$'p-value'))

}

#' Calculate the ROC-AUC value of our PC1 over Treatment values
#' 
#' @param allDat A data.table object output by runPCA$allDat
#' @return The AUC value of the ROC-AUC analysis
getPC1AUC = function(allDat){

  # Get our AUC value for PC1 over Treatment
	pred = ROCR::prediction(allDat[, PC1], allDat[, Treatment])
	perf = ROCR::performance(pred, "auc")
	forPlot =  ROCR::performance(pred,"tpr","fpr")
	AUC = perf@y.values[[1]]

	return(AUC)

}

#' Find our top performing metrics, remove the lowest performing variants, create an 'Inflammation Index' for the data,
#' calculate its effectiveness using the chosen method
#' 
#' @param paramByAuc A data.table object where each row is a metric and its ROC-AUC value
#' @param howMany An integer indicating how many of the best performing metrics we want to use to build our index
#' @param method A string indicating whether we want to evaluate the effectiveness of our index using 'p value' or AUC
#' @param aggData A data.table object output by formatROCRInput
#' @param labCols A string vector of the ID columns in aggData
#' @return A list with two elements: PCAOut is the PCA object we used to create our index;
#' tableOut is a data.table reporting the parameters we use, the number of top performing parameters we selected,
#' and the AUC or p-value of our index performance
#' @export
createEvaluateInfIndex = function(paramByAuc, howMany, method, aggData, labCols) {

  # Get the top parameters by AUC
  topParams = paramByAuc[AUC %in% tail(sort(AUC),howMany), Parameter]    
  
  # Remove the worst performing variants
  topParams = removeWorstPerformingVariants(topParams, paramByAuc)
  
  # Format a data.table of the best performing metrics
  forInfIndex = filterTopMetrics(aggData, topParams, labCols)
  
  # If we return actual formmated data
  if(is.null(forInfIndex) == F) {
    
    # Get our initial inflammation index
    pca_out = runPCA(forInfIndex)
    
    # Get the p value of the effect of treatment on PC1
    if(method == 'p value') {
  	  lmMod = getPC1PValue(pca_out$allDat)
  	  AUC = NA
  	
  	# Get the ROC-AUC value for our PC1 on Treatment values
  	} else {
  		lmMod = list('pval' = NA)
  		AUC = getPC1AUC(pca_out$allDat)
  	}
  
  # Else set our pval, AUC, and PCA values to NULL as the formatted data was empty
  } else {
  
  	AUC = NA
  	lmMod = list('pval' = NA)
  	pca_out = list('PCA' = NA)
  
  }  
  
  # Create a data.table to return our top parameters, the number of descriptors
  # included, and our p value and AUC value
  tableOut = 
  data.table('p-value' = lmMod$pval,"AUC" = AUC)
  
  # Return our PCA object and this tableOut report
  return(list('PCAOut' = pca_out$PCA,
  	'tableOut' = tableOut))
  
}

#' Wrapper function. Takes the output of morphPreProcessing filtered for training conditions,
#' and returns a PCA object that can be used to build an Inflammation Index optimised for the TCS value and number of metrics
#' that lead to the greatest sensitivity to the training conditions
#' 
#' @param procDat A data.table object output by morphPreProcessing that is filtered to only contains 2 Treatment values (training data)
#' @param method A string that indicates what method to use to select the optimal Inflammation Index. Can either be 'p value' or 'AUC'
#' @param noDesc An integer vector that indicates what different combinations of the best descriptors we want to try building our Index using
#' @param labCols A string vector of the ID columns in procDat
#' @return A PCA object
constructInfInd <- function(procDat, method, noDesc = 5:15, 
                            labCols = c('Animal', 'Treatment', 'TCSValue', 'CellNo', 'UniqueID')) {

  exit = F
  
  if(is.null(procDat)) {
  	exit = T
  	print("Data not provided")
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

	tableOut = list()
	PCAOut = list()
	addIndex = 1
  
  # For each TCS value we have in our training data
  for(currTCS in unique(procDat$TCSValue)) {
  
  	PCAOut[[currTCS]] = list()
  
    # Get out gathered data for this TCS value
    aggData = formatROCRInput(copy(procDat[TCSValue == currTCS]), labCols)
    
    # Get out AUC values for every metric in our gathered data
    ROCList = list()
    for(currMetric in unique(aggData$Parameter)) {
      ROCList[[currMetric]] = getROCValues(aggData, currMetric)
      ROCList[[currMetric]]$Parameter = currMetric
    }
    paramByAuc = rbindlist(ROCList)
    
    # Loop through whether we're using the 1st, 1st+2nd, 1st+2nd+3rd etc. best discriminators
    for(howMany in noDesc) {
      
      # Get the PCA of our inflammation index, and a table of evaluation metrics
      infIndices = createEvaluateInfIndex(paramByAuc, howMany, method, aggData, labCols)
      
      # Return our inflammation index PCA and pval and AUC values
      PCAOut[[currTCS]][[howMany]] = infIndices$PCAOut
      
      tableOut[[addIndex]] = infIndices$tableOut
      tableOut[[addIndex]][, TCS := currTCS]
      tableOut[[addIndex]][, Vals := howMany]
      
      addIndex = addIndex+1
  
    }

  }
  
	# Combine our tableOut tables into a single data.table
  forComp = unique(rbindlist(tableOut))
  
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
  
  # Return the PCA object
	return(toUse)

}

#' Function to apply the outputs of constructInfInd to novel data
#' 
#' @param infIndOutput A PCA object output by constructInfInd
#' @param applyTo A data.table that we want to create an Inflammation Index for
#' @return A data.table that is identical to applyTo but with the Inflammation Index added as a final column
#' @export
applyInfInd = function(infIndOutput, applyTo) {
  
  # Apply the PCA object and extract PC1 and store this as InfInd
  for_output = copy(applyTo)
  for_output[, InfInd := predict(infIndOutput, newdata = for_output)[,1]]
  return(for_output)
  
}
