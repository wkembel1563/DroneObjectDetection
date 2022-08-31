//
//  CameraFPVViewController.m
//  DJISdkDemo
//
//  Copyright © 2015 DJI. All rights reserved.
//
/**
 *  This file demonstrates how to receive the video data from DJICamera and display the video using DJIVideoPreviewer.
 */
#import "CameraFPVViewController.h"
#import "DemoUtility.h"
#import "VideoPreviewerSDKAdapter.h"
#import <DJIWidget/DJIVideoPreviewer.h>
#import <DJISDK/DJISDK.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreML/CoreML.h>
#import <Vision/Vision.h>
#import "Resnet50.h"

@interface CameraFPVViewController () <DJICameraDelegate, VideoFrameProcessor>

@property (nonatomic, weak) IBOutlet UIView* fpvView;
@property (weak, nonatomic) IBOutlet UIView *fpvTemView;
@property (weak, nonatomic) IBOutlet UISwitch *fpvTemEnableSwitch;
@property (weak, nonatomic) IBOutlet UILabel *fpvTemperatureData;
@property (weak, nonatomic) IBOutlet UIButton *showImageButton;
@property (strong, nonatomic) MLModel *model;

@property(nonatomic, assign) BOOL needToSetMode;

@property(nonatomic) VideoPreviewerSDKAdapter *previewerAdapter;

@property(atomic) CVPixelBufferRef currentPixelBuffer;

@end

@implementation CameraFPVViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    DJICamera* camera = [DemoComponentHelper fetchCamera];
    if (camera) {
        camera.delegate = self;
    }
    
    self.needToSetMode = YES;
    
    [[DJIVideoPreviewer instance] start];
    self.previewerAdapter = [VideoPreviewerSDKAdapter adapterWithDefaultSettings];
    [self.previewerAdapter start];
    
    DJIBaseProduct *product = [DemoComponentHelper fetchProduct];
    if ([product.model isEqualToString:DJIAircraftModelNameMatrice300RTK] && camera && camera.index == 0) {
        [[self ocuSyncLink] assignSourceToPrimaryChannel:DJIVideoFeedPhysicalSourceLeftCamera
                                        secondaryChannel:DJIVideoFeedPhysicalSourceFPVCamera
                                          withCompletion:^(NSError *_Nullable error) {
                                            if (error) {
                                                ShowResult(@"allocation error: %@", error.description);
                                            } else {
                                                ShowResult(@"success");
                                            }
                                          }];
    }

    [self.previewerAdapter setupFrameControlHandler];
    
    [[DJIVideoPreviewer instance] registFrameProcessor:self];
    [DJIVideoPreviewer instance].enableHardwareDecode = true;
    self.showImageButton.enabled = [DJIVideoPreviewer instance].enableHardwareDecode;
    
    _model = [[[Resnet50 alloc] init] model];
    
}

- (DJIOcuSyncLink *)ocuSyncLink {
    return [DemoComponentHelper fetchAirLink].ocuSyncLink;
}

-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[DJIVideoPreviewer instance] setView:self.fpvView];
    
    [self updateThermalCameraUI];
}

-(void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Call unSetView during exiting to release the memory.
    [[DJIVideoPreviewer instance] unSetView];
   
    if (self.previewerAdapter) {
        [self.previewerAdapter stop];
        self.previewerAdapter = nil;
    }
}

-(IBAction)showCurrentFrameImage:(id)sender{
    CVPixelBufferRef pixelBuffer;
    if(self.currentPixelBuffer){
        pixelBuffer = self.currentPixelBuffer;
        UIImage* image = [self imageFromPixelBuffer:pixelBuffer];
        if (image){
            [self showPhotoWithImage:image];
        }
    }
}


/**
 *  DJIVideoPreviewer is used to decode the video data and display the decoded frame on the view. DJIVideoPreviewer provides both software
 *  decoding and hardware decoding. When using hardware decoding, for different products, the decoding protocols are different and the hardware decoding is only supported by some products.
 */
-(IBAction) onSegmentControlValueChanged:(UISegmentedControl*)sender
{
    [DJIVideoPreviewer instance].enableHardwareDecode = sender.selectedSegmentIndex == 1;
}

- (IBAction)onThermalTemperatureDataSwitchValueChanged:(id)sender {
    DJICamera* camera = [DemoComponentHelper fetchCamera];
    if (camera) {
        DJICameraThermalMeasurementMode mode = ((UISwitch*)sender).on ? DJICameraThermalMeasurementModeSpotMetering : DJICameraThermalMeasurementModeDisabled;
        [camera setThermalMeasurementMode:mode withCompletion:^(NSError * _Nullable error) {
            if (error) {
                ShowResult(@"Failed to set the measurement mode: %@", error.description);
            }
        }];
    }
}

- (void)updateThermalCameraUI {
    DJICamera* camera = [DemoComponentHelper fetchCamera];
    if (camera && [camera isThermalCamera]) {
        [self.fpvTemView setHidden:NO];
        WeakRef(target);
        [camera getThermalMeasurementModeWithCompletion:^(DJICameraThermalMeasurementMode mode, NSError * _Nullable error) {
            WeakReturn(target);
            if (error) {
                ShowResult(@"Failed to get the measurement mode status: %@", error.description);
            }
            else {
                BOOL enabled = mode != DJICameraThermalMeasurementModeDisabled ? YES : NO;
                [target.fpvTemEnableSwitch setOn:enabled];
            }
        }];
    }
    else {
        [self.fpvTemView setHidden:YES];
    }
}

