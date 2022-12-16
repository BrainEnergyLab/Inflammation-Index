# Inflammation-Index

In this repo you'll find all the code necessary to process 3D image stacks of microglia, extract morphological features for detected cells, and combine these features into a single metric of morphological change sensitive to the training data you provide. This is detailed in other READMEs in this repo, and also in the associated **[publication](https://pubmed.ncbi.nlm.nih.gov/34375551/)**

**You can follow progress on changes and updates to this GitHub repo and the R and Fiji plugins [here](https://github.com/BrainEnergyLab/Inflammation-Index/projects/1) and observe development of the Fiji plugin [here](https://github.com/DAZN-DKClarke/ImageJMicroMorphJarTest)**

**If you're having issues with the plugin that we are unable to resolve, you can find a standalone Fiji package [here](https://drive.google.com/drive/folders/1ZNUTkUueam0nT7ZjUI2-f5VO9UCv_cRM?usp=share_link) that has the plugin installed that you can download and use to unblock your work**

---

# Documentation

---

### [Using the Microglia Morphology Analysis ImageJ Plugin.md](https://github.com/BrainEnergyLab/Inflammation-Index/blob/master/Using%20the%20Microglia%20Morphology%20Analysis%20ImageJ%20Plugin.md)

This file describes how to use the ImageJ plugin for image processing, cell detection, and morphological feature extraction.

### [Using-the-R-Inflammation-Index-Package.md](https://github.com/BrainEnergyLab/Inflammation-Index/blob/master/Using-the-R-Inflammation-Index-Package.md)

This file describes how to use and install the Inflammation-Index R package to read in data extracted by the Microglia Morphology Analysis plugin, and use it to generate and apply an 'Inflammation Index' to novel data

---

## Discussions

---

Please post any questions, suggestions, etc. [here](https://github.com/BrainEnergyLab/Inflammation-Index/discussions)

---

## Roadmap

---

Outstanding issues, feature changes, updates etc. will be posted and tracked [here](https://github.com/BrainEnergyLab/Inflammation-Index/projects)

---


## Other Folder Contents

---

### [Microglia Morphology Analysis Plugin - ImageJ](https://github.com/BrainEnergyLab/Inflammation-Index/tree/master/Microglia%20Morphology%20Analysis%20Plugin%20-%20ImageJ)

Contains the .jar and .py files necessary for running the Microglia Morphology Analysis ImageJ plugin. Drop the .jar file into your Fiji plugins folder, and the .py file into the plugins/scripts folder.

### [R Package](https://github.com/BrainEnergyLab/Inflammation-Index/tree/master/R%20Package)

Contains the R package code that can be installed using devtools.

### [MarkdownAssets](https://github.com/BrainEnergyLab/Inflammation-Index/tree/master/MarkdownAssets)

Contains images used to enrich the markdown README files.

### [Microglia Morphology Analysis Example Videos](https://github.com/BrainEnergyLab/Inflammation-Index/tree/master/Microglia%20Morphology%20Analysis%20Example%20Videos)

Contains video files demonstrating how to use the Fiji plugin functions.
