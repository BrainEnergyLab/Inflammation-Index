# This README is currently being updated to reflect changes made to the plugin 

# Microglia Morphology Analysis ImageJ Plugin

## Installation and Dependencies

---

This plugin was written to be applied to *in vivo* images of fluorescent microglia obtained in awake mice on a two photon microscope, but in theory can be run on any single channel 3D image stacks of cells with clearly labelled soma and processes.

Running the Microglia Morphology Analysis ImageJ script / plugin requires the installation of:
- [Fiji](https://imagej.net/Fiji)
- [FeatureJ](https://imagej.net/FeatureJ) 
- [MultiStackReg](http://bradbusse.net/sciencedownloads.html)
- [TurboReg](http://bigwww.epfl.ch/thevenaz/turboreg/) (drop the .jar file included in the distribution into your Fiji plugins folder)
- [FracLac](https://imagej.nih.gov/ij/plugins/fraclac/fraclac.html)
- [Stack Contrast Adjustment](https://imagej.nih.gov/ij/plugins/stack-contrast/index.htm)
- [SNT](https://github.com/morphonets/SNT) (including extra SciView functionality)
- [Jython](https://imagej.nih.gov/ij/plugins/jython/) (download the .jar file and place it in a '/jars' folder in your Fiji plugins folder if it isn't already present)

To install the Microglia Morphology Analysis plugin, download the [.jar](https://github.com/BrainEnergyLab/Inflammation-Index/blob/master/Microglia%20Morphology%20Analysis%20Plugin%20-%20ImageJ/microglia-morphology-analysis-0.1.0.jar) file from this GitHub repo  and drop it into your Fiji plugins folder. In addition, download the [Microglia_Morphology_Analysis_Plugin_Sholl_Analysis_Script.py](https://github.com/BrainEnergyLab/Inflammation-Index/blob/master/Microglia%20Morphology%20Analysis%20Plugin%20-%20ImageJ/Microglia_Morphology_Analysis_Plugin_Sholl_Analysis_Script.py) script and drop it into the 'Scripts' folder in your Fiji plugins folder.

**Plugin .jar file location:**

![Plugin .jar location](./MarkdownAssets/microglia_morphology_plugin_plugins_location.jpg)

**Plugin .py file location:**

![Plugin .py file location](./MarkdownAssets/microglia_morphology_plugin_py_location.png)

### Example Data

You can find a directory containing the same image and folder structure as outlined below and download it yourself to follow along with the instructions [here](https://drive.google.com/drive/folders/1e3qkTAhBBKOFFnTt9iWhM7Jtzr2GXH6o?usp=sharing)

## Step 1: Setting Up Folder Structures

---

### Raw Image Storage

To begin with, image stacks should be stored in a folder structure as follows:

**Parent Directory -> Animal Name -> Treatment Name -> Image File**

![Example image storage structure](./MarkdownAssets/example_image_storage_directory.png)

In the above image for example:
- Parent Directory: 'Image Storage Directory'
- Animal Name: 'CE1L'
- Treatment Name: 'HFD21'
- Image File: '20181023...'

In addition a text file containing the calibration information for the images in this parent directory should be saved in the parent directory with the '.ini' file extension. This file should contain the strings:
- "x.pixel.sz = "
- "y.pixel.sz = "
    - X and Y pixel size refer to the X and Y pixel sizes in microns
- "z.spacing = "
    - Z spacing refers to the size of voxels in Z in microns
- "no.of.planes = "
    - Number of planes refers to the number of unique Z planes in the image stack
- "frames.per.plane = " 
    - Frames per plane refers to how many frames were collected at each Z plane

These strings should be followed by their associated numeric values.

For example, a stack of 606 frames in total, with 101 unique Z planes, would have 6 frames per plane.

![Example ini file](./MarkdownAssets/example_ini_file.png)

### Working Folder Structure

In addition you need to have an empty folder where the plugin can save all its outputs. This can be any empty folder. For example, here we will be using the 'Working Directory' folder.

![Example working directory](./MarkdownAssets/example_working_directory.png)

## Step 2: Running Stack Preprocessing

---

The first step in the image processing pipeline is stack preprocessing. This can be accessed in the 'Microglia Morphology Analysis Plugin' menu option within the Fiji 'Plugins' menu.

![Stack preprocessing command location](./MarkdownAssets/StackPreprocessingModule/stack_preprocessing_command_location.png)

You will then be prompted to select the image storage and working directories that you set up in step 1.

![Working directory selection prompt](./MarkdownAssets/working_directory_selection_prompt.png)

![Working directory folder selection](./MarkdownAssets/working_directory_folder_selection.png)

![Image storage directory selection prompt](./MarkdownAssets/image_storage_selection_prompt.png)

![Image storage folder selection](./MarkdownAssets/image_storage_folder_selection.png)

### User Inputs

When selecting this first option, the user will be asked for a number of inputs.

- How many of the 'best' frames per Z plane do you want to include in the final Z plane image?

This is an integer value with the default set to 1. This value determines how many of the least motion-contaminated frames the script will average over to create a final single frame for each Z plane. If 1, rather than averaging frames, the least contamined frame is smoothed using a median filter. This value cannot be 0, and cannot more than the number of frames per Z plane.

- How many frames do you want to include in the average projection of least blurry frames per Z plane?

In order to identify the least motion-contaminated frames described above, the plugin first uses a blur detector to choose the least blurry frames to average over to create a reference frame. All the frames for that Z plane are then compared to this reference frame and the frames that are least different to this reference frame are identified as the least motion-contaminated.

This user input chooses the number of least blurry frames to use to create the reference frame. This input requires an integer value and defaults to 3. Setting this to half the number of frames per Z plane is a good rule of thumb. This value cannot be 0, and cannot more than the number of frames per Z plane.

- If you have already run the 'Stack QA' module, do you want to manually select frames to keep from images that failed automated selection QA in this run?

For image stacks that have already been processed and QA'd (the subsequent step in the pipeline) and failed QA, if checked the plugin will present these stacks to the user so they can manually select the least motion-contaminated frames to retain for each Z plane. These will then be recompiled into a final Z stack and this will be available for QA in the stack QA step.

- What string should we search for in the Image Storage directory to find stacks to process?

This is a string value that indicates which string identifier to use to identify images to process. This can be useful if you only want to process a subset of the images in your Image Storage directory and this subset can be identified by a unique string. It cannot be empty and defaults to "Morphology".

![Stack preprocessing user inputs](./MarkdownAssets/StackPreprocessingModule/stack_preprocessing_user_inputs.png)

### Outputs

For each image processed, a new folder with a name created by concatenating the Animal name, Treatment name, and 'string to search for', is created in the 'Output' folder in the working directory. This folder contains the processed stack for that image.

In addition, a copy of the raw image is saved in the 'Done' folder in the working directory.

![Stack preprocessing outputs](./MarkdownAssets/StackPreprocessingModule/stack_preprocessing_outputs.png)

Finally, an 'Images to Use' csv file is saved in the 'Output' folder. This file has a row for each image processed, an indicates if the image has been automatically processed, if this automatically processed version passed QA (in the next step), if the image has been manually processed, and if this manually processed version passed QA (in the next step). In this file values of 1 represent 'Yes', values of 0 represent 'No', and a value of -1 means 'null' i.e. for the QA values, -1 means we haven't run a QA step for the image.

![Stack preprocessing images_to_use.csv auto](./MarkdownAssets/StackPreprocessingModule/stack_preprocessing_images_to_use_1.png)

## Step 3: Running Stack QA

---

### "QC Motion Processing"
### Quality Controlling The Processing Output

Once processing has been done, users should select this option to quality control the output images. Here users are asked how many images to show on the screen at once as the script loops through all processed images. The user then closes images they wish to ignore for the next steps in the analysis. If these ignored images were generated automatically (i.e. "Manually select frames" was not ticked) they are flagged for manual selection the next time the processing step is run. If they were manually selected, they are ignored for all future steps.

### "Mark cell positions"
### Identifying Cell Body Locations

Here the approved processed stacks are split into 10um thick substacks, with at least 20um between substacks and substacks beginning at least 10um from the start of the stack and ending at least 10um from its end. These substacks are averaged into 2D images which are then what all future steps are carried out on. In this section the script automatically detects cell body locations on these 2D projections. The user can then approve or discard the automatic cell location detection. If approved, the user can then add more point selections to identify cells that may have been missed. If discarded, the user indicates if they discarded the locations because of poor image registration, or poor cell body detection. If poor registration, the image is flagged for manual frame selection the next time the processing step is run. If it has already been manually selected, the image is discarded from further sections. If poor detection, the user can manually select the location of cell bodies.

### "Generate masks for cells"
### Automatically Generate Cell Masks

In this section the script automatically generates cell masks for each marked cell body using the methodology outlined in  Kozlowski and Weimar (2012): https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0031814. Briefly, a 120 x 120um square is drawn around each cell, and an initial threshold for the image is calculated using Otsu's method. The area of all pixels that are connected to the cell body that pass this threshold is measured, and if this area falls within a user defined mask size +/- range, these pixels are saved as the mask of the cell. If the area does not fall in the area, the threshold is adjusted iteratively until the area falls in the range. If the area stabilises for 3 consecutive iterations but is outside of the range, the mask is retained. If the area is within the range but also within 5 microns of the edges of the 120 x 120um local region, the mask is discarded.

In this section the user is asked for a number of inputs:

- What mask size would you like to use as a lower limit?
- What mask size would you like to use as an upper limit?
- What range would you like to use for mask size error?
- What increment would you like to increase mask size by per loop?

Here the user indicates the starting (lower limit) and end (upper limit) mask sizes to loop through and the increment by which to do this, as well as the range around the mask size that cell areas can fall within. For the initial run of this Fiji script, which should be limited to the positive control inflammation dataset, a range from lower to upper values of 200-800 is recommended (though a smaller range can be used to save time), with an error of 100 and an increase of 100 per loop. This is so that further on in the pipeline inflammation indices can be constructed for each mask size trialled, and the mask size associated with the inflammation index with the best ability to detect inflammatory morphological changes can then be set as the exclusive value to run on all other data.

The formula for iteratively changing the threshold is as follows:
Next Threshold = Current Threshold + Current Threshold * ((Current Area - Mask Size) / (Number of Iterations * Mask Size))

### "Quality control masks"
### Approve Generated Cell Masks

Here users are presented with each automatically generated cell mask, as well as an automatically generated outline of the soma for each cell. Users can reject the cell mask (if it encompasses two cells for example, or is located on a cell that is not in focus) or approve it. If approved, they can do the same for the soma mask, and if the soma mask is rejected, they must draw an appropriate outline of the soma manually. Users can also select the option to "Manually trace processes" where for each mask they can trace around processes that the automatic mask generation missed.

This process starts with the highest mask size trialled. If a mask has been approved at a higher mask size than is currently being checked, it will automatically be approved. In this way the number of masks a user has to approve is reduced. Soma masks only have to be approved / drawn for a single mask size as they stay consistent between mask sizes.

### "Analyse masks"
### Extract Morphological Descriptors

Approved cell and soma masks are then analysed across a number of morphological descriptors, and the results of these analyses are saved in the appropriate output folder for each animal / treatment combination. These results then form the input for the functions in the InflammationIndex R package. The generation of results from the FracLac plugin in Fiji requires that users manually run the plugin on the "fracLac" folder in the output folder of the working directory that is created and populated once this analysis step has been run on all generated masks.

#### FracLac Settings and Directions

Users should select the FracLac plugin within the Plugins -> Fractal Analysis menu in Fiji. They should then select the "BC" button, and tick the Save -> Results box. Tick the Hull and Circle -> Metrics box Select ok. Now click on Batch, and select the fracLac folder in the working directory -> output folder as this is where results will be saved. When asked about using the ROI manager, select cancel. Then in the next dialog box, i.e. "select files to analyse", highlight all the files in the fracLac folder. Once more the user must select the fracLac folder in a dialog box. Then tick "disable time checks" and continue. The plugin will now run on the files in the fracLac folder, and save its output in this folder as well. This output will be processed with the R InflammationIndex package.  
