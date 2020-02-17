# Inflammation-Index
This is the repo for the code used to construct the Inflammation Index, developed by Devin Clarke in Catherine Hall's lab.

##MicrogliaMorphologyAnalysis.ijm

Plugins required:
- MultiStackReg (http://bradbusse.net/sciencedownloads.html)

This script is to be used with Fiji, and runs on single channel .tif images. When run, the user is asked what options they want to run, these are:
- Preprocess morphology stacks and save them
- Mark cell positions
- Generate masks for cells
- Quality control masks
- Analyse masks
- Quality control motion processing

###Preprocessing Morphology Stacks

Package for R, which works with the output of the MicroMorphologyAnalysis.ijm script. This script semi-automatically identifies and extracts morphological measurements from microglial cells, and the R package is used to process and format the output of this, before using the data to build a PCA-based composite measure that is sensitive to inflammation-associated morphological changes
