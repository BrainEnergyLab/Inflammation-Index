read_in_file = function(locations, seperators, fileEncoding) {
  # Takes the location of a file, what seperators are in the file, and what encoding
  # If it's a FracLac file, we read it in as lines, else using fread
  # Return the read in data.table
  
  if(grepl("Scan", locations)) {
    con = file(locations, encoding = 'UTF-8')
    gotGaps = strsplit(readLines(con), "\t")
    asMatrix = do.call(rbind, gotGaps)
    temp = as.data.frame(asMatrix[-1,])
    names(temp) = asMatrix[1,]
    temp = as.data.table(temp)
    close(con)
  } else {
    temp = fread(locations, sep = seperators, na.string = 'NaN', encoding = fileEncoding, header = T)
  }
  
  temp[, Location := locations]
  
  return(temp)
}

get_file_locations = function(morphologyWD, useFrac) {
# Takes the directory where our morphology data is stored, and a boolean of whether we're using
# FracLac data or not
# If we're using FracLac, we  append / remove FracLac specific values to the lists we return containing the
# directories to look into

	# List to store the pattern we'll search in our directory for each data type,
	# as well as the character that separates fields in the data, and the 
	# character that separates headers, also fileEncoding argument since on some
	# occassions we need to change it, and the column we'll refer to to assign
	# animal/timepoint info in forInfo
	storageList = 
	list("Cell Parameters" = 
		list("Sep" = ",",
			"fileEncoding" = "unknown",
			"forInfo" = "Location",
			"Locations" = dir(path = morphologyWD, pattern = "Cell Parameters.csv", full.names = T,
				recursive = T, ignore.case = T)),
		"Sholl Parameters" = 
		list("Sep" = ",",
			"fileEncoding" = "Latin-1",
			"forInfo" = "Location",
			"Locations" = dir(path = morphologyWD, 
				pattern = 'Substack \\(\\d+-\\d+\\) x \\d* y \\d* \\.csv$', 
				full.names = T, recursive = T, ignore.case = T)))

	if(useFrac == T) {

		# Get the directory where our fractal analysis files are stored
		main_fracLac_dir = 
		dir(path = morphologyWD, pattern = "fracLac", full.names = T, 
			recursive = F, ignore.case = T)

		storageList$`Hull and Circularity` = 
		list("Sep" = "\t",
			"fileEncoding" = "unknown",
			"forInfo" = "ID",
			"Locations" = dir(path = main_fracLac_dir, 
				pattern = "Hull and Circle Results.txt", full.names = T, 
				recursive = T, ignore.case = T))
		storageList$`FracLac` = 
		list("Sep" = "\t",
			"fileEncoding" = "unknown",
			"forInfo" = "ID",
			"Locations" = dir(path = main_fracLac_dir, 
				pattern = "Scan Types.txt", full.names = T, 
				recursive = T, ignore.case = T))

	}

return(storageList)

}

filter_nonfrac_locations = function(passList, filterBy) {
  
  checkAgainst = paste(toupper(gsub(" ", "", filterBy, fixed = T)), collapse = "|")
  for(currType in names(passList)) {
    
    clean_locs = sapply(passList[[currType]]$Locations, function(x, checkAgainst) {
      checkLoc = toupper(gsub(" ", "", x, fixed = T))
      if(regexpr(checkAgainst, checkLoc, perl = T)>-1) {
        return(x)
      } else {
        return(NULL)
      }
    }, checkAgainst)
    
    clean_locs[sapply(clean_locs, is.null)] <- NULL
    passList[[currType]]$Locations = unlist(clean_locs)
    
  }
  return(passList)
}

read_in_raw_data = function(storageList, TCSExclude) {
# Runs the read_in_file function for every location passed in from storageList and removes any locations
# that we want to exclude based on the values in TCSExclude

	# For every element in storageList (sholl parameters, cell descriptors etc.)
	comboList = lapply(storageList, function(storageList, TCSExclude) {

		# Clean up the locations vector by removing NULLs
		storageList$Locations[sapply(storageList$Locations, is.null)] <- NULL

		# If we're excluding certain TCS values, remove them from the location vector
		if(is.null(TCSExclude) == F) {
			storageList$Locations = storageList$Locations[!str_detect(storageList$Locations, paste(TCSExclude, collapse = "|"))]
			storageList$Locations = storageList$Locations[is.na(storageList$Locations)==F]
		}

		# For each location read in the file using the read_in_file function
		storageList$Files = rbindlist(lapply(storageList$Locations, function(locations, seperators, fileEncoding) {

			temp = read_in_file(locations, seperators, fileEncoding)
			return(temp)

			}, storageList$Sep, storageList$fileEncoding))

		return(storageList)

	}, TCSExclude)

	return(comboList)

}

