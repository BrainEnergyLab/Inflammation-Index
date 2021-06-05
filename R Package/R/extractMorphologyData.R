#' Return a list of animal and treatment IDs from the image storage directory 
#' used with the Microglia Morphology Analysis Fiji package
#' 
#' @param imageStorageDirectory A file path as a string
#' @return A list with two elements, each a string vector, containing the animal and treatment IDs found in the imageStorageDirectory
#' $animalIDs contains the animal IDs
#' $treatmentIDs contains the treatment IDs
#' @export
getAnimalAndTreatmentIDs <- function(imageStorageDirectory) {
  
  # Get all the directories in the imageStorageDirectory
  subFolders = list.dirs(path = imageStorageDirectory, full.names = F)
  
  # Remove the first element since this is empty
  subFoldersClean = subFolders[2:length(subFolders)]
  
  # Get the subdirectories of the animal directories and store these as treatment IDs
  treatmentFolders = subFoldersClean[grepl('/', subFoldersClean)]
  treatmentIDs = unique(sapply(treatmentFolders, function(x) {
    temp = substring(x, gregexpr(pattern = '/', x)[[1]][1] + 1)
    if(gregexpr(pattern = '/', temp)[[1]][1] != -1) {
      output = substring(temp, 1, gregexpr(pattern = '/', temp)[[1]][1]-1)
    } else {
      output = temp
    }
    return(output)
  }
  ))
  
  # Get the first level subdirectories as these are the animal directories and store these as animal IDs
  animalIDs = subFoldersClean[!grepl('/', subFoldersClean)]
  
  # Return the list
  return(list('treatmentIDs' = as.vector(treatmentIDs), 'animalIDs' = animalIDs))
  
}

#' Formatted function for reading in morphology data output by the Microglia Morphology Analysis Fiji plugin
#' 
#' @param locations A file location as a string
#' @param seperators A string vector of what string is used to seperate data in the file .e.g ','
#' @param fileEncoding A string of the encoding used in the file
#' @return A data.table object
readInFile = function(locations, seperators, fileEncoding) {

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
    temp = fread(locations, sep = seperators, na.string = 'NaN', encoding = fileEncoding, header = T, data.table = T)
  }
  
  temp$Location = locations
  
  return(temp)
}

#' Return a list containing all the information needed to read in data from the Microglia Morphology Analysis Fiji plugin
#' 
#' @param morphologyWD A path to the 'Working Directory/Output' folder users used with the Fiji plugin, passed as a string
#' @param useFrac A boolean indicating if users want to retrieve the information for FracLac data
#' @return A list where each element corresponds to a data type extracted from the plugin, and within each element
#' we have strings identifying what seperating character and fileEncoding are used, as well as a vector of all file locations
getFileLocations = function(morphologyWD, useFrac) {
  
  # If the last character in our path is a forward slash, remove it as this messes with our
  # path construction
  lastPathCharacter = substr(morphologyWD, nchar(morphologyWD), nchar(morphologyWD))
  if(lastPathCharacter == '/') {
    morphologyWD = substr(morphologyWD, 0, nchar(morphologyWD)-1)
  }

	# List to store the pattern we'll search in our directory for each data type,
	# as well as the character that separates fields in the data, and the 
	# character that separates headers, also fileEncoding argument since on some
	# occassions we need to change it
	storageList = 
	list("Cell Parameters" = 
		list("Sep" = ",",
			"fileEncoding" = "unknown",
			"Locations" = dir(path = morphologyWD, pattern = "Cell Parameters", full.names = T,
				recursive = T, ignore.case = T)),
		"Sholl Parameters" = 
		list("Sep" = ",",
			"fileEncoding" = "Latin-1",
			"Locations" = dir(path = morphologyWD, 
				pattern = 'Sholl Candidate mask', 
				full.names = T, recursive = T, ignore.case = T)))

	if(useFrac == T) {

		# Get the directory where our fractal analysis files are stored
		main_fracLac_dir = 
		dir(path = morphologyWD, pattern = "fracLac", full.names = T, 
			recursive = F, ignore.case = T)

		storageList$`Hull and Circularity` = 
		list("Sep" = "\t",
			"fileEncoding" = "unknown",
			"Locations" = dir(path = main_fracLac_dir, 
				pattern = "Hull and Circle Results.txt", full.names = T, 
				recursive = T, ignore.case = T))
		storageList$`FracLac` = 
		list("Sep" = "\t",
			"fileEncoding" = "unknown",
			"Locations" = dir(path = main_fracLac_dir, 
				pattern = "Scan Types.txt", full.names = T, 
				recursive = T, ignore.case = T))

	}

return(storageList)

}

