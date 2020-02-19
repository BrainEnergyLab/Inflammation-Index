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
	for(i=0; i<iniFileList.length; i++) {
		if(endsWith(toLowerCase(iniFileList[i]), "ini")) {
			//Create a variable that tells us which ini file to open
			iniToOpen = iniFolder + iniFileList[i]; 
			i = iniFileList.length;
		}
	}
	
	//This is an array of codes that refer to specific numbers in unicode, 
	//grabbed from: https://unicode-table.com/en/ - The characters these codes 
	//refer to are characters that we can use to iden1385tify where in the ini file 
	//the calibration information that we want to grab is stored since these are 
	//the codes for all the numerical digits 0-9
	uniCodes = newArray(46, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57);
	
	//This is an array with the strings that come just before the information we 
	//want to retrieve from the ini file. We want to get the x, y, and z pixel 
	//sizes, as well as the no of planes and the frames per plane of the image
	iniTextStringsPre = newArray("x.pixel.sz = ",
								  "y.pixel.sz = ",
								  "z.spacing = ",
								  "no.of.planes = ",
								  "frames.per.plane = ");
	
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

		if(i == iniTextStringsPre.length-1) {
			realString = substring(iniText, startPoint);
		} else {
			
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
					print(newString);
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
		}
		iniTextValuesMicrons[i] = parseFloat(realString);
	}
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
		if(false) {
		run("MultiStackReg", "stack_1=[new] action_1=Align file_1=[]  stack_2=None action_2=Ignore file_2=[] transformation=[Translation]");
		run("MultiStackReg", "stack_1=[new] action_1=Align file_1=[]  stack_2=None action_2=Ignore file_2=[] transformation=[Affine]");
		}
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

