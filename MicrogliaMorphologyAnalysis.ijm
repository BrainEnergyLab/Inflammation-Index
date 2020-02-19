//Automated Microglial Morphology Analysis
//Edited and rewritten by Devin 17/01/19

//Method based on: 
//https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0031814

//This script is used to analyse the morphology of microglial cells taken from 
//2P images, requires a dedicated folder within which to work and create its own 
//directories, as well as being pointed to the 2P directory where the raw 2P 
//images are stored in a directory structure of AnimalNameDietType/Timepoint/
//SessionFolder/2PData

//Gives the user the ability to preprocess morphology images, mark positions of 
//cells on them, automatically generate masks of the cells, user controlled QC 
//of masks, and then quantification of various parameters of the masks

//Dependencies are many - need to look through and add in dependencies here

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////Functions///////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

//This function takes an array and a string as arguments. The string is a file
//name that we cut into segments that give us info about the animal and 
//timepoint that we store at index [0] in the array, the timepoint only at [1]
//the animal only at [2] and finally the file name without the .tif on the end
//that we store at [3]
function getAnimalTimepointInfo(outputArray, inputName) {
  outputArray[0] = substring(inputName, 0, indexOf(inputName, " Microglia Morphology"));
  outputArray[1] = toLowerCase(substring(outputArray[0], lastIndexOf(outputArray[0], " ")+1));
  outputArray[2] = toLowerCase(substring(outputArray[0], 0, lastIndexOf(outputArray[0], " ")));
  outputArray[3] = substring(inputName, 0, indexOf(inputName, ".tif"));
}

//This function takes an input array, and removes all the 0's in it, outputting 
//it as the output array which must be passed in as an argument

function removeZeros(inputArray, output) {

	//Loop through the input array, if the value isn't a 0, we place that in our 
	//output array (which should be of length 1) before then concatenating an 
	//array of length 1 to it to add another location to store another non-zero 
	//value from the input array
	
	arrayToConcat = newArray(1);

	for(i=0; i<inputArray.length; i++) {
		if(inputArray[i]!=0) {
			currentIndex=output.length-1;
			output[currentIndex]=inputArray[i];
			output = Array.concat(output, arrayToConcat);
		}
	}

	//If the final value of the output array is 0, we trim the array by one
	if(output[output.length-1]==0) {
		output = Array.trim(output, output.length-1);
	}

	return output;
}

//Findfolders, directoryname is path to search in, substring is substring to 
//look for, fileLocations is array to fill with paths that contain substring
function listFilesAndFilesSubDirectories(directoryName, subString,
                                         fileLocations) {

	//Get the list of files in the directory
	listOfFiles = getFileList(directoryName);

	//an array to add onto our fileLocations array to extend it so we can keep 
	//adding to it
	arrayToConcat = newArray(1);

	//Loop through the files in the file list
	for (i=0; i<listOfFiles.length; i++) {

		//Create a string of the full path name
		fullPath = directoryName+listOfFiles[i];
		
		//If the file we're checking is a file and not a directory and if it 
		//contains the substring we're interested in within its full path We check 
		//against the absolute path of our file in lower case on both counts
		if (File.isDirectory(fullPath)==0 && indexOf(toLowerCase(fullPath), 
		                                             toLowerCase(subString))>-1) {
			
			//We store the full path in the output fileLocations at the latest index 
			//(end of the array) and add an extra bit onto the Array so we can keep 
			//filling it
			fileLocations = Array.concat(fileLocations, arrayToConcat);
			currentIndex=fileLocations.length-1;
			fileLocations[currentIndex] = fullPath;

		//If the file we're checking is a directory, then we run the whole thing on 
		//that directory
		} else if (File.isDirectory(fullPath)==1) {
			//print("Going into directory", fullPath);

			//Create a new array to fill whilst we run on this directory and at the 
			//end add it onyo the fileLocations array 
			tempArray= newArray(1);
			tempArray = listFilesAndFilesSubDirectories(fullPath, subString, 
			                                            tempArray);
			fileLocations = Array.concat(fileLocations, tempArray);     
			
		}
	}

	//Create a new array that we fill with all non zero values of fileLocations
	output = newArray(1);

	output = removeZeros(fileLocations, output);

	//Then return the output array
	return output;
	
}

//This function clear results if they exist, clears the roimanager, and closes 
//all open images - useful for quickly clearing the workspace
function Housekeeping() {
	
	if (isOpen("Results")) {
		run("Clear Results");
	}
	if(roiManager("count")>0) {
		roiManager("deselect");
		roiManager("delete");
	}
	if(nImages>0) {
		run("Close All");
	}
}

//This function essentially checks if a mask is touching the edges of the canvas
//that it is contained within. It's behaviour varies depending on the type 
//argument. It acts to determine whether a microglia cell mask is touching the
//edges of the local area around it, and returns whether to keep iteratively
//thresholding the cell mask or not depending on the context as follows:

//Below lower limit description: 
//Function decides whether to continue iteratively thresholding a mask that has 
//an area below threshold by checking if it touches edges, if so, we stop 
//processing this cell, otherwise continue where threshContinueF is binary and 1
//if you should continue thresholding

//Within range description: 
//Function does the same as above but for a cell that falls within range of 
//desired areas - i.e. within +/- range of the current TCS. If not touching, the
//mask is saved and we move to next cell, otherwise we continue iterating in the
//hope we find a threshold value that satistifies the TCS and range and that 
//means it isn't touching the edge

//Stabilized description: 
//Function checks cell masks that have stabilized for 3 iterations, if they are 
//touching an edge they are disregarded, otherwise saved, either way we move 
//onto the next cell afterwards i.e. we save cell masks that are TCS +/- range, 
//or that have reached a stable area for 3 iterations and that this mask isn't 
//touching the edges

//Args: imageName is the mask to check whether its touching the edges of the LR, 
//saveName is where to save it if we want to, fileName is what to save it as, 
//and type is what kind of check we're running where 0 is whether the mask 
//touches an edge whilst the size of the mask is below the lower size limit, 1 
//is to check it touches whilst its within our desired area range, and 2 is to 
//check once the image area has stabilized

function touchingCheck(imageName, saveName, fileName, type) {

	//These are arrays of strings that we're going to print out to inform the user 
	//of the decision of this function, what we print will come from 
	//firstStringArray if the mask isn't touching the edges of the image and the 
	//secondStringArray if it is, which string index depends on the type of check 
	//we're running
	firstStringArray = newArray("", 
	                            "Cell within limits and not touching edges, saving", 
	                            "Cell size stabilized and didn't touch edges, saving");
	secondStringArray =  newArray("High threshold / low area mask touches edges already, ignoring cell", 
	                              "Cell within limits but touches edges, resuming iterative thresholding", 
	                              "Cell size stabilized but touches edges, ignoring");

	//Takes the mask of the cell and turns it into its bounding quadrilateral, 
	//then gets an array of all the coordinates of that quadrilateral
	selectWindow(imageName);
	run("Create Selection");
	run("To Bounding Box");
	getSelectionCoordinates(xF,yF);

	//Get out the number of coordinates i.e. pixels in the selection and then 
	//create a single array, selectionCoords, to store all the coordinates
	xFLength = xF.length;
	selectionCoords = Array.concat(xF, yF);

	//The distance in image units that we use as a buffer around the edges of our 
	//image - i.e., if our image is within "distance" of the edges of our image, 
	//we say its touching the edges
	distance = 5;

	//Get out the width and height of the input image and create a new array to 
	//store whether the mask touches the edges, and the maximum possible Y and X 
	//coordinates that the selection can be to avoid coming within "distance" of 
	//the edges of the image
	getDimensions(functionWidth, functionHeight, functionChannels, functionSlices, functionFrames);
	coordinatesArray = newArray(false, functionHeight-distance, functionWidth-distance);
	//[0] is touching, [1] is newHeightF, [2] is newWidthF

	//Loop through the coordinates of the selection
	for (i=0; i<xF.length; i++) {

		//If the x coordinate at that point is <= distance, then the mask touches, 
		//if it is >= the maximum x value it can be without touching, then it touches
		//If the y coordinates is <= distance then it touches, if it is >= maximum 
		//possible y value then it touches
		if(selectionCoords[i]<=distance || selectionCoords[i]>=coordinatesArray[2] || 
		   selectionCoords[i+xFLength]<=distance || 
		   selectionCoords[i+xFLength]>=coordinatesArray[1]) {
			
			//Set [0] to true since the selection touches the edges and stop checking 
			//for touching, since only one coordinate has to be close enough
			coordinatesArray[0] = true;
			i = xF.length;
			
			//Print out that the mask touches the edges and depending on the type of 
			//check we're running, the appropriate conclusion
			print(secondStringArray[type]);

			//If we're checking for touching below the area limits or once the image 
			//has stabilized, touching means we disregard this cell and so we set 
			//output to false
			if(type==0 || type == 2) {
				output = false; 

			//Otherwise if we're checking for a cell within the area limits, this 
			//isn't necessarily the only outcome so we set output to true to continue
			//iterating to try and find a new threshold value that means we're in the 
			//limits but not touching
			} else if (type ==1) {
				output = true;
			}
			
		}
		
	}

	//If the mask isn't touching, we print out the appropriate message for the 
	//type of check we're doing
	if(coordinatesArray[0]==false) {
		print(firstStringArray[type]);

		//If the image is below the area limit, we continue threshold iterations
		if(type==0) {
			output = true;

		//Otherwise if the image is within the area limits or has a stabilised area, 
		//we clear our selection, and save the image using the saveName and fileName
		//inputs before setting output to false as we're now done with this cell
		} else if (type==1 || type==2) {
			selectWindow(imageName);
			run("Select None");
			saveAs("tiff", saveName);
			selectWindow(fileName);
			rename(imageName);
			output = false;
		}
	}

	//Return our output value
	return output;
}

//This is a function to retrieve the data from the ini file for a given animal, 
//at a given timepoint. The ini file contains calibration information for that 
//particular experiment that we use to calibrate our images. iniFolder is the 
//folder within which the ini files are located, and iniTextValuesMicrons is an 
//array we pass into the function that we fill with calibration values before 
//later returning it
function getIniData(iniFolder, iniTextValuesMicrons) {

	//We get the list of files in the iniFolder
	iniFileList = getFileList(iniFolder);
	
	//Whilst its false, loop through the ini files and if we find one that matches 
	//the animal and timepoint, we set it to true, otherwise we ask the user to 
	//provide the right file
	do {
		for(i=0; i<iniFileList.length; i++) {
			if(matches(toLowerCase(iniFileList[i]), "*.ini.")) {
				
				//Create a variable that tells us which ini file to open
				iniToOpen = iniFolder + iniFileList[i]; 
				found = true;
				i = iniFileList.length;
			}
		}
	} while (found == false);
	
	//This is an array of codes that refer to specific numbers in unicode, 
	//grabbed from: https://unicode-table.com/en/ - The characters these codes 
	//refer to are characters that we can use to iden1385tify where in the ini file 
	//the calibration information that we want to grab is stored since these are 
	//the codes for all the numerical digits 0-9
	uniCodes = newArray(46, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57);
	
	//This is an array with the strings that come just before the information we 
	//want to retrieve from the ini file. We want to get the x, y, and z pixel 
	//sizes, as well as the no of planes and the frames per plane of the image
	iniTextStringsPre = newArray("x.pixel.sz = ",
								  "y.pixel.sz = ",
								  "z.spacing = ",
								  "no.of.planes",
								  "frames.per.plane");
	
	//This is an array of indices that we use to index into the substring of the 
	//ini file that we get using iniTextStringsPre so that we can then retrieve 
	//the numeric values i.e. we have a substring of active.objective 1, and to 
	//get the number we index at position 19
	iniTextIndicesPreAdds = newArray(13, 13, 12, 15, 19);	
		
	//We open the ini file as a string
	iniText = File.openAsString(iniToOpen);	
		
	//Here we start looking in our ini data 
		//Looping through the values we want to grab
		for(i=0; i<iniTextStringsPre.length; i++) {

			//We create a start point that is the index of our iniTextStringsPre in 
			//our ini file plus the index associated with that information
			startPoint = indexOf(iniText, iniTextStringsPre[i])+iniTextIndicesPreAdds[i];
			
			//Looping from our start point through to the end of our ini file
			for(i0=startPoint; i0<lengthOf(iniText); i0++) {
				
				//If the substring we make of our ini file starting at i0 (which moves 1
				//position each iteration past startPoint) and ending 1 character later 
				//isn't a blank space
				if(indexOf(substring(iniText, i0, i0+1), " ")>-1) {
					
					//We Create a new string from our start point to that point because 
					//that means this new substring will contain the information we're 
					//after as well as a string describing
					//the next bit of information stored in the ini file i.e. 
					//1.2345                      root.path c://... - so we make a 
					//newString of 1.2345               root.path
					newString = substring(iniText, startPoint, i0);
					
					//Loop through this new string
					for(i1=0; i1<lengthOf(newString); i1++) {

						//Create a variable to track whether the character is a number, 
						//default to false
						isNumb = false;

						//Loop through our uniCodes array, and if the character code at a 
						//given index in the newString matches one of the uniCode values
						//then we know we're at a number and set isNumb to true and set our 
						//loop to the terminating condition since we no longer
						//need to check
						for(i2=0; i2<uniCodes.length; i2++) {
							if(charCodeAt(newString, i1) == uniCodes[i2]) {
								isNumb = true;
								i2 = uniCodes.length;
							}
						}

						//If we're not at a number then we know we're at the first character 
						//of the description for the next bit of inoformation i.e. the 'r' 
						//of root.path
						if(isNumb == false) {
							
							//In that case we set the end of our string to that index, and 
							//create a new substring of our newString that ends here so that 
							//it cuts off the next 
							//descriptive string
							stringEnd = i1;
							realString = substring(newString, 0, stringEnd);
							
							//Set our i1 looping variable to meet its terminating condition
							i1 = lengthOf(newString);
						}
					}
				}
			}

			//If we're finding the values that are in the 1st or 2nd index of our 
			//iniTextStringsPre array we parseFloat the value before multiply by 1e6
			if(i<3) {
				iniTextValuesMicrons[(i-1)] = parseFloat(realString) * 1e6;

			//Else we just parseFloat if the values if we are at 3 or above
			} else if (i>=3) {
				iniTextValuesMicrons[(i-1)] = parseFloat(realString);
			}
		}
}

//Function to check if the inputValue is above the topLimit - this is so that if 
//our thresholding calculated value ends up above the highest grey value in the 
//image then we set inputValue to that top value
function valueCheck(inputValue, topLimit) {
	
	if(inputValue>=topLimit) {
		inputValue = topLimit-1;
	}

	//We want a rounded threshold value since the images are in 8-bit, so we do 
	//that before returning it
	return round(inputValue);
}

//This function finds the area of a mask that is above a certain threshold value
//(threshValue) and connected to a point with coordinates xPoint, yPoint
function getConnectedArea(xPoint, yPoint, threshValue) {
	
	//We make the point on our image then use the find connected regions plugin to 
	//generate an image of all the pixels connected to that coordinate that have a
	//grey value above threshValue
	makePoint(xPoint, yPoint);
	setBackgroundColor(0,0,0);
	run("Find Connected Regions", "allow_diagonal display_image_for_each start_from_point regions_for_values_over="+threshValue+" minimum_number_of_points=1 stop_after=1");
	
	//Get the area of the mask generated and return it, leaving the mask open so 
	//that we can grab it outside the function for further manipulation
	imgNamemask=getTitle();
	selectWindow(imgNamemask);
	run("Select None");
	run("Invert");
	run("Create Selection");
	getStatistics(area);

	return area;

}

//This is a function that generates a waitForUser dialog with waitForUserDialog 
//that then retrieves a checkbox value with the string checkboxString so that 
//the user can check an image and then return feedback for a given string
function userApproval(waitForUserDialog, dialogName, checkboxString) {

	//We zoom into an image 3 times so that its bigger on the screen for the user 
	//to check
	for(i=0; i<3; i++) {
		run("In [+]");
	}

	//Scale the image to fit, before exiting and displaying hidden images from 
	//batch mode, autocontrasting the image, then waiting for the user				
	run("Scale to Fit");					
	setBatchMode("Exit and Display");
	setOption("AutoContrast", true);
	waitForUser(waitForUserDialog);

	
	//Once exiting the wait for user dialog we ask the user to give feedback 
	//through a dialog box and then return the checkbox boolean value						
	Dialog.create(dialogName);
	Dialog.addCheckbox(checkboxString, true);
	Dialog.show();
	output = Dialog.getCheckbox();
	return output;
}

//This is a function used to fill an inputArray using data from a csv file 
//referenced in resultsTableRefs, from a column referenced in 
//resultsTableColumns, and whether that column contains strings are stored in 
//resultsAreStrings, and finally the argument inputsAreArrays can be set to true 
//if we're referencing multiple columns and multiple results tables to store in 
//a single inputArray

//InputArray needs to be a multiple of resultsTableRefs.length since if we have 
//multiple resultsTableRefs values, we need to store at least that many values 
//in the inputArray
function fillArray(inputArray, resultsTableRefs, resultsTableColumns, 
                   resultsAreStrings, inputsAreArrays) {
	
	//Clear the results table, check if our results table to load exists
	run("Clear Results");
	
	//Here if we are referencing multiple columns then inputsAreArrays will be 
	//true
	if(inputsAreArrays == true) {

		//The section of the inputArray that we want to dedicate to each results 
		//value is calculated
		sizePerSection = inputArray.length / resultsTableRefs.length;

		//Then loopping through the different data we want to fill our inputArray 
		//with
		for(i=0; i<resultsTableRefs.length; i++) {
			
			//We first clear results, then if our resultsTableRefs file exists, we 
			//open it 
			run("Clear Results");
			if(File.exists(resultsTableRefs[i])==1) {
				open(resultsTableRefs[i]);
				tabName = Table.title;
				
				//Looping through the section of our inputArray that we're filling
				for(i0=0; i0<sizePerSection; i0++) {

					//If our current results we're getting aren't a string and we are 
					//still within the limits of the results table then we fill our 
					//inputArray with the result associated with our resultsTableColumns
					if(resultsAreStrings[i]==false && i0 < Table.size) {
						inputArray[(i*sizePerSection)+i0] = Table.get(resultsTableColumns[i] 
						                                              ,i0);

					//Otherwise if it is a string then we use getResultString
					} else if (i0<Table.size) {
						inputArray[(i*sizePerSection)+i0] = 
						getResultString(resultsTableColumns[i], i0);
					
					//Otherwise if we're past the size of our results table, we fill our 
					//inputArray with a 0
					} else {
						inputArray[(i*sizePerSection)+i0] = 0;
					}
				}
				selectWindow(tabName);
				Table.reset(tabName);
				run("Clear Results");
			}
			//Table.reset(File.getName(resultsTableRefs[i]));
		}

	//If we're not getting multiple columns
	} else {

		//Check if our results table actually exists
		if(File.exists(resultsTableRefs)==1) {
			
			//Open our results table then loop through the results, filling our 
			//inputArray with the data depending on if its a string or not
			open(resultsTableRefs);
			tabName = Table.title;
			
			//Loop through the results table and fill the input array with the 
			//information we want to get
			for(i0=0; i0<Table.size; i0++) {
				if(resultsAreStrings==false) {
					inputArray[i0] = Table.get(resultsTableColumns, i0);
				} else {
					inputArray[i0] = Table.getString(resultsTableColumns, i0);
				}
			}
			selectWindow(tabName);
			Table.reset(tabName);
			run("Clear Results");	
			//Table.reset(File.getName(resultsTableRefs));
		}
		
	}
}

//Function to incorporate the reordering of Z slices in registration. Takes an 
//inputImage, then rearranges slices that are maximally layersToTest apart 
//before renaming it toRename
function zSpaceCorrection(inputImage, layersToTest, toRename) {

	//Array to store the name of output images from the spacing correction to 
	//close
	toClose = newArray("Warped", 
			   		   "Image",
			   		   inputImage);

	//Runs the z spacing correction plugin on the input image using the 
	//layersToTest value as the maximum number of layers to check against for z 
	//positioning
	selectWindow(inputImage);
	run("Z-Spacing Correction", "input=[] type=[Image Stack] text_maximally="+layersToTest+" outer_iterations=100 outer_regularization=0.40 inner_iterations=10 inner_regularization=0.10 allow_reordering number=1 visitor=lazy similarity_method=[NCC (aligned)] scale=1.000 voxel=1.0000 voxel_0=1.0000 voxel_1=1.0000 render voxel=1.0000 voxel_0=1.0000 voxel_1=1.0000 upsample=1");


	//Closes any images that are in the toClose array first by getting a list of 
	//the image titles that exist
	imageTitleList = getList("image.titles");

	//Then we loop through the titles of the images we want to close, each time 
	//also looping through the images that are open
	for(k = 0; k<toClose.length; k++) {
		for(j=0; j<imageTitleList.length; j++) {
			
			//If the title of the currently selected open image matches the one we 
			//want to close, then we close that image and terminate our search of the 
			//current toClose title in our list of images and move onto the next 
			//toClose title
			if(indexOf(imageTitleList[j], toClose[k]) == 0) {
				selectWindow(imageTitleList[j]);
				run("Close");
				j = imageTitleList.length;
			}
		}
	}

	//Renames the output image to the toRename variable
	selectWindow("Z-Spacing: " + inputImage);
	rename(toRename);

	//Close the exception that is thrown by the rearranging of stacks
	selectWindow("Exception");
	run("Close");

}

