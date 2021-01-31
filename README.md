# Inflammation-Index

In this repo you'll find all the code necessary to process 3D image stacks of microglia, extract morphological features for detected cells, and combine these features into a single metric of morphological change sensitive to the training data you provide. This is detailed in other READMEs in this repo, and also in the associated **[pre-print publication](https://www.biorxiv.org/content/10.1101/2021.01.12.426422v1)**

**Work on updating the Fiji plugin has concluded, and is now focused on updating the README file for its use. Following this, work will commence on updating the R package to align with the updated outputs produced by the Fiji plugin updates**

**You can follow progress on changes and updates to the plugin [here](https://github.com/BrainEnergyLab/Inflammation-Index/projects/1) and observe development of the Fiji plugin [here](https://github.com/DAZN-DKClarke/ImageJMicroMorphJarTest)**

---

# Documentation

---

### [Using the Microglia Morphology Analysis ImageJ Plugin.md](https://github.com/BrainEnergyLab/Inflammation-Index/blob/master/Using%20the%20Microglia%20Morphology%20Analysis%20ImageJ%20Plugin.md)

This file describes how to use the ImageJ plugin for image processing, cell detection, and morphological feature extraction.

**This file is currently being updated**

### [Using the R Inflammation-Index Package.md](https://github.com/BrainEnergyLab/Inflammation-Index/blob/master/Using%20the%20R%20Inflammation-Index%20Package.md)

This file describes how to use and install the Inflammation-Index R package to read in data extracted by the Microglia Morphology Analysis plugin, and use it to generate and apply an 'Inflammation Index' to novel data

**Given updates to the Fiji plugin, the R package and README need to be updated to be compatible with the changes**

---

## Other Folder Contents

---

### [Microglia Morphology Analysis Plugin - ImageJ](https://github.com/BrainEnergyLab/Inflammation-Index/tree/master/Microglia%20Morphology%20Analysis%20Plugin%20-%20ImageJ)

Contains the .jar and .py files necessary for running the Microglia Morphology Analysis ImageJ plugin. Drop the .jar file into your Fiji plugins folder, and the .py file into the plugins/scripts folder.

### [R Folder](https://github.com/BrainEnergyLab/Inflammation-Index/tree/master/R)

Contains the functions that are part of the InflammationIndex R package.
