This repo contains all the code necessary to generate an inflammation index - i.e. a single measure that is sensitive to the morphological effects of inflammation on microglial morphology. This code was written to be applied to in vivo images of fluorescent microglia obtained in awake mice on a two photon microscope, but in theory can be run on any single channel 3D microglia image stacks. The inflammation index is a composite measure based on multiple individual morphological measures, and serves as a way to reduce the dimensionality of a morphological dataset and provide a single measure of morphological change.

Running the scripts and package in this repo requires the installation of Fiji with the MultiStackReg plugin (http://bradbusse.net/sciencedownloads.html), the FracLac plugin (https://imagej.nih.gov/ij/plugins/fraclac/fraclac.html), and the Stack Contrast Adjustment plugin (https://imagej.nih.gov/ij/plugins/stack-contrast/index.htm), and RStudio with the devtools package.

To construct this index, images from a positive control condition of inflammation must be present. In brief, the morphological measures of microglia that are best at discriminating between this positive control condition, and a control condition, are combined into a composite measure and this is what forms the inflammation index. The weightings of these measures can then be applied to other data to generate a measure of inflammatory morphological changes.

# Step 1: Raw Image Storage Folder Structure

To begin with, single channel 3D image stacks of microglia should be stored in a folder structure as follows:

Parent Directory -> Animal Name -> Treatment / Timepoint Name -> Image File

If not calibrated, a text file saved with the .ini extension can be saved in the same folder as the Image File it corresponds to. It should contain the strings: "x.pixel.sz = ", "y.pixel.sz = ", "z.spacing = ", "no.of.planes = ", "frames.per.plane = " followed by numeric values. Z spacing refers to the size of voxels in Z, no. of.planes refers to the number of unique Z planes in the image stack, and frames.per.plane refers to how many frames were collected at each Z plane. For 3D stacks acquired in awake animals, movement can disrupt image acquisition. As such, taking multiple frames at a single Z plane allows the motion-contaminated frames to be removed and a clearer final 3D stack to be generated.

**Note: a future aim is to have the option to store calibration values in a single .ini file in the parent directory containing the calibration info for all image files in that directory**

The following pipeline, **Step 2**, should first be run exclusively on the inflammatory positive control and control conditions. This can be done by searching for specific strings in image or image folder names in the motion processing section. 

# Step 2: Running MicrogliaMorphologyAnalysis.ijm in Fiji on Positive Control Inflammation Images

## Motion Processing, Registration, and Z Correction

First, create a directory for the Fiji script to work within. This can be just a single empty folder, and this will be populated by the script.

Open the MicrogliaMorphologyAnalysis.ijm file in Fiji, and click the run button in the script editor. Tick the script option labelled "Preprocess morphology stacks and save them". If calibration values are stored in ini files for each image, tick this box as well. Click ok. Select the working directory followed by the parent directory for image storage. The user is then asked for a number of inputs.

- How many frames per Z plane to average over for the final Z plane image?

This is an integer value with the default set to 1. This value determines how many of the least motion-contaminated/blurry images the script will average to create a final single each for the associate Z plane. If 1, this frame is smoothed using a median filter. This value cannot be 0, and cannot more than the number of frames per Z plane.

- An average projection of least blurry frames for each Z plane is used to select the frames to retain. How many frames do you want to include in this average projection?

Part of the process in determining how motion-contaminated images are is to use a blur detector to select the least blurred images, average these, and then compare this average to the frames. This input requires an interger value and defaults to 3. Setting this to half the number of frames per Z plane is a good rule of thumb. This value cannot be 0, and cannot more than the number of frames per Z plane.

- Manually select frames?

This is a tickbox where users can indicate if rather than using the automated method of detecting and retaining the least motion-contaminated / blurry frames, they would prefer to select the frames to use themselves. If selected, the script cycles through each Z plane, presenting all the frames, and the user must select the frames to retain. They must select the same number of frames as indicated in the first input (How many frames per Z plane to average over for the final Z plane image?) though the input to the second option (An average projection of least blurry frames for each Z plane is used to select the frames to retain. How many frames do you want to include in this average projection?) is ignored if this is ticked.

- String to search for

This is a string value that indicates which string identifier to use to identify images to process. This can be useful if the microglia images are stored with other images, or if the user wants to limit processing to a single animal / treatment. It cannot be empty and defaults to "Morphology".

If the user has not put calibration values in a .ini file, they are asked how many frames exist per plane.

Once run, this section of the script saves processed image stacks in the working directory in the Output folder, in folders labelled with the animal name and treatment/timepoint the image was sourced from. If ini files were used, these are saved with the animal name and treatment/timepoint in the Ini File folder.

## Quality Controlling Processing

Once processing has been done, users should select this option to quality control the output images. Here users are asked how many images to show on the screen at once as the script loops through all processed images. The user then closes images they wish to ignore for future analyses. If these ignored images were generated automatically (i.e. "Manually select frames" was not ticked) they are flagged for manual selection the next time the processing step is run. If they were manually selected, they are ignored for all future steps.

## Marking Cell Positions

Here the approved processed stacks are split into 10um thick substacks, with at least 10um between substacks and substacks beginning at least 10um from the start of the stack and ending at least 10um from its end. These substacks are averaged into 2D images which are then what all future steps are carried out on. In this section the script automatically detects cell body locations on these 2D projections. The user can then approve, edit, or discard, the automatic cell location detection. If discarded, the user indicates if they discarded the locations because of poor image registration, or poor cell body detection. If poor registration, the image is flagged for manual frame selection the next time the processing step is run. If it has already been manually selected, the image is discarded from further sections. If poor detection, the user can manually select the location of cell bodies.

## Generating Cell Masks

In this section the script automatically generates cell masks for each marked cell body using the methodology first outlined in  Kozlowski and Weimar (2012): https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0031814. Briefly, a 120 x 120um square is drawn around each cell, and an initial threshold for the image is calculated using Otsu's method. The area of all pixels that are connected to the cell body that pass this threshold is measured, and if this area falls within a user defined mask size +/- range, these pixels are saved as the mask of the cell. If the area does not fall in the area, the threshold is adjusted iteratively until the area falls in the range. If the area stabilises for 3 consecutive iterations but is outside of the range, the mask is retained. If the area is within the range but also within 5 microns of the edges of the 120 x 120um local region, the mask is discarded.

In this section the user is asked for a number of inputs:

- What mask size would you like to use as a lower limit?
- What mask size would you like to use as an upper limit?
- What range would you like to use for mask size error?
- What increment would you like to increase mask size by per loop?

Here the user indicates the starting (lower limit) and end (upper limit) mask sizes to loop through and the increment by which to do this, as well as the range around the mask size that cell areas can fall within. For the initial run of this Fiji script, which should be limited to the positive control inflammation experiment images, a combination of lower-upper values of 200-800 is recommended, with a range of 100 and an increase of 100 per loop. This is so that further on in the pipeline, inflammation indices can be constructed for each mask size trialled, and the mask size associated with the inflammation index with the best ability to detect inflammatory morphological changes can then be set as the exclusive value to run on all other images.

## Quality Control Cell Masks

Here users are presented with each automatically generated cell mask, as well as an automatically generated outline of the soma for each cell. Users can reject the cell mask (if it encompasses two cells for example, or is located on a cell that is not in focus) or approve it. Additionally, they can do the same for the soma mask, and if the soma mask is rejected, they must draw an appropriate outline of the soma manually. Users can also select the option to "Manually trace processes" where for each mask they can trace around processes that the automatic mask generation missed.

Cell masks must be approved at each mask size they have been generated. If masks have been approved at a higher mask size, they do not need to be approved at lower values. Soma masks must only be approved/edited once per cell.

**Note: future change is to loop through mask size values from highest to lowest to take advantage of the fact that cell masks once approved at higher values, don't need approval at lower values**

## Analyse Cell Masks

Approved cell and soma masks are then analysed across a number of morphological descriptors, and the results of these analyses are saved in the appropriate output folder for each animal / treatment combination. These results then form the input for the functions in the InflammationIndex R package. The generation of results from the FracLac plugin in Fiji requires that users manually run the plugin on the now generated "fracLac" folder in the output folder of the working directory.

### FracLac Settings and Directions

# Step 3: InflammationIndex R Package Running on Positive Control Inflammation Data

In RStudio the InflammationIndex package can be installed first by installing and loading devtools -
install.packages("devtools")
require(devtools)

Then by installing and loading the InflammationIndex package -
install_github("DKClarke/Inflammation-Index")
require(InflammationIndex)

Now users should run the morphPreProcessing() function. Here they should specify the pixel size in microns (assuming a square pixel), and the morphologyWD argument should be a string that is a path to the output folder of the working directory of the Fiji script. AnimalIDs should be a string vector of the names of the Animal folders in the image storage structure, and likewise for the TreatmentIDs argument. This function puts together all the output of the Fiji script analysis into a single data table where each row is a cell and each column is a morphological measure.

Following this, users should run the constructInfInd() function, where inDat is set to the output of the morphPreProcessing() function, LPSGroups is a string vector (length of 2) of the TreatmentIDs that identify the positive control and control groups for the inflammation experiment, method is the method used to identify the mask sizes that are best at discrminating inflammation from control groups (can use the smallest p value of comparisons, or the area under the curve of a receiver-operating characteristic (ROC) analysis). This function loops through each mask size value present, and first uses an ROC analysis to rank the morphological measures that are best at discriminating between inflammed/non-inflammed cells. Then, the function builds a composite index composed of between 1 to 15 of the best discriminators at each mask size, and using the method specified to pick which mask size, and number of features included in the composite, provides the best discrimination of inflammed/non inflammed cells. This building of a composite measure is based on work by Heindl et al. (2018): https://doi.org/10.3389/fncel.2018.00106.

When run, the constructInfInd function prints to the console the mask size best at discrminating inflammation. This mask size should be noted.

# Step 4: Running MicrogliaMorphologyAnalysis.ijm in Fiji on Remaining Data

As in step 2, the script in Fiji should now be run on all imaging data in the image storage folder. Now when specifying the range of mask sizes to use, set both the upper and lower values to the mask size value printed to the R console at the end of step 3.

# Step 5: InflammationIndex R Package Running on All Data

Users can now use the infInd() function which wraps both morphPreProcessing() and constructInfInd() into one. This function will compile all data from the Fiji script (the TCSExclude argument can be used to avoid compiling all mask sizes except the one of interest), before applying the weights derived from the positive control experiment to all other data to generate a final inflammation index. This function will return a list containing the compiled data with the final column as the inflammation index, and a PCA object containing the PCA run on the positive control data to generate the weights for the inflammation index.

This final inflammation index can then be analysed as a single metric of inflammation related morphological changes.