//Part of motion processing, takes an array (currentStackSlices), removes zeros from it, then
//creates a string of the numbers in the array before then making a substack of these slices
//from an imagesInput[i] window, registering them if necessary, before renaming them
//according to the info in motionArtifactRemoval
function getAndProcessSlices(currenStackSlices, motionArtifactRemoval, currTime) {
	
	//Here we order then cutoff the zeros so we get a small array of the 
	//slices to be retained
	imageNumberArrayCutoff = newArray(1);
	imageNumberArrayCutoff=removeZeros(currenStackSlices, imageNumberArrayCutoff);

	selectWindow("Timepoint");	
	timeSlices = nSlices;
					
	//This loop strings together the names stored in the arrayIn into a 
	//concatenated string (called strung) that can be input into the substack 
	//maker function so that we can make a substack of all kept TZ slices in
	//a single go - we input the imageNumberArrayCutoff array
	strung="";
	for(i1=0; i1<imageNumberArrayCutoff.length; i1++) {
		
		numb = imageNumberArrayCutoff[i1] - (currTime * timeSlices);
		string=toString(numb, 0);
						
		//If we're not at the end of the array, we separate our values with a 
		//comma
		if(i1<imageNumberArrayCutoff.length-1) {
			strung += string + ",";
	
		//Else if we are, we don't add anything to the end
		} else if (i1==imageNumberArrayCutoff.length-1) {
			strung += string;	
		}
	
	}
	
	print(strung);
	
	//We then make a substack of our input image of the slices we're keeping 
	//for this particular ZT point
	selectWindow("Timepoint");	
	run("Make Substack...", "slices=["+strung+"]");
	rename("new");
	selectWindow("new");
	newSlices = nSlices;
		
	//If the image has more than 1 slice, register it and average project it 
	//so that we get a single image for this ZT point
	if(newSlices>1){
						
		print("Registering T", motionArtifactRemoval[2], " Z", motionArtifactRemoval[3]);
		run("MultiStackReg", "stack_1=[new] action_1=Align file_1=[]  stack_2=None action_2=Ignore file_2=[] transformation=[Translation]");
		run("MultiStackReg", "stack_1=[new] action_1=Align file_1=[]  stack_2=None action_2=Ignore file_2=[] transformation=[Affine]");
		print("Registered");
						
		selectWindow("new");
		rename("T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]);
		run("Z Project...", "projection=[Average Intensity]");
		selectWindow("T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]);
		run("Close");
		selectWindow("AVG_T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]);
		rename("T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]);	
		
	//Otherwise just rename it appropriately
	} else {	
		selectWindow("new");
		rename("T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]);	
	}

}
////////////////////////////////////////////////////////////////////////////////
//////////////////////// Main user input sections //////////////////////////////
////////////////////////////////////////////////////////////////////////////////

//A string array that contains the functionality choices that the user has wrt. 
//running this macro
stringChoices = newArray("Preprocess morphology stacks and save them", "Mark cell positions", "Generate masks for cells",  
"Quality control masks", "Analyse masks", "QC Motion Processing");

//Create a dialog box where the user can input which functionalities they want 
//to run
Dialog.create("Analysis Selection");

//Here we loop through the strings and add either a checkbox for the user or a 
//number input
for(i=0; i<stringChoices.length; i++) {
	Dialog.addCheckbox(stringChoices[i], false);
}

Dialog.show();

//Here we create an array to get the user choices of which functionalities to 
//run
analysisSelections = newArray(stringChoices.length);

for(i=0; i<stringChoices.length; i++) {
	analysisSelections[i] = Dialog.getCheckbox();
}


MorphologyProcessing = getDirectory("Choose morphology analysis working directory");

//Here we create an array to store the full name of the directories we'll be 
//working with within our morphology processing directory
directories=newArray(MorphologyProcessing+"Input" + File.separator, 
                     MorphologyProcessing+"Output" + File.separator, 
                     MorphologyProcessing+"Done" + File.separator);
//[0] is input, [1] is output, [2] is done

//Here we make our working directories by looping through our folder names, 
//concatenating them to our main parent directory
//and making them if they don't already exist
for(i=0; i<directories.length; i++) {
	if(File.exists(directories[i])==0) {
		File.makeDirectory(directories[i]);
	}	
}
	
//Here we set the macro into batch mode and run the housekeeping function which 
//clears the roimanager, closes all open windows, and clears the results table
setBatchMode(true);
Housekeeping();

//If the user wants to preprocess images
if(analysisSelections[0] == true) {

	//Get the parent 2P directory i.e. where all the raw 2P images are stored
	//directoryName = dropPath + "2P data/Devin/";
	directoryName = getDirectory("Choose the image storage directory");

	//Ask the user how many frames they want to retain for motion correction and how many frames they want to use
	//to make the average projection to compare other frames to (lapFrames) - also ask if the user would rather select
	//the frames to use manually 
	Dialog.create("Info for each section");
	Dialog.addNumber("How many frames per Z plane to average over for the final Z plane image?",1); 
	Dialog.addNumber("How many frames do you want to include in the average projection of least blurry frames?", 3);
	Dialog.addCheckbox("Manually select frames?", false);
	Dialog.addString("String to Search For", "Morphology");
	Dialog.show();
	fToKeep = Dialog.getNumber();
	lapFrames = Dialog.getNumber();
	manCorrect = Dialog.getCheckbox();
	preProcStringToFind = Dialog.getString();

	//If the user would rather select the frames to use manually, ask if they want to select the frames,
	//process the previously selected frames, or both
	if(manCorrect == true) {
		Dialog.create("Manual Correction Options");
		Dialog.addCheckbox("Manually select frames?", true)
		Dialog.addCheckbox("Process images where frames have been previously selected?", true);
		Dialog.show();
		frameSelect = Dialog.getCheckbox();
		frameProcess = Dialog.getCheckbox();
	}

}

//This is an array to story the inputs the user provides
selection=newArray(5);
//[0] is TCSLower, [1] is TCSUpper, [2] is range, [3] is increment, [4] is trace

//If the user wants to generate cell masks
if(analysisSelections[2] == true) { 
	
	//These are the required inputs from the user

	strings = newArray("What mask size would you like to use as a lower limit?",
	"What mask size would you like to use as an upper limit?",
	"What range would you like to use for mask size error?",
	"What increment would you like to increase mask size by per loop?");

	//TCS is target cell size, we iteratively threshold our cells to reach the 
	//TCS +/- the range/ The TCS lower is the minimum TCS we want to get results 
	//from, the TCS upper is the highest. Increment is how much we increase the 
	//TCS we're using each iteration to go from TCS lower to TCS upper. Trace is 
	//whether the user wants to manually trace processes to add to the analysis
	
	Dialog.create("Info for each section");
		
	//Here we loop through the strings and add a box for numeric input for each
	for(i=0; i<strings.length; i++) {
		Dialog.addNumber(strings[i], 0);
	}
			
	Dialog.show();
						
	//Retrieve user inputs and store the selections in the selection array
	for(i=0; i<strings.length; i++) {
		selection[i] = Dialog.getNumber();
	}
	
	//Here we calculate how many loops we need to run to cover all the TCS values 
	//the user wants to use
	numberOfLoops = ((selection[1]-selection[0])/selection[3])+1;

}

//If the user wants to do quality control, they're saked if they also want to 
//trace any processes missed by the automated mask generation
if(analysisSelections[3] == true) {
	Dialog.create("Tracing");
	Dialog.addCheckbox("Do you want to manually trace processes on this run?", 
	                   false);
	Dialog.show();
	selection[4] = Dialog.getCheckbox();
}

//If the user wants to mark cell positions, generate masks, quality control 
//masks, or analyse masks
if(analysisSelections[1] == true || analysisSelections[2] == true || 
   analysisSelections[3] == true || analysisSelections[4] == true) {	
	
	//These folder names are where we store various outputs from the processing 
	//(that we don't need for preprocessing)
	storageFolders=newArray("Cell Coordinates/", "Cell Coordinate Masks/",
	                        "Somas/", "Candidate Cell Masks/", "Local Regions/",
							            "Results/");

	//maskGenerationArray = newArray("21-30", "51-60", "81-90", 120);
	LRSize = 120;

	//[0] through to [2] are the pieces of the stack we're going to analyze, [3] 
	//is the size of the local region to draw in microns. The stacks are 100 
	//microns and we chop them up into separate 10 micron segments that are at 
	//least 20 microns apart to avoid analysing the same cell twice.

	//The size of the local region to draw around the cell in microns is hardcoded 
	//to 120 microns based on the paper this analysis is based on 
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////Main Processing Sections ///////////////////////////////
////////////////////////////////////////////////////////////////////////////////

//Now we're about to start the actual code functionalities, as we've gotten 
//pretty much all the user inputs we need. To begin with we get a list of all the 
//files in our input directory - images we're going to be working with
imagesInput = getFileList(directories[0]);

//If we're preprocessing the images
if(analysisSelections[0] == true) {

	//Here we run the listFilesAndFilesSubDirectories function on our parent 2P 
	//raw data location looking for locations that are labelled with the user indicated string

	fileLocations = newArray(1);
	fileLocations = listFilesAndFilesSubDirectories(directoryName, preProcStringToFind, fileLocations);
	//Loop through all matching files
	for(i=0; i<fileLocations.length; i++) {

		//Here we take the location of the file that is a microglia morphology 
		//image, and we split up parts of the file name and store them in the 
		//parentArray for easier access where index [0] contains the whole string 
		//of image location, and each subsequent index is the parent directory of 
		//the previous index
		parentArray=newArray(5);
		parentArray[0] = fileLocations[i];
		for(i1=0; i1<4; i1++){
			parentArray[i1+1] = File.getParent(parentArray[i1]);
		}
		
		//Here we create a name to save the image as based the names in the last 2
		//directories of our image location and we add " Microglia Morphology" on 
		//to the end of it
		saveName = File.getName(parentArray[2]) + " " + 
		           File.getName(parentArray[1]) + " Microglia Morphology";

		//If this file is already saved in our input directory, or in our done 
		//directory, then we ignore it, but if it isn't we proceed
		if((File.exists(directories[0] + saveName + ".tif")==0 && File.exists(directories[2] + saveName + ".tif")==0)) {
					
			//Here copy the image to the input folder with the saveName
			File.copy(fileLocations[i], directories[0] + saveName + ".tif");
		
			//Here get the parent directory of the image
			parentFiles = getFileList(parentArray[1]);
		}
	}
	
	//Now we get out the list of files in our input folder 
	//once we've gone through all the microglia morphology images in our raw 2P 
	//data directory
	imagesInput = getFileList(directories[0]);
	
////////////////////////////////////////////////////////////////////////////////	
///////////////////////////////Motion Processing////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
	
	Housekeeping();

	//Check to retrieve information about any images that have already been processed
	ArrayConc = newArray(1);
	if(File.exists(directories[1] + "Images to Use.csv") == 1) {
		
		//An array storing the column names that we'll use in our results file
		valuesToRecord = newArray("Image List", "Kept", "Manual Flag", "Ignore");
		
		open(directories[1] + "Images to Use.csv");
		analysisRecordInput = newArray(Table.size * valuesToRecord.length);
			
		//For each row in the results table, get out the data and store it in analysisRecordInput
		for(currRow = 0; currRow < Table.size; currRow ++ ) {
			for(currVal = 0; currVal < valuesToRecord.length; currVal ++ ) {
				if(currVal == 0) {
					analysisRecordInput[(Table.size * currVal)+currRow] = Table.getString(valuesToRecord[currVal], currRow);
				} else {
					analysisRecordInput[(Table.size * currVal)+currRow] = Table.get(valuesToRecord[currVal], currRow);
				}
			}
		}
	
		selectWindow("Images to Use.csv");
		run("Close");
	
		//Create a results table to fill with previous data if it exists
		Table.create("Images to Use");
		
		//File the table with previous data
		for(i0=0; i0<(analysisRecordInput.length / valuesToRecord.length); i0++) {
			for(i1=0; i1<valuesToRecord.length; i1++) {
				if(i1 == 0) {
					stringValue = analysisRecordInput[((analysisRecordInput.length / valuesToRecord.length)*i1)+i0];
					Table.set(valuesToRecord[i1], i0, stringValue);
				}
				Table.set(valuesToRecord[i1], i0, analysisRecordInput[((analysisRecordInput.length / valuesToRecord.length)*i1)+i0]);
			}
		}
		Table.update;

		//If an image has a manual flag, get out a list of these
		manualFlag = Table.getColumn("Manual Flag");
		imageName = Table.getColumn("Image List");
		for(currImage = 0; currImage<manualFlag.length; currImage++) {
			if(manualFlag[currImage]==0) {
				imageName[currImage] = 0;
			}
		}
		//Array.show(imageName);
		forStorage = newArray(1);
		forStorage = removeZeros(imageName, forStorage);

		//Get the file name of the manually flagged images
		if(forStorage.length != 0) {
			ArrayConc = Array.copy(forStorage);
			if(File.exists(directories[0] + File.getName(forStorage[0]) + ".tif")==1 || File.exists(directories[2] + File.getName(forStorage[0]) + ".tif")==1) {
				for(currImage = 0; currImage<forStorage.length; currImage++) {
					ArrayConc[currImage] = File.getName(forStorage[currImage]);
				}
			}
		}

		selectWindow("Images to Use");
		run("Close");
		
	}

	//If the user wants to manually process the image and the user chose to select frames
	if(manCorrect == true) {
		if(frameSelect == true) {

			//Set the array to cycle through as the manually flagged images
			imagesInput = ArrayConc;
			
			//Loop through the files in the input folder
			for(i=0; i<imagesInput.length; i++) {
	
				//print(imagesInput[i]);
	
				if(File.exists(directories[1] + imagesInput[i] + "/Slices To Use.csv")==0 && File.exists(directories[0] + imagesInput[i] + ".tif")==1) {
					print("To process: ", imagesInput[i]);
				}

			} 

			waitForUser("Check what to process");
	
			for(i=0; i<imagesInput.length; i++) {
				
				//If we haven't already selected frames for the current image and it is in our input folder
				if(File.exists(directories[1] + imagesInput[i] + "/Slices To Use.csv")==0 && File.exists(directories[0] + imagesInput[i] + ".tif")==1) {
	
					print("Manually selecting frames");
					forInfo = imagesInput[i] + ".tif";
						
					//Get out the animal name info - animal and 
					//timepoint that we store at index [0] in the array, the timepoint only at [1]
					//the animal only at [2] and finally the file name without the .tif on the end
					//that we store at [3]
					imageNames = newArray(4);
					getAnimalTimepointInfo(imageNames, forInfo);
					
					print("Preprocessing ", imageNames[0]); 

					//Array to store the values we need to calibrate our image with
					iniTextValuesMicrons = newArray(5);
					//Index 0 is xPxlSz, then yPxlSz, zPxlSz, ZperT, FperZ, final index is 
					//whether the ini file was correctly calibrated	

					getIniData(directoryName, iniTextValuesMicrons)

					//Calculate the number of timepoints in the image, and also a value framesReorder that we pass in 
					//to reorganise our slices as we want
					timepoints = iniTextValuesMicrons[3]/(iniTextValuesMicrons[3] * iniTextValuesMicrons[4]);
					framesReorder = iniTextValuesMicrons[3]/timepoints;
		
					//This makes an array with a sequence 0,1,2...slices
					imageNumberArray = Array.getSequence(iniTextValuesMicrons[3]+1); 
		
					//This array is used in motion artifact removal to store the image numbers 
					//being processed that contains 1,2,3...slices
					imageNumberArray = Array.slice(imageNumberArray, 1, imageNumberArray.length); 
		
					//Here we reorder our input image so that the slices are in the right structure for motion artefact removal
					run("Stack to Hyperstack...", "order=xyczt(default) channels=1 slices="+timepoints+" frames="+framesReorder+" display=Color");
					run("Hyperstack to Stack");
					run("Stack to Hyperstack...", "order=xyczt(default) channels=1 slices="+framesReorder+" frames="+timepoints+" display=Color");
		
					//Reorder each individual timepoint stack in Z so that any out of position slices are positioned correctly for motion artifact detection and removal
					//Go through each timepoint
					for(k=0; k<timepoints; k++) {	
		
						selectWindow(forInfo);
						//Get out the current timepoint, split it into a stack for each frame (i.e. 14 stacks of 26 slices)
						run("Duplicate...", "duplicate frames="+(k+1)+"");
						currentTimepoint=getTitle();	
						rename("Timepoint");
		
						//Loop through all Z points in our image
						for(i0=0; i0<(iniTextValuesMicrons[3]); i0++) {
					
							//Here we create substacks from our input image - one substack 
							//corresponding to all the frames at one Z point
							subName="Substack ("+((iniTextValuesMicrons[4]*i0)+1)+"-"+ (iniTextValuesMicrons[4]*(i0+1))+")";
							selectWindow("Timepoint");
							slicesInTimepoint = nSlices;
							print(slicesInTimepoint);
							print(((iniTextValuesMicrons[4]*i0)+1)+"-"+ (iniTextValuesMicrons[4]*(i0+1)));
							run("Make Substack...", " slices="+((iniTextValuesMicrons[4]*i0)+1)+"-"+(iniTextValuesMicrons[4]*(i0+1))+"");
							rename(subName);
							subSlices=nSlices;
		
							//Create an array to store which of the current substack slices we're keeping - fill with zeros
							slicesKeeping = newArray(subSlices);
							slicesKeeping = Array.fill(slicesKeeping, 0);

							setOption("AutoContrast", true);
		
							//Looping through the number of frames the user selected to keep, ask the user to
							//scroll to a frame to retain, the index of this frame in slicesKeeping is then set to 1
							for(currFrame=0; currFrame < fToKeep; currFrame++) {
								
								setBatchMode("Exit and Display");
								run("Tile");
								selectWindow(subName);
								waitForUser("Scroll onto the frame to retain");
								setBatchMode(true);
								keptSlice = getSliceNumber();
								print("Slice selected: ", keptSlice);
								print("If selecting more, select a different one");
		
								//keptSlice = 6;
		
								slicesKeeping[(keptSlice-1)] = 1;
								
							}

							setOption("AutoContrast", false);
			
							//Close the image
							selectWindow(subName);
							run("Close");
								
							//If the user is keeping a particular frame, we retain that number in our imageNumberArray, else
							//we set it to zero
							for (i1=0;i1<subSlices;i1++) {
								if(slicesKeeping[i1] == 0) {
									imageNumberArray[i1+(i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3])))] = 0;
								}
							}
						}

						selectWindow("Timepoint");
						run("Close");
					}
		
					//Save our array in a csv file so we can read this in later
					Table.create("Slices To Use");
					selectWindow("Slices To Use");
					Table.setColumn("Slices", imageNumberArray);
		
					//If the output directory for the input image hasn't already been made, make it
					if(File.exists(directories[1]+imagesInput[i]+"/") == 0) {
						File.makeDirectory(directories[1]+imagesInput[i]+"/");
					}
		
					Table.save(directories[1] + imagesInput[i] + "/Slices To Use.csv");
					TableName = Table.title;
					
					//Since we save it every time, we have to rename it to get rid of the .csv 
					if(TableName != "Slices To Use") {
						Table.rename(TableName, "Slices To Use");
					}
					
					selectWindow("Slices To Use");
					run("Close");
		
					Housekeeping();
	
				}	 
			}
		}
	}

	if(manCorrect == false) {
		frameProcess = false;
	}

		//If we're going to frame process our manually selected frames, or we're not manually processing motion issues
	if(manCorrect == false || manCorrect == true && frameProcess == true ) {

		//If we want to process our manually selected frames, set the image array to the manually flagged images
		if(manCorrect == true) {
			imagesInput = ArrayConc;
			
			for(currCheck = 0; currCheck < imagesInput.length; currCheck++) {
				imagesInput[currCheck] = toString(imagesInput[currCheck]) + ".tif";
			}

		//Otherwise get a list of the images in the input folder before removing from this list any images
		//that have been flagged for manual analysis i.e. images that haven't been registered before
		} else {
			imagesInput = getFileList(directories[0]);
				for(currInput = 0; currInput < imagesInput.length; currInput++) {
					noTif = substring(imagesInput[currInput], 0, indexOf(imagesInput[currInput], ".tif"));
					//print("No Tif: ", noTif);
					for(currConc = 0; currConc < ArrayConc.length; currConc++) {
						//print("CurrConc: ", ArrayConc[currConc]);
						//noTifCheck = substring(ArrayConc[currConc], 0, indexOf(ArrayConc[currConc], ".tif"));
						if(ArrayConc[currConc] == noTif) {
							imagesInput[currInput] = 0;
							currConc = 1e99;
						}
					}
				}
				newImages = newArray(1);
				newImages = removeZeros(imagesInput, newImages);			
				imagesInput = newImages;
					
			}
		}

		Array.show(imagesInput);
		waitForUser("Images input check");
		
		//Loop through the files in the input folder
		for(i=0; i<imagesInput.length; i++) {
			
			//If the file exists in our input folder, we proceed
			proceed = false;
			if(File.exists(directories[0] + imagesInput[i])==1) {
				proceed = true;
			}

			//Though if we're doing manual correction and don't have a list of the frames to use, we don't
			//proceed
			if(manCorrect == true && File.exists(directories[1] + substring(imagesInput[i], 0, indexOf(imagesInput[i], ".tif")) + "/Slices To Use.csv")==0) {
				proceed = false;
			}

			print(imagesInput[i], proceed);

			if(proceed == true) {

				run("TIFF Virtual Stack...", "open=["+directories[0]+""+imagesInput[i]+"]");
				//print(imagesInput[i]);
		
				//Work out the animal and timepoint labels for the current image based on 
				//its name
				imageNames = newArray(4);
			  	getAnimalTimepointInfo(imageNames, imagesInput[i]);
	
				//If the file hasn't been processed before (we check it against whether a 
				//processed version of the image exists in its output directory), we process 
				//it
		
				//if (File.exists(directories[1] + imageNames[3]+"/"+ imageNames[3]+
		 		//              " processed.tif")==0) {
				// " processed.tif") == 1) {
			
				print("Preprocessing ", imageNames[0]); 

				//Open our raw image
				print("Opening " + imagesInput[i]);
				//run("TIFF Virtual Stack...", "open=["+directories[0] + imagesInput[i]+"]");
				open(directories[0] + imagesInput[i]);
				print(imagesInput[i] + " opened");

				//Array to store the values we need to calibrate our image with
				iniTextValuesMicrons = newArray(5);
				//Index 0 is xPxlSz, then yPxlSz, zPxlSz, ZperT, FperZ, final index is 
				//whether the ini file was correctly calibrated	

				if(analysisSelections[6] == true) {
				
					//Fill that array with the calibration data for that animal at that 
					//timepoint
					getIniData(directories[3], imageNames[2], imageNames[1], iniTextValuesMicrons);

				} else {

					iniTextValuesMicrons[4] = noIniFperZ;
					iniTextValuesMicrons[3] = nSlices;
					
					getVoxelSize(vWidth, vHeight, vDepth, vUnit);
					iniTextValuesMicrons[0] = vWidth;
					iniTextValuesMicrons[1] = vHeight;
					iniTextValuesMicrons[2] = vDepth;

				}
					
				//Calculate the number of timepoints in the image
				timepoints = nSlices/(iniTextValuesMicrons[3] * iniTextValuesMicrons[4]);
				framesReorder = nSlices/timepoints;
		
				//Convert the image to 8-bit, then adjust the contrast across all slices 
				//to normalise brightness to that of the top slice in the image
				selectWindow(imagesInput[i]);
				print("Converting to 8-bit");
				run("8-bit");
				print("Stack Contrast Adjusting");
				selectWindow(imagesInput[i]);
				setSlice(1);
				run("Stack Contrast Adjustment", "is");
				stackWindow = getTitle();
				selectWindow(imagesInput[i]);
				run("Close");
				selectWindow(stackWindow);
				rename(imagesInput[i]);
				run("8-bit");
	
				//Increase the canvas size of the image by 100 pixels in x and y so that 
				//when we run registration on the image, if the image drifts we don't lose
				//any of it over the edges of the canvas
				getDimensions(width, height, channels, slices, frames);
				run("Canvas Size...", "width="+(width+500)+" height="+(height+500)+" position=Center zero");
	
				//Start motion artifact removal here
				print("Starting motion artifact removal");

				//This array stores information we need to refer to during motion artifact 
				//removal - i.e. the current timepoint we're processing as well as the 
				//current z position we're processing, and the timepoint and z position 
				//labels we want to use (these are appended with 0's if necessary so that
				//all timepoints and z positions have the same number of digits)
				motionArtifactRemoval = newArray(0,0,0,0);
				//[0] is tNumber, [1] is zSlice, [2] is tOut, [3] is zLabel
	
				//This is an array we fill with the names of the processed timepoint stacks
				timepointNamesCutoff = newArray(timepoints);

				//If we're working with manually chosen frames, get them out as imageNumberArray, else
				//generate imageNumberArray as all the slices in the image, and copy this to a forLap object
				//which we use to select frames for our laplacian average - also, if we're not doing manual analysis but there exists a
				//manually chosen frame table for our image, use that instead
				if(manCorrect == true || manCorrect == false && File.exists(directories[1] +substring(imagesInput[i], 0, indexOf(imagesInput[i], ".tif")) + "/Slices To Use.csv")==1) {

					open(directories[1] + substring(imagesInput[i], 0, indexOf(imagesInput[i], ".tif")) + "/Slices To Use.csv");
					selectWindow("Slices To Use.csv");
					imageNumberArray = Table.getColumn("Slices");
					selectWindow("Slices To Use.csv");
					run("Close");
					
				} else {

					//This makes an array with a sequence 0,1,2...slices
					imageNumberArray = Array.getSequence(nSlices+1); 
		
					//This array is used in motion artifact removal to store the image numbers 
					//being processed that contains 1,2,3...slices
					imageNumberArray = Array.slice(imageNumberArray, 1, imageNumberArray.length); 
					forLap = Array.copy(imageNumberArray);
					
				}
				

				//Reorder each individual timepoint stack in Z so that any out of position slices are positioned correctly for motion artifact detection and removal
				//Go through each timepoint
				for(k=0; k<timepoints; k++) {
	
					//Set our current z slice to 0
					motionArtifactRemoval[1] = 0;
					selectWindow(imagesInput[i]);
					
					//Get out the current timepoint, split it into a stack for each frame (i.e. 14 stacks of 26 slices)
					run("Duplicate...", "duplicate frames="+(k+1)+"");
					selectWindow(substring(imagesInput[i], 0, indexOf(imagesInput[i], ".tif")) + "-1.tif");
					currentTimepoint=getTitle();	
					rename("Timepoint");
						
					slicesForZ = nSlices;
	
					//This array is used to store the square difference between images and 
			      	//their references in artifact removal
					intDenDiff=newArray(slicesForZ); 
			
					//This array is used to store which images pass the motion artifact 
					//removal process using the cutoff method
					imagesToCombineCutoff=newArray(iniTextValuesMicrons[3]); 
				
					//Loop through all Z points in our image
					for(i0=0; i0<(iniTextValuesMicrons[3]); i0++) {
			
						//If our z or t labels are below 10, prefix with a 0
						for(i1=0; i1<2; i1++) {
							if(motionArtifactRemoval[i1]<10) {
								motionArtifactRemoval[i1+2] = "0" + motionArtifactRemoval[i1];
							} else {
								motionArtifactRemoval[i1+2] = "" + motionArtifactRemoval[i1];
							}
						}
						
						
						//If automatically selecting frames and we dont have a store of manually selected frames
						if(manCorrect == false && File.exists(directories[1] +substring(imagesInput[i], 0, indexOf(imagesInput[i], ".tif")) + "/Slices To Use.csv")==0) {

							//Here we create substacks from our input image - one substack 
							//corresponding to all the frames at one Z point
							subName="Substack ("+((iniTextValuesMicrons[4]*i0)+1)+"-"+(iniTextValuesMicrons[4]*(i0+1))+")";
							selectWindow("Timepoint");
							run("Make Substack...", " slices="+((iniTextValuesMicrons[4]*i0)+1)+"-"+(iniTextValuesMicrons[4]*(i0+1))+"");
							rename(subName);
						
							//As a way of detection blur in our imgaes, we use a laplacian of gaussian filter on our stack,
							//https://www.pyimagesearch.com/2015/09/07/blur-detection-with-opencv/
							//https://stackoverflow.com/questions/7765810/is-there-a-way-to-detect-if-an-image-is-blurry
									
							//We register our substack before running it through the laplacian filter
							print("Registering and removing artifacts from", subName);
							selectWindow(subName);
							subSlices=nSlices;
							run("FeatureJ Laplacian", "compute smoothing=1.0");
						
							//Close our pre laplacian image and rename our laplacian filtered image
							selectWindow(subName);
							rename("toKeep");
							selectWindow(subName + " Laplacian");
							rename(subName);
							imageSlices = nSlices;
								
							//For each slice in the stack, store the maximum pixel value of the laplacian filtered slice
							for(currSlice = 1; currSlice < (imageSlices+1); currSlice++) {
								setSlice(currSlice);
								getRawStatistics(nPixels, mean, min, max, std, hist);
								intDenDiff[((currSlice-1)+(i0*nSlices))] = max;
							}
		
							//Close the laplacian filtered image
							selectWindow(subName);
							run("Close");
							
							//Cutoff routine
								
							//This cutoff routine takes the measured square differences of each 
							//slice, and ranks them highest to lowest. We then select the best of 
							//the images (those with the lowest square differences). In this case we 
							//select the FramesToKeep lowest images i.e. if we want to keep 5 frames 
							//per TZ point, we keep the 5 lowest square difference frames per FZ.
								
							//Here we create an array that contains the intDenDiff values that 
							//correspond to the substack we're currently processing
							currentStackDiffs = Array.slice(intDenDiff, (i0*subSlices), (subSlices+(i0*subSlices)));
					
							//Here we rank the array twice, this is necessary to get the ranks of 
							//the slices so that the highest sq diff value has the highest rank and 
							//vice versa
							IMTArrayCutoffRank1=Array.rankPositions(currentStackDiffs);
							IMTArrayCutoffRank2=Array.rankPositions(IMTArrayCutoffRank1);
												
							//Here we compare the ranks to the frames to keep - if the rank is above 
							//our number of frames to keep, i.e. worse ranked than our threshold, we 
							//set the slice number to 0 in the array. This allows us to store only 
							//the slice numbers of the slices we want to use
							for (i1=0;i1<subSlices;i1++) {
								print(IMTArrayCutoffRank2[i1]);
								print(intDenDiff[i1]);
								if (IMTArrayCutoffRank2[i1]>(lapFrames-1)) {
									forLap[i1+(i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3])))] = 0;
								}
								print(forLap[i1+(i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3])))]);
							}

							waitForUser("Check the laplacian of gaussian filtering is selecting those with the highest values");
							
							//Here we create a new array that stores the slice numbers for the 
							//substack we're currently working with
							currentStackSlices = Array.slice(forLap, ((i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3])))), (subSlices+((i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3]))))));
						
						} else {
							
							subSlices = iniTextValuesMicrons[4];
							
							//Here we create a new array that stores the slice numbers for the 
							//substack we're currently working with
							currentStackSlices = Array.slice(imageNumberArray, (i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3]))),  (subSlices+((i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3]))))));
		
						}
								
						getAndProcessSlices(currentStackSlices, motionArtifactRemoval, k);

						//If automatically selecting frames and we dont have a store of manually selected frames
						if(manCorrect == false && File.exists(directories[1] + substring(imagesInput[i], 0, indexOf(imagesInput[i], ".tif")) + "/Slices To Use.csv")==0) {
			
							//Stick our average projected image in front of the ZT point to register then by translation (to minimize differences when comparing them)
							//before then removing the average projection from the stack
							run("Concatenate...", " title = wow image1=[T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]+"] image2=toKeep image3=[-- None --]");
							run("MultiStackReg", "stack_1=[Untitled] action_1=Align file_1=[]  stack_2=None action_2=Ignore file_2=[] transformation=[Translation]");
							selectWindow("Untitled");
							run("Make Substack...", "delete slices=1");
							selectWindow("Substack (1)");
							rename("T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]);
							selectWindow("Untitled");
							rename("toKeep");
	
							//Calculate the difference between the average projection and the stack
							imageCalculator("Difference create stack", "toKeep", "T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]);
						
							//Measure the difference (mean grey value) for each slice - ideally all this code should be put into a function since it
							//is a repeat of the laplacian frame selection from earlier
							selectWindow("Result of toKeep");
							keepSlices = nSlices;
							diffArray = newArray(keepSlices);
							for(currSlice = 1; currSlice < (keepSlices+1); currSlice++) {
								setSlice(currSlice);
								getRawStatistics(nPixels, mean, min, max, std, hist);
								diffArray[currSlice-1]= mean;
							}
							selectWindow("Result of toKeep");
							run("Close");
							selectWindow("toKeep");
							run("Close");
							selectWindow("T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]);
							run("Close");

							//Here we rank the array twice, this is necessary to get the ranks of 
							//the slices so that the highest sq diff value has the highest rank and 
							//vice versa
							IMTArrayCutoffRank1=Array.rankPositions(diffArray);
							IMTArrayCutoffRank2=Array.rankPositions(IMTArrayCutoffRank1);
												
							//Here we compare the ranks to the frames to keep - if the rank is above 
							//our number of frames to keep, i.e. worse ranked than our threshold, we 
							//set the slice number to 0 in the array. This allows us to store only 
							//the slice numbers of the slices we want to use
							for (i1=0;i1<subSlices;i1++) {
								if (IMTArrayCutoffRank2[i1]>(fToKeep-1)) {
									imageNumberArray[i1+(i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3])))] = 0;
								}
							}
				
							//Here we create a new array that stores the slice numbers for the 
							//substack we're currently working with
							currentStackSlices = Array.slice(imageNumberArray, ((i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3])))), (subSlices+((i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3]))))));
			
							getAndProcessSlices(currentStackSlices, motionArtifactRemoval, k);

						}
				
						//At the slice index, add a string of the image number, and its t and z 
						//labels to the imagesToCombineCutoff array - this is in the format 
						//needed to be used with the image concatenator as we will be 
						//concatenating our Z slices together
						imagesToCombineCutoff[motionArtifactRemoval[1]]="image"+(motionArtifactRemoval[1]+1)+"=[T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]+"] ";
				
				        //Increase the zSlice number
						motionArtifactRemoval[1]++;
			
						//If we've reached the end of our timepoint (as microglia morphology is 
						//only done on a single timepoint, this just means we've hit the end of 
						//the unique z positions in our stack), we concatenate them all together 
						//to get a single timepoint
						if(motionArtifactRemoval[1]==iniTextValuesMicrons[3]) {
									
							//This strung loop strings together the names stored in the 
							//arrayDuring into a format that can be used to concatenate only the 
							//selected open images
							strung="";
							for (i1=0; i1<imagesToCombineCutoff.length; i1++) {
							   	strung +=  imagesToCombineCutoff[i1];
							}	
				
							//Here we concatenate all the images we're keeping and rename it 
							//according to the timepoint label stored in motionArtifactRemoval
							run("Concatenate...", "title=[T"+motionArtifactRemoval[2]+"] "+strung+"");
				
							//Reorder the image in Z just to make sure everything lines up, before 
							//registering it

							selectWindow("T"+motionArtifactRemoval[2]);
							run("8-bit");
							print("Reordering and registering T", motionArtifactRemoval[2]);
							run("MultiStackReg", "stack_1=[T"+motionArtifactRemoval[2]+"] action_1=Align file_1=[] stack_2=None action_2=Ignore file_2[] transformation=[Translation]");
							selectWindow("T"+motionArtifactRemoval[2]);
							run("8-bit");
							zSpaceCorrection("T"+motionArtifactRemoval[2], (iniTextValuesMicrons[3]*5), "T"+motionArtifactRemoval[2]);
							selectWindow("T"+motionArtifactRemoval[2]);
							run("8-bit");
							run("MultiStackReg", "stack_1=[T"+motionArtifactRemoval[2]+"] action_1=Align file_1=[] stack_2=None action_2=Ignore file_2[] transformation=[Affine]");
							selectWindow("T"+motionArtifactRemoval[2]);
							run("8-bit");
							print("Done");
											
							//If we're only keeping a single frame (which means we won't have 
							//average projected our image earlier function) then we median blur 
							//our image 
							if(fToKeep==1) {
								selectWindow("T"+motionArtifactRemoval[2]);
								run("Median 3D...", "x=1 y=1 z=1");
							}
			
							timepointNamesCutoff[k] = "T"+motionArtifactRemoval[2];
					
						}
		
					}

					selectWindow("Timepoint");
					run("Close");
			
					motionArtifactRemoval[0]++;
					
				}
		
				//Close the original input image and concatenate all the registered timepoint images
				selectWindow(imagesInput[i]);
				run("Close");
		
				selectWindow(timepointNamesCutoff[(timepoints-1)]);
				run("Duplicate...", "duplicate");
				rename(timepointNamesCutoff[(timepoints-1)] + "Mask");
				setThreshold(1,255);
				run("Convert to Mask", "method=Default background=Dark");
					
				//Min project the mask showing all common pixels to get a single image that we turn into a selection, that we then impose on our concatenated stacks, turn into a proper square,
				//and then create a new image from the concatenate stacks that should contain no blank space
				selectWindow(timepointNamesCutoff[(timepoints-1)] + "Mask");
				run("Z Project...", "projection=[Max Intensity]");
				run("Create Selection");
				
				roiManager("add");
				selectWindow(timepointNamesCutoff[(timepoints-1)]);
				rename(imagesInput[i]);
				roiManager("select", 0);
				run("To Bounding Box");
				run("Clear Outside", "stack");
				run("Duplicate...", "duplicate");
	
				selectWindow(timepointNamesCutoff[(timepoints-1)] + "Mask");
				run("Close");
				selectWindow(imagesInput[i]);
				run("Close");
		
				//As this isn't a timelapse experiment, we can close our original input 
				//image and rename our registered timepoint as the input image
				selectWindow(substring(imagesInput[i], 0, indexOf(imagesInput[i], ".tif")) + "-1.tif");
				rename(imagesInput[i]);
				run("Select None");
				
				//Here we check that the image is calibrated - if not we just recalibrate 
				//using the iniTextValuesMicrons data
				getPixelSize(unit, pixelWidth, pixelHeight);
				if(unit!="um") {
					selectWindow(imagesInput[i]);
					getDimensions(width, height, channels, slices, frames);
					run("Properties...", "channels="+channels+" slices="+slices+" frames="+frames+" unit=um pixel_width="+iniTextValuesMicrons[0]+" pixel_height="+iniTextValuesMicrons[1]+" voxel_depth="+iniTextValuesMicrons[2]+"");
				}

				//If we haven't made an output directory for our input image in the output 
				//folder, we make it
				if(File.exists(directories[1]+imageNames[3]+"/")==0) {
					File.makeDirectory(directories[1]+imageNames[3]+"/");
				}

				selectWindow(imagesInput[i]);
				//run("Select None");
				saveAs("tiff", directories[1]+imageNames[3]+"/" + imageNames[3]+ " processed.tif");
	
				wasMoved = File.rename(directories[0]+imagesInput[i], directories[2]+imagesInput[i]);
				if(wasMoved == 0) {
					print("Issue with moving image");
					waitForUser("Issue with moving image");
				}
				
			}

	Housekeeping();

	}
	
}

