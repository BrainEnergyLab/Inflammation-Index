#@LogService log

'''
Based on https://github.com/morphonets/SNT/blob/master/src/main/resources/script_templates/Neuroanatomy/Analysis/Sholl_Extensive_Stats_Demo.groovy
and https://github.com/morphonets/SNT/blob/master/src/main/resources/script_templates/Neuroanatomy/Analysis/Sholl_Extract_Profile_From_Image_Demo.py
and https://gist.github.com/GenevieveBuckley/d9a7238b47d501063a3ddd782067b151 (for writing to csv)

API for LinearProfileStats = https://javadoc.scijava.org/Fiji/sc/fiji/snt/analysis/sholl/math/LinearProfileStats.html#getKStestOfFit--
for Normalised stats = https://javadoc.scijava.org/Fiji/index.html?sc/fiji/snt/package-summary.html
'''

# Import all the libraries we need to do our sholl analysis
from ij import IJ
from ij.measure import Calibration
from sc.fiji.snt import Tree
from sc.fiji.snt.analysis.sholl import (Profile, ShollUtils)
from sc.fiji.snt.analysis.sholl.gui import ShollPlot
from sc.fiji.snt.analysis.sholl.math import LinearProfileStats
from sc.fiji.snt.analysis.sholl.math import NormalizedProfileStats
from sc.fiji.snt.analysis.sholl.math import ShollStats
from sc.fiji.snt.analysis.sholl.parsers import (ImageParser2D, ImageParser3D)
import os
import csv

# Define a function where we print if there's a difference between teh numeric value we're using to extract
# semi-log or log-log values, and the numeric value actually returned by the API
def checkCorrectMethodFlag(normProfileMethodFlag, assumedValue):
    if normProfileMethodFlag != assumedValue:
        print(str(normProfileMethodFlag))
        print('Problem with method flag')
        return

# Populate a dictionary of our mask metrics
def populateMaskMetrics(maskName, tcsVal, lStats, nStatsSemiLog, nStatsLogLog, cal):

    # Store all our metrics in a dictionary
    maskMetrics = {'Mask Name': maskName,
        'TCS Value': tcsVal,
        'Primary Branches': lStats.getPrimaryBranches(False),
        'Intersecting Radii': lStats.getIntersectingRadii(False),
        'Sum of Intersections': lStats.getSum(False),
        'Mean of Intersections': lStats.getMean(False),
        'Median of Intersections': lStats.getMedian(False),
        'Skewness (sampled)': lStats.getSkewness(False),
        'Kurtosis (sampled)': lStats.getKurtosis(False),
        'Kurtosis (fit)': 'NaN',
        'Maximum Number of Intersections': lStats.getMax(False),
        'Max Intersection Radius': lStats.getXvalues()[lStats.getIndexOfInters(False, float(lStats.getMax(False)))],
        'Ramification Index (sampled)': lStats.getRamificationIndex(False),
        'Ramification Index (fit)': 'NaN',
        'Centroid Radius': lStats.getCentroid(False).rawX(cal),
        'Centroid Value': lStats.getCentroid(False).rawY(cal),
        'Enclosing Radius': lStats.getEnclosingRadius(False),
        'Critical Value': 'NaN',
        'Critical Radius': 'NaN',
        'Mean Value': 'NaN',
        'Polynomial Degree': 'NaN',
        'Regression Coefficient (semi-log)': nStatsSemiLog.getSlope(),
        'Regression Coefficient (Log-log)': nStatsLogLog.getSlope(),
        'Regression Intercept (semi-log)': nStatsSemiLog.getIntercept(),
        'Regression Intercept (Log-log)': nStatsLogLog.getIntercept()
        }

    return maskMetrics

def populatePercentageMaskMetrics(nStatsSemiLog, nStatsLogLog):
    # Get our P10-90 metrics
    nStatsSemiLog.restrictRegToPercentile(10, 90)
    nStatsLogLog.restrictRegToPercentile(10, 90)

    maskPercMetrics = {'Regression Coefficient (semi-log)[P10-P90]': nStatsSemiLog.getSlope(),
        'Regression Coefficient (Log-log)[P10-P90]': nStatsLogLog.getSlope(),
        'Regression Intercept (Semi-log)[P10-P90]': nStatsSemiLog.getIntercept(),
        'Regression Intercept (Log-log)[P10-P90]': nStatsLogLog.getIntercept()
        }

    return maskPercMetrics

def saveMaskMetrics(saveLoc, cellName, maskMetrics):

    # Save our file
    writeResultsLoc = saveLoc + "Sholl " + cellName + ".csv"
    with open(writeResultsLoc, 'wb') as f:
        writer = csv.writer(f)
        writer.writerow(list(maskMetrics.keys()))
        writer.writerow(list(maskMetrics.values()))

def saveShollPlots(nStatsObj, saveLoc):
    plot = ShollPlot(nStatsObj).getImagePlus()
    IJ.save(plot, saveLoc)


def addPolyFitToMaskMetrics(lStats, cal, maskMetrics, bestDegree):

    trial = lStats.getPolynomialMaxima(0.0, 100.0, 50.0)
    critVals = list()
    critRadii = list()
    for curr in trial.toArray():
        critVals.append(curr.rawY(cal))
        critRadii.append(curr.rawX(cal))

    maskMetrics['Kurtosis (fit)'] =  lStats.getKurtosis(True)
    maskMetrics['Ramification Index (fit)'] = lStats.getRamificationIndex(True)
    maskMetrics['Critical Value'] =  sum(critVals) / len(critVals)
    maskMetrics['Critical Radius'] =  sum(critRadii) / len(critRadii)
    maskMetrics['Mean Value'] =  lStats.getMean(True)
    maskMetrics['Polynomial Degree'] =  bestDegree

    return maskMetrics