fill_to_add = function(storageListElement) {
# Returns a list of things we need to add to the hull and circularity and fraclac files

	return(list("TCS" = 
		with(storageListElement$Files,
			substring(unlist(Location),regexpr("^(TCS)[0-9]*", unlist(Location)) +3, 
				attributes(regexpr("^(TCS)[0-9]*", unlist(Location)))$match.length)),
		"CellName" = with(storageListElement$Files,
			substring(as.character(Location), regexpr("CANDIDATE", toupper(as.character(Location))),
				regexpr("TIF", toupper(as.character(Location)))-1))))
}

format_fraclac_files = function(fracLacComboList) {
# Formats the fraclac files appropriately so they can be passed to similar loops as other data types

	# For the ID value, get the characters to the left of the underscore
	fracLacComboList[, Location := sapply(strsplit(as.character(Location), "_"),function(x) x[1])]

	# Retain every 2nd row of the FracLac data (the data is in triplicate, where
	# the first and 3rd row are readings with formula for fractal dimensions
	# that we don't want to use)
	fracLacComboList = 
	fracLacComboList[rep(c(F,T,F), nrow(fracLacComboList)/3),]

	# Change the names for the fractal dimension and lacunarity measurements to be
	# readable
	names(fracLacComboList)[grep("^6. ", names(fracLacComboList))] = "FractalDimension"
	names(fracLacComboList)[grep("^16. ", names(fracLacComboList))] = "Lacunarity"

	return(fracLacComboList) 

}

remove_unused_metrics = function(storageList, useFrac) {
# Removes certain metrics from our data and return it

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

		# A vector of the fracLac columns we want to keep
		fracToKeep = 
		c("Animal", "Treatment", "TCS", "CellName", "UniqueID", "FractalDimension", "Lacunarity", "Location")

		# List of columns to remove from the hull and circ and fraclac data
		fracColsToRemove = list(
			"Hull and Circularity" = 
			c("MEAN FOREGROUND PIXELS", "TOTAL PIXELS", "Hull's Centre of Mass",
				"Width of Bounding Rectangle", "Height of Bounding Rectangle",
				"Circle's Centre", "Method Used to Calculate Circle"),
			"FracLac" =  unique(names(storageList$FracLac$Files)[!(names(storageList$FracLac$Files) %in% fracToKeep)]))

		colsToRemove = c(colsToRemove, fracColsToRemove)

	}

	# Remove the columns we want to get rid of
	for(curr_element in names(colsToRemove)) {
		storageList[[curr_element]]$Files[, eval(colsToRemove[[curr_element]]) := NULL]
	}

	return(storageList)

}

add_missing_info = function(storageList, useFrac) {
# Adds in info that is missing from our data using the mapStuff list and fill_to_add() output

	# Sholl parameter things to add - TCS values
	mapStuff = 
	list(
		"Sholl Parameters" = 
		list("TCS" = 
			with(storageList$`Sholl Parameters`, 
				substring(Locations, regexpr("TCS", Locations)+3, 
					regexpr("/Results", Locations)-1))))

	if(useFrac == T) {

		frac_names = c('FracLac', 'Hull and Circularity')

		# Remove the location column
		for(curr_element in frac_names) {
			storageList[[curr_element]]$Files[, Location := NULL]

		# Rename the column in the first index as location
		names(storageList[[curr_element]]$Files)[1] = 'Location' 
	}

	# Format the fraclac files
	storageList$FracLac$Files =  format_fraclac_files(storageList$FracLac$Files)

	toAdd = list("Hull and Circularity" = list(),
		"FracLac" = list())

	# For each frac data type, use fill_to_add to get he data we need to add
	for(curr_element in names(toAdd)) {
		toAdd[[curr_element]] = fill_to_add(storageList[[curr_element]])
	}

	# Add our nonFrac data to add to our frac data to add into a single list
	mapStuff = c(mapStuff, toAdd)

	}

	# Here we add on our data we need to add to each element of our data
	for(curr_element in names(mapStuff)) {
		storageList[[curr_element]]$Files = cbind(storageList[[curr_element]]$Files, as.data.table(mapStuff[[curr_element]]))
	}

	return(storageList)

}

