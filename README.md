# Inflammation-Index
This is the repo for the code used to construct the Inflammation Index, developed by Devin Clarke in Catherine Hall's lab.

# MicrogliaMorphologyAnalysis.ijm

Plugins required:
- MultiStackReg (http://bradbusse.net/sciencedownloads.html)

This script is to be used with Fiji, and runs on single channel .tif images. These images should be 3D stacks. If the stacks contain multiple frames for single Z positions, the least blurred/motion contaminated of these will be retained. When the script is run, the user is asked what options they want to run, these are:
- Preprocess morphology stacks and save them
- Mark cell positions
- Generate masks for cells
- Quality control masks
- Analyse masks
- Quality control motion processing

The user is then asked to locate the working directory for the script to run in. This can be an empty directory, and this will be populated as necessary, or to a previously used directory for the script.

## Preprocessing Morphology Stacks

This selection prompts the user to select the parent directory within which their raw images are stored, before the user is then asked for:
- How many frames to keep (FtoKeep)
- How many frames to use for an average projection (FAvgProj)
- Whether to manually select frames or not
- What string to use to identify images
- Whether calibration values are stored in an .ini file

Images should be stored in the form Parent Directory -> Animal Names -> Treatments/Timepoints -> Image. How many frames to keep refers to how many frames per Z point should be retained once the least blurred/motion contmainated are identified. The number of frames to use for the average projection changes how the least motion contaminated images are identified. Manual frame selection lets the user select the best frames manually. Image string identifiers are used to find images to process, and finally if calibration values are stored in a .ini text file, these can be retrieved if indicated.

The script then proceeds to look in the selected directory for images labelled with the indicated string, and extracts the animal name and treatment. These are concatenated together along with the string "Microglia Morphology" and the image is saved under that name in the working directory indicated previously within the "Input" folder. 

If the calibration of the images is stored in a text file saved with the .ini extension, this should be saved in the same folder as the image i.e. in the Treatments/Timepoints folder. Calibration values for the image will be extracted from this file. Alternatively, if the image is calibrated, they can be extracted from the image, though the number of planes per frame will need to be manually input. If present, the ini file for the image will be labelled with the animal and treatment values before being moved into the Ini File folder in the working directory. Calibration values are assumed to be in microns, but this isn't a necessity.

The ini file should contain the strings "x.pixel.sz = ", "y.pixel.sz = ", "z.spacing = ", "no.of.planes = ", "frames.per.plane = " followed by numeric values. Z spacing refers to the size of voxels in Z, no. of.planes refers to the number of unique Z planes images, and frames.per.plane refers to how many frames were collected at each Z plane.

### Motion Artefact Removal and Image Registration

#### Manual frame selection

If the user has indicated that they want to manually select frames, the image stack will be split up into individual Z planes and the user will be asked to select however many frames they indicated in the section menu (FtoKeep) that they deem least motion contaminated / blurry. The frames chosen will be saved in a Slice to Use.csv file and saved in the Output folder of the working directory in the appropriate animal/treatment folder.

#### Automatic Frame Selection

Otherwise for each Z plane, the frames are run through a laplacian of gaussian filter where the maximum pixel value is then used as an indicator of "blurriness" where higher values indicate images are less blurred. Then the number of least blurred frames (indicated by the user (FAvgProj)) are retained before being averaged. This average is then compared to the other frames and by a simple process of pixel subtraction, the difference between the average projection and each frame is calculated. The number of least different frames indicated by the user (FtoKeep) are then retained.

#### Registration and Re-ordering

For each Z plane, the retained frames are averaged, and then each average is concatenated before being registered and reordered in Z. This reordering in Z is done according to image similarity using the Z Spacing Correction plugin, and is done because motion during image acquisition can cause the apparent Z positon of an image to be different to its actual Z position. Images are then calibrated (a check is run to see if the unit of the image is um or not, and if not, it is calibrated) and saved in the working directory in the output folder in folders labelled with the animal name and treatment/timepoint.

## Quality Control Motion Processing

In this selection, users are presented with the motion processed images and asked to indicate if the processing is satisfactory or not. They are asked how many images they would like to be displayed on the screen at a single time, and then to close images that don't meet their satisfaction before pressing "ok" on a dialog box. Closed images will be flagged as unsuitable in a .csv file. These flagged images will be available for manual frame selection on the next run of the image preprocessing option selection. If they have already gone through manual frame selection, they will be ignored for the remained of the scripts options.

## Marking Cell Positions

This stage involves the user placing point selections on cell bodies in substacks of the processed image stacks. These are first generated automatically, before users are then allowed to either approve the automatic generation, change the generation, or manually select, cells. If the automated selection is poor, the user is asked what went wrong, whether it was bad image registration, or bad body detection. If bad registration, the image is flagged so frames can be manually selected when running the preprocessing step, and ignored from future analysis steps. If detection was bad, the user manually selects / edits the cell selection. Stacks are split into substacks 10um deep, with at least 10um separating each substack, and a buffer of 10um from the beginning and end of the stack. These substacks are average projected and it is these average projections on which cell selections are made, and cells masks are drawn and analysed.

## Automatically Generate Cell Masks

From these point selections, cell masks are automatically generated using the methodlogy outlined in Kozlowski and Weimar (2012): https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0031814. Briefly, 120um x 120um ROIs are drawn around the point selections, and the selections are optimised (to ensure they sit on the brightest point of the cell body). A threshold is then applied to the image, and the area of all the pixels (in um^2) that are in direct contact with the point selection that pass this threshold are compared to a user defined mask size (MS) +/- a user defined range. If the area is within the MS +/- the range, the area is retained as a mask of the cell. Otherwise, through an interative process, the threshold of the image is adjusted until the area of the pixels sits in this range. If, after three consecutive iterations, the area is stable but does not sit within the range, the mask is still retained, else, the cell location is ignored for future processing.

When choosing this option in the menu, the user is asked 
- What mask sizes to use as lower and upper limits
- What range to use for MS error
- What increment to increase the MS by on each loop

Here the script loops from the lower and upper limits of the MS and creates cell masks that lie within the current MS +/- the defined range. The loop increase the MS by the increment defined by the user. In this way we generate cell masks across a range of MS values for each individual cell.

## InflammationIndex R Package

Package for R, which works with the output of the MicroMorphologyAnalysis.ijm script. This script semi-automatically identifies and extracts morphological measurements from microglial cells, and the R package is used to process and format the output of this, before using the data to build a PCA-based composite measure that is sensitive to inflammation-associated morphological changes