def main(imp, startRad, stepSize, saveLoc, maskName, cellName, tcsVal):

    # Create a parser object based on our thresholded cell mask image
    parser = ImageParser2D(imp)

    # Set the span of our measurement radii to 0 - i.e. get a meaasurement at every pixel away
    # from the centre of the cell
    parser.setRadiiSpan(0, ImageParser2D.MEAN) 

    # Set our position in the parser (just to be safe)
    parser.setPosition(1, 1, 1) # channel, frame, Z-slice

    # Center: the x,y,z coordinates of center of analysis
    # Set this from a ROI currently placed on the image
    parser.setCenterFromROI()

    # Sampling distances: start radius (sr), end radius (er), and step size (ss).
    # A step size of zero would mean 'continuos sampling'. Note that end radius
    # could also be set programmatically, e.g., from a ROI
    parser.setRadii(startRad, stepSize, parser.maxPossibleRadius()) # (sr, er, ss)

    # Set our hemi shells to 'none' i.e. we're taking measurements from both hemispheres
    # of our image
    parser.setHemiShells('none')
    # (...)

    # Parse the image. This may take a while depending on image size
    parser.parse()
    if not parser.successful():
        log.error(imp.getTitle() + " could not be parsed!!!")
        return

    # We can e.g., access the 'Sholl mask', a synthetic image in which foreground
    # pixels have been assigned the no. of intersections
    # Save this image
    maskImage = parser.getMask()
    maskLoc = saveLoc + "Sholl Mask " + cellName + ".tif"
    IJ.save(maskImage, maskLoc)

    # Now we can access the Sholl profile:
    profile = parser.getProfile()
    if profile.isEmpty():
        log.error("All intersection counts were zero! Invalid threshold range!?")
        return

    # Remove zeros here as otherwise this messes with polynomial fitting functions
    profile.trimZeroCounts()

    # Calculate the best fit polynomial
    lStats = LinearProfileStats(profile)

    #plot = ShollPlot(lStats)
    #plot.show()

    # Fit out polynomial
    #plot.rebuild()

    # Calculate stats from our area normalised semi-log and log-log profiles (128 is semi-log and 256 is log-log)
    nStatsSemiLog = NormalizedProfileStats(profile, ShollStats.AREA, 128)
    nStatsLogLog = NormalizedProfileStats(profile, ShollStats.AREA, 256)

    # Do some checks here to make sure we're specifying semi log and log log correctly
    checkCorrectMethodFlag(NormalizedProfileStats(profile, ShollStats.AREA).getMethodFlag('Semi-log'), 128)
    checkCorrectMethodFlag(NormalizedProfileStats(profile, ShollStats.AREA).getMethodFlag('Log-log'), 256)

    # Get our image calibration and use it to extract the critical values and radii
    cal = Calibration(imp)

    # Get our mask metrics
    maskMetrics = populateMaskMetrics(maskName, tcsVal, lStats, nStatsSemiLog, nStatsLogLog, cal)

    # Get metrics based on the 10th-90th precentile of our semi log and log log data
    maskPercMetrics = populatePercentageMaskMetrics(nStatsSemiLog, nStatsLogLog)

    # Update our maskMetrics dictionary with our percentage metrics
    maskMetrics.update(maskPercMetrics)

    # Save our mask metrics
    saveMaskMetrics(saveLoc, cellName, maskMetrics)

    # Save our sholl plots
    saveShollPlots(nStatsSemiLog, saveLoc + "Sholl SL " + cellName + ".tif")
    saveShollPlots(nStatsLogLog, saveLoc + "Sholl LL " + cellName + ".tif")

    # Get the best fitting polynomial degree between 1 and 30
    bestDegree = lStats.findBestFit(1, # lowest degree
                            30,     # highest degree
                            0.7,   # lowest value for adjusted RSquared
                            0.05)   # the two-sample K-S p-value used to discard 'unsuitable fits'

    # If we actually found a best fit:
    if bestDegree != -1:

        # Fit our polynomial, save a plot of our best fit, update our mask metrics with fit metrics
        lStats.fitPolynomial(bestDegree)
        saveShollPlots(lStats, saveLoc + "Sholl Fit " + cellName + ".tif")

        maskMetrics = addPolyFitToMaskMetrics(lStats, cal, maskMetrics, bestDegree)

        # Save our updated mask metrics
        saveMaskMetrics(saveLoc, cellName, maskMetrics)
    

# Get the arguments passed to the function from our ImageJ macro
args = getArgument()

# Format these arguments as a dictionary and then extract the relevant values
arg_dict = dict([x.split("=") for x in args.split(",")])
startRad = float(arg_dict['startRad'])
stepSize = float(arg_dict['stepSize'])
saveLoc = str(arg_dict['saveLoc'])
maskName = str(arg_dict['maskName'])
tcsVal = str(arg_dict['tcsVal'])

cellName = os.path.splitext(maskName)[0]

imp = IJ.getImage()
main(imp, startRad, stepSize, saveLoc, maskName, cellName, tcsVal)