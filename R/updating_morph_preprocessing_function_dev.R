require(devtools)
install_github("BrainEnergyLab/Inflammation-Index")
require(InflammationIndex)

pixelSize = 0.58 # Pixel size in microns
morphologyWD = "/Microglial Morphology/Output" # Output directory of the MicroMorph.ijm script as a string
imageStorageDirectory = '/Users/devin.clarke/Google Drive/Microglia Morphology Analysis Plugin - ImageJ Example Directory and Input Data/Image Storage Directory'
useFrac = T # Boolean indicating whether to use the output of the FracLac plugin
TCSExclude = NULL # String vector of mask sizes to exclude from the preprocessing function, can also take NULL

# This function returns a list that contains the animal IDs and treatment IDs that are
# present in the image storage directory users have been using in the Inflammation Index
# pipeline
getAnimalAndTreatmentIDs <- function(imageStorageDirectory) {
 
  # Get all the directories in the imageStorageDirectory
  subFolders = list.dirs(path = imageStorageDirectory, full.names = F)
  
  # Remove the first element since this is empty
  subFoldersClean = subFolders[2:length(subFolders)]
  
  # Get the subdirectories of the animal directories and store these as treatment IDs
  treatmentFolders = subFoldersClean[grepl('/', subFoldersClean)]
  treatmentIDs = sapply(treatmentFolders, function(x) substring(x, gregexpr(pattern = '/', treatmentFolders[1])[[1]][1] + 1))
  
  # Get the first level subdirectories as these are the animal directories and store these as animal IDs
  animalIDs = subFoldersClean[!grepl('/', subFoldersClean)]
  
  # Return the list
  return(list('treatmentIDs' = as.vector(treatmentIDs), 'animalIDs' = animalIDs))

}

allIDs = getAnimalAndTreatmentIDs(imageStorageDirectory)
animalIDs = allIDs$animalIDs
treatmentIDs = allIDs$treatmentIDs


output = 
  morphPreProcessing(
    pixelSize = pixelSize, morphologyWD = morphologyWD, 
    animalIDs = animalIDs, treatmentIDs = treatmentIDs,
    useFrac = useFrac)