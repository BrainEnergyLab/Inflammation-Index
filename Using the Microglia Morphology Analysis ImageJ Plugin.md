# This README is currently being updated to reflect changes made to the plugin 

# Microglia Morphology Analysis ImageJ Plugin

---

## Table of Contents
1. [Installation and Dependencies](#installation-and-dependencies)
2. [Step 1: Setting up Folder Structures](#step-1-setting-up-folder-structures)
3. [Image Stack Processing: Motion Artefact Removal and Cleaning](#image-stack-processing-motion-artefact-removal-and-cleaning)
    1. [Step 2: Running Stack Preprocessing](#step-2-running-stack-preprocessing)
    2. [Step 3: Running Stack QA](#step-3-running-stack-qa)
        1. [Optional: Manual Processing](#step-3a-optional-manually-processing-stacks-that-were-rejected-from-qa)
        2. [Optional: QA Manually Processed Stacks](#step-3b-optional-qa-manually-processed-stacks)
4. [Automated Cell Detection](#automated-cell-detection)
    1. [Step 4: Cell Detection](#step-4-cell-detection)
    2. [Step 5: Mask Generation](#step-5-mask-generation)

---

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

---

## Image Stack Processing: Motion Artefact Removal and Cleaning

This aspect of the pipeline covers two modules in the plugin menu:
- Stack Preprocessing
- Stack QA

These modules are used to process and clean 3D image stacks so that they are suitable for use with the cell detection and quantification modules later in the pipeline.

---

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

After running this step on a stack for the first time, 'Auto Processing' will have a value of 1. If an automatically processed image does not pass QA in the next step, when the user manually processes it in this step again, its 'Manual Processing' value is changed to 1.

## Step 3: Running Stack QA

---

The next step in the pipeline is to QA the processed substacks.

![Stack QA command location](./MarkdownAssets/StackQAModule/stack_qa_command_location.png)

### User Inputs

When selecting to run this step, users are asked for some inputs:

- How many images do you want to display on the screen at once?

Here users can specify how many images they want to display on the screen at once for them to visually inspect. This needs to be an integer value and to be greater than 0. The value defaults to 1.

![Stack QA user inputs](./MarkdownAssets/StackQAModule/stack_qa_user_inputs.png)

Users are then asked to select the 'working directory' and 'image storage directory' as they were in the previous step.

After providing these inputs, the plugin displays the number of processed stacks the user indicated and prompts the user to 'close the images that aren't good enough in terms of registration for analysis then press ok'.

![Stack QA user inputs1](./MarkdownAssets/StackQAModule/stack_qa_user_inputs1.png)

The plugin proceeds in this manner until it has obtained user inputs (i.e. was the image closed or not closed) for all available processed images.

### Outputs

Whether the user has closed an image or not updates its values in the 'Images to Use.csv' file created in the previous step. In each case:

- If an image was the result of automated processing steps:
    - ... and it was not closed in this step:
        - This stack is cleared for use in the next steps
        - The value of 'Auto QA Passed' in 'Images to Use.csv' is set to 1  
    - ... and it was closed in this step:
        - The copy of the input stack in the 'Done' folder is moved back into the 'Input' folder and the 
        - The value of 'Auto QA Passed' in 'Images to Use.csv' is set to 0

In this second case, users can then run Step 1 again and tick the 'If you have already run the 'Stack QA' module, do you want to manually select frames to keep from images that failed automated selection QA in this run?' option when asked for user inputs. This will then prompt the user to manually select the best frames to retain from the image. Output images that have been manually processed can then be run through this 'Stack QA' section and now:

- If an image was the result of manual processing:
    - ... and it was not closed in this step:
        - This stack is cleared for use in the next steps
        - The value of 'Manual QA Passed' in 'Images to Use.csv' is set to 1  
    - ... and it was closed in this step:
        - This stack is now ignored for all future steps 
        - The value of 'Manual QA Passed' in 'Images to Use.csv' is set to 0

## Step 3A (Optional): Manually Processing Stacks That Were Rejected from QA

---

If an automatically processed image is rejected in the previous step, we can run Step 2 again (Stack preprocessing) and this time manually select the frames to keep.

### User Inputs

After selecting the 'working directory' and 'image storage directory' as in previous steops, the key input that needs to be ticked to manually process stacks is:

- If you have already run the 'Stack QA' module, do you want to manually select frames to keep from images that failed automated selection QA in this run?

![Stack Preprocessing manual user inputs](./MarkdownAssets/StackPreprocessingModule/stack_preprocessing_manual_user_inputs.png)

The other relevant user input for manually processing is:

- How many of the 'best' frames per Z plane do you want to include in the final Z plane image?

Whilst for automated processing this value decides how many frames per Z plane to retain based on motion detection steps, for manual processing this value decides how many frames per Z plane users must manually select to keep to average over into a cleaned version of that Z plane.

If the manual processing option is ticked, the plugin will then cycle the image stacks that have been flagged for manually processing and loops through each Z plane in the image stack and presents all the frames from that Z plane in a substack. The user is then prompted to:

- Scroll onto the frame to retain and click 'OK' 

![Stack Preprocessing manual user inputs1](./MarkdownAssets/StackPreprocessingModule/stack_preprocessing_manual_user_inputs1.png)

Users must select the required number of frames for each Z plane for all Z planes in the stack. Once this is done, these chosen frames are compiled into an output stack.

### Outputs

The outputs are virtually the same as in Step 2. However, an additional file: 'Slices to Use.csv' is saved in the approriate images subfolder in the 'Output' folder. This file stores the number of the frame/s at each Z plane the user chose to retain. 0's indicate the frame was not chosen, whilst a non-zero number indicates the frame number that was chosen at it's associated Z plane. In additional, image stacks that have been manually processed have their 'Manual Processing' value in the 'Images to Use.csv' file is set to 1.

## Step 3B (Optional): QA Manually Processed Stacks

---

After manually processing images, the 'Stack QA' step can be run again where users will now be presented with the manually processed stacks to approve. As stated previously:

- If an image was the result of manual processing:
    - ... and it was not closed in this step:
        - This stack is cleared for use in the next steps
        - The value of 'Manual QA Passed' in 'Images to Use.csv' is set to 1  
    - ... and it was closed in this step:
        - This stack is now ignored for all future steps 
        - The value of 'Manual QA Passed' in 'Images to Use.csv' is set to 0

---

## Automated Cell Detection

This aspect of the pipeline covers three modules in the plugin menu:
- Cell Detection
- Mask Generation
- Mask QA

These modules are used to semi-automatically detect and segment cells in the image stacks so they can be quantified in the final part of this pipeline.

---

## Step 4: Cell Detection

---

This module automatically detects cells in the image stacks, but allows for users to either select cells manually, or manually edit the automatic cell selections

![Cell detection command location](./MarkdownAssets/CellDetectionModule/cell_detection_command_location.png)

### User Inputs

As in previous steps, users are prompted to select their 'working directory' and 'image storage directory'.

Following this, they are asked:

- What size buffer in um to use to seperate substacks?

This value is used to ensure that when the image stack is split into multiple substacks, the cells in each substack are adequately seperated so that single cells are not represented more than once (i.e. present in multiple substacks). E.g. for a 50um deep stack we want to cut it up into multiple 10um substacks. We take the first 10 microns (0-10) and turn this into a substack. We then leave a buffer (the user indicated value) and then take the next 10 um. E.g. if the buffer is 10 um, we will create a 20-30 um substack from the input image. Etc.

This value needs to be an integer and defaults to 10.

![Cell detection user inputs](./MarkdownAssets/CellDetectionModule/cell_detection_user_inputs.png)

For each substack created, we average project it and display this to the user with the automated cell location detection overlaid and the user is prompted to 'check that the automated CP selection has worked'. 

![Cell detection automated detection](./MarkdownAssets/CellDetectionModule/cell_detection_automated_detection.png)

Here we see the automated cell detection has identified a cell location where the cyan circle ROI is drawn.

Once users click 'ok', they are asked 'Automated CPs Acceptable?'. 

**In this context, 'acceptable' means the cell detection has detected the soma of at least one cell accurately. If we have detected no cells, or the detection has highlighted a region of the image that is not cell soma, the detection is unacceptable**

**If users indicate that the automated cell detection has worked:**

Users are then prompted to 'click on cells that were missed by automated detection, if any, and click 'ok' when done'. 

At this point, after clicking on cells missed by the automated detection process and then clicking 'ok', these cell locations are saved and users are presented with the next substack projection, and so on until cell detection is complete. Users should click on the soma of cells in the image.

![Cell detection automated detection added](./MarkdownAssets/CellDetectionModule/cell_detection_automated_detection_added.png)

Here you can see we have indicated cells manually where the red circular ROIs are drawn.

**If users indicate that the automated cell detection has not worked:**

Users are then prompted to 'check what's wrong with the automated CP generation'. Once they have determined if the incorrect cell detection is due to their poor image quality, or poor detection, they can click 'ok' and indicate which of these reasons apply.

![Cell detection bad reasons](./MarkdownAssets/CellDetectionModule/cell_detection_bad_reasons.png)

If users indicate that the problem is bad registration, this substack is flagged as failing 'QC' and ignored for all future steps. If users indicate that the only problem is poor detection, they are prompted to 'click on cells to select for analysis, if any, and click 'ok' when done'. Here users can manually indicate cells on the image, and when done the locations of these cells will be saved. Users should click on the soma of cells in the image.

### Outputs

This module creates multiple outputs.

1. 'Mask Generation Status.csv'
    - This file is saved in the 'Output' folder and indicates for each image, how many substacks we can make of that image (based on the user defined buffer) and how many substacks have been made for that image. This is so that if the user exits the 'Cell Detection' module midway, we know where to pick up from in terms of substack generation.

![Cell detection mask generation status](./MarkdownAssets/CellDetectionModule/cell_detection_mask_generation_status.png)

2. 'Cell Coordinates/CP Coordinates for Substack (xx-xx).csv'
    - This file is generated for each substack in an image, and is stored in that image's 'Cell Coordinates' folder. This file contains the X and Y coordinates for each cell location detected / added, as well as columns for the 'optimal' X and Y coordinates for each cell, and the 'optimal' threshold for each cell. These optimal values are described in further detail in the next step.

![Cell detection CP coordinates for substack](./MarkdownAssets/CellDetectionModule/cell_detection_cp_coordinates_for_substack.png)

3. 'Cell Coordinate Masks/CP mask for Substack (xx-xx).tif'
    - This is the average projection of the substack saved for each substack in the image's folder, within the 'Cell Coordinate Masks' folder.

3. 'Cell Coordinate Masks/Cell Position Marking.csv'
    - This file stores, for each substack, whether it has been 'Processed' i.e. if it has had cell locations generated / edited, and whetheris has been 'QC'd' i.e. whether these detected cell locations have gone through user approval. This file is created for each substack for each image in the image's 'Cell Coordinate Masks' folder.
        - For images that users reject for 'bad registration', the QC value is set to 0, else it is set to 1.

![Cell detection cell position marking](./MarkdownAssets/CellDetectionModule/cell_detection_cell_position_marking.png)


---

## Step 5: Mask Generation

---

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