format_unique_id = function(storageList, treatmentIDs, animalIDs) {
# Adds in a unique ID for each cell, animal, timepoint, and TCS value, for each data type

	# Change the name of the image column to CellName in the sholl parameter
	# data since this makes it consistent with the other data forms, also the
	# Cell Name column in cell parameters
	setnames(storageList$`Sholl Parameters`$Files, old = "Image", new = "CellName")
	setnames(storageList$`Cell Parameters`$Files, old = "Cell Name", new = "CellName")

	# Format the cell name, depending on whether there's a.tif extension in the cellname or not
	wheresTif = grepl(".tif", storageList$`Cell Parameters`$Files$CellName)
	storageList$`Cell Parameters`$Files[wheresTif, CellName := sapply(strsplit(CellName, ".tif"), function(x) x[1])]
	storageList$`Cell Parameters`$Files[wheresTif==FALSE, CellName := gsub(" ", "", paste("Candidate mask for ", `Stack Position`, CellName), fixed = T)]

	# Add a uniqueID value to every data type, where we paste the animal, 
	# timepoint, cellname, and TCS together with no spaces so we have an 
	# identifier of every unique measurement that we can check across data types -
	# also note we make it all uppercase
	for(currType in names(storageList)) {
		storageList[[currType]]$Files$Animal = 
			as.vector(unlist(sapply(storageList[[currType]]$Files$Location, function(loc, animalIDs) {
				names(which.max(sapply(animalIDs[str_detect(toupper(loc), fixed(animalIDs))], nchar)))
			}, animalIDs)))

		storageList[[currType]]$Files$CellName = 
			toupper(gsub(" ", "", storageList[[currType]]$Files$CellName))
		checkAgainst = paste(treatmentIDs, "(?![0-9])", sep = "")
		storageList[[currType]]$Files[, Location := toupper(gsub(" ", "", Location, fixed = T))]
		for(currTreat in 1:length(treatmentIDs)) {
			storageList[[currType]]$Files[regexpr(checkAgainst[currTreat], Location, perl = T)>-1, Treatment := treatmentIDs[currTreat]] 
		}

		storageList[[currType]]$Files[, UniqueID := toupper(paste(Animal, Treatment, CellName, TCS, sep = ""))]
	}

	return(storageList)

}

retain_common_cells = function(with_id) {

	# Get out a list containing all the uniqueIDs for each data type before 
	# finding the intersection of all the uniqueID vectors
	uniqueIDList = lapply(with_id, function(x) {
		x$Files$UniqueID
	})
	Intersections = Reduce(intersect, uniqueIDList)

	# Subset out the uniqueIDs that aren't present in all of the data types so
	# that we only end up with data where we have a complete set of measurements
	# for each cell - conincidentally this ensures the 'Analysed == 1' and 'Radius Step' == pixelSize conditions
	# we apply earlier also influence the fracLac data were retain
	for(currType in names(with_id)) {
		with_id[[currType]]$Files = with_id[[currType]]$Files[UniqueID %in% Intersections]
	}

	return(with_id)

}

convert_hc_to_um = function(storageList, pixelSize) {
  
  # Vector of measures in the hull and ciricularity data we want to convert from
  # pixels to um
  conv_list_names <- c("Area", "Perimeter", "Diameter of Bounding Circle", "Mean Radius", 
                       "Maximum Span Across Hull", "Maximum Radius from Hull's Centre of Mass",
                       "Maximum Radius from Circle's Centre", "Mean Radius from Circle's Centre")
  
  # A vector of the numbers to multiple by respectively to do
  # that
  multiplyBy = rep(pixelSize, length(conv_list_names))
  multiplyBy[1] = pixelSize^2
  
  # Create a list where each element is a metric, and the value is what to multiple that metric by to turn it into um
  conv_list <- vector("list", length(conv_list_names))
  names(conv_list) <- conv_list_names
  for(currCol in 1:length(names(conv_list))) {conv_list[[currCol]] = multiplyBy[currCol]}
  
  # For each column to convert, convert it to numeric
  for(currCol in names(conv_list)) {
  	if(sum(currCol %in% names(storageList$`Hull and Circularity`$Files)) >= 1) {
   		storageList$`Hull and Circularity`$Files[, eval(currCol) := as.numeric(unlist(get(currCol))) * conv_list[[currCol]]]
  	}
  }
  
  return(storageList)
  
}

