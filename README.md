Swift files for a functional version of the tennis app.

## Helpful links

API link is [here](http://tennis-lb-api-308609498.us-east-1.elb.amazonaws.com/docs#/default/upload_video_upload_post)

API python code is [here](http://youtube.com)

Guide for Apple App store publishing is [here](https://docs.google.com/document/d/1yzudAkzDLAEHwZn63od8n-9wG33_ITMqXDPEGZJMCW4/edit?usp=sharing)

## Breakdown of file heirarchy

AnalysisView - Main container for the analysis pathway

AppDelegate - Tools for ensuring orientation works

ArchiveView - Main container for the archive pathway

CameraView - Handles showing the camera 

CameraViewController - Handles the logic behind camera processes

ContentView - The code for the app's landing page, links to Archive/Record/CameraView

CourtCamApp - Highest level, calls ContentView

OrientationLockedHostingController - Tools for ensuring orientation works

OrientationLockedView - Tools for ensuring orientation works

RecordingView - Main container for the recording pathway

RotatingAVPlayerViewController - Tools for ensuring orientation works