#' Remove vector elements that don't match a filter, but retain original vector indices
#' 
#' @param filter_it A vector to be filtered
#' @param filter_by A string to find within the filter_it vector
#' @return A vector where any elements that didn't contain filter_by are removed
filterForVector = function(filter_it, filter_by) {
  clean_vec = list()
  
  # For each element in filter_it
  for(currLoc in filter_it) {
    
    # Remove spaces from that element, and uppercase the element
    checkLoc = toupper(gsub(" ", "", currLoc, fixed = T))
    
    # If we find filter_by in the element, add that element to the list
    if(regexpr(filter_by, checkLoc, perl = T)>-1) {
      clean_vec[[currLoc]] = currLoc
    
    # Else set to null
    } else {
      clean_vec[[currLoc]] = NULL
    }
  }
  
  # Remove nulls and return (but keep indices of non null elements as they were originally)
  if(length(clean_vec) != 0) {
    clean_vec[sapply(clean_vec, is.null)] <- NULL
    return(unlist(clean_vec))
  } else {
    stop("Could not match any .csv files to animal and treatment combinations specified")
  }
  
}

#' Takes the output of getFileLocations and uses its contents with the readInFile function to read in Microglia Morphology Analysis Fiji plugin data
#' 
#' @param storageList A list output by the getFileLocations function
#' @param TCSExclude A numeric vector of the TCS values (mask sizes) we don't want to read in
#' @return A list with all the same elements as storageList, plus an additional element for each data type: Files, a list where each element is a file read in for that data type
readInRawData = function(storageList, TCSExclude) {
# Runs the readInFile function for every location passed in from storageList and removes any locations
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

		# For each location read in the file using the readInFile function
		storageList$Files = rbindlist(lapply(storageList$Locations, function(locations, seperators, fileEncoding) {

			temp = readInFile(locations, seperators, fileEncoding)
			return(temp)

			}, storageList$Sep[1], storageList$fileEncoding[1]))

		return(storageList)

	}, TCSExclude)

	return(comboList)

}