-(void) showPhotoWithImage:(UIImage*)image
{
    UIView* bkgndView = [[UIView alloc] initWithFrame:self.view.bounds];
    bkgndView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
    UITapGestureRecognizer* tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onImageViewTap:)];
    [bkgndView addGestureRecognizer:tapGesture];

    float width = image.size.width;
    float height = image.size.height;
    if (width > self.view.bounds.size.width * 0.7) {
        height = height*(self.view.bounds.size.width*0.7)/width;
        width = self.view.bounds.size.width*0.7;
    }
    UIImageView* imgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    imgView.image = image;
    imgView.center = bkgndView.center;
    imgView.backgroundColor = [UIColor blackColor];
    imgView.layer.borderWidth = 2.0;
    imgView.layer.borderColor = [UIColor blueColor].CGColor;
    imgView.layer.cornerRadius = 4.0;
    imgView.layer.masksToBounds = YES;
    imgView.contentMode = UIViewContentModeScaleAspectFill;

    [bkgndView addSubview:imgView];
    [self.view addSubview:bkgndView];
}

-(void) onImageViewTap:(UIGestureRecognizer*)recognized
{
    UIView* view = recognized.view;
    [view removeFromSuperview];
}


#pragma mark - DJICameraDelegate
/**
 *  DJICamera will send the live stream only when the mode is in DJICameraModeShootPhoto or DJICameraModeRecordVideo. Therefore, in order
 *  to demonstrate the FPV (first person view), we need to switch to mode to one of them.
 */
-(void)camera:(DJICamera *)camera didUpdateSystemState:(DJICameraSystemState *)systemState
{
    if (systemState.mode == DJICameraModePlayback ||
        systemState.mode == DJICameraModeMediaDownload) {
        if (self.needToSetMode) {
            self.needToSetMode = NO;
            WeakRef(obj);
            [camera setMode:DJICameraModeShootPhoto withCompletion:^(NSError * _Nullable error) {
                if (error) {
                    WeakReturn(obj);
                    obj.needToSetMode = YES;
                }
            }];
        }
    }
}

-(void)camera:(DJICamera *)camera didUpdateTemperatureData:(float)temperature {
    self.fpvTemperatureData.text = [NSString stringWithFormat:@"%f", temperature];
}

#pragma mark - VideoFrameProcessor

- (BOOL)videoProcessorEnabled {
    return YES;
}


/* Classify objects in frame using CoreML model */
- (void) processImage: (CIImage *)image {
    VNCoreMLModel *m = [VNCoreMLModel modelForMLModel: _model error:nil];
    VNCoreMLRequest *req = [[VNCoreMLRequest alloc] initWithModel: m completionHandler: (VNRequestCompletionHandler) ^(VNRequest *request, NSError *error){
        dispatch_async(dispatch_get_main_queue(), ^{
            self.resultsCount = request.results.count;
            self.results = [request.results copy];
            VNClassificationObservation *topresult = ((VNClassificationObservation *)(self.results[0]));
            float percent = topresult.confidence * 100;
            self.predictionOutput.text = [NSString stringWithFormat: @"Confidence: %.f%@ %@", percent,@"%", topresult.identifier];
        });
    }];
    
    NSDictionary *options = [[NSDictionary alloc] init];
    NSArray *reqArray = @[req];
    
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCIImage:image options:options];
    dispatch_async(dispatch_get_main_queue(), ^{
        [handler performRequests:reqArray error:nil];
    });
}


/* Process each video frame as it comes in
 *  Converts the pixel buffer to a CIImage type,
 *  then calls processImage to send the image to the classifier*/
-(void) videoProcessFrame:(VideoFrameYUV*)frame {
    if ([DJIVideoPreviewer instance].enableHardwareDecode &&
        (frame->cv_pixelbuffer_fastupload != NULL)) {
        CVPixelBufferRef pixelBuffer = frame->cv_pixelbuffer_fastupload;
        if (self.currentPixelBuffer) {
            CVPixelBufferRelease(self.currentPixelBuffer);
        }
        self.currentPixelBuffer = pixelBuffer;
        CVPixelBufferRetain(pixelBuffer);
        
        // convert to UIImage
        CIImage *image = [self imageFromPixelBuffer:self.currentPixelBuffer];
        
        // perform classification
        [self processImage:image];
        
    } else {
        self.currentPixelBuffer = nil;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self.showImageButton.enabled = self.currentPixelBuffer != nil;
    });
    
}

#pragma mark - Help Method

- (CIImage *)imageFromPixelBuffer:(CVPixelBufferRef)pixelBufferRef {
    CVImageBufferRef imageBuffer =  pixelBufferRef;
    CIImage* sourceImage = [[CIImage alloc] initWithCVPixelBuffer:imageBuffer options:nil];
    return sourceImage;
}


@end