//Function to incorporate the reordering of Z slices in registration. Takes an 
//inputImage, then rearranges slices that are maximally layersToTest apart 
//before renaming it toRename
function zSpaceCorrection(inputImage, layersToTest, toRename) {

	//Array to store the name of output images from the spacing correction to 
	//close
	toClose = newArray("Warped", "Image", inputImage);

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



////////////////////////////////////////////////////////////////////////////////
//////////////////////// Main user input sections //////////////////////////////
////////////////////////////////////////////////////////////////////////////////

//A string array that contains the functionality choices that the user has wrt. 
//running this macro
stringChoices = newArray("Preprocess morphology stacks and save them", "QC Motion Processing",
"Mark cell positions", "Generate masks for cells", 
"Quality control masks", "Analyse masks");

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
//Get the parent 2P directory i.e. where all the raw 2P images are stored
directoryName = getDirectory("Choose the image storage directory");
	
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
	//process the previously selected frames, or both - basically the second choice processes
	//frames selected when the first choice is chosen
	if(manCorrect == true) {
		Dialog.create("Manual Correction Options");
		Dialog.addCheckbox("Manually select frames?", true)
		Dialog.addCheckbox("Process images where frames have been previously selected?", true);
		Dialog.show();
		frameSelect = Dialog.getCheckbox();
		frameProcess = Dialog.getCheckbox();
	} else {
		frameSelect = false;
		frameProcess = false;
	}

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

	Housekeeping();

	//Check to retrieve information about any images that have already been processed
	//If this file exists, get the info out
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
		ignoreFlag = Table.getColumn("Ignore");
		for(currImage = 0; currImage<manualFlag.length; currImage++) {
			if(manualFlag[currImage]==0 || ignoreFlag[currImage] == 1) {
				imageName[currImage] = 0;
			}
		}
		forStorage = newArray(1);
		forStorage = removeZeros(imageName, forStorage);

		//Get the file name of the manually flagged images
		if(forStorage.length != 0) {
			ArrayConc = Array.copy(forStorage);
			for(currImage = 0; currImage<forStorage.length; currImage++) {
				ArrayConc[currImage] = File.getName(forStorage[currImage]);
			}
		}

		selectWindow("Images to Use");
		run("Close");
		
	}

	//If the user wants to manually process images and the user chose to select frames
	if(manCorrect == true && frameSelect == true) {
		
		//Loop through the files in the manually flagged images array
		for(i=0; i<ArrayConc.length; i++) {
			//If we haven't already selected frames for the current image and it is in our input folder
			if(File.exists(directories[1] + ArrayConc[i] + "/Slices To Use.csv")==0 && File.exists(directories[0] + ArrayConc[i] + ".tif")==1) {

				print("Manually selecting frames");
				forInfo = ArrayConc[i] + ".tif";
						
				//Get out the animal name info - animal and 
				//timepoint that we store at index [0] in the array, the timepoint only at [1]
				//the animal only at [2] and finally the file name without the .tif on the end
				//that we store at [3]
				imageNames = newArray(4);
				getAnimalTimepointInfo(imageNames, forInfo);
				open(directories[0] + forInfo);
					
				print("Preprocessing ", imageNames[0]); 

				//Array to store the values we need to calibrate our image with
				iniTextValuesMicrons = newArray(5);
				//Index 0 is xPxlSz, then yPxlSz, zPxlSz, ZperT, FperZ

				getIniData(directoryName, iniTextValuesMicrons);

				//Calculate the number of timepoints in the image, and also a value framesReorder that we pass in 
				//to reorganise our slices as we want
				timepoints = (iniTextValuesMicrons[3] * iniTextValuesMicrons[4])/nSlices;
				framesReorder = (iniTextValuesMicrons[3] * iniTextValuesMicrons[4])/timepoints;
		
				//This makes an array with a sequence 0,1,2...slices
				imageNumberArray = Array.getSequence((iniTextValuesMicrons[3] * iniTextValuesMicrons[4])+1); 
		
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
							if(false) {
							waitForUser("Scroll onto the frame to retain on the image labelled 'Substack etc'");
							}
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
				if(File.exists(directories[1] + ArrayConc[i]+"/") == 0) {
					File.makeDirectory(directories[1]+ArrayConc[i] +"/");
				}
		
				Table.save(directories[1] + ArrayConc[i] + "/Slices To Use.csv");
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
				//Index 0 is xPxlSz, then yPxlSz, zPxlSz, ZperT, FperZ
				
				getIniData(directoryName, iniTextValuesMicrons);
					
				//Calculate the number of timepoints in the image
				timepoints = (iniTextValuesMicrons[3] * iniTextValuesMicrons[4])/nSlices;
				framesReorder = iniTextValuesMicrons[3]/timepoints;
		
				//Convert the image to 8-bit, then adjust the contrast across all slices 
				//to normalise brightness to that of the top slice in the image
				selectWindow(imagesInput[i]);
				print("Converting to 8-bit");
				run("8-bit");
				if(false) {
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
				}
	
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
							subName="Substack ("+((iniTextValuesMicrons[4]*i0)+1)+"-"+(iniTextValuesMicrons[4]*(i0+1))+")";
							selectWindow("Timepoint");
							run("Make Substack...", " slices="+((iniTextValuesMicrons[4]*i0)+1)+"-"+(iniTextValuesMicrons[4]*(i0+1))+"");
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
								//print(IMTArrayCutoffRank2[i1]);
								//print(intDenDiff[i1]);
								if (IMTArrayCutoffRank2[i1]<(IMTArrayCutoffRank2.length-lapFrames)) {
									forLap[i1+(i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3])))] = 0;
								}
								//print(forLap[i1+(i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3])))]);
							}

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
							if(false) {
							run("MultiStackReg", "stack_1=[Untitled] action_1=Align file_1=[]  stack_2=None action_2=Ignore file_2=[] transformation=[Translation]");
							}
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
							if(false) {
							run("MultiStackReg", "stack_1=[T"+motionArtifactRemoval[2]+"] action_1=Align file_1=[] stack_2=None action_2=Ignore file_2[] transformation=[Translation]");
							}
							selectWindow("T"+motionArtifactRemoval[2]);
							run("8-bit");
							zSpaceCorrection("T"+motionArtifactRemoval[2], (iniTextValuesMicrons[3]*5), "T"+motionArtifactRemoval[2]);
							selectWindow("T"+motionArtifactRemoval[2]);
							run("8-bit");
							if(false) {
							run("MultiStackReg", "stack_1=[T"+motionArtifactRemoval[2]+"] action_1=Align file_1=[] stack_2=None action_2=Ignore file_2[] transformation=[Affine]");
							}
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
if(analysisSelections[1] == 1) {

	//Array to store variables for use in generating the Images to Use.csv file
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
			Table.save(directories[1]+"Images to Use.csv");
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
			rename("curr");
			run("Duplicate...", "duplicate");
			selectWindow("curr");
			run("Close");
			selectWindow("curr-1");
			rename(File.getName(outputMaxFiles[i]));
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


////////////////////////////////////////////////////////////////////////////////	
//////////////////////////////Cell Position Marking/////////////////////////////
////////////////////////////////////////////////////////////////////////////////

//If we're going to mark cell positions on our processed images

if(analysisSelections[2] == true) {

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
				run("TIFF Virtual Stack...", "open=["+images[row]+" processed.tif]");
				getVoxelSize(vWidth, vHeight, vDepth, vUnit);
				zSize = nSlices*vDepth;
				counting = 0;
				for(currZ = 10; currZ < zSize; currZ++) {
					if(currZ%10 == 0 && currZ <= (zSize-20)) {
						counting = counting+1;
					}
				}

				//Fill maskGenerationArray with a string of the range of z planes to include in each substack
				countingTwo = 0;
				maskGenerationArray = newArray(counting);
				for(currZ = 10; currZ < zSize; currZ++) {
					if(currZ%10 == 0 && currZ <= (zSize-20)) {
						maskGenerationArray[countingTwo] = toString(currZ)+"-"+toString((currZ+10));
						countingTwo = countingTwo + 1;
					}
				}

				noStacksRaw[row] = maskGenerationArray.length;

				//For each substack, check if we've made cell locations
				checkIt = false;
				for(i0 = 0; i0<maskGenerationArray.length; i0++) {
			
					stringToSave = "Substack ("+maskGenerationArray[i0]+") positions marked"; 

					//Check if we've already generated cell locations for this substack
					//for this image
					if(File.exists(File.getParent(images[row]) + "/Cell Coordinate Masks/"+stringToSave+".txt")==0) {
						checkIt = true;
						i0 = 1e99;
					}
				}

				//If we haven't got all the coordinates for every substack for this image
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

		Array.show(finalImagestoUseArray, noStacksRaw, noStacks, maskGenerationArray);
		waitForUser("");

		//Loop through the images that we want to calculate our motility indices for
		for(i=0; i<finalImagestoUseArray.length; i++) {


			/// Up to here on the edits
			
			Housekeeping();
		
			//Work out the animal and timepoint labels for the current image based on 
			//its name
			imageNames = newArray(4);
			forUse = finalImagestoUseArray[i] + ".tif";
		  	getAnimalTimepointInfo(imageNames, forUse);

		  	/////////////////We're up to here in the checking process

			
			//Look for the files in the cell coordinates masks folder for that image
			maskFolderFiles = getFileList(directories[1] + imageNames[3] + "/Cell Coordinate Masks/");
	
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
				}
 else {
					Table.reset("Cell Position Marking");
				}
					
				//Create an array here of the columns that will be / are in the cell
				//position marking table
				TableColumns = newArray("Substack", "Bad Registration", "Bad Detection", 
"Processed", "QC");
					                        
				//TableValues is an array we'll fill with the values from any existing
				//cell position marking table for this image
				TableValues = newArray(noCounts[i]*TableColumns.length);
					
				//TableResultsRefs is an array of the location where we would find any
				//previuosly existing table, repeated for each column
				TableResultsRefs = newArray(directories[1] + imageNames[3] + 
"/Cell Coordinate Masks/Cell Position Marking.csv", directories[1] + 
imageNames[3] + "/Cell Coordinate Masks/Cell Position Marking.csv", 
					directories[1] + imageNames[3] + 
"/Cell Coordinate Masks/Cell Position Marking.csv", directories[1] + 
imageNames[3] + "/Cell Coordinate Masks/Cell Position Marking.csv", 
					directories[1] + imageNames[3] + 
"/Cell Coordinate Masks/Cell Position Marking.csv");
						
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