//If the user has chosen to select images to analyse
if(analysisSelections[5] == 1) {

	//Array to store variables for use in generating the Images To Use.csv file
	variableArray = newArray(3);
	variableArray[1] = 0;
	//Indexes: how many images the user wants on the screen at once, how many images we've added to our imagesToUse array, and an index of how many images we've
	//added to our final output array
	
	//Ask the user how many images to display on the screen at once for quality control and return this number
	stringa="How many images do you want to display on the screen at once?";
	Dialog.create("Experiment Information");
		
	Dialog.addNumber(stringa,0);
	Dialog.show();
	
	variableArray[0] = Dialog.getNumber();

	//Create an array to fill with locations of images that match the max substring (max projections of processed images) and fill it
	fileLocations=newArray(1);
	forChecking = directories[1];
	outputMaxFiles = listFilesAndFilesSubDirectories(forChecking, "processed", fileLocations);

	//An array storing the column names that we'll use in our results file
	valuesToRecord = newArray("Image List", "Kept", "Manual Flag", "Ignore");

	//If we've previuosly created a results file, open it up, and create an array analysisRecordInput that will store all the results
	//from it
	if(File.exists(directories[1] + "Images to Use.csv") == 1) {
		open(directories[1] + "Images to Use.csv");
		analysisRecordInput = newArray(Table.size * valuesToRecord.length);
		
		//For each row in the results table, get out the data and store it in analysisRecordInput
		for(currRow = 0; currRow < Table.size; currRow ++ ) {
			for(currVal = 0; currVal < valuesToRecord.length; currVal ++ ) {
				if(currVal == 0) {
					analysisRecordInput[(Table.size * currVal)+currRow] = Table.getString(valuesToRecord[currVal], currRow);
				} else {
					analysisRecordInput[(Table.size * currVal)+currRow] = Table.get(valuesToRecord[currVal], currRow);
				}
			}
		}

		selectWindow("Images to Use.csv");
		run("Close");
	
	//If we haven't previuosly created a results table, set the analysisRecordInput array length to store the data
	//for all the images in the output folder		
	} else {
		analysisRecordInput = newArray(outputMaxFiles.length*valuesToRecord.length);
	}
	
	//Create an array to fill with the names of the images we want to calculate motility indices for based on which max projected images pass QA
	imagesToUse = newArray(outputMaxFiles.length);

	//waitForUser("check images to use table");

	//Create a results table to fill with previous data if it exists
	Table.create("Images to Use");
	//Table.create("Hippo Image Check");

	//File the table with previous data
	for(i0=0; i0<(analysisRecordInput.length / valuesToRecord.length); i0++) {
		for(i1=0; i1<valuesToRecord.length; i1++) {
			if(i1 == 0) {
				stringValue = analysisRecordInput[((analysisRecordInput.length / valuesToRecord.length)*i1)+i0];
				Table.set(valuesToRecord[i1], i0, stringValue);
			}
			Table.set(valuesToRecord[i1], i0, analysisRecordInput[((analysisRecordInput.length / valuesToRecord.length)*i1)+i0]);
		}
	}
	Table.update;

	//Opened is a variable that counts how many images we've opened
	opened = 0;

	//Indices is an array that we fill with the location of the images within the file list of the output folder
	indices = newArray(0);

	//Loop through the list of files that have max in their name - start i at 1 so we can use it as a counter of how many images we've opened
	for(i=0; i<outputMaxFiles.length; i++) {

		//Here we go through each row of the results table and check if we already have data for the current max image, where if we do
		//we get out whether the image was analysed already - also create a variable to store whether this image is in our table or not
		checkImage = true;
		selectWindow("Images to Use");
		//selectWindow("Hippo Image Check");
		match = false;
		print(outputMaxFiles[i]);
		
		for(currRow = 0; currRow < Table.size; currRow++) {

			if(Table.get("Image List", currRow)!= 0) {
				if(indexOf(toLowerCase(File.getParent(outputMaxFiles[i])), toLowerCase(File.getParent(Table.getString("Image List", currRow)))) > -1) {
					match = true;
					if(File.exists(File.getParent(outputMaxFiles[i]) + "/TCS Status.csv")==1) {
						Table.set("Kept", currRow, 1);
						print("Already thresholded image");
					}
					if(Table.get("Kept", currRow)==1 || Table.get("Ignore", currRow)==1) {
						checkImage = false;
						print("Already kept or ignored image");
					}
					if(Table.get("Manual Flag", currRow)==1 && File.exists(directories[0] + File.getName(Table.getString("Image List", currRow) + ".tif"))==1) {
						checkImage = false;
					}
					currRow = 1e99;
				}
			}
		}

		//If we couldn't find our image in the table
		if(match == false) {
		print("Not found");
		
			//Set kept and analysed to 0
			kept = 0;

			//Though if it isn't in the table but has been thresholded, we set kept and
			//analysed to 1
			if(File.exists(File.getParent(outputMaxFiles[i]) + "/TCS Status.csv")==1) {
				print("Setting kept for thresholded image to 1");
				kept = 1;
				checkImage = false;
			}

			//Update and save our table
			selectWindow("Images to Use");
			//selectWindow("Hippo Image Check");
			currentImage = substring(outputMaxFiles[i], 0, indexOf(toLowerCase(outputMaxFiles[i]), " processed"));
			Table.set("Image List", i, currentImage);
			Table.set("Kept", i, kept);
			Table.update;
			Table.save(directories[1]+"Images To Use.csv");
			//Table.save(directories[1]+"Hippo Image Check.csv");

			TableName = Table.title;
			//Since we save it every time, we have to rename it to get rid of the .csv 
			if(TableName != "Images to Use") {
			//if(TableName != "Hippo Image Check") {
				Table.rename(TableName, "Images to Use");
				//Table.rename(TableName, "Hippo Image Check");
			}
			
		}

		//if(indexOf(toLowerCase(File.getParent(outputMaxFiles[i])), "hipp") > -1) {
		//If we haven't analysed the current image
		if(checkImage == true) {
		
			//Open each image
			open(outputMaxFiles[i]);
			print(outputMaxFiles[i]);
			print("Curr index", i);

			//Store the index of the image in indices, and add one to the opened variable
			storeIndex = newArray(1);
			storeIndex[0] = i;
			indices = Array.concat(indices, storeIndex);
			opened++;

		}

		//If we've opened enough images to satisfy our image limit value, we print that we've hit the limit
		if(opened != 0 && opened%variableArray[0]==0) {
			print("Hit the limit");
		//Otherwise if we're on our final opened image and we don't have enough images open to reach the limit, we print as such
		} else if (i==(outputMaxFiles.length-1) && nImages < variableArray[0]) {
			print("Reached end of the directory and not enough images to reach limit");
		}

		//If we've hit our limit or we're done opening images
		if((opened!= 0 && opened%variableArray[0]==0) || (i==(outputMaxFiles.length-1) && nImages < variableArray[0])) {
			
			setOption("AutoContrast", true);
			//We get a list of all their titles
			allImages = getList("image.titles");
			imagesKept = newArray(allImages.length);
			manualFlag = newArray(allImages.length);
			ignore = newArray(allImages.length);
			
			//We tile all the open images, display them to the user, and ask the user to close the ones that don't pass QA
			setBatchMode("Exit and Display");
			run("Tile");
			waitForUser("Close the images that aren't good enough in terms of registration for analysis then press ok");

			//If any images are left open
			//if(nImages>0) {

			openImages = getList("image.titles");
			
			//We loop through the titles of the open images and check within the outputMaxFiles array (all the files with max in the name)
			//to find the images location, and we set the imagesToUse array value at that location to 1 (from 0) to indicate that the associated
			//images in outputMaxFiles is one we want to use
			for(i0=0; i0<allImages.length; i0++) {
				for(i1=0; i1<openImages.length; i1++) {
					if(indexOf(toLowerCase(allImages[i0]), toLowerCase(openImages[i1]))>-1) {
						imagesKept[i0] = 1;
						i1 = 1e20;
							
						//We increase our variableArray[1] value to keep track of how many images we've added to our imagesToUse array 
						variableArray[1]++;
					}

				}

				//If we're not keeping this image
				if(imagesKept[i0] == 0) {
					fileName = substring(allImages[i0], 0, (indexOf(toLowerCase(allImages[i0]), "processed"))-1);

					//If this image has a manual registration frame selection file and is in our done folder, this means we've manually
					//registered it and still don't want it so set ignore to 1
					if(File.exists(directories[1] + fileName + "/Slices To Use.csv")==1 && File.exists(directories[2] + fileName + ".tif")==1) {
						ignore[i0] = 1;

						//Else, if this image doesn't have a manual registration frame selection file, we flag it for manual analysis and move
						//the image from the done folder to the input folder
						} else if(File.exists(File.getParent(fileName) + "/Slices To Use.csv")==0) {
							//directories[1] + fileName + "/Slices To Use.csv")==0) {	
							manualFlag[i0] = 1;
							if(File.exists(directories[0] + fileName + ".tif")==0) {
								print(directories[2] + fileName + ".tif");
								wasMoved = File.rename(directories[2]+fileName + ".tif", directories[0]+fileName + ".tif");
								if(wasMoved == 0) {
									waitForUser("Issue with moving image");
								} else {
									print("moved");
								}
							}
						}
					}

				}

				//We close all the open images after editing the imagesToUse array
				if(nImages>0) {
				run("Close All");
				}

			//}
			
			//Update our results table with the names of the images we've checked, as well as their keep value
			selectWindow("Images to Use");
			//selectWindow("Hippo Image Check");
			for(indexLoop =0; indexLoop < indices.length; indexLoop++) {
				print(indexLoop);
				currentIndex = indices[indexLoop];
				currentImage = substring(outputMaxFiles[currentIndex], 0, indexOf(toLowerCase(outputMaxFiles[currentIndex]), " processed"));
				currentKept = imagesKept[indexLoop];
				currentFlag = manualFlag[indexLoop];
				currentIgnore = ignore[indexLoop];
				Table.set("Image List", currentIndex, currentImage);
				Table.set("Kept", currentIndex, currentKept);
				Table.set("Manual Flag", currentIndex, currentFlag);
				Table.set("Ignore", currentIndex, currentIgnore);
				Table.update;
				Table.save(directories[1] + "Images to Use.csv");
				//Table.save(directories[1]+"Hippo Image Check.csv");
			}

			TableName = Table.title;
			//Since we save it every time, we have to rename it to get rid of the .csv 
			if(TableName != "Images to Use") {
			//if(TableName != "Hippo Image Check") {
				Table.rename(TableName, "Images to Use");
				//Table.rename(TableName, "Hippo Image Check");
			}

			//Reset opened to 0 and reset indices to be a blank array
			opened = 0;
			indices = newArray(0);
					
		}
		
	}

}