#' Applies formatting to the FracLac data to align it with non FracLac data types
#' 
#' @param fracLacComboList A data.table object containing the FracLac data type
#' @return A data.table object
formatFracLacFiles = function(fracLacComboList) {
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

#' Removes metrics from our data that we aren't considering in Inflammation Index construction
#' 
#' @param storageList A list output by the addMissingInfo function
#' @return A list with the metrics removed where relevant
removeUnusedMetrics = function(storageList) {
# Removes certain metrics from our data and return it

	# A vector of the fracLac columns we want to keep
	fracToKeep = 
	c("Animal", "Treatment", "TCS Value", "FractalDimension", "Lacunarity", "Location", "Mask Name")

	# List of columns to remove from the hull and circ and fraclac data
	colsToRemove = list(
		"Hull and Circularity" = 
		c("MEAN FOREGROUND PIXELS", "TOTAL PIXELS", "Hull's Centre of Mass",
			"Width of Bounding Rectangle", "Height of Bounding Rectangle",
			"Circle's Centre", "Method Used to Calculate Circle"),
		"FracLac" =  unique(names(storageList$FracLac$Files)[!(names(storageList$FracLac$Files) %in% fracToKeep)]))

	# Remove the columns we want to get rid of
	for(curr_element in names(colsToRemove)) {
		storageList[[curr_element]]$Files[, eval(colsToRemove[[curr_element]]) := NULL]
	}

	return(storageList)

}

#' Retrieve ID info from a file path
#' 
#' @param idList A string vector of the possible IDs we're trying to associate with this path
#' @param locations A string vector of the file paths we're looking for IDs for
#' @return A string vector of the same length as locations where each element is the ID the element matched in idList
getIDFromLocations = function(idList, locations) {
  
  # Grab the part of the locations file path that contains our ID info (animal or treatment)
  grabStuff = sapply(locations, function(x) substring(x, gregexpr('Output', x)))
  
  # Get the exact part of that substring that contains IDs
  imageName = as.vector(sapply(grabStuff, function(x) strsplit(x, '/')[[1]][2]))
  
  animals = returnVectorOfMatchingValues(idList, imageName)
  
  return(animals)
  
}

#' Retrieve the TCS value (mask size) from a vector of file locations
#' 
#' @param locations A string vector of file locations
#' @return A vector of TCS values the same length as locations
getTCSFromLocations = function(locations) {
  
  # Grab the part of the locations file path that contains our ID info
  grabStuff = sapply(locations, function(x) substring(x, gregexpr('Output', x)))
  
  # Get the exact part of that substring that contains TCS values
  imageName = as.vector(sapply(grabStuff, function(x) strsplit(x, '/')[[1]][3]))
  
  # Remove the 'TCS' string
  tcsVector = as.vector(sapply(imageName, function(x) strsplit(x, 'TCS')[[1]][2]))
  
  return(tcsVector)
  
}

#' Retrieve the TCS value (mask size) from a vector of file locations. Unlike getTCSFromLocations(), this is suitable for use with FracLac and Hull and Circularity data
#' 
#' @param locations A string vector of file paths
#' @return A vector of TCS values
getTCSFromFracLacLocations = function(locations) {
  
  # For each location, cut out the bit that corresponds to TCS size
  TCSValues = as.vector(sapply(locations, 
                               function(x) substring(x, 
                                                     gregexpr("(TCS)[0-9]", x)[[1]][1]+3, 
                                                     gregexpr("Candidate", x)[[1]][1]-1)))
  
  return(TCSValues)

}

#' Return the strings that match a vector of strings
#' 
#' @param idList A string vector of the possible string values we're looking for
#' @param locations A string vector of all the strings we want to find our idList value within
#' @return A string vector the same length as locations where each element is a value from idList
returnVectorOfMatchingValues = function(idList, locations) {
  
  # Create a vector of the length of our locations to populate with IDs
  animals = vector(length = length(locations))
  
  # For each element we have in idList, if it matches the string in locations that
  # we've isolated, store that id in animals
  for (currentAnimal in idList) {
    matches = as.vector(sapply(toupper(gsub(' ', '', locations, fixed = T)), function(x) grepl(gsub(' ', '',currentAnimal, fixed = T), x)))
    animals[matches] = currentAnimal
  }
  
  return(animals)
  
}

#' Extract a 'Mask Name' from the FracLac / Hull and Circularity file locations that matches the format of the Parameters data types
#' 
#' @param locations A string vector of file locations from FracLac data outputs
#' @return A string vector of Mask Names
getFracLacMaskNames = function(locations) {
  
  # If we've got FracLac data, first get out a Mask Name in a similar format 
  # to how it is built for the non FracLac data
  mask_name = sapply(locations, function(x) {
    
    cutString = substring(x, gregexpr('candidate', tolower(x)))
    xCoord = substring(cutString, gregexpr('x', cutString)[[1]][1]+1, gregexpr('y', cutString)[[1]][1]-1)
    yCoord = substring(cutString, gregexpr('y', cutString)[[1]][1]+1, gregexpr('tif', cutString)[[1]][1]-1)
    substack = substring(cutString, gregexpr('for', cutString)[[1]][1]+3, gregexpr('x', cutString)[[1]][1]-1)
    
    paste('Candidate mask for', substack, 'x', xCoord, 'y', yCoord, 'tif', sep = ' ')
    
  })
  
  return(mask_name)

}

#' Adds in values missing from each data type
#' 
#' @param storageList A list output by readInRawData
#' @param animalIDs A string vector of the animal IDs we want to read in data for
#' @param treatmentIDs A string vector of the treatment IDs we want to read in data for
#' @return A list similar to storageList but with missing data added to the $Files elements
addMissingInfo = function(storageList, animalIDs, treatmentIDs) {
# Adds in info that is missing from our data using the mapStuff list and fill_to_add() output
  
  # Sholl parameter things to add - TCS values
  mapStuff = 
    list(
      "Cell Parameters" =
        list("Animal" =
               getIDFromLocations(animalIDs, storageList$`Cell Parameters`$Location),
             "Treatment" =
               getIDFromLocations(treatmentIDs, storageList$`Cell Parameters`$Location),
             "TCS Value" =
               getTCSFromLocations(storageList$`Cell Parameters`$Location)),
      "Sholl Parameters" = 
        list("Animal" = 
               getIDFromLocations(animalIDs, storageList$`Sholl Parameters`$Location),
             "Treatment" =
               getIDFromLocations(treatmentIDs, storageList$`Sholl Parameters`$Location)))
  
  if(sum(grepl('FracLac', names(storageList))) > 0) {

		frac_names = c('FracLac', 'Hull and Circularity')

		# Remove the location column
		for(curr_element in frac_names) {
		  
			storageList[[curr_element]]$Files[, Location := NULL]

		  # Rename the column in the first index as location
		  names(storageList[[curr_element]]$Files)[1] = 'Location' 
		}
		
		# Format the fraclac files
		storageList$FracLac$Files =  formatFracLacFiles(storageList$FracLac$Files)
		
		# Sholl parameter things to add - TCS values
		mapStuffFrac = 
		  list(
		    "Hull and Circularity" =
		      list("TCS Value" =
		             getTCSFromFracLacLocations(storageList$`Hull and Circularity`$Files$Location),
		           "Animal" = 
		             returnVectorOfMatchingValues(animalIDs, storageList$`Hull and Circularity`$Files$Location),
		           "Treatment" =
		             returnVectorOfMatchingValues(treatmentIDs, storageList$`Hull and Circularity`$Files$Location),
		           "Mask Name" = getFracLacMaskNames(storageList$`Hull and Circularity`$Files$Location)),
		    "FracLac" =
		      list("TCS Value" =
		             getTCSFromFracLacLocations(storageList$FracLac$Files$Location),
		           "Animal" = 
		             returnVectorOfMatchingValues(animalIDs, storageList$FracLac$Files$Location),
		           "Treatment" =
		             returnVectorOfMatchingValues(treatmentIDs, storageList$FracLac$Files$Location),
		           "Mask Name" = getFracLacMaskNames(storageList$FracLac$Files$Location)))
		
		mapStuff = c(mapStuff, mapStuffFrac)
		
	}
	
	# Here we add on our data we need to add to each element of our data
	for(curr_element in names(mapStuff)) {
		storageList[[curr_element]]$Files = cbind(storageList[[curr_element]]$Files, as.data.table(mapStuff[[curr_element]]))
	}

	return(storageList)

}

#' Add a unique ID for each animal, treatment, TCS, and cell, to our files
#' 
#' @param storageList A list output by addMissingInfo
#' @return A list identical to storageList but with a UniqueID column added to the $Files elements
formatUniqueID = function(storageList) {
  
  # Now adjust the Mask Name for our other data to be identical to the FracLac data
  for(currData in c('Cell Parameters', 'Sholl Parameters')) {
    
    mask_name = sapply(storageList[[currData]]$Files$`Mask Name`, function(x) {
      
      gsub('\\.', '', x)
      
    })
    storageList[[currData]]$Files[, 'Mask Name':= mask_name]
  }
  
  # Now paste together all our ID info into a unique ID for each cell
	for(currType in names(storageList)) {
	  
	  storageList[[currType]]$Files[, UniqueID := tolower(paste(Animal, Treatment, `TCS Value`, `Mask Name`, sep = ""))]
	  
	}

  # Return our storageList
	return(storageList)

}

#' Remove all cells that aren't common across different data types
#' 
#' @param with_id A list output by formatUniqueID
#' @return A list identical in structure to with_id but with non-common cells removed
retainCommonCells = function(with_id) {

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

#' Converts FracLac metrics from pixels into the correct units to align with Parameter data
#' 
#' @param storageList A list output by retainCommonCells
#' @param pixelSize A numeric that is the pixel size in microns
#' @return A list identical to storageList except with calibrated values for FracLac related data
convertHCtouM = function(storageList, pixelSize) {
  
  # Vector of measures in the hull and circularity data we want to convert from
  # pixels to um
  conv_list_names <- c("Area", "Density = Foreground Pixels/Hull Area", 
                       "Perimeter", "Diameter of Bounding Circle", "Mean Radius", 
                       "Maximum Span Across Hull", "Maximum Radius from Hull's Centre of Mass",
                       "Maximum Radius from Circle's Centre", "Mean Radius from Circle's Centre")
  
  # A vector of the numbers to multiple by respectively to do
  # that
  multiplyBy = rep(pixelSize, length(conv_list_names))
  multiplyBy[1] = pixelSize^2
  multiplyBy[2] = pixelSize^2
  names(multiplyBy) = conv_list_names
  
  # Copy our storageList so we can edit it w/o inintended consequences..
  edit = copy(storageList)
  
  # For each metric in our converison list, convert it according to the multiplyBy value
  for(curr_metric in names(multiplyBy)) {
    edit$`Hull and Circularity`$Files[, eval(curr_metric) := as.numeric(unlist(get(curr_metric))) * multiplyBy[curr_metric]]
  }
  
  # Return our list
  return(edit)
  
}

#' Formats labelling column names to be identical across different data types
#' 
#' @param inputData A list output by retainCommonCells
#' @return A list identical to inputData but with formatted column names
formatNames = function(inputData) {
# Format the column names in our data
	
  um_data = copy(inputData)
  
	# Get the column names of every data type
	uniqueIDList = lapply(um_data, function(x) {
    	names(x$Files)
	})

	# Get the names that are common to more than one data type, and identify those that aren't labels
	repeat_names = names(which(table(unlist(uniqueIDList)) > 1))
	name_change = repeat_names[!repeat_names %in% c('Animal', 'Mask Name', 'Location', 'TCS Value', 'Treatment', 'UniqueID')]

	# For column names that aren't labels and are present in more than one data type, make them unique by pasting the data
	# type to their name
	for(curr_name in name_change) {
		for(curr_element in names(um_data)) {
			if(curr_name %in% names(um_data[[curr_element]]$Files)) {
				setnames(um_data[[curr_element]]$Files, old = curr_name, new = paste(curr_element, curr_name, sep = ''), skip_absent = T)
			}
		}
	}

	# For all the data, remove spaces from the headers, and from the Mask Name
	# values to make them consistent between data types
	returnList = 
	lapply(um_data, function(x) { 
		names(x$Files) = gsub(" ", "", names(x$Files))
		x$Files$MaskName = gsub(" ", "", x$Files$MaskName)
		return(x) 
	})

	return(returnList)

}

#' Merge all our different data types together into a single data.table object
#' 
#' @param inputData A list output by formatNames
#' @return A data.table object that contains our merged dataset
mergeDataTogether = function(inputData) {
# Merge all our data types into a single data.table
  
  storageList = copy(inputData)

	# Get out the data.table for the elements of storageList to merge together into a single list
	forMerge = lapply(storageList, function(x) {
		x$Files[, c("Animal", "Treatment", "MaskName", "TCSValue", "UniqueID") :=
		list(as.character(unlist(Animal)), as.character(unlist(Treatment)),
			as.character(unlist(MaskName)), as.numeric(unlist(TCSValue)),
			as.character(unlist(UniqueID)))]
		if("Location" %in% names(x$Files)) {
			x$Files[, Location := NULL]
		}
		return(x$Files)
	})

	# Merge everything together 
	merged = Reduce(merge, forMerge)

	# Create a unique name that could be repeated across TCS values, and assign each unique numeric value
	merged[, TCSName := paste(Treatment, Animal, MaskName)]
	merged = merged %>% group_by(TCSName) %>% mutate(CellNo = cur_group_id())
	merged = as.data.table(merged)

	# If we're using frac, calculate branching density
	if('FracLac' %in% names(storageList)) {
		merged$BranchingDensity = merged$SkelArea / merged$Area
	}

	# Create a list of columns to remove from the final merged DF and then remove them
	mergeToRemove = c("TCSName", "MaskName")
	mergeToRemoveChecked = names(merged)[grepl(paste(mergeToRemove, collapse = "|"), names(merged))]
	merged[, eval(mergeToRemoveChecked) := NULL]

	# Make all non-label columns numeric
	labelCols =     c('TCSValue', 'Animal', 'Treatment', 'UniqueID', 'CellNo')
	make_numeric = names(merged)[!names(merged) %in% labelCols]

	for(currCol in make_numeric) {
		merged[, eval(currCol) := as.numeric(get(currCol))]
	}

	return(merged)

}

#' Wrapper function for all morphology data preprocessing for data output by the Microglia Morphology Analysis Fiji Plugin
#' 
#' @param pixelSize A numeric identifying the pixel size of our analysed images in microns (assuming a square pixel)
#' @param morphologyWD A string path pointing to the 'Output' folder of the 'Working Directory' users used when running the Fiji plugin
#' @param animalIDs A string vector of the animal IDs we want to read in data for
#' @param treatmentIDs A string vector of the treatment IDs we want to read in data for
#' @param TCSExclude OPTIONAL A vector of the TCS values (mask sizes) we don't want to read data in for. Defaults to NULL.
#' @param useFrac OPTIONAL A boolean indicating whether we want to read in FracLac related data. Defaults to False.
#' @return A data.table object of our morphology data merged and cleaned.
#' @export
morphPreProcessing <- function(pixelSize,
	morphologyWD,
	TCSExclude = NULL,
	animalIDs,
	treatmentIDs,
	useFrac = F) {

	if(is.null(pixelSize)) {
		stop("Need to provide a pixelSize in um")
	}

	if(is.null(morphologyWD)) {
		stop("Need to provide a directory (morphologyWD) for input files")
	}

	if(is.null(animalIDs)) {
		stop("Need to provide a vector of animal IDs")
	} else {
		animalIDs = toupper(animalIDs)
	}

	if(is.null(treatmentIDs)) {
		stop("Need to provide a vector of treatment IDs")
	} else {
		treatmentIDs = toupper(treatmentIDs)
	}

	if(is.null(useFrac)) {
		stop("Need to provide a boolean for useFrac")
	}

	# Format our locations, seperators, encoding info to pass into our data reading function
	passList = getFileLocations(morphologyWD, useFrac)
	
	# Remove any animals or treatments from our non-fraclac data that isn't in our animalIDs or treatmentIDs input vectors
	for(currType in c('Cell Parameters', 'Sholl Parameters')){
	  
	  # Filter for our animals and treatments - collapse these vectors using the 'OR' symbol and remove whitespace
	  passList[[currType]]$Locations = filterForVector(passList[[currType]]$Locations, gsub(paste(animalIDs, collapse = '|'), ' ', ''))
	  passList[[currType]]$Locations = filterForVector(passList[[currType]]$Locations, gsub(paste(treatmentIDs, collapse = '|'), ' ', ''))
	}
	
	# Read in our raw csv files
	comboList = readInRawData(passList, TCSExclude)
	# Alter storageList with info we need to add on (called mapstuff in the function)

	# mapStuff is a bunch of stuff we need to add onto each data type that its 
	# missing, this is either cell identifiers, or values for the TCS. These are
	# calculated using the file locations or IDs of the rows
	mapList = addMissingInfo(storageList = comboList, animalIDs = toupper(animalIDs), treatmentIDs = toupper(treatmentIDs))
	
	# Filter our fractal data by animal and treatment IDs
	if(useFrac == T) {
  	for(currType in c('Hull and Circularity', 'FracLac')){
  	  mapList[[currType]]$Files = mapList[[currType]]$Files[Animal %in% animalIDs]
  	  mapList[[currType]]$Files = mapList[[currType]]$Files[Treatment %in% treatmentIDs]
  	}
	  
	  # Remove columns we no longer need
	  cleanList = removeUnusedMetrics(mapList)
	  
	} else {
	  cleanList = copy(mapList)
	}

	# Add in a unique ID for each cell and mask size to all our elements
	with_id = formatUniqueID(copy(cleanList))

	# Retain only data where we have cells for all data types
	common_data = retainCommonCells(with_id)
	
	if(useFrac == T) {

		# Convert our HC data to um
		common_data = convertHCtouM(common_data, pixelSize)

	}

	# Format all our metric names so we can merge data types
	name_changed = formatNames(common_data)

	# Merge our data types into a single data.table
	merged = mergeDataTogether(name_changed)

	return(merged)

}