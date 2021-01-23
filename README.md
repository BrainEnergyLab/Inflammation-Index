# Inflammation-Index
In this repo you'll find all the code necessary to process 3D image stacks of microglia, extract morphological features for detected cells, and combine these features into a single metric of morphological train sensitive to the training data you provide. This is detailed in other READMEs in this repo, and also in the associated publication.

**Read the publication here: https://www.biorxiv.org/content/10.1101/2021.01.12.426422v1**

**Current work is focusing on converting the Microglia Morphology Analysis Plugin for ImageJ from a script file into a .jar file that will introduce menu options into ImageJ to improve its useability**

## Documentation

### Using the Microglia Morphology Analysis ImageJ Plugin.md

This file describes how to use the ImageJ script for image processing, cell detection, and morphological feature extraction.

**Since the addition of the ImageJ plugin this file needs to be updated**

### Using-the-R-InflammationIndex-Package.md

This file describes how to use and install the Inflammation-Index R package to read in data extracted by the Microglia Morphology Analysis plugin, and use it to generate and apply an 'Inflammation Index' to novel data

## Other Folder Contents

### Microglia Morphology Analysis Plugin - ImageJ

Contains the .jar and .py files necessary for running the Microglia Morphology Analysis ImageJ script. Drop the .jar file into your Fiji plugins folder, and the .py file into the plugins/scripts folder.

**You can follow progress on changes and updates to the plugin at https://github.com/BrainEnergyLab/Inflammation-Index/projects/1 and observe development of the plugin at https://github.com/DAZN-DKClarke/ImageJMicroMorphJarTest**

### R Folder

Contains the functions that are part of the InflammationIndex R package