//If we're going to mark cell positions on our processed images

if(analysisSelections[1] == true) {

////////////////////////////////////////////////////////////////////////////////	
//////////////////////////////Cell Position Marking/////////////////////////////
////////////////////////////////////////////////////////////////////////////////

//If we have generated an images to use csv file - otherwise we can't run this step
	if(File.exists(directories[1] + "Images to Use.csv") == 1) {

		//Run housekeeping
		Housekeeping();

		//Get the image name and whether the image was kept and analysed
		open(directories[1] + "Images to Use.csv");
		Table.rename("Images to Use.csv", "Images to Use");
		selectWindow("Images to Use");
		images = Table.getColumn("Image List");
		kept = Table.getColumn("Kept");
		manFlag = Table.getColumn("Manual Flag");
		ignore = Table.getColumn("Ignore");

		selectWindow("Images to Use");
		run("Close");

		//Here we loop through all the images in the images to use table
		//No counts stores how many substacks we can make from our image
		toConcat = newArray(1);
		finalImagestoUseArray = newArray(1);
		noStacks = newArray(1);
		noStacksRaw = newArray(images.length);
		count = 0;
		for(row = 0; row < images.length; row++) {
			
			//If we kept the image (and have analysed it)
			if(kept[row] == 1) {

				//If the image was kept, count how many 10um thick substacks we can make with at least
				//10um spacing between them, and 10um from the bottom and top of the stack
				run("TIFF Virtual Stack...", "open=["+images[row]+".tif]");
				getVoxelSize(vWidth, vHeight, vDepth, vUnit);
				zSize = nSlices*vDepth;
				counting = 0;
				for(currZ = 10; currZ < zSize; currZ++) {
					if(currZ%10 == 0 && currZ <= zSize-20) {
						counting = counting+1;
					}
				}

				//Fill maskGenerationArray with a string of the range of z planes to include in each substack
				count = 0;
				maskGenerationArray = newArray(counting);
				for(currZ = 10; currZ < zSize; currZ++) {
					if(currZ%10 == 0 && currZ <= zSize-20) {
						maskGenerationArray[count] = currZ+"-"+(currZ+10);
					}
				}

				noStacksRaw[row] = maskGenerationArray.length;

				checkIt = false;
				for(i0 = 0; i0<maskGenerationArray.length; i0++) {
		
				//We need to make 3 chunks of images to analyse - so we loop 3 times
				//Create a substack of 10um deep using our dividingArraySlices array 
				//(i.e. 21-30um, 51-60um, and 81-90um)
				//checkIt = false;
				//for(i0=0; i0<3; i0++) {
			
					imgName="Substack ("+maskGenerationArray[i0]+")"; 
					stringToSave = "Substack ("+maskGenerationArray[i0]+") positions marked"; 

					//Check if we've already generated cell locations for this substack
					//for this image
					if(File.exists(File.getParent(images[row]) + "/Cell Coordinate Masks/"+stringToSave+".txt")==0) {
						checkIt = true;
						i0 = 1e99;
					}
				}
			

				//If we haven't calculated the threshold for this image, add it to our finalImagestoUseArray
				if(checkIt== true) {
				
					//If we're not on the first image, we concatenate our finalImagesToUseArray with our toConcat array
					if(count!=0) {
						finalImagestoUseArray = Array.concat(finalImagestoUseArray, toConcat);
						noStacks = Array.concat(noStacks, toConcat);
					}

					//If the image contains " .tif" in the name we set finalImagestoUseArray[count] to the image name without it,
					//else we just set it to that name
					if(lastIndexOf(images[row], " .tif") > -1 ) {
						finalImagestoUseArray[count] = File.getName(substring(images[row], 0, lastIndexOf(images[row], " .tif")));
					} else {
						finalImagestoUseArray[count] = File.getName(images[row]);
					}

					//Add how many substacks we can make for this image
					noStacks[count] = maskGenerationArray.length;
					
					//Increase our count by one
					count++;
				}
			}
			
			noStacksRaw[row] = 0;
		}

		//Loop through the images that we want to calculate our motility indices for
		for(i=0; i<finalImagestoUseArray.length; i++) {

			Housekeeping();
		
			//Work out the animal and timepoint labels for the current image based on 
			//its name
			imageNames = newArray(4);
			forUse = finalImagestoUseArray[i] + ".tif";
		  	getAnimalTimepointInfo(imageNames, forUse);

		  	/////////////////We're up to here in the checking process
			
			//Look for the files in the cell coordinates masks folder for that image
			maskFolderFiles = getFileList(directories[1] + imageNames[3] + "/Cell Coordinate Masks/");
	
	      	//Set found to 0
			found = 0;
	      
	     	//Loop through the files and if we find a .txt file (an indicator that 
	      	//we've previuosly marked coordinates for this image) then we add 1 to 
	      	//found
			for(i0 = 0; i0<maskFolderFiles.length; i0++) {
				if(indexOf(maskFolderFiles[i0], ".txt")>0) {
					found++;
				}
			}
			
			//If found doesn't equal the number of stacks we can make for this image (i.e. we haven't marked coordinates for all
			//substacks of out input image, even if we have for some) then we continue
			//if(found!=noCounts[i]) {		
			//if(found==noCounts[i]) {		
				
				//Here we make any storage folders that aren't related to TCS and 
				//haven't already been made
				for(i0=0; i0<noCounts[i]; i0++) {
					dirToMake=directories[1]+imageNames[3]+"/"+storageFolders[i0];
					if(File.exists(dirToMake)==0) {
						File.makeDirectory(dirToMake);
					}
				}	
			
				//If the cell position marking table isn't open, we create it
				if(isOpen("Cell Position Marking")==0) {
					Table.create("Cell Position Marking");
				} else {
					Table.reset("Cell Position Marking");
				}
					
				//Create an array here of the columns that will be / are in the cell
				//position marking table
				TableColumns = newArray("Substack", "Bad Registration", "Bad Detection", "Processed", "QC");
					                        
				//TableValues is an array we'll fill with the values from any existing
				//cell position marking table for this image
				TableValues = newArray(noCounts[i]*TableColumns.length);
					
				//TableResultsRefs is an array of the location where we would find any
				//previuosly existing table, repeated for each column
				TableResultsRefs = newArray(directories[1] + imageNames[3] + "/Cell Coordinate Masks/Cell Position Marking.csv", directories[1] + imageNames[3] + "/Cell Coordinate Masks/Cell Position Marking.csv", 
					directories[1] + imageNames[3] + "/Cell Coordinate Masks/Cell Position Marking.csv", directories[1] + imageNames[3] + "/Cell Coordinate Masks/Cell Position Marking.csv", 
					directories[1] + imageNames[3] + "/Cell Coordinate Masks/Cell Position Marking.csv");
						
				//This tells the function whether the results we're getting are strings
				TableResultsAreStrings = newArray(true, false, false, false, false);
					
				//Run the fillArray function to fill TableValues
				fillArray(TableValues, TableResultsRefs, TableColumns, 
					      TableResultsAreStrings, true);
			
				//Here we fill our current or new cell position marking table with data 
				//from our TCSValues array
				selectWindow("Cell Position Marking");
				for(i0=0; i0<noCounts[i]; i0++) {
					for(i1=0; i1<TableColumns.length; i1++) {
						Table.set(TableColumns[i1], i0, TableValues[(noCounts[i]*i1)+i0]);
						if(i1 == TableColumns.length-2) {
							//alreadyProcessed[i0] = TableValues[(3*i1)+i0];
						}
					}
				}

				subName = newArray(noCounts[i]);
				procForTable = newArray(noCounts[i]);
				for(currI = 0; currI < noCounts[i], currI++) {
					procForTable[currI] = 1;
				}
				//procForTable = newArray(1,1,1);
			
				//We need to make 3 chunks of images to analyse - so we loop 3 times
				//Create a substack of 10um deep using our dividingArraySlices array 
				//(i.e. 21-30um, 51-60um, and 81-90um)
				for(i0=0; i0<noCounts[i]; i0++) {
			
					imgName="Substack ("+maskGenerationArray[i0]+")"; 
					stringToSave = "Substack ("+maskGenerationArray[i0]+") positions marked"; 

					subName[i0] = "Substack (" +maskGenerationArray[i0]+ ")";
						
					//Check if we've already generated cell locations for this substack
					//for this image
					//if(File.exists(directories[1] + imageNames[3] + "/Cell Coordinate Masks/"+stringToSave+".txt")==0) {
					if(File.exists(directories[1] + imageNames[3] + "/Cell Coordinate Masks/"+stringToSave+".txt")==1) {

						print("Marking ", imageNames[3], " at ", imgName);
							
						//Open the processed image, make a substack, max project it
						open(directories[1]+imageNames[3]+"/"+imageNames[3]+ " processed.tif");
						if(is("Inverting LUT")==true) {
							run("Invert LUT");
						}
						imageSlices = nSlices;
						lastSlice = parseFloat(substring(maskGenerationArray[i0], indexOf(maskGenerationArray[i0], "-") + 1));
						
						if(lastSlice <= imageSlices){

							selectWindow(imageNames[3]+ " processed.tif");
							rename(imageNames[3]);
							run("Make Substack...", " slices="+maskGenerationArray[i0]+"");
							selectWindow(imgName);
							run("Z Project...", "projection=[Average Intensity]");
							selectWindow("AVG_"+imgName);
							rename("AVG");
									
							//We use a max projection of the chunk to look for our cells, and we 
							//set its calibration to pixels so that the coordinates we retrieve 
							//are accurate as imageJ when plotting points plots them according 
							//to pixel coordinates
		
							getDimensions(width, height, channels, slices, frames);
							run("Properties...", "channels="+channels+" slices="+slices+" frames="+frames+" unit=pixels pixel_width=1 pixel_height=1 voxel_depth=1.0000000");
							run("8-bit");
							run("Clear Results");
								
							//We look for cells using the fina maxima function and ouput a list
							//of the maxima and save these as coordinates
							run("Find Maxima...", "noise=200 output=[Maxima Within Tolerance] exclude");
							if(is("Inverting LUT")==true) {
								run("Invert LUT");
							}
							selectWindow("AVG");
							run("Find Maxima...", "noise=200 output=List exclude");
							selectWindow("Results");
							numbResults = nResults;
							newX = Table.getColumn("X");
							newY = Table.getColumn("Y");

							//Excluding this soma code since the locations of the somas are way off given we changed our registration method
							if(false) {

							//If for this image we already have somas generated then get the corodinates of the somas for this substack and add these
							//to the maxima locations, removing any soma locations that are already represented in the maxima locations
							if(File.exists(directories[1]+imageNames[3]+"/Somas/")==1) {
								somaFiles = getFileList(directories[1]+imageNames[3]+"/Somas/");
								allX = newArray(somaFiles.length);
								allY = newArray(somaFiles.length);
								count = 0;
								for(currSoma = 0; currSoma < somaFiles.length; currSoma++) {
									if(indexOf(somaFiles[currSoma], imgName)>-1){
										allX[count] = parseFloat(substring(somaFiles[currSoma], indexOf(somaFiles[currSoma], "x ") +1, indexOf(somaFiles[currSoma], " y")));
										allY[count] = parseFloat(substring(somaFiles[currSoma], indexOf(somaFiles[currSoma], "y ") +1));
										for(currNew = 0; currNew < numbResults; currNew++) {
											if(newX[currNew] == allX[count] && newY[currNew] == allY[count]) {
												allX[count] = 0;
												allY[count] = 0;
											}
										}
										count++;
									}
								}

								//Remove zeros from our new coordinates
								cleanX = newArray(1);
								cleanX = removeZeros(allX, cleanX);		

								cleanY = newArray(1);
								cleanY = removeZeros(allY, cleanY);

								//Concatenate our new points (if any don't match) to our old points
								newX = Array.concat(newX, cleanX);
								newY = Array.concat(newY, cleanY);
							}

							}

							//Here we load in the coordinates file if it already exists and remove any of these additional points if they are already
							//represented, then concatenate them
							if(File.exists(directories[1]+imageNames[3]+"/Cell Coordinates/CP coordinates for " + imgName + ".csv")==1) {
								Table.open(directories[1]+imageNames[3]+"/Cell Coordinates/CP coordinates for " + imgName + ".csv");
								selectWindow("CP coordinates for " + imgName + ".csv");
								oldX = Table.getColumn("X");
								oldY = Table.getColumn("Y");

								//Looping through our new points and comparing them to our existing points, if they're the same, set their values to 0
								for(currRow = 0; currRow < oldX.length; currRow++) {
									rX = oldX[currRow];
									rY = oldY[currRow];
									for(currResult = 0; currResult < newX.length; currResult++) {
										if(newX[currResult] == rX && newY[currResult] == rY) {
											oldX[currRow] = 0;
											oldY[currRow] = 0;
										}
									}
								}

								//Remove zeros from our new coordinates
								cleanX = newArray(1);
								cleanX = removeZeros(oldX, cleanX);		

								cleanY = newArray(1);
								cleanY = removeZeros(oldY, cleanY);

								//Concatenate our new points (if any don't match) to our old points
								newX = Array.concat(newX, cleanX);
								newY = Array.concat(newY, cleanY);

							}

							//Create / reset a table to store our coordinates, set the X and Y columns appropriately, save
							if(isOpen("CP coordinates for " + imgName + ".csv")==1) {
								selectWindow("CP coordinates for " + imgName + ".csv");
								Table.reset("CP coordinates for " + imgName + ".csv");
							} else {
								Table.create("CP coordinates for " + imgName + ".csv");
							}

							selectWindow("CP coordinates for " + imgName + ".csv");
							if(newX.length == 0) {
								Table.setColumn("X", 1);
								Table.setColumn("Y", 1);
							} else {
								Table.setColumn("X", newX);
								Table.setColumn("Y", newY);
							}
							
							saveAs("Results", directories[1]+imageNames[3]+"/Cell Coordinates/CP coordinates for " + imgName + ".csv");

							selectWindow("CP coordinates for " + imgName + ".csv");
							Table.reset("CP coordinates for " + imgName + ".csv");
							
							selectWindow("AVG Maxima");
							run("Select None");

							//Save the selections around the maxima and the image itself
							saveAs("tiff", directories[1] + imageNames[3] + "/Cell Coordinate Masks/Automated CPs for Substack (" + maskGenerationArray[i0] + ").tif");
							selectWindow("AVG");
							run("Select None");
							saveAs("tiff", directories[1] + imageNames[3] + "/Cell Coordinate Masks/CP mask for Substack (" + maskGenerationArray[i0] + ").tif");

						}

						//Set the values in our cell position marking table according to the 
						//image we've just processed, set processed to 1, save the table, and 
						//lastly save a .txt file which we use to check quickly whether we've
						//processed this image as opening the table to read values for each
						//image takes ages
						File.saveString(stringToSave, directories[1]+imageNames[3]+"/Cell Coordinate Masks/"+stringToSave+".txt");
								
					}
		
					Housekeeping();

				}
					
				//Set the values in our cell position marking table according to the 
				//image we've just processed, set processed to 1, save the table, and 
				//lastly save a .txt file which we use to check quickly whether we've
				//processed this image as opening the table to read values for each
				//image takes ages
				selectWindow("Cell Position Marking");
				Table.setColumn("Substack", subName);
				Table.setColumn("Processed", procForTable);
				Table.save(directories[1] + imageNames[3] + "/Cell Coordinate Masks/Cell Position Marking.csv");
				currName = Table.title;
				Table.reset(currName);

			}
		}

		Housekeeping();

		toConcat = newArray(1);
		finalImagestoUseArray = newArray(1);
		count = 0;
		for(row = 0; row < images.length; row++) {
			
			//If we kept the image (and have analysed it)
			if(kept[row] == 1) {
		
				//We need to make 3 chunks of images to analyse - so we loop 3 times
				//Create a substack of 10um deep using our dividingArraySlices array 
				//(i.e. 21-30um, 51-60um, and 81-90um)
				checkIt = false;
				for(i0=0; i0<noStacksRaw[row]; i0++) {
			
					imgName="Substack ("+maskGenerationArray[i0]+")"; 
					stringToSave = "Substack ("+maskGenerationArray[i0]+") positions marked"; 

					//Check if we've already generated cell locations for this substack
					//for this image
					if(File.exists(File.getParent(images[row]) + "/Cell Coordinate Masks/"+stringToSave+".txt")==1) {
						checkIt = true;
						i0 = 1e99;
					}
				}
			

				//If we haven't calculated the threshold for this image, add it to our finalImagestoUseArray
				if(checkIt== true) {
				
					//If we're not on the first image, we concatenate our finalImagesToUseArray with our toConcat array
					if(count!=0) {
						finalImagestoUseArray = Array.concat(finalImagestoUseArray, toConcat);
					}

					//If the image contains " .tif" in the name we set finalImagestoUseArray[count] to the image name without it,
					//else we just set it to that name
					if(lastIndexOf(images[row], " .tif") > -1 ) {
						finalImagestoUseArray[count] = File.getName(substring(images[row], 0, lastIndexOf(images[row], " .tif")));
					} else {
						finalImagestoUseArray[count] = File.getName(images[row]);
					}
					
					//Increase our count by one
					count++;
				}
			}
		}
		
		//Once we've automatically generated cell masks for all images, we then loop through
		//all the images again
		for (i=0; i<finalImagestoUseArray.length; i++) {
			
			//Work out the animal and timepoint labels for the current image based on 
			//its name
			imageNames = newArray(4);
			forUse = finalImagestoUseArray[i] + ".tif";
			getAnimalTimepointInfo(imageNames, forUse);
			
			print("Checking ", imageNames[3]);
			
			//Get the list of the files in our cell coordinates subfolder
			coordinateFiles = getFileList(directories[1] + imageNames[3] + "/Cell Coordinates/");
	
			//If we have at least a file there (we've generated some coordinates)
			if(coordinateFiles.length!=0) {
				
				//If we have a cell position marking.csv window open already, just reset it instead of closing
				if(isOpen("Cell Position Marking.csv")==true){
					selectWindow("Cell Position Marking.csv");
					Table.reset("Cell Position Marking.csv");
				}
				
				//Open our cell position marking csv file
				Table.open(directories[1] + imageNames[3] + "/Cell Coordinate Masks/Cell Position Marking.csv");
				
				//Get out the QC column from the cell position marking table and calculate its mean
				selectWindow("Cell Position Marking.csv");
				QCArray = Table.getColumn("QC");
	
				//Get out the QC values for the substacks that we actually have coordinate files for
				QCArray = Array.slice(QCArray, 0, coordinateFiles.length);
				Array.getStatistics(QCArray, QCMin, QCMax, QCMean, QCSD);
				
				//If the mean isn't 1 (i.e. not all substacks for this image have had their masks quality controlled
				//since once they're QC'd we set the QC value to 1, therefore when they're all done the QC value mean
				//should =1) then we proceed
				if(QCMean!=1) {
	
					//Rename our window to without the .csv
					selectWindow("Cell Position Marking.csv");
					Table.rename("Cell Position Marking.csv", "Cell Position Marking");
		
					//Loop through the substacks we have coordinates for
					for(i0=0; i0<coordinateFiles.length; i0++) {
				
						//Get the QC value of the current substack, and set the variables badReg and badDetection to 0
						//(These variables set whether the image either didn't register properly or if the automatic
						//mask detection was no good)
						currentQC = QCArray[i0];
						badReg = 0;
						badDetection = 0;
		
						//If the current substack hasn't been quality controleld
						if(currentQC==0) {
							
							//Create a variable to store the name of the current substack
							imgName="Substack ("+maskGenerationArray[i0]+")"; 
							print(directories[1]+imageNames[3]+"/Cell Coordinate Masks/CP mask for Substack ("+maskGenerationArray[i0]+").tif");
							
							//Open its cell placement masks image and the image that has the automated CPs
							open(directories[1]+imageNames[3]+"/Cell Coordinate Masks/CP mask for Substack ("+maskGenerationArray[i0]+").tif");
							if(is("Inverting LUT")==true) {
								run("Invert LUT");
							}
							
							selectWindow("CP mask for Substack (" + maskGenerationArray[i0]+").tif");
							rename("MAX");

							print(directories[1]+imageNames[3]+"/Cell Coordinates/CP coordinates for Substack ("+maskGenerationArray[i0]+").csv");
							print(File.exists(directories[1]+imageNames[3]+"/Cell Coordinates/CP coordinates for Substack ("+maskGenerationArray[i0]+").csv"));

							Table.open(directories[1]+imageNames[3]+"/Cell Coordinates/CP coordinates for Substack ("+maskGenerationArray[i0]+").csv");
							selectWindow("CP coordinates for Substack ("+maskGenerationArray[i0]+").csv");
							xPoints = Table.getColumn("X");
							yPoints = Table.getColumn("Y");

							selectWindow("MAX");
							makeSelection("point", xPoints, yPoints);
							setBatchMode("Exit and Display");
	
							//If there are cell ROIs generated
							if(selectionType() != -1) {
								roiManager("add");
								selectWindow("MAX");
								roiManager("select", 0);
							
								//Ask the user whether these automated masks were generated well or not
								goodCPs = userApproval("Check that the automated CP selection has worked", "CP Checking", "Automated CPs Acceptable?");
	
							} else {
								goodCPs = false;
							}
												
							//If they're poor
							if (goodCPs == false) {
								
								//Ask the user to check what was wrong with the image and get whether it was bad registration,
								//bad detection, or both
								//run("Tile");
								waitForUser("Check whats wrong with automated CP generation");		
								Dialog.create("What went wrong?");
								Dialog.addCheckbox("Bad registration?", true);
								Dialog.addCheckbox("Bad detection?", true);
								Dialog.show();
								badRegRaw = Dialog.getCheckbox();
								badDetectionRaw = Dialog.getCheckbox();		
	
								//Convert the boolean user choices to integers
								badReg = 0;
								if(badRegRaw == true) {
									badReg = 1;
								}
								badDetection = 0;
								if(badDetectionRaw == true) {
									badDetection = 1;
								}
								
							//If the CP generation was good
							} else {
								
								//Set the tool to multipoint and ask the user to click on any cells the
								//automatic placement generation missed
								setTool("multipoint");
								selectWindow("MAX");
								roiManager("Show All");
								waitForUser("Click on cells that were missed by automatic detection, if any");
								
								//If the user clicked on additional cells
								if(selectionType()!=-1) {
									
									//Add the cell locations to the roiManager and measure them to get their X,Y coords
									//in the results window
									roiManager("add");
									run("Set Measurements...", "centroid redirect=None decimal=0");
									run("Clear Results");
									roiManager("Select", 1);
									roiManager("Measure");
									
									setBatchMode(true);
									
									//Get the X,Y coords from the results window
									selectWindow("Results");
									X = Table.getColumn("X");
									Y = Table.getColumn("Y");
			
									//Concatenate the two - the original X and Y coords and the ones we've added
									newX = Array.concat(xPoints, X);
									newY = Array.concat(yPoints, Y);
	
									//Then set the concatenated arrays as the X and Y results in the results table before
									//saving it over the CP coordinates file
									Table.setColumn("X", newX);
									Table.setColumn("Y", newY);
									Table.update;
									saveAs("Results", directories[1]+imageNames[3]+"/Cell Coordinates/CP coordinates for " + imgName + ".csv");
									selectWindow("CP coordinates for Substack ("+maskGenerationArray[i0]+").csv");
									run("Close");
								}
							
							}
			
							//If the image had bad detection but otherwise the registration was fine
							if(badDetection == 1 && badReg == 0) {
								
								//Delete the automatically generated masks overlay
								if(roiManager("count")>0) {
									roiManager("deselect");
									roiManager("delete");
								}
								selectWindow("MAX");
								
								//Ask the user to click on cell bodies
								setTool("multipoint");
								setBatchMode("Exit and Display");
								roiManager("show none");
								run("Select None");
								waitForUser("Click on cell bodies to select cells for analysis");
								setBatchMode(true);
								
								//Once the user has selected all the cells, we add them to roiManager before measuring them with roiManager to get their coordinates
								roiManager("add");
								run("Set Measurements...", "centroid redirect=None decimal=0");
								selectWindow("MAX");
								roiManager("Select", 0);
								run("Clear Results");
								roiManager("Measure");
								roiManager("delete");
				
								//Save the coordinates of cell placements
								selectWindow("Results");
								saveAs("Results", directories[1]+imageNames[3]+"/Cell Coordinates/CP coordinates for " + imgName + ".csv");
			
								//Set bad detection 0
								badDetection = 0;
			
							//If the image had bad registration, we do nothing
							} else {
								setBatchMode(true);
							}

							//Future - write code so that if the image had bad registration we can rbound to manually register it
							//Or just get out a list of bad reg so its not automated?
							
							//Set currentQC to 1 since we've finished quality control
							currentQC = 1;
			
							//Update our cell position marking table and save it
							selectWindow("Cell Position Marking");
							Table.set("Bad Detection", i0, badDetection);
							Table.set("Bad Registration", i0, badReg);
							Table.set("QC", i0, currentQC);
							Table.update;
							Table.save(directories[1] + imageNames[3] + "/Cell Coordinate Masks/Cell Position Marking.csv"); 
			
							Housekeeping();
						
						}
		
					}
		
				Table.reset("Cell Position Marking");
	
				}
	
			}
	
		}
	
	}


