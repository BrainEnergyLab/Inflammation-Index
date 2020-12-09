# Inflammation-Index
In this repo you'll find all the code necessary to process 3D image stacks of microglia, extract morphological features for detected cells, and combine these features into a single metric of morphological train sensitive to the training data you provide. This is detailed in other READMEs in this repo, and also in the associated publication.

**Current work is focusing on converting the Microglia Morphology Analysis Plugin for ImageJ from a script file into a .jar file that will introduce menu options into ImageJ to improve its useability**

## Documentation

### Using the Microglia Morphology Analysis ImageJ Plugin.md

This file describes how to use the ImageJ script for image processing, cell detection, and morphological feature extraction.

### Using-the-R-InflammationIndex-Package.md

This file describes how to use the Inflammation-Index R package to read in data extracted by the Microglia Morphology Analysis plugin, and use to generate and apply an 'Inflammation Index'

## Other Folder Contents

### Microglia Morphology Analysis Plugin - ImageJ

Contains the code for the Microglia Morphology Analysis plugin. Currently (as of 03.12.20) this contains a single script file that users have to read in and run. The next iteration will provide this as a .jar file that users can use to add a plugin to their ImageJ installation, and access functionality through items in the plugin menu.

### Microglia Morphology Analysis Plugin - ImageJ Example Directory and Input Data

This folder contains example data that users can run the Microglia Morphology Analysis plugin on in order to test it.

### R Folder

Contains the functions that are part of the InflammationIndex R package
