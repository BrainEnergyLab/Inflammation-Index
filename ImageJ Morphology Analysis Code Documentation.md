# MicrogliaMorphologyAnalysis.ijm

Plugins required:
- MultiStackReg (http://bradbusse.net/sciencedownloads.html)

This script is to be used with Fiji, and runs on single channel .tif images. These images should be 3D stacks. The code and pipeline was designed to work with two-photon image stacks of microglia obtained in awake animals. If the stacks contain multiple frames for single Z positions, the least blurred/motion contaminated of these will be retained. When the script is run, the user is asked what options they want to run, these are:

- Preprocess morphology stacks and save them (1)
- Mark cell positions (3)
- Generate masks for cells (4)
- Quality control masks (5)
- Analyse masks (6)
- Quality control motion processing (2)

The user is then asked to locate the **working directory** for the script to run in. This can be an empty directory, and this will be populated as necessary, or to a previously used directory for the script. Generally the options should be run in the numeric order indicated in parentheses.

## Preprocessing Morphology Stacks

This selection prompts the user to select the parent directory within which their raw images are stored, before the user is then asked for:

- How many frames to keep **(FtoKeep)**
- How many frames to use for an average projection **(FAvgProj)**
- Whether to manually select frames or not
- What string to use to identify images
- Whether calibration values are stored in a .ini file

Images should be stored in the form **Parent Directory -> Animal Names -> Treatments/Timepoints -> Image**. How many frames to keep (**FtoKeep**) refers to how many frames per Z point should be retained once the least blurred/motion contmainated frames are identified. If this is one, the chosen frame is smoothed with a median filter, else the frames are averaged. The smoothed/averaged images for each Z plane are then recompiled to form the processed image stack. The number of frames to use for the average projection (**FAvgProj**) changes how the least motion contaminated images are identified. Manual frame selection lets the user select the best frames manually rather than using the automated detection of blurred/motion contaminated frames. Image string identifiers are used to find images to process. Finally if calibration values are stored in a .ini text file, these can be retrieved if indicated.

The script looks in the selected directory for images labelled with the indicated string, and extracts the animal name and treatment. These are concatenated together along with the string "Microglia Morphology" and the image is saved under that name in the **working directory** indicated previously within the "Input" folder. 

If the calibration of the images is stored in a text file saved with the .ini extension, this should be saved in the same folder as the image i.e. in the Treatments/Timepoints folder. Calibration values for the image will be extracted from this file. Alternatively, if the image is calibrated, these values can be extracted from the image, though the number of **planes per frame** (i.e. how many frames represent a single Z plane) will need to be manually input. If present, the ini file for the image will be labelled with the animal and treatment values before being moved into the Ini File folder in the **working directory**. Calibration values are assumed to be in microns, but this isn't a necessity.

The ini file should contain the strings "x.pixel.sz = ", "y.pixel.sz = ", "z.spacing = ", "no.of.planes = ", "frames.per.plane = " followed by numeric values. Z spacing refers to the size of voxels in Z, no. of.planes refers to the number of unique Z planes in the image stack, and frames.per.plane refers to how many frames were collected at each Z plane.

### Motion Artefact Removal and Image Registration

#### Manual frame selection

If the user has indicated that they want to manually select frames, the image stack will be split up into individual Z planes and the user will be asked to select however many frames they indicated in the section menu (**FtoKeep**) that they deem least motion contaminated / blurry. The location of the chosen frames will be saved in a Slice to Use.csv file in the Output folder of the **working directory** in the appropriate animal/treatment folder.

#### Automatic Frame Selection

Otherwise for each Z plane, the frames are run through a laplacian of gaussian filter where the maximum pixel value is then used as an indicator of "blurriness" where higher values indicate images are less blurred (https://www.pyimagesearch.com/2015/09/07/blur-detection-with-opencv/; https://stackoverflow.com/questions/7765810/is-there-a-way-to-detect-if-an-image-is-blurry). Then the number of least blurred frames indicated by the user (**FAvgProj**) are averaged. This average is then compared to the raw frames and by a simple process of pixel subtraction, the difference between the average projection and each frame is calculated. The number of frames that are least different from the avaerage projection indicated by the user (**FtoKeep**) are then retained.

#### Registration and Re-ordering

For each Z plane, the retained frames (whether detected automatically or indicated manually) are averaged, and then each average is concatenated before being registered and reordered in Z. This reordering in Z is done according to image similarity using the Z Spacing Correction plugin, and is done because motion during image acquisition can cause the apparent Z positon of an image to be different to its actual Z position. Images are then calibrated (a check is run to see if the unit of the image is um or not, and if not, it is calibrated) and saved in the **working directory** in the output folder in folders labelled with the animal name and treatment/timepoint.

## Quality Control Motion Processing

In this section users are presented with the motion processed images and asked to indicate if the processing is satisfactory or not. They are asked how many images they would like to be displayed on the screen at a single time, and then to close images that don't meet their satisfaction before pressing "ok" on a dialog box. Closed images will be flagged as unsuitable in a .csv file. These flagged images will be available for manual frame selection on the next run of the image preprocessing option selection. If the discarded images have already gone through manual frame selection, they will be ignored for the remainder of the script options.

## Marking Cell Positions

This stage involves the user placing point selections on cell bodies in substacks of the processed image stacks. These are first generated automatically, before users are then allowed to either approve the automatic generation, change the generation, or manually select, cells. If the automated selection is poor, the user is asked what went wrong, whether it was bad image registration, or bad cell body detection. If bad registration, the image is flagged so it will be ignored from future processing steps but also so frames can be manually selected when re-running the preprocessing step to try and improve the registration. If detection was bad, the user manually selects / edits the cell selection. Stacks are split into substacks 10um deep, with at least 10um separating each substack, and a buffer of 10um from the beginning and end of the stack. These substacks are average projected and it is these average projections on which cell selections are made, and cells masks are generated and analysed.

## Automatically Generate Cell Masks

From these point selections, cell masks are automatically generated using the methodlogy outlined in Kozlowski and Weimar (2012): https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0031814. Briefly, 120um x 120um ROIs are drawn around the point selections, and the selections are optimised (to ensure they sit on the brightest point of the cell body). A threshold is then applied (initially this is calculated using the Otsu method) to the image, and the area of all the pixels (in um^2) that are in direct contact with the point selection that pass this threshold are compared to a user defined mask size (MS) +/- a user defined range. If the area is within the MS +/- the range, the area is retained as a mask of the cell. Otherwise, through an interative process, the threshold of the image is adjusted until the area of the pixels sits in this range. If, after three consecutive iterations, the area is stable but does not sit within the range, the mask is still retained, else, the cell location is ignored for future processing. Masks are discarded if they are within 5um of the edge of the 120 x 120um area.

When choosing this option in the menu, the user is asked 
- What mask sizes to use as lower and upper limits
- What range to use for MS error
- What increment to increase the MS by on each loop

Here the script loops from the lower to upper limits of the MS and creates cell masks that lie within the current MS +/- the defined range. The loop increase the MS by the increment defined by the user. In this way cell masks are generated across a range of MS values for each individual cell.

The formula for iteratively generating masks is: 

Next Threshold = Current Threshold + Current Threshold * ((Current Area - Mask Size) / (Number of Iterations * Mask Size))

## Quality Control Cell Masks

Here the script loops through all the automatically generated cell masks. The masks, as well as an automatically generated mask of their somata, are presented to the user. The user can either accept, or draw their own soma mask. Users also are asked to approve or discard cell masks. This is to ensure only accurate masks are retained i.e. not masks that incorporate two adjacent cells, or masks that cover cells that are no in focus. Soma masks only need to be approved for a single mask size value, though cell masks must be approved for all mask size values. Users are presented with a menu when running this section with a single option:

- Manually trace processes?

When selected, users can manually draw around processes that the automatically generated cell masks missed. Again, this needs to be done for each mask size.

## Analyse Cell Masks

This section of the script analyses various morphological descriptors for the cell and soma masks. A full list of these is presented in the associated publication. These measures are saved in .csv files in a folder structure that is compatible with the InflammationIndex R package also stored in this GitHub repo. Additionally, copies of the cell masks to be analysed are saved in a "fracLac" folder in the Output folder of the **working directory**. The files in this fracLac folder can be run through the FracLac imageJ plugin, a plugin that takes morphology measures using fractal and hull and circularity morphometrics.

### Running FracLac