format_names = function(um_data) {
# Format the column names in our data
	
	# Get the column names of every data type
	uniqueIDList = lapply(um_data, function(x) {
    	names(x$Files)
	})

	# Get the names that are common to more than one data type, and identify those that aren't labels
	repeat_names = names(which(table(unlist(uniqueIDList)) > 1))
	name_change = repeat_names[!repeat_names %in% c('Animal', 'CellName', 'Location', 'TCS', 'Treatment', 'UniqueID')]

	# For column names that aren't labels and are present in more than one data type, make them unique by pasting the data
	# type to their name
	for(curr_name in name_change) {
		for(curr_element in names(um_data)) {
			if(curr_name %in% names(um_data[[curr_element]]$Files)) {
				setnames(um_data[[curr_element]]$Files, old = curr_name, new = paste(curr_element, curr_name, sep = ''), skip_absent = T)
			}
		}
	}

	# For all the data, remove spaces from the headers, and from the cellName
	# values to make them consistent between data types
	storageList = 
	lapply(um_data, function(x) { 
		names(x$Files) = gsub(" ", "", names(x$Files))
		x$Files$CellName = gsub(" ", "", x$Files$CellName)
		return(x) 
	})

	return(storageList)

}

merge_data_togeher = function(storageList, useFrac) {
# Merge all our data types into a single data.table

	# Get out the data.table for the elements of storageList to merge together into a single list
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

	# Merge everything together 
	merged = Reduce(merge, forMerge)

	# Create a unique name that could be repeated across TCS values, and assign each unique numeric value
	merged[, TCSName := paste(Treatment, Animal, CellName)]
	merged[, CellNo := seq_along(TCSName)]

	# If we're using frac, calculate branching density
	if(useFrac == T) {
		merged$BranchingDensity = merged$SkelArea / merged$Area
	}

	# Create a list of columns to remove from the final merged DF and then remove them
	mergeToRemove = c("TCSName", "CellName",  "Analysed", "StackPosition", "ExperimentName", "WrongObjective")
	mergeToRemoveChecked = names(merged)[grepl(paste(mergeToRemove, collapse = "|"), names(merged))]
	merged[, eval(mergeToRemoveChecked) := NULL]

	# Make all non-label columns numeric
	labelCols =     c('TCS', 'Animal', 'Treatment', 'UniqueID', 'CellNo')
	make_numeric = names(merged)[!names(merged) %in% labelCols]

	for(currCol in make_numeric) {
		merged[, eval(currCol) := as.numeric(get(currCol))]
	}

	return(merged)

}

# This function is for preprocessing the microglial morphology data output by 
# the MicrogliaMorphologyAnalysis.ijm ImageJ script
morphPreProcessing <- function(pixelSize,
	morphologyWD,
	TCSExclude = NULL,
	animalIDs,
	treatmentIDs,
	useFrac = F) {
# Pixel size is a numeric
# morphologyWD is a string
# TCSExclude is either NULL or a vector of numerics
# animalIDs is a vector of strings
# treatmentIDs is a vector of strings
# useFrac is a boolean

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

	if(is.null(useFrac)) {
		exit = T
		print("Need to provide a boolean for useFrac")
	}

	if(exit == T) {
		return(NULL)
	}

	# Format our locations, seperators, encoding info to pass into our data reading function
	passList = get_file_locations(morphologyWD, useFrac)
	
	noanimals = filter_nonfrac_locations(passList[1:2], animalsIDs)
	onlytreatments = filter_nonfrac_locations(noanimals, treatmentIDs)
	
	# Read in our raw csv files
	comboList = read_in_raw_data(passList, TCSExclude)
	# Alter storageList with info we need to add on (called mapstuff in the function)

	# mapStuff is a bunch of stuff we need to add onto each data type that its 
	# missing, this is either cell identifiers, or values for the TCS. These are
	# calculated using the file locations or IDs of the rows
	mapList = add_missing_info(comboList, useFrac)

	# Remove columns we no longer need
	cleanList = remove_unused_metrics(mapList, useFrac)

	# Next we subset out cells we don't want to keep in our cell parameter data
	# by removing cells that weren't analysed in ImageJ because they didn't pass
	# quality control, or were taken on an imaging session where the objective
	# ini file was wrongly calibrated so the pixel size isn't what we have the
	# values for. For sholl parameters, we subset out cells where we know the
	# pixel size isn't 0.58 as we expect.
	cleanList$`Cell Parameters`$Files = cleanList$`Cell Parameters`$Files[Analysed == 1,]

	# Add in a unique ID for each cell and mask size to all our elements
	with_id = format_unique_id(cleanList, treatmentIDs, animalIDs)

	# Retain only data where we have cells for all data types
	common_data = retain_common_cells(with_id)

	if(useFrac == T) {

		# Convert our HC data to um
		common_data = convert_hc_to_um(common_data, pixelSize)

	}

	# Format all our metric names so we can merge data types
	name_changed = format_names(common_data)

	# Merge our data types into a single data.table
	merged = merge_data_togeher(name_changed, useFrac)

	return(merged)

}