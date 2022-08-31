# DroneObjectDetection

The final version of this project was adapted from the following github repository from DJI:
https://github.com/dji-sdk/Mobile-SDK-iOS

All other project files can be found in that repository.
The files I modified for the project are included in this submission.
They were adapted from the files located at:

Mobile-SDK-iOS/Sample Code/ObjcSampleCode/DJISdkDemo/Demo/Camera/fpv/

###############
Project Overview #
###############
For this project I adapted a DJI iphone app to be able to secure a video feed from a connected DJI drone
and then display that video feed while performing real-time object detection. The model prediction at any
moment is displayed in text above the video feed.

Object detection was set up using Apple’s CoreML framework together with a pretrained Resnet50 model.
Each time the phone receives a new frame from the drone, the raw pixel data is transferred into a buffer
after which it is converted into a CoreML-friendly datatype called CIImage. From there the image is passed
to the model which returns a prediction and the result is displayed in a label above the live video feed from the drone.

##############
File explanation #
##############
.m file   ← main file of interest
    * This is the logic for the view controller. All the dynamic features of the apps FPV mode i
    are controlled here - including the parsing of video frames using the CoreML framework.
    * Especially pay attention to the following methods:
      - videoProcessFrame
      - processImage

.h file
    * Typical header file: imports libraries and declares variables. The UI elements defined in
    the xib file are connected to the .m file here.

.xib file
    * The XML code which defines the user interface.

.mlmodel
    * The Resnet vision model was too large for github upload, so this is omitted