//If the user wants to automatically generate masks of microglial cells
if(analysisSelections[2] == true) {
	
	//Set the background color to black otherwise this messes with the clear outside command
	
	loopThrough = getFileList(directories[1]);
	////////////////////////////////////Automatic Microglial Segmentation///////////////////////////////////////////////////////////
	
	//This is the main body of iterative thresholding, we open processed input images and use the coordinates of the cell locations previuosly 
	//input to determine cell locations and create cell masks
	for (i=0; i<loopThrough.length; i++) {	
		
		//Work out the animal and timepoint labels for the current image and create a variable for the name without .tif
		//animalTimepoint = substring(loopThrough[i], 0, indexOf(loopThrough[i], " Microglia Morphology"));
		//timepoint = toLowerCase(substring(animalTimepoint, lastIndexOf(animalTimepoint, " ")+1));
		//animal = toLowerCase(substring(animalTimepoint, 0, lastIndexOf(animalTimepoint, " ")));
		//baseName=substring(imagesInput[i], 0, indexOf(imagesInput[i], ".tif"));

		imageNames = newArray(4);
		forUse = loopThrough[i] + ".tif";

		proceed = false;
		if(loopThrough[i] != "Images To Use.csv" && loopThrough[i] != "fracLac/") {
		
			//Find out how many cell coordinate files there are in the basename directory, and if there's at least one
			//we proceed, so we don't end up looking in directories where cell coordinates haven't been marked
			coordinateFiles = getFileList(directories[1]+baseName+"/Cell Coordinates/");
			print(directories[1]+baseName+"/Cell Coordinates/");
		
			if(coordinateFiles.length>0) {

				Table.create("ToBChanged");
			
				//Here we create a table that will store all the TCS values we're going through, and for each one, whether we've
				//generated masks for it, whether we've QC checked it, and whether we've analysed it - headings are in TCSColumns
				TCSColumns = newArray("TCS", "Masks Generated", "QC Checked", "Analysed");
	
				//TCSValues is an array that we will store all this data in with a single dimension - we just have to index into the first TCSColumns.length
				//indices to get the TCS values, and the second to get the masks generated values etc
				TCSValues = newArray(numberOfLoops*TCSColumns.length);
			
				//This is an array of where we get the data for these values from if they previuosly exist - from the TCS Status.csv files
				//that are saved if we've done this before
				TCSResultsRefs = newArray(directories[1]+baseName+"/TCS Status.csv", directories[1]+baseName+"/TCS Status.csv", 
										directories[1]+baseName+"/TCS Status.csv", directories[1]+baseName+"/TCS Status.csv");
	
				//This array stores whether the values we're getting are strings or not
				TCSResultsAreStrings = newArray(false, false, false, false);
	
				//Array to store the calibration values
				iniTextValuesMicrons = newArray(5);
				//Index 0 is xPxlSz, then yPxlSz, zPxlSz, ZperT, FperZ, then wrong objective
	
				//Variable to set whether we've gotten calibration values for this image
				gottenCalibration = false;

				//Here we begin looping through the different TCS values we're going to be analysing
				for(TCSLoops=0; TCSLoops<numberOfLoops; TCSLoops++) {
		
					//This is an array to store the associated values for the current TCS loop
					currentLoopValues = newArray(TCSColumns.length);
					//[0] is TCS, [1] is masks generated, [2] is QC checked, [3] is analysed, [4] is wrong obj

					//Set the TCS as the lowest TCS + the increment we want to increase by, X how many times we've increased
					//We set these variables so that TCS is the current TCS to use, and TCSLoops is the number of loops we've been through
					currentLoopValues[0]=selection[0]+(selection[3]*TCSLoops);
	
					//Here we fill our TCSValues array with all the associated data taken from previous instances
					//we've run this macro if we have generated a TCS Status.csv file before
	
					fillArray(TCSValues, TCSResultsRefs, TCSColumns, TCSResultsAreStrings, true); 
		
					//Here we fill our TCS Status table with data from our TCSValues array
					selectWindow("ToBChanged");
					for(i0=0; i0<numberOfLoops; i0++) {
						for(i1=0; i1<TCSColumns.length; i1++) {
							Table.set(TCSColumns[i1], i0, TCSValues[(numberOfLoops*i1)+i0]);
						}
					}
				
					selectWindow("ToBChanged");
					for(i0 = 0; i0<Table.size; i0++) {
						if(currentLoopValues[0] == Table.get("TCS", i0)) {
							//Here we fill our currentLoopValues table with the TCSValues data that corresponds to the TCS value
							//we're current processing - this will be a bunch of zeros if we haven't processed anything before
							for(i1=0; i1<TCSColumns.length; i1++) {
								currentLoopValues[i1] = Table.get(TCSColumns[i1], i0);
							}
						}
					}

					Table.rename("ToBChanged", "TCS Status");
	
					//limits is an array to store the lower and upper limits of the cell area we're using within this TCS loop, calculated
					//according to the error the user input
					limits = newArray(currentLoopValues[0]-selection[2], currentLoopValues[0]+selection[2]);
					//Selection: //[0] is TCSLower, [1] is TCSUpper, [2] is range, [3] is increment, [4] is framesToKeep, [5] is trace
					//Limits: [0] is lower limit, [1] is upper
		
					//This is the directory for the current TCS
					TCSDir=directories[1]+baseName+"/"+"TCS"+currentLoopValues[0]+"/";
		
					//Here we make a TCS specific directory for our input image if it doesn't already exist
					if(File.exists(TCSDir)==0) {
						File.makeDirectory(TCSDir);
					}
		
					//Here we store the full names of the directories in an array for access later
					storageFoldersArray=newArray(storageFolders.length);
		
					//Here we make sure we have all the working directories we need, either within or without the
					//TCS specific directory
					for(i0=0; i0<storageFolders.length; i0++) {
	
						//Depending on what storageFolder we're working with, the dirToMake and parentDir vary
						if(i0<3) {
							dirToMake=directories[1]+baseName+"/"+storageFolders[i0];
							parentDir=directories[1]+baseName+"/";	
						} else {
							dirToMake=TCSDir+storageFolders[i0];
							parentDir=TCSDir;	
						}
	
						//Either way, we store the parentDir and storageFolders[i0] value in storageFoldersArray
						storageFoldersArray[i0]=parentDir+storageFolders[i0];
	
						//And if dirToMake doesn't exist, we make it
						if(File.exists(dirToMake)==0) {
							File.makeDirectory(dirToMake);
						}	
					}
		
					//Here if we haven't already looped through this TCS, we enter the process
					if(currentLoopValues[1]==0) {
		
						//We use this variable to store the total number of cells we've counted for a given image
						totalCells=0;
		
						//These arrays are used to store all the X and Y coordinates, and the substack names associated with them
						tempX = newArray(1);
						tempY = newArray(1);
						tempName = newArray(1);

						//Here we get out the cell postion marking informatino about whther the positions were makred
						//correctly or if there were issues with the image
						open(directories[1]+baseName+"/Cell Coordinate Masks/Cell Position Marking.csv");
						selectWindow("Cell Position Marking.csv");
						QCArray = Table.getColumn("QC");
						ProcessedArray = Table.getColumn("Processed");
						detectionArray = Table.getColumn("Bad Detection");
						regArray = Table.getColumn("Bad Registration");
						Table.reset("Cell Position Marking.csv");
						
						coordPath = directories[1] + baseName + "/Cell Coordinates/";
		
						noStacks = getfileList(coordPath);
						//Here we loop through all 3 substacks of cell placements and add together all the cells in them
						for(i0=0; i0<noStacks.length; i0++) {
						
							//Find the number of coordinates for the associated chunk by opening the coordinates table and finding nResults
							imgName = substring(noStacks[i0], indexOf(noStacks[i0], "for "), indexOf(noStacks[i0], ".csv"));
							//imgName="Substack ("+maskGenerationArray[i0]+")";
							inputpath=directories[1]+baseName+"/Cell Coordinates/"+noStacks[i0];
							print(ProcessedArray[i0], QCArray[i0], detectionArray[i0], regArray[i0]);

							//If the image has been processed, QC'd, and theres is no bad detection or bad registration, then proceed
							if(ProcessedArray[i0] == 1 && QCArray[i0] == 1 && detectionArray[i0] == 0 && regArray[i0] == 0) {
							
								//Add the nResults of the cell coordinates to the totalCells count
								//run("Clear Results");
								open(inputpath);
								totalCells += Table.size;
		
								//Here we create an array to store the name of the image chunk 
								substackName = newArray(Table.size);
								for(i1=0; i1<Table.size; i1++) {
									substackName[i1] = imgName;
								}
		
								//Here we get out all the X and Y coordinates from the results table and store all the X's in tempX, and all the Y's
								//in tempY, as well as the substackNames in tempName
		
								selectWindow("CP coordinates for " + imgName + ".csv");
								currentX = Table.getColumn("X");
								currentY = Table.getColumn("Y");
								tempX = Array.concat(tempX,currentX);
								tempY = Array.concat(tempY, currentY);
								tempName = Array.concat(tempName, substackName);
								selectWindow("CP coordinates for " + imgName + ".csv");
								Table.reset("CP coordinates for " + imgName + ".csv");
							}

						}


						//If we have at least one coordinates to analyze
						if(totalCells!=0) {
	
							//Here we cut out all the zeros from the tempX, tempY,and tempName arrays and move the data into X,Y, and finalSub arrays
							X = newArray(1);
							Y = newArray(1);
							finalSub = newArray(1);
		
							X = removeZeros(tempX, X);
							Y = removeZeros(tempY, Y);
							finalSub = removeZeros(tempName, finalSub);
						
							//Here we make arrays to fill with the name of the current cell and whether we've attempted to create a mask from it already that we fill
							//with 1's by default
							maskSuccessPrev = newArray(totalCells);
							Array.fill(maskSuccessPrev, 1);
		
							//If we're not in the first TCS loop
	
							if(TCSLoops>0) {
			
								//We create an array to store these values from our previous TCS loop
								prevLoopValues = newArray(TCSColumns.length);
								//[0] is TCS, [1] is masks generated, [2] is QC checked, [3] is analysed, [4] is wrong obj, [5] is TCS error
					
		
								//Here we fill the array with the values from the previuos TCS loop as stored in TCSValues
		
								for(i0=0; i0<TCSColumns.length; i0++) {
									prevLoopValues[i0] = TCSValues[(numberOfLoops*i0)+(TCSLoops-1)];
								}
		
								//Here we open the Mask Generation.csv file from the previous TCS loop and get out the information
								//about which mask generation was successful and store these in the maskSuccessPrev array
								previousTCSDir=directories[1]+baseName+"/TCS"+prevLoopValues[0]+"/";
			
								run("Clear Results");
								open(previousTCSDir+"Mask Generation.csv");
								selectWindow("Mask Generation.csv");
								resultsNo=Table.size; 	
								for(i0=0; i0<resultsNo; i0++) {
									maskSuccessPrev[i0] = Table.get("Mask Success", i0);
								}
								Table.reset("Mask Generation.csv");
								//Array.show(maskSuccessPrev);
								//waitForUser("Check this line 2820");
								Table.update;
			
							}
	
							//This is an array of headers for data we want to record for the cells we're going to be creating masks for - xOpt and yOpt are the x and y coordinates
							//that are located on the pixel with the maximum grey value on that cell, details follow later
							//Mask name is the name of the mask, try is whether we tried generating a mask for it or not, success is whether it was a success
							valuesToRecord = newArray("Mask Name", "Mask Try", "Mask Success", "xOpt", "yOpt");
						
							//This is an array that will store all the data associated wtih the headers but in a single dimension, where the first maskDirFiles.length
							//indices correspond to "Mask Name", then "Mask Try" etc.
							analysisRecordInput = newArray(totalCells*valuesToRecord.length);
						
							//These are the locations of any previously generated tables that contain the valuesToRecord info
							resultsTableRefs = newArray(TCSDir+"Mask Generation.csv", TCSDir+"Mask Generation.csv", TCSDir+"Mask Generation.csv",
													TCSDir+"Mask Generation.csv", TCSDir+"Mask Generation.csv");
					
							//This is whether the results to get are strings or not
							resultsAreStrings = newArray(true, false, false, false, false);
				
							//Here we fill our analysisRecordInput with the data we want as outlined in valuesToRecord if it exists from previous runs of the macro
							fillArray(analysisRecordInput, resultsTableRefs, valuesToRecord, resultsAreStrings, true);
				
							//We then concatenate on the x and y coordinates of our cell positons as well the as the name of the substack these coordinates are in to our
							//analysisRecordInput array
							analysisRecordInput = Array.concat(analysisRecordInput, X);
							analysisRecordInput = Array.concat(analysisRecordInput, Y);
							analysisRecordInput = Array.concat(analysisRecordInput, finalSub);
							
							//We then also add on the headers for this data to our valuestoRecord array and make a new headers array that contains them both
							toAdd = newArray("X Coord", "Y Coord", "Substack Name");
							tableLabels = Array.concat(valuesToRecord, toAdd);
		
							//Here make a table that we fill with information that corresponds to table lables i.e.
							// "Mask Name", "Mask Try", "Mask Success", "xOpt", "yOpt", "X Coord", "Y Coord", "Substack Name"
				
							Table.create("Mask Generation PreChange");
							selectWindow("Mask Generation PreChange");
							for(i1=0; i1<totalCells; i1++) {
								for(i2=0; i2<tableLabels.length; i2++) {
									if(i2 == 0 || i2 == 7) {
										stringValue = analysisRecordInput[(totalCells*i2)+i1];
										Table.set(tableLabels[i2], i1, stringValue);
									} else {
										Table.set(tableLabels[i2], i1, analysisRecordInput[(totalCells*i2)+i1]);
									}
								}
							}

							if(isOpen("Mask Generation PreChange")==false) {
								setBatchMode("exit and display");
								waitForUser("Table not made or disappearead");
							}
		
							//We now loop through all the cells for this given input image
							for(i0=0; i0<totalCells; i0++) {
							
								//Here we create an array to store the following data for a given cell
								currentMaskValues = newArray(8);
								//[0] is mask name, [1] is mask try, [2] mask success, [3] xopt, [4] yopt, [5] x, [6] y, [7] substack
		
								//We fill our currentMaskValues with the correct data from analysisRecordInput by indexing into it in the appropriate locations
								for(i1=0; i1<currentMaskValues.length; i1++) {
									currentMaskValues[i1] = analysisRecordInput[(totalCells*i1)+i0];
								}
							
								//We create an array to store different names we need for our mask generation where [0] is the name to save an image as, [1] is the
								//fileName, and [2] is the LRName. [0] and [1] are repeats as we edit them differently within functions
								imageNamesArray = newArray(storageFoldersArray[3]+"Candidate mask for " + finalSub[i0] + " x " + X[i0] +  " y " + Y[i0] + " .tif", 
												"Candidate mask for " + finalSub[i0] + " x " + X[i0] +  " y " + Y[i0] + " .tif",
												"Local region for " + finalSub[i0] + " x " + X[i0] + " y " + Y[i0] + " .tif");
												//[0] is saveName, [1] is fileName, [2] is LRName
			
								//Here we set the cell name of the current mask to fileName
								currentMaskValues[0]=imageNamesArray[1];
							
								//If the current mask hasn't been tried, and making the mask previously was a success then we try to make a mask - the reason we check previously
								//is because our TCS sizes increase with each loop, so if we couldn't make a mask on a previous loop where the TCS was smaller, that means the mask 
								//must have been touching the edges of the image, so with a larger TCS, then we're guaranteed that the mask will touch the edges so we don't bother
								//trying to make a mask for it anymore
		
								if(currentMaskValues[1]==0 && maskSuccessPrev[i0]==1) {
		
									//If we haven't previously retrieved the calibration values for this image, then we fill the
									//iniTextValuesMicrons array with the calibration information and set gottenCalibration to true
									if(gottenCalibration == false) {

										getAnimalTimepointInfo(imageNames, forUse);
										baseName = substring(loopThrough[i], 0, lastIndexOf(loopThrough[i], "/"));

										if(analysisSelections[6] == true) {
				
											//Fill that array with the calibration data for that animal at that 
											//timepoint
											getIniData(directories[3], imageNames[2], imageNames[1], iniTextValuesMicrons);

										} else {

											open(directories[1]+baseName+"/"+baseName+" processed.tif");
							
											iniTextValuesMicrons[4] = noIniFperZ;
											iniTextValuesMicrons[3] = nSlices;
												
											getVoxelSize(vWidth, vHeight, vDepth, vUnit);
											iniTextValuesMicrons[0] = vWidth;
											iniTextValuesMicrons[1] = vHeight;
											iniTextValuesMicrons[2] = vDepth;
							
											run("Close");

										
										}
					
										gottenCalibration = true;
									}

									//Array.show(iniTextValuesMicrons);
									//waitForUser("Check if this is wrongly calibrated - last index should be 1 if wrong - also need to check how this relates to hippo vs V1");
				
									//This is an array to store the size of the local region in pixels (i.e. 120um in pixels)
									LRLengthPixels=(LRSize*(1/iniTextValuesMicrons[0]);
									//[3] is size of the local region, [0] is the pixel size
								
									//If the CP mask image isn't already open
									if(!isOpen("CP mask for " + finalSub[i0] + ".tif")) {
			
										//We open the image then calibrate it before converting it to 8-bit
										open(directories[1]+baseName+"/Cell Coordinate Masks/CP mask for " + finalSub[i0]+".tif");
										imgName = getTitle();
										run("Select None");
										run("Properties...", "channels=1 slices=1 frames=1 unit=um pixel_width="+iniTextValuesMicrons[0]+" pixel_height="+iniTextValuesMicrons[1]+" voxel_depth="+iniTextValuesMicrons[2]+"");
										getDimensions(originalWidth, originalHeight, originalChannels, originalSlices, originalFrames);
										run("8-bit");	
									}
								
									//Here we create an array to store the coordinates we're going to be analysing for this cell
									coordsArray = newArray(X[i0], Y[i0]);
											
									//Here we work out the number of pixels that represent 5 microns so we can use this to calculate if the coordinates are within the 5um buffer zone
									//of the edge of the image
									fiveMicronsInPixels=5*(1/iniTextValuesMicrons[0]);
			
									//If the y coordinate isn't less than 5 microns from the bottom or top edges of the image, and the x coordinate isn't less than 5 pixels from the width, then we
									//proceed
									if (!(coordsArray[1]<=fiveMicronsInPixels) || !(coordsArray[1]>=(originalHeight-fiveMicronsInPixels)) || !(coordsArray[0]>=(originalWidth-fiveMicronsInPixels)) || !(coordsArray[0]<=fiveMicronsInPixels)) { 	
			
										//Here we store x and y values that we would use to draw a 120x120um square aruond our coordinate - we store the coordinates
										//that would be the top left corner of this square as that is what we need to input to draw it
										newCoordsArray = newArray(coordsArray[0]-(LRLengthPixels/2), coordsArray[1]-(LRLengthPixels/2));
										//[0] is xcordn, [1] is ycordn
			
										//This array is created to store the length in x and y of the local region we're going to draw - in theory it should be 120um
										//for both directions but if our coordinate is close enough to the edge of our image that this isn't true, we adjust it
										LRLengthArray = newArray(2);
										//[0] is xLength, [1] is yLength
			
										//This array stores the width and height of our image so we can check against these
										dimensionsCheckingArray = newArray(originalWidth, originalHeight);
				
										//Idea here is that if our x or y coordinates are less than half a LR length away from the edge, the LR length we create is half the 
										//usual length + however far our coordinate is from the edge
										//We also set our rectangle making coordinates to 0 if they would be less than 0 (i.e. our coordinates are less than half the LR distance
										//from the pictre edges
				
										//For each iteration we first do x then y coordinates
										for(i1=0; i1<2; i1++) {
											if(coordsArray[i1]<(LRLengthPixels/2)) {
												newCoordsArray[i1]=0;
												LRLengthArray[i1]=(LRLengthPixels/2) + coordsArray[i1];
											
											//Here we calculate what the length of our selection will have to be to take into account the coordinates location in the image
											} else if (coordsArray[i1]>(dimensionsCheckingArray[i1]-(LRLengthPixels/2))) {
												LRLengthArray[i1] = (LRLengthPixels/2)+(dimensionsCheckingArray[i1]-coordsArray[i1]);
											} else {
												LRLengthArray[i1] = LRLengthPixels;
											}
										}
				
										//Making and saving local regions, running first Otsu method and getting initial value on which to base iterative process	
										print("Coordinate number " + (i0+1) + "/" + totalCells);
										print("Making local region image of 120um x 120um centered on X: " + coordsArray[0] + " Y: " + coordsArray[1]);
										selectWindow(imgName);
	
										imageT = getList("image.titles");
										otherT =  getList("window.titles");
										Array.show(imageT, otherT);
										found = false;
										for(currName = 0; currName < otherT.length; currName++) {
											if(otherT[currName] == "Mask Generation PreChange") {
												found = true;
												currName = 1e99;
											}
										}
										if(found==false) {
											setBatchMode("Exit and Display");
											waitForUser("Not present at very start");
											setBatchMode(true);
										}
			
										//Here we make our local region based on all the values we've calculated
										makeRectangle(newCoordsArray[0], newCoordsArray[1], LRLengthArray[0], LRLengthArray[1]);
										run("Duplicate...", " ");
										tifLess = substring(imgName, 0, indexOf(imgName, ".tif"));
										selectWindow(tifLess + "-1.tif");
										rename("LR");
			
										//We then auto threshold the LR and then get the lower and upper threshold levels from the otsu method and call the lower threshold
										//otsu
										setAutoThreshold("Otsu dark");
										getThreshold(otsu, upper);
										print("Finding connected pixels from CP using threshold");
				
										getDimensions(LRwidth, LRheight, LRchannels, LRslices, LRframes); //These are the dimensions of our LR image
										run("Select None");
			
										//Here we create an array that stores the coordinates of a point selection right in the middle of our LR - this is assuming of course
										//that our selection was somewhere near the cell to begin with
										LRCoords = newArray(round((LRLengthPixels/2)+(LRwidth-LRLengthPixels)), round((LRLengthPixels/2)+(LRheight-LRLengthPixels)));
										//[0] is newXCoord, [1] is newYCoord
				
										//We get the grey value at that point selection, and then if the lower threshold of the image
										//is bigger than that value, we set it to that value
										pointValue = (getPixel(LRCoords[0], LRCoords[1])) - 1;
										if(otsu>=pointValue) {
											otsu = pointValue-1;
										}
	
										//print(pointValue);
										//print(otsu);
										//We then make the point on our image and find all connected pixels to that point that have grey values greater than the otsu value
										selectWindow("LR");
										makePoint(LRCoords[0], LRCoords[1]);
										setBackgroundColor(0,0,0);
										run("Find Connected Regions", "allow_diagonal display_image_for_each start_from_point regions_for_values_over="+otsu+" minimum_number_of_points=1 stop_after=1");
										imgNamemask=getTitle();
										rename("Connected");
										selectWindow("Connected");
										run("Invert");
										run("Create Selection");
										roiManager("add");
										print("Connected pixels found");
				
										//We clear outside of our selection in our LR, then find the maxima in that and get the coordinates of the maxima
										//to store these coordinates as the optimal point selection location
				
										//We need to find the optimal location as we want our point selection to be on the brightest pixel on our target cell
										//to ensure that our point selection isn't on a local minima, which whould make finding connected pixels that are 
										//actually from our target cell very error-prone
										
										print("Fine-tuning CP point selection based on mask");
										selectWindow("LR");
										run("Duplicate...", " ");
										selectWindow("LR-1");
										roiManager("Select", 0);
										run("Clear Outside");
										List.setMeasurements;
						
										//Here we get the max value in the image and get out the point selection associated with the maxima using the
										//"find maxima" function			
										topValue = List.getValue("Max");
										run("Select None");
										run("Find Maxima...", "noise=1000 output=[Point Selection]");
										getSelectionCoordinates(tempX, tempY);
										currentMaskValues[3] = tempX[0];
										currentMaskValues[4] = tempY[0];
										selectWindow("LR-1");
										run("Close");
										selectWindow("Connected");
										run("Close");
				
										//Now that we're certain we've got the optimal coordinates, we save our LR image
										selectWindow("LR");
										saveAs("tiff", storageFoldersArray[4]+imageNamesArray[2]);
										selectWindow(imageNamesArray[2]);
										rename("LR");
										run("Select None");
						
										//Here we are finding the same connected regions using the maxima as our point selection and then measuring the area
										//of the connected region to get an initial area size associated with the starting otsu value
										area = getConnectedArea(currentMaskValues[3], currentMaskValues[4], otsu);
										imgNamemask = getTitle();
										
										//Here we check the area output, and if it fits in certain conditions we either proceed with the iterative thresholding or move onto the next cell - more explanation can be found
										//with the corresponding functions for each condition
										
										//If it less than our lower limit, then we check if its touching edges and it not, we keep iterating
										if (area<limits[0]) {
											threshContinue=touchingCheck(imgNamemask, imgNamemask, imgNamemask, 0);
								     	
								     	//If its within our limits, we check if its touching edges, and if it isn't touching any edges we save it, else we keep going
								     	} else if (area<=limits[1] && area>=limits[0]) {
											print("Area is = "+currentLoopValues[0]+"um^2 +/- "+selection[2]+"um^2");
											threshContinue=touchingCheck(imgNamemask, imageNamesArray[0], imageNamesArray[1],1);
											
											//Set mask success to 1
											if(threshContinue == false) {
												currentMaskValues[2] = 1;
											}
			
								     	//If we're above the limits, we continue iterating
								     	} else if (area>limits[1]) {
											threshContinue=true;	
										}
				
										selectWindow(imgNamemask);
										run("Close");
										
										//These variables are changed depending on how many iterations a mask has stabilised for (regardless of whether it fits
										// the TCS +/- the range, as if it stabilized 3 times we keep it), and loopcount ticks up each iteration we go through
										//as we use this value to change the otsu we use for the subsequent iteration 
										maskGenerationVariables = newArray(0,0);
										//[0] is stabilized, [1] is loopcount
	
										imageT = getList("image.titles");
										otherT =  getList("window.titles");
										Array.show(imageT, otherT);
										found = false;
										for(currName = 0; currName < otherT.length; currName++) {
											if(otherT[currName] == "Mask Generation PreChange") {
												found = true;
												currName = 1e99;
											}
										}
										if(found==false) {
											setBatchMode("Exit and Display");
											waitForUser("Mask generation not present before entering while loop");
											setBatchMode(true);
										}
				
										//Here we are proceeding with the iterative thresholding
										while (threshContinue==true) {
							
											maskGenerationVariables[1]++; //Each iteration we increase loopCount, this modifies how we alter the threshold value
						
											//Here we have to constantly check if our Otsu value is above the top and adjust accordingly
											otsu = valueCheck(otsu, topValue);
				
											//This array stores out current otsu value normalised to 255 in index [0], and the next threshold value we'll use in postion [1] based
											//on a formula outlined later
											otsuVariables = newArray(otsu/255, (((otsu/255)*(((area-currentLoopValues[0])/maskGenerationVariables[1])/currentLoopValues[0]))+(otsu/255))*255);
											//[0] is otsuNorm, [1] is nextThresh
		
											//print("nextThresh: ", otsuVariables[1]);
											//print("otsuNorm: ", otsu/255);
											//print("area: ", area);
											//print("TCS: ", currentLoopValues[0]);
											//print("Loop count: ", maskGenerationVariables[1]);
											
											//nextTRaw=((otsuNorm*(((area-TCS[TCSLoops])/loopCount)/TCS[TCSLoops]))+otsuNorm); //Eq for calculating next threshold
			
											//Similarly here to check if our next threshold value is above the top and adjust accordingly
											otsuVariables[1] = valueCheck(otsuVariables[1], topValue);
						
											//Here we get another area from our find connected regions
											selectWindow("LR");
											//print("otsu to check: ", otsuVariables[1]);
											//print("bottom value: ", bottomValue);
											//print("top value: ", topValue);
											areaNew = getConnectedArea(currentMaskValues[3], currentMaskValues[4], otsuVariables[1]);
											imgNamemask = getTitle();
							
											//If we get the same area for 3 iterations we exit the iterative process, so here we count identical areas 
											//(but if for any one instance they are not identical, we rest the counter)
											if (areaNew==area){
												maskGenerationVariables[0]++;
											} else {
												maskGenerationVariables[0]=0;	
											}
				
											//Here, as before, we look at which condition the mask falls into and act appropriately to either continue iterating, 
											//save the mask, or discard the mask
			
											//If we're below the lower limit for area and not stabilised, we check for touching
											if(areaNew<limits[0] && maskGenerationVariables[0]!=3) {
												threshContinue=touchingCheck(imgNamemask, imgNamemask, imgNamemask, 0);
			
											//If we're within limits and not stabilised, we touchingCheck
											} else if (areaNew<=limits[1] && areaNew>=limits[0] && maskGenerationVariables[0]!=3) {	
												print("Area is = "+currentLoopValues[0]+"um^2 +/- "+selection[2]+"um^2");
												threshContinue=touchingCheck(imgNamemask, imageNamesArray[0], imageNamesArray[1],1);
											
											//If we're over the limits and not stabilised, we continue
											} else if (areaNew>limits[1] && maskGenerationVariables[0]!=3) {
												threshContinue=true;
											
											//If we're stabilised, we touching check with type 2
											} else if (maskGenerationVariables[0] == 3) {
												threshContinue = touchingCheck(imgNamemask, imageNamesArray[0], imageNamesArray[1],2);
											}
											
											selectWindow(imgNamemask);
											run("Close");
							
											//print("Old area:" + area);
											//print("Old otsu: "+ otsu);
											//print("Current area: "+ areaNew);
											//print("Current otsu:" + otsuVariables[1]);
											print("Stabilised:" + maskGenerationVariables[0]);
						
											//If we're continuing, then we reset our areas and otsus and go through this again
											if (threshContinue==true) {
												print("Continuing");
												otsu=otsuVariables[1];
												area=areaNew;
											
											//If we're done with this cell, we set maskSuccess to 1 if we've saved a mask
											} else {
												print("Finished");
												if(File.exists(imageNamesArray[0])==1) {
													currentMaskValues[2] = 1;
												}
											}
				
										} //Once the output of threshContinue==false, then we exit the process
										selectWindow("LR");
										run("Close");
									}
										
									//Now that we've attempted mask generation (successful or otherwise) we set this variable to 1	
									currentMaskValues[1]=1;	
				
									//Update and save our TCS analysis table
	
									imageT = getList("image.titles");
									otherT =  getList("window.titles");
									Array.show(imageT, otherT);
									found = false;
									for(currName = 0; currName < otherT.length; currName++) {
										if(otherT[currName] == "Mask Generation PreChange") {
											found = true;
											currName = 1e99;
										}
									}
									if(found==false) {
										setBatchMode("Exit and Display");
										waitForUser("Issue");
										setBatchMode(true);
									}
									
									selectWindow("Mask Generation PreChange");
									for(i1=0; i1<tableLabels.length; i1++) {
										if(i1==0 || i1 == 7) {
											stringValue = currentMaskValues[i1];
											Table.set(tableLabels[i1], i0, stringValue);
										} else {
											Table.set(tableLabels[i1], i0, currentMaskValues[i1]);
										}
									}
									
									//We then close it - as we create a new one for the next cell - otherwise we get issues with writing to things
									//whilst they're open
			
									if (isOpen("Results")) {
										run("Clear Results");
									}
									if(roiManager("count")>0) {
										roiManager("deselect");
										roiManager("delete");
									}
			
									selectWindow(imgName);
									close("\\Others");
	
									imageT = getList("image.titles");
									otherT =  getList("window.titles");
									Array.show(imageT, otherT);
									foundNow = false;
									for(currName = 0; currName < otherT.length; currName++) {
										if(otherT[currName] == "Mask Generation PreChange") {
											foundNow = true;
											currName = 1e99;
										}
									}
									if(foundNow==false && found == true) {
										setBatchMode("Exit and Display");
										waitForUser("Found eralier but not after closing");
										setBatchMode(true);
									}
												
								}
									
							}
					
							selectWindow("Mask Generation PreChange");
							Table.update;
							Table.save(TCSDir+"Mask Generation.csv");
							maskGTitle = Table.title;
							Table.rename(maskGTitle, "Mask Generation PreChange");	
							
							//Set masks generated to 1 for this TCS
							currentLoopValues[1]=1;
							
							//Update and save our TCS analysis table
							selectWindow("TCS Status");
							for(i0=0; i0<TCSColumns.length; i0++) {
								Table.set(TCSColumns[i0], TCSLoops, currentLoopValues[i0]);
							}
							Table.update;
							Table.save(directories[1]+baseName+"/TCS Status.csv");
							Housekeeping();
						}	
					}	
					
					if(isOpen("TCS Status")) {
						Table.rename("TCS Status", "ToBChanged");
					} else if (isOpen("TCS Status.csv")) {
						Table.rename("TCS Status.csv", "ToBChanged");
					}
					
				}
	
				if(isOpen("TobChanged")) {
					selectWindow("ToBChanged");
					run("Close");
				}
			}
		}
	}
}

//////////////////////////Quality Control//////////////////////////////////////////////////////////////////////////////////////////////////////////
//If the user wants to perform quality control on the cells
if(analysisSelections[3] == true) {

	//Set the background color to black otherwise this messes with the clear outside command
	setBackgroundColor(0,0,0);
	
	loopThrough = getFileList(directories[1]);
	Array.show("file list", loopThrough);

	for(i=0; i<loopThrough.length; i++) {
	
		imageNames = newArray(4);
		forUse = loopThrough[i] + ".tif";
	
		proceed = false;
		if(loopThrough[i] != "Images To Use.csv" && loopThrough[i] != "fracLac/") {
			proceed = true;		
		}

		//If a TCS status file exists already
		if(proceed== true && File.exists(directories[1] + baseName + "/TCS Status.csv")==1) {

			//Read it and get out the various TCS
			//values we will need to cycle through during QC
			newSelection = newArray(4);
			open(directories[1] + baseName+"/TCS Status.csv");
			selectWindow("TCS Status.csv");
			numberOfLoops = Table.size;
			newSelection[0] = Table.get("TCS", 0);
			if(numberOfLoops>1) {
				newSelection[3] = abs(Table.get("TCS",1) - Table.get("TCS",0));
			} else {
				newSelection[3] = 0;
			}
			
			print(baseName);
			qcCol = Table.getColumn("QC Checked");
			Array.getStatistics(qcCol, qcMin, qcMax, qcMean, qcSD);
			selectWindow("TCS Status.csv");
			Table.reset("TCS Status.csv");
			
			//If we haven't QC'd all the TCS levels for this datapoint (if we had, qcMean would be 1)
			//then proceed
			//if(qcMean!=1) {
			if(qcVal == 0) {
			
				//Fill the TCS Status table with current TCS status values if they already exist
			
				TCSColumns = newArray("TCS", "Masks Generated", "QC Checked", "Analysed");
				TCSValues = newArray(numberOfLoops*TCSColumns.length);
				//First numberOfLoops indices are TCS, then Masks Generated etc.
				
				TCSResultsRefs = newArray(directories[1]+baseName+"/TCS Status.csv", directories[1]+baseName+"/TCS Status.csv", 
											directories[1]+baseName+"/TCS Status.csv", directories[1]+baseName+"/TCS Status.csv");
				TCSResultsAreStrings = newArray(false, false, false, false);
			
				fillArray(TCSValues, TCSResultsRefs, TCSColumns, TCSResultsAreStrings, true); 
			
				Table.create("TCS Status");
				selectWindow("TCS Status");
				for(i0=0; i0<numberOfLoops; i0++) {
					for(i1=0; i1<TCSColumns.length; i1++) {
						Table.set(TCSColumns[i1], i0, TCSValues[(numberOfLoops*i1)+i0]);
					}
				}
		
				//We QC all masks for all TCSs
				for(TCSLoops=0; TCSLoops<numberOfLoops; TCSLoops++) {

					currentLoopValues = newArray(TCSColumns.length);
					//[0] is TCS, [1] is masks generated, [2] is QC checked, [3] is analysed

					//Set the TCS as the lowest TCS + the increment we want to increase by, X how many times we've increased
					//We set these variables so that TCS is the current TCS to use, and TCSLoops is the number of loops we've been through
					currentLoopValues[0]=newSelection[0]+(newSelection[3]*TCSLoops);
			
					selectWindow("TCS Status");
					for(i0 = 0; i0<Table.size; i0++) {
						if(currentLoopValues[0] == Table.get("TCS", i0)) {
							//Here we fill our currentLoopValues table with the TCSValues data that corresponds to the TCS value
							//we're current processing - this will be a bunch of zeros if we haven't processed anything before
							for(i1=0; i1<TCSColumns.length; i1++) {
								currentLoopValues[i1] = Table.get(TCSColumns[i1], i0);
							}
						}
					}
			
					//If the QC for this TCS hasn't been done in its entirety..
					if(currentLoopValues[2]==0) {
		
						TCSDir=directories[1]+baseName+"/"+"TCS"+currentLoopValues[0]+"/";
				
						storageFoldersArray=newArray(storageFolders.length);
						//[2] is somas, [3] is maskDir, [4] is localregion
						
						for(i0=0; i0<storageFolders.length; i0++) {
							if(i0<3) {
								parentDir=directories[1]+baseName+"/";	
							} else {
								parentDir=TCSDir;	
							}
							storageFoldersArray[i0]=parentDir+storageFolders[i0];
						}
		
						//Our maskName array is just a list of the files in our maskDirFiles folder
						//Fill QC checked with preivous results if they exist
			
						maskDirFiles = getFileList(storageFoldersArray[3]);
			
						valuesToRecord = newArray("Single Cell Check", "Keep", "Traced"); 
			
						analysisRecordInput = newArray(maskDirFiles.length*valuesToRecord.length);
						//First maskDirFiles.length indices are "Analysed", then "Keep", etc
						
						resultsTableRefs = newArray(TCSDir+"QC Checked.csv", TCSDir+"QC Checked.csv", TCSDir+"QC Checked.csv");
						print(TCSDir + "QC Checked.csv");
						print(File.exists(TCSDir + "QC Checked.csv"));
						
						resultsAreStrings = newArray(false, false, false);
			
						fillArray(analysisRecordInput, resultsTableRefs, valuesToRecord, resultsAreStrings, true);
						
						maskName=Array.copy(maskDirFiles);
			
						analysisRecordInput = Array.concat(maskName, analysisRecordInput);
			
						toAdd = newArray("Mask Name");
						tableLabels = Array.concat(toAdd, valuesToRecord);
			
						Table.create("QC Checked");
						selectWindow("QC Checked");
						for(i0=0; i0<maskDirFiles.length; i0++) {
							for(i1=0; i1<tableLabels.length; i1++) {
								if(i1 == 0) {
									stringValue = analysisRecordInput[(maskDirFiles.length*i1)+i0];
									Table.set(tableLabels[i1], i0, stringValue);
								} else {
									Table.set(tableLabels[i1], i0, analysisRecordInput[(maskDirFiles.length*i1)+i0]);
								}
							}
						}
						Table.update;

						fileNames = getFileList(directories[1]+baseName+"/");
						TCSCount = 0;
						TCSVals = newArray(1);
						for(currFile = 0; currFile<fileNames.length; currFile++){
							if(indexOf(fileNames[currFile], "/")>-1 && indexOf(fileNames[currFile], "TCS")>-1) {
								if(TCSCount>0) {
									toAdd = newArray(1);
									TCSVals = Array.concat(TCSVals,toAdd);
								}
								TCSVals[TCSCount] = parseInt(substring(fileNames[currFile], indexOf(fileNames[currFile], "TCS")+3, indexOf(fileNames[currFile], "/")));
								TCSCount++;
							}
						}
						TCSVals = Array.sort(TCSVals);

						prevExists = false;
						nextExists = false;
						for(i0 = 0; i0<TCSVals.length; i0++) {
							if(TCSVals[i0] == parseInt(currentLoopValues[0])) {
								if(i0 > 0) {
									previousTCSDir=directories[1]+baseName+"/TCS"+TCSVals[i0-1]+"/";
									if(File.exists(previousTCSDir)) {
										prevExists = true;
										open(previousTCSDir+"QC Checked.csv");
										selectWindow("QC Checked.csv");
										keptPrevTCS=Table.getColumn("Keep");
										namesPrevTCS=Table.getColumn("Mask Name");
										Table.reset("QC Checked.csv");
									}
								}
								if(i0 < TCSVals.length-1) {
									nextTCSDir=directories[1]+baseName+"/TCS"+TCSVals[i0+1]+"/";
									if(File.exists(nextTCSDir)) {
										nextExists = true;
										open(nextTCSDir+"QC Checked.csv");
										selectWindow("QC Checked.csv");
										keptNextTCS=Table.getColumn("Keep");
										namesNextTCS=Table.getColumn("Mask Name");
										Table.reset("QC Checked.csv");
									}
								}
							}
						}
	
						//Loop through all masks generated in the chosen TCS
						for(i0=0; i0<maskDirFiles.length; i0++) {
			
							currentMaskValues = newArray(4);
							//[0] is mask name, [1] is single cell check, [2] is keep, [3] is trace
					
							for(i1=0; i1<currentMaskValues.length; i1++) {
								currentMaskValues[i1] = analysisRecordInput[(maskDirFiles.length*i1)+i0];
							}
							
							//Here we get out the values for whether the images have been checked for overall issues (singleChecked),
							//Whether we decided to keep the image (keepImage), and whether (if the user wants to trace the cells), the cells
							//have been traced
			
							cutName = substring(maskDirFiles[i0], indexOf(maskDirFiles[i0], "Substack"));
							imageNames = newArray("Local region for " +cutName, "Candidate Soma Mask for " + cutName);
							//[0] is localName, [1] is csmname

							print(maskName[i0]);
							xCoord = parseInt(substring(maskName[i0], indexOf(maskName[i0], "x ")+2, indexOf(maskName[i0], "y")-1));
							yCoord = parseInt(substring(maskName[i0], indexOf(maskName[i0], "y ")+2, indexOf(maskName[i0], ".tif")-1));
							substackLoc = substring(maskName[i0], 0, indexOf(maskName[i0], "x"));
							print(xCoord);
							print(yCoord);
			
							//Here, we look for the kept value of the current coordinates in the previous TCS directory
							//if it was kept previously, set keptPrevTCS to 1, otherwise to 0
							currentKeptPrev = 1;
							currentKeptNext = 0;
							somaName = storageFoldersArray[2]+imageNames[1];
							otherSomaName = storageFoldersArray[2]+imageNames[1];
							if(prevExists ==true || nextExists == true) {
								if(prevExists == true) {
									for(i1 = 0; i1<namesPrevTCS.length; i1++) {
										newxCoord = parseInt(substring(namesPrevTCS[i1], indexOf(namesPrevTCS[i1], "x ")+2, indexOf(namesPrevTCS[i1], "y")-1));
										newyCoord = parseInt(substring(namesPrevTCS[i1], indexOf(namesPrevTCS[i1], "y ")+2, indexOf(namesPrevTCS[i1], ".tif")-1));
										newsubstackLoc = substring(namesPrevTCS[i1], 0, indexOf(namesPrevTCS[i1], "x"));
										if(maskName[i0] == namesPrevTCS[i1]) {
											currentKeptPrev = keptPrevTCS[i1];
											print("found prev", keptPrevTCS[i1]);
											i1 = 1e99;
										} else if(abs(xCoord-newxCoord) <= 10 && abs(yCoord-newyCoord) <= 10 && newsubstackLoc == substackLoc) {
											currentKeptPrev = keptPrevTCS[i1];
											print(maskName[i0]);
											print(namesPrevTCS[i1]);
											otherSomaName = storageFoldersArray[2] + "Candidate Soma Mask for " + substring(namesPrevTCS[i1], indexOf(namesPrevTCS[i1], "Substack"));
											print(otherSomaName);
											i1 = 1e99;
										}
										
									}
									Array.show(keptPrevTCS, namesPrevTCS);
								}
								if(nextExists == true) {
									for(i1 = 0; i1<namesNextTCS.length; i1++) {
										newxCoord = parseInt(substring(namesNextTCS[i1], indexOf(namesNextTCS[i1], "x ")+2, indexOf(namesNextTCS[i1], "y")-1));
										newyCoord = parseInt(substring(namesNextTCS[i1], indexOf(namesNextTCS[i1], "y ")+2, indexOf(namesNextTCS[i1], ".tif")-1));
										newsubstackLoc = substring(namesNextTCS[i1], 0, indexOf(namesNextTCS[i1], "x"));
										if(maskName[i0] == namesNextTCS[i1]) {
											currentKeptNext = keptNextTCS[i1];
											print("found next", keptNextTCS[i1]);
											i1 = 1e99;
										} else if(abs(xCoord-newxCoord) <= 10 && abs(yCoord-newyCoord) <= 10 && newsubstackLoc == substackLoc) {
											print("found match", keptNextTCS[i1]);
											currentKeptNext = keptNextTCS[i1];
											print(maskName[i0]);
											print(namesNextTCS[i1]);
											otherSomaName = storageFoldersArray[2] + "Candidate Soma Mask for " + substring(namesNextTCS[i1], indexOf(namesNextTCS[i1], "Substack"));
											print(otherSomaName);
											i1 = 1e99;
										}
									}
								Array.show(keptNextTCS, namesNextTCS);
								}
							}

							checkMask = false;
							//If we haven't checked the mask yet and it wasn't disregarded previously
							//If it wasn't disregarded before and it was kept next
							//then we don't need to check it
							if(currentMaskValues[1] == 0 && currentKeptPrev == 1) {
								checkMask = true;
								print("Not checked and kept previously");
							}

							//If no soma mask exists and the mask and it wasn't disregarded previously
							if(File.exists(somaName)==0 && File.exists(otherSomaName)==0 && currentKeptPrev==1) {
								checkMask = true;
								print("Need soma mask");
							}
			
							//If it wasn't disregarded before and it was kept next
							//then we don't need to check it
							if(currentKeptPrev == 1 && currentKeptNext == 1) {
								checkMask = false;
								print("Kept previously and next");

								//Set kept to 1
								currentMaskValues[2]=1;

							}

							//If we're tracing processes and we haven't traced the mask and it wasn't disregarded before
							if(selection[4] == 1 && currentMaskValues[3] == 0 && currentKeptPrev == 1) {
								checkMask = true;
								print("Need to trace");
							}
							

							if(checkMask == true) {
			
								print("QC for: ", maskDirFiles[i0]);
								print("Cell no.: ", i0, " / ", maskDirFiles.length);
			
								open(storageFoldersArray[3]+maskDirFiles[i0]);
								currentMask = getTitle();
								tifLess = substring(currentMask, 0, indexOf(currentMask, ".tif"));
								run("Select None");
								run("Auto Threshold", "method=Default");
								
								open(storageFoldersArray[4]+imageNames[0]);
								LRImage = getTitle();
								LRTifLess = substring(LRImage, 0, indexOf(LRImage, ".tif"));
				
								//Here we open the local regions, outline the mask, and ask the user whether to keep the image or not
								if(currentMaskValues[1]==0) {
				
									setBatchMode("Exit and Display");
									selectWindow(currentMask);
									run("Create Selection");
									roiManager("Add");
									
									selectWindow(LRImage);
									roiManager("show all");
									approved = userApproval("Check image for issues", "Soma check", "Keep the image?");
			
									if(approved == true) {
										currentMaskValues[2] = 1;
									} else {
										currentMaskValues[2] = 0;
									}
				
									//The variable indicates we've checked the mask
									currentMaskValues[1]=1; 
			
									roiManager("deselect");
									roiManager("delete");
										
								}
				
								//Here if we decided to keep the mask and we haven't generated a soma mask for it yet, we do that
								//The soma masks we generate aren't TCS specific so we save them in the overall output folder and check for all TCS's whether 
								//we have a soma mask for the coordinates
								//We check whether our soma mask has been created by looking in the directory where we would have saved it
								if(currentMaskValues[2]==1 && File.exists(somaName)==0) {
				
									selectWindow(currentMask);
									run("Create Selection");
									Roi.setStrokeColor("red");
									roiManager("Add");
				
									//Soma mask generation is done below - auto thresholding, and clearing outside the cell mask etc. etc.
									selectWindow(LRImage);
									run("Select None");
									run("Duplicate...", " ");
									selectWindow(LRTifLess+"-1.tif");
									roiManager("Select", 0);
									run("Clear Outside");
									run("Select None");
									selectWindow(LRTifLess+"-1.tif");
									run("Auto Threshold", "method=Intermodes  white");
									logString = getInfo("log");
									intermodesIndex = lastIndexOf(logString, "Intermodes");
									
									if(intermodesIndex!=-1) {
										print("Intermodes didn't work");
										run("Auto Threshold", "method=Otsu  white");
										selectWindow("Log");
										run("Close");
									}
									
									
									run("Invert");
									run("Open");
									run("Watershed");
			
									for(i1=0; i1<2; i1++) {
										run("Erode");
									}
			
									for(i1=0; i1<3; i1++) {
										run("Dilate");
									}
			
									//Here we check how many particles have been left after this process
									run("Auto Threshold", "method=Default");
									run("Analyze Particles...", "size=20-Infinity circularity=0.60-1.00 show=Masks display clear");
									run("Clear Results");
									run("Set Measurements...", "area mean redirect=None decimal=2");
									selectWindow("Mask of " + LRTifLess + "-1.tif");
									run("Measure");
									
									getStatistics(imageArea);
		
									if(getResult("Mean")==0 || getResult("Mean")==255) {
										keep = false;
										somaArea = imageArea;
									} else {
										run("Create Selection");
										run("Clear Results");
										run("Measure");
										somaArea = getResult("Area");
										run("Select None");
									}
				
									//If only one particle is present
									if(somaArea!= imageArea && nResults==1) {
									
										selectWindow("Mask of " + LRTifLess + "-1.tif");
										rename(imageNames[1]);
										run("Create Selection");
										roiManager("Add");
										selectWindow(LRImage);
										roiManager("select", 1);
										roiManager("Show All");
										keep = userApproval("Check image soma mask", "Soma check", "Keep the soma mask?");
			
										if(keep == true) {
											
											selectWindow(imageNames[1]);
											saveAs("tiff", somaName);
											run("Close");
			
										}
			
										roiManager("select", 1);
										roiManager("delete");
				
									//If we have more or less than 1 particle, we have to draw our own soma mask and we do that
									//Could incorporate this with the code above as it does very similar things?
									} 
									
									if (keep==false || somaArea == imageArea) {
				
										waitForUser("Need to draw manual soma mask");
										selectWindow(LRImage);
										roiManager("Show All");
			
										for(i1=0; i1<3; i1++) {
											run("In [+]");
										}
			
										run("Scale to Fit");
										setTool("polygon");
										setBatchMode("Exit and Display");
										waitForUser("Draw appropriate soma mask");
										roiManager("add");
										roiManager("select", 1);
										run("Create Mask");
										selectWindow("Mask");
										saveAs("tiff", somaName);
										run("Close");
										
									}
			
									selectWindow(LRTifLess+"-1.tif");
									run("Close");
									roiManager("deselect");
									roiManager("delete");
								}
				
								//Here if we want to trace cells, and haven't traced the cell in questions and we've deicded to keep it, then we do just that
								if(selection[4]==1 && currentMaskValues[3]==0 && currentMaskValues[2]==1) {
				
									selectWindow(currentMask);
									run("Invert");
									run("Create Selection");
									roiManager("Add");
									selectWindow(currentMask);
									run("Close");
									
									selectWindow(LRImage);
									roiManager("select", 0);
									roiManager("Show All");
					
									setTool("polygon");
									setBatchMode("Exit and Display");
									waitForUser("Draw around any missing processes, add these to roi manager");
				
									//Here we combine all the traces into a single ROI and use this to create a new mask from the local region
									if((roiManager("count"))>1) {
										roiManager("deselect");
										roiManager("Combine");
										roiManager("deselect");
										roiManager("delete");
										roiManager("add");
									} else {	
										roiManager("deselect");	
									}
										
									run("Select None");
									selectWindow(LRImage);
									roiManager("select", 0);
									run("Clear Outside");
									run("Fill", "slice");
									run("Select None");
									run("Invert");
									run("Auto Threshold", "method=Default");
									run("Invert");
									selectWindow(LRImage);
									saveAs("tiff", storageFoldersArray[3]+maskDirFiles[i0]);
									run("Close");
				
									//This indicates we've traced the image
									currentMaskValues[3]=1;
									
								}
				
								Housekeeping();
							
							} else {
								currentMaskValues[1]=1; 
							}

							//Update and save our TCS analysis table
							selectWindow("QC Checked");
							for(i1=0; i1<tableLabels.length; i1++) {
								if(i1==0) {
									stringValue = currentMaskValues[i1];
									Table.set(tableLabels[i1], i0, stringValue);
								} else {
									Table.set(tableLabels[i1], i0, currentMaskValues[i1]);
								}
							}
								
			
							Housekeeping();

							
						}
			
						selectWindow("QC Checked");
						Table.save(TCSDir+"QC Checked.csv");
						newName = Table.title;
						Table.rename(newName, "QC Checked");
						Table.reset("QC Checked");
						Table.update;
						print("saved at: ", TCSDir + "QC Checked.csv");
				
						//Here we set that we've finished QC for the particular TCS
						currentLoopValues[2] = 1;
			
						//Update and save our TCS analysis table
						selectWindow("TCS Status");
						for(i0=0; i0<TCSColumns.length; i0++) {
							Table.set(TCSColumns[i0], TCSLoops, currentLoopValues[i0]);
						}
		
						Table.update;
						Housekeeping();
			
					}
						
				}
				
				selectWindow("TCS Status");
				Table.update;
				Table.save(directories[1]+baseName+"/TCS Status.csv");
				currtitle = Table.title;
				Table.rename(currtitle, "TCS Status");
					
			}
		} else if (proceed == false) {
			print(baseName, " used wrong objective");
		}
	}
}

if(analysisSelections[4] == true) {
	/////////////////////Analysis////////////////////////////////////////////////////////////////////////////

	//Set the background color to black otherwise this messes with the clear outside command
	setBackgroundColor(0,0,0);
		
	//Set the path to where we copy our analysed cells to so we can run a fractal analysis on this folder in 
	//batch at a later timepoint - if this directory doesn't exist, make it
	fracLacPath = directories[1]+"fracLac/";
	
	if(File.exists(fracLacPath)==0) {
		File.makeDirectory(fracLacPath);
	}
	
	loopThrough = getFileList(directories[1]);
	Array.show("file list", loopThrough);

	for(i=0; i<loopThrough.length; i++) {
	
		imageNames = newArray(4);
		forUse = loopThrough[i] + ".tif";
	
		proceed = false;
		if(loopThrough[i] != "Images To Use.csv" && loopThrough[i] != "fracLac/") {
			proceed = true;
		}

		//If a TCS status file exists already
		if(proceed== true && File.exists(directories[1] + baseName + "/TCS Status.csv")==1) {
	
			//Read it and get out the various TCS
			//values we will need to cycle through during QC
			newSelection = newArray(4);
			open(directories[1] + baseName+"/TCS Status.csv");
			selectWindow("TCS Status.csv");
			numberOfLoops = Table.size;
			newSelection[0] = Table.get("TCS", 0);
			if(numberOfLoops>1) {
				newSelection[3] = abs(Table.get("TCS",1) - Table.get("TCS",0));
			} else {
				newSelection[3] = 0;
			}

			//Get out the average value of whether we've analysed each TCS or not (where 1 = true and 0 = false)
			//so that if our mean value isn't 1, it means we've not analysed all TCS values, else we have
			selectWindow("TCS Status.csv");
			aCol = Table.getColumn("Analysed");
			Array.getStatistics(aCol, aMin, aMax, aMean, aSD);
			run("Clear Results");
			selectWindow("TCS Status.csv");
			Table.reset("TCS Status.csv");
			
			//If we haven't analysed all TCS levels already
			if(aMean!=1) {
			//if(aMean != 1 || qcVal == 0) {
				
				//Clear results table just to be sure
				run("Clear Results");
				
				//Fill TCS Status table with its existing/previous values
				TCSColumns = newArray("TCS", "Masks Generated", "QC Checked", "Analysed");
				TCSValues = newArray(numberOfLoops*TCSColumns.length);
				
				//First numberOfLoops indices are TCS, then Masks Generated etc.
				TCSResultsRefs = newArray(directories[1]+baseName+"/TCS Status.csv", directories[1]+baseName+"/TCS Status.csv", 
											directories[1]+baseName+"/TCS Status.csv", directories[1]+baseName+"/TCS Status.csv");
				TCSResultsAreStrings = newArray(false, false, false, false);
			
				fillArray(TCSValues, TCSResultsRefs, TCSColumns, TCSResultsAreStrings, true); 
				
				Table.create("TCS Status");
				selectWindow("TCS Status");
				for(i0=0; i0<numberOfLoops; i0++) {
					for(i1=0; i1<TCSColumns.length; i1++) {
						Table.set(TCSColumns[i1], i0, TCSValues[(numberOfLoops*i1)+i0]);
					}
				}

				print(loopThrough[i]);
				
				//Loop through the number of TCS loops we need to do
				for(TCSLoops=0; TCSLoops<numberOfLoops; TCSLoops++) {

					currentLoopValues = newArray(TCSColumns.length);
					//[0] is TCS, [1] is masks generated, [2] is QC checked, [3] is analysed

					//Set the TCS as the lowest TCS + the increment we want to increase by, X how many times we've increased
					//We set these variables so that TCS is the current TCS to use, and TCSLoops is the number of loops we've been through
					currentLoopValues[0]=newSelection[0]+(newSelection[3]*TCSLoops);
			
					selectWindow("TCS Status");
					for(i0 = 0; i0<Table.size; i0++) {
						if(currentLoopValues[0] == Table.get("TCS", i0)) {
							//Here we fill our currentLoopValues table with the TCSValues data that corresponds to the TCS value
							//we're current processing - this will be a bunch of zeros if we haven't processed anything before
							for(i1=0; i1<TCSColumns.length; i1++) {
								currentLoopValues[i1] = Table.get(TCSColumns[i1], i0);
							}
						}
					}
									
					//if(currentLoopValues[2] == 1 && currentLoopValues[3] == 0) {
					if(currentLoopValues[2] == 1) {

						//Set the directory for the current TCS value
						TCSDir=directories[1]+baseName+"/"+"TCS"+currentLoopValues[0]+"/";
				
						//Store the directories we'll refer to for the listed properties of the cells and fill it
						storageFoldersArray=newArray(storageFolders.length);
						//[0] is cell coords, [1] is cell coordinates masks, [2] is somas, [3] is maskDir, [4] is localregion
						//[5] is results
						
						for(i0=0; i0<storageFolders.length; i0++) {
							if(i0<3) {
								parentDir=directories[1]+baseName+"/";	
							} else {
								parentDir=TCSDir;	
							}
							storageFoldersArray[i0]=parentDir+storageFolders[i0];
						}
				
			
						//If the results folder doesn't exist yet, make it
						if(File.exists(storageFoldersArray[5])==false) {
								File.makeDirectory(storageFoldersArray[5]);
						}

						somaFiles = getFileList(storageFoldersArray[2]);
			
						//Get the list of cell masks present
						maskDirFiles = getFileList(storageFoldersArray[3]);
			
						//oldParams is a list of the parameters we measure using the normal measurements function in
						//imageJ
						oldParams = newArray("Analysed", "Perimeter", "Cell Spread", "Eccentricity", 
													"Roundness", "Soma Size", "Mask Size"); 

						//skelNames is a list of the parameters we measure on a skeletonised image in imageJ
						skelNames = newArray("# Branches", "# Junctions", "# End-point voxels", "# Junction voxels", 
						"# Slab voxels", "Average Branch Length", "# Triple points", "# Quadruple points", 
						"Maximum Branch Length", "Longest Shortest Path", "SkelArea");

						valuesToRecord = Array.concat(oldParams, skelNames);
			
						analysisRecordInput = newArray(maskDirFiles.length*valuesToRecord.length);
						//First maskDirFiles.length indices are "Analysed", then "Keep", etc

						//Fill analysisRecordInput appropriately
						resultsTableRefs = newArray(valuesToRecord.length);
						resultsAreStrings = newArray(valuesToRecord.length);
						for(i0 = 0; i0<valuesToRecord.length; i0++) {
							resultsTableRefs[i0] = TCSDir + "Cell Parameters.csv";
							resultsAreStrings[i0] = false;
						}
			
						fillArray(analysisRecordInput, resultsTableRefs, valuesToRecord, resultsAreStrings, true);

						//Fill an array of whether each cell passed the QC control or not
						imagesKept = newArray(maskDirFiles.length);
						fillArray(imagesKept, TCSDir+"QC Checked.csv", "Keep", true, false);
			
						//Get values for the substack location, experiment (animal and timepoint), as well as the TCS value,
						//cellName, and whether we used the wrong Objective settings, add these to the analysisRecordInput
						//array
						substackLoc = newArray(maskDirFiles.length);
						for(i0 = 0; i0<substackLoc.length; i0++) {
							substackLoc[i0] = substring(maskDirFiles[i0], indexOf(toLowerCase(maskDirFiles[i0]), "substack"), indexOf(maskDirFiles[i0], "x")); 
						}
						
						experimentName = newArray(maskDirFiles.length);
						cellName = newArray(maskDirFiles.length);
						for(i0=0; i0<maskDirFiles.length; i0++) {
							experimentName[i0] = baseName;
							cellName[i0] = substring(maskDirFiles[i0], indexOf(maskDirFiles[i0], "x"), indexOf(maskDirFiles[i0], ".tif")); 
						}
						
						TCSForParameters=newArray(maskDirFiles.length);
						Array.fill(TCSForParameters, currentLoopValues[0]);
						//cellName=Array.copy(maskDirFiles);
	
						wrongObjArray = newArray(maskDirFiles.length);
						fillArray(wrongObjArray, TCSDir+"Cell Parameters.csv", "Wrong Objective", false, false);
						
						analysisRecordInput = Array.concat(analysisRecordInput, substackLoc);
						analysisRecordInput = Array.concat(analysisRecordInput, experimentName);
						analysisRecordInput = Array.concat(analysisRecordInput, TCSForParameters);
						analysisRecordInput = Array.concat(analysisRecordInput, cellName);
						analysisRecordInput = Array.concat(analysisRecordInput, wrongObjArray);
			
						//Fill our cell parameters with all this concatenated data and the names for it all
						toAdd = newArray("Stack Position", "Experiment Name", "TCS", "Cell Name", "Wrong Objective");
						tableLabels = Array.concat(valuesToRecord, toAdd);
			
						Table.create("Cell Parameters");
						selectWindow("Cell Parameters");

						for(i0=0; i0<maskDirFiles.length; i0++) {
							for(i1=0; i1<tableLabels.length; i1++) {
									if(i1 == 18 || i1 == 19 || i1 == 21) {
										stringValue = analysisRecordInput[(maskDirFiles.length*i1)+i0];
										Table.set(tableLabels[i1], i0, stringValue);
									}
									Table.set(tableLabels[i1], i0, analysisRecordInput[(maskDirFiles.length*i1)+i0]);
							}
						}
						
						//Loop through the input files
						for(i0=0; i0<maskDirFiles.length; i0++) {
				
							currentMaskValues = newArray(7);
							//[0] is analysed, [1] is perimeter, [2] is cell spread, [3] is eccentricity, [4] is roundness,
							//[5] is soma size, [6] is mask area
					
							//Fill with existing values
							for(i1=0; i1<currentMaskValues.length; i1++) {
								currentMaskValues[i1] = analysisRecordInput[(maskDirFiles.length*i1)+i0];
							}
			
							//If we haven't analysed the image yet and we're keeping it (acc. to QC), then we enter here
							//if(imagesKept[i0] == 1 && currentMaskValues[0] == 0) {
							if(imagesKept[i0] == 1) {

								print(maskDirFiles[i0]);
								
								//If we haven't already copied the cell to the fracLac folder, do so
								if(File.exists(fracLacPath + "TCS" + toString(currentLoopValues[0]) +  imageNames[0] + maskDirFiles[i0]) == 0) {
									File.copy(storageFoldersArray[3] + maskDirFiles[i0], fracLacPath + "TCS" + toString(currentLoopValues[0]) +  imageNames[0] + maskDirFiles[i0]);
								}
								
								//Get out our skeleton values
								open(storageFoldersArray[3] + maskDirFiles[i0]);
								getDimensions(maskWidth, maskHeight, maskChannels, maskSlices, maskFrames);

								//Set calibration to pixels
								run("Properties...", "channels="+maskChannels+" slices="+maskSlices+" frames="+maskFrames+" unit=pixels pixel_width=1 pixel_height=1 voxel_depth=1");
								rename("Test");

								run("Clear Results");
								
								//Skeletonise the image then get out the measures associated with the skelNames array from earlier
								run("Duplicate...", " ");
								run("Invert");
								run("Skeletonize (2D/3D)");
								run("Analyze Skeleton (2D/3D)", "prune=[shortest branch] calculate");
								
								//If we're getting out length, we measure the number of pixels in the skeleton
								storeValues = newArray(skelNames.length);
								for(i1 = 0; i1< skelNames.length; i1++) {
									if(i1 < skelNames.length-1) {
									storeValues[i1] = getResult(skelNames[i1], 0);
									} else {
										selectWindow("Test-1");
										run("Invert");
										run("Create Selection");
										getRawStatistics(nPixels);
										storeValues[i1] = nPixels;
										run("Select None");
									}
								}
								run("Clear Results");

								//Close images we don't need anymore
								toClose = newArray("Longest shortest paths", "Tagged skeleton", "Test-1");
								for(i1 = 0; i1< toClose.length; i1++) {
									if(isOpen(toClose[i1])==1) {
									selectWindow(toClose[i1]);
									run("Close");
									}
								}
								
								//Select our non skeletonised image, get its perim, circul, AR, and area
								selectWindow("Test");
								rename(maskDirFiles[i0]);
								run("Create Selection");
								roiManager("add");
								List.setMeasurements;
			
								resultsStrings = newArray("Perim.", "Circ.", "AR", "Area");
								currentLoopIndices = newArray(1,4,3,6);
			
								for(i1=0; i1<resultsStrings.length; i1++) {
									currentMaskValues[(currentLoopIndices[i1])] = List.getValue(resultsStrings[i1]);
								}
			
								run("Select None");
								run("Invert");
								run("Points from Mask");
					
								//This bit is used to calculate the leftmost, rightmost, bottommost, and topmost parts of the mask
								//We then calculate the average distance between the centre of mass of the mask and these points
								//for our measure of cell spread
			
								//Get the selection coordinates of our mask
								getSelectionCoordinates(x, y);
			
								Array.getStatistics(x, xMin, xMax, mean, stdDev);
								Array.getStatistics(y, yMin, yMax, mean, stdDev);
			
								valuesToMatch = newArray(xMax, xMin, yMax, yMin);
			
								xAndYPoints = newArray(xMax, 0, xMin, 0, 0, yMax, 0, yMin);
								//[0] and [1] are highest x with y (rightmost), [2] and [3] are lowest x with y (leftmost), 
								//[4] and [5] are x and highest y (topmost) [7] and [8] are x with lowest y (bottommost)
			
								for(i1=0; i1<valuesToMatch.length; i1++) {	
									associatedValues = newArray(1);
									arrayToConcat = newArray(1);
									for(i2=0; i2<x.length; i2++) {
										matched = false;
										if(i1<2) {
											if(x[i2] == valuesToMatch[i1]) {
												associatedValues[associatedValues.length-1] = y[i2];
												matched = true;
											}
										} else {
											if(y[i2] == valuesToMatch[i1]) {
												associatedValues[associatedValues.length-1] = x[i2];
												matched = true;
											}
										}
										if(matched == true){
											//setBatchMode("exit and display");
											//Array.show("test", associatedValues);
											//waitForUser("");
											associatedValues = Array.concat(associatedValues, arrayToConcat);
										}	
									}
			
									finalList = newArray(1);
									finalList = removeZeros(associatedValues, finalList);
									
									Array.getStatistics(finalList, asMin, asMax, asMean, asStdDev);
			
									if(i1<2) {
										xAndYPoints[(i1*2)+1] = round(asMean);
									} else {
										xAndYPoints[(i1*2)] = round(asMean);
									}
								}
							
								open(storageFoldersArray[4]+"Local region for "+ substring(maskDirFiles[i0], indexOf(maskDirFiles[i0],"Substack")));
								LRImage = getTitle();
								selectWindow(LRImage);
								getDimensions(LRwidth, LRheight, LRchannels, LRslices, LRframes);
					
								//Calibrate to pixels so we can get the right values when we make points on our image as the previously generated variables are all
								//calibrated in pixels
								selectWindow(LRImage);
								run("Properties...", "channels="+LRchannels+" slices="+LRslices+" frames="+LRframes+" unit=pixels pixel_width=1 pixel_height=1 voxel_depth=1");
								roiManager("select", 0);
								List.setMeasurements;
			
								resultsStrings = newArray("XM", "YM");
								centresOfMass = newArray(2);
			
								for(i1=0; i1<resultsStrings.length; i1++) {
									centresOfMass[i1] = List.getValue(resultsStrings[i1]);
								}
			
								run("Select None");
								distances = newArray(4);
								//[0] is distance to the right, [1] is to the left, [2] is the top, [3] is the bottom
			
								for(i1=0; i1<4; i1++) {
									xToCheck = xAndYPoints[(i1*2)];
									yToCheck = xAndYPoints[(i1*2)+1];
			
									xDistance = abs(xToCheck-centresOfMass[0]);
									yDistance = abs(yToCheck-centresOfMass[1]);
			
									distances[i1] = sqrt((pow(xDistance,2) + pow(yDistance,2)));
			
									makeLine(centresOfMass[0], centresOfMass[1],  xAndYPoints[(i1*2)], xAndYPoints[(i1*2)+1]);
									Roi.setStrokeColor("red");
									roiManager("add");
								}
			
								//Store the average distance from the centre of mass to the xtremeties
								Array.getStatistics(distances, disMin, disMax, disMean, disStdDev);
								currentMaskValues[2] = disMean;
								
								run("Select None");
					
								//This is saving an image to show where the lines and centre are
								selectWindow(LRImage);
								run("Properties...", "channels="+LRchannels+" slices="+LRslices+" frames="+LRframes+" unit=um pixel_width="+iniTextValuesMicrons[0]+" pixel_height="+iniTextValuesMicrons[1]+" voxel_depth="+iniTextValuesMicrons[2]+"");
								roiManager("show all without labels");
								run("Flatten");
								selectWindow(LRImage);
								saveAs("tiff", storageFoldersArray[5]+"Extrema for "+ substring(maskDirFiles[i0], indexOf(toLowerCase(maskDirFiles[i0]), "substack")));
					
								//Here we open the soma mask for the cell in question, and get its size
								oldxCoord = parseInt(substring(maskDirFiles[i0], indexOf(maskDirFiles[i0], "x ")+2, indexOf(maskDirFiles[i0], "y")-1));
								oldyCoord = parseInt(substring(maskDirFiles[i0], indexOf(maskDirFiles[i0], "y ")+2, indexOf(maskDirFiles[i0], ".tif")-1));
								oldSubstackLoc = substring(maskDirFiles[i0], indexOf(maskDirFiles[i0], "Substack"), indexOf(maskDirFiles[i0], "x"));
								adjustBy = newArray(0,0);
								if(File.exists(storageFoldersArray[2]+"Candidate Soma Mask for "+ substring(maskDirFiles[i0], indexOf(toLowerCase(maskDirFiles[i0]), "substack")))==0) {
									//waitForUser("doesn't exist");
									for(i1 = 0; i1<somaFiles.length; i1++) {
										newxCoord = parseInt(substring(somaFiles[i1], indexOf(somaFiles[i1], "x ")+2, indexOf(somaFiles[i1], "y")-1));
										newyCoord = parseInt(substring(somaFiles[i1], indexOf(somaFiles[i1], "y ")+2, indexOf(somaFiles[i1], ".tif")-1));
										newsubstackLoc = substring(somaFiles[i1], indexOf(somaFiles[i1], "Substack"), indexOf(somaFiles[i1], "x"));
										if(abs(oldxCoord-newxCoord) <= 10 && abs(oldyCoord-newyCoord) <= 10 && newsubstackLoc == oldSubstackLoc) {
											adjustBy[0] = newxCoord-oldxCoord;
											adjustBy[1] = newyCoord-oldyCoord;
											//print(maskDirFiles[i0]);
											//print(somaFiles[i1]);
											open(storageFoldersArray[2] + somaFiles[i1]);
										}
									}
								} else {
									open(storageFoldersArray[2]+"Candidate Soma Mask for "+ substring(maskDirFiles[i0], indexOf(toLowerCase(maskDirFiles[i0]), "substack")));
								}
								rename("Soma");
								run("Properties...", "channels="+LRchannels+" slices="+LRslices+" frames="+LRframes+" unit=pixels pixel_width=1 pixel_height=1 voxel_depth=1");
								run("Create Selection");
								List.setMeasurements;
			
								resultsToGet = newArray("Area", "XM", "YM");
								resultsToOutput = newArray(3);
								//[0] is soma area, [1] is xMass, [2] is yMass
		
								for(i1=0; i1<3; i1++) {
									resultsToOutput[i1] = List.getValue(resultsToGet[i1]);
									//print(resultsToOutput[i1]);
								}
		
								currentMaskValues[5] = resultsToOutput[0];
					
								//We then find the centre of mass of the soma, and the radius of the soma (on average)
								//so that we can use the point and the radius to calculate a sholl analysis on the cell masks
								//starting from the edge of the soma
								//startradius=sqrt((currentMaskValues[5]*(iniTextValuesMicrons[1]/PI);
		
								startradius=sqrt((currentMaskValues[5]*pow(iniTextValuesMicrons[1], 2))/PI);
					
								//Here we run the sholl analysis using the point, the radius, and ending at the ending radius of the local region
								//We also output all the semi-log, log-log, linear, and linear-norm plots of the number of intersections at various distances
								//The normalisation is done using the area of the mask
								//Results are saved in the results folder
								roiManager("show none");
			
								selectWindow(maskDirFiles[i0]);
								run("Select None");
								makePoint(resultsToOutput[1]+adjustBy[0], resultsToOutput[2]+adjustBy[1]);

								//if(adjustBy[0] != 0 || adjustBy[1] != 0) {
									//print(resultsToOutput[1], resultsToOutput[2]);
									//print(adjustBy[0], adjustBy[1]);
									//setBatchMode("exit and display");
									//waitForUser("");
									//setBatchMode(true);
								//}
								
								run("Properties...", "channels="+maskChannels+" slices="+maskSlices+" frames="+maskFrames+" unit=um pixel_width="+iniTextValuesMicrons[0]+" pixel_height="+iniTextValuesMicrons[1]+" voxel_depth="+iniTextValuesMicrons[2]+"");
								run("Sholl Analysis...", "starting="+startradius+" ending="+maskGenerationArray[3]+" radius_step=0 enclosing=1 #_primary=0 infer fit linear polynomial=[Best fitting degree] linear-norm semi-log log-log normalizer=Area create save directory=["+storageFoldersArray[5]+"] do");

								saveAs("Results", storageFoldersArray[5]+substring(maskDirFiles[i0], indexOf(toLowerCase(maskDirFiles[i0]), "substack"), indexOf(maskDirFiles[i0], ".tif")) + ".csv");
								selectWindow(substring(maskDirFiles[i0], indexOf(toLowerCase(maskDirFiles[i0]), "substack"), indexOf(maskDirFiles[i0], ".tif")) + ".csv");
								run("Close");
								run("Clear Results");
			
								Housekeeping();
								
								//Set the fact we've analysed the cell to 1 (true)
								currentMaskValues[0] = 1;

								//Concatenate the measured values together, with the info about the cell
								newValsOne = Array.concat(currentMaskValues, storeValues);
								toAdd = newArray(substackLoc[i0], baseName, currentLoopValues[0], cellName[i0], wrongObjArray[i0]);
								newVals = Array.concat(newValsOne, toAdd);
								
								//Here we update and save our cell parameters table
								selectWindow("Cell Parameters");
								for(i1 = 0; i1<tableLabels.length; i1++) {
									if(i1 == 18 || i1 == 19 || i1 == 21) {
										stringValue = newVals[i1];
										Table.set(tableLabels[i1], i0, stringValue);
									} else if (i1==1 || i1==2 || i1 == 12 || i1 == 15 || i1 == 16) {
										numberToStore = newVals[i1] * iniTextValuesMicrons[0];
										Table.set(tableLabels[i1], i0, numberToStore);
									} else if (i1==5 || i1==6 || i1 == 17) {
										numberToStore = newVals[i1] * pow(iniTextValuesMicrons[0],2);
										Table.set(tableLabels[i1], i0, numberToStore);
									} else {
										Table.set(tableLabels[i1], i0, newVals[i1]);
									}
								}
		
								Table.set("Wrong Objective", i0, iniTextValuesMicrons[5]);
								Table.update;
							
							}	
						
						}	
		
						//Indicate that this TCS has been analysed
						currentLoopValues[3] = 1;
			
						//Update and save our TCS analysis table
						selectWindow("TCS Status");
						for(i0=0; i0<TCSColumns.length; i0++) {
							Table.set(TCSColumns[i0], TCSLoops, currentLoopValues[i0]);
						}
		
						selectWindow("Cell Parameters");
						Table.update;
						Table.save(TCSDir+"Cell Parameters.csv");
						currParam = Table.title;
						Table.rename(currParam, "Cell Parameters");
						
					}
			
				}

				selectWindow("TCS Status");
				Table.save(directories[1]+baseName+"/TCS Status.csv");
				currTCSTitle = Table.title;
				Table.rename(currTCSTitle, "TCS Status");
			
			}
		}
	}
}
print("Morphological analysis complete");