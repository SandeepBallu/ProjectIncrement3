//
//  ViewController.m
//  HelloRomo
//

#import "ViewController.h"
#import "GCDAsyncSocket.h"
#include <ifaddrs.h>
#include <arpa/inet.h>
#import <AudioToolbox/AudioToolbox.h>

#include "AppDelegate.h"

#define WELCOME_MSG  0
#define ECHO_MSG     1
#define WARNING_MSG  2

#define READ_TIMEOUT 15.0
#define READ_TIMEOUT_EXTENSION 10.0

#define FORMAT(format, ...) [NSString stringWithFormat:(format), ##__VA_ARGS__]
#define PORT 1234

@interface ViewController () {
    dispatch_queue_t socketQueue;
    NSMutableArray *connectedSockets;
    BOOL isRunning;
    
    GCDAsyncSocket *listenSocket;
}
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLLocation *endLocation;
@property (nonatomic) CLLocationDirection currentHeading;
@property (strong, nonatomic) AppDelegate *appDelegate;
@property (strong, nonatomic) IBOutlet UIButton *recordButton;
@end

const unsigned char SpeechKitApplicationKey[] = {0x55, 0x65, 0xe3, 0x36, 0x65, 0x0c, 0xfe, 0xde, 0xd9, 0xdb, 0x0f, 0x04, 0x79, 0xb0, 0x44, 0xd6, 0x56, 0x27, 0x42, 0xed, 0x8e, 0x94, 0xa5, 0xeb, 0x95, 0xbf, 0x67, 0x0d, 0xf9, 0x05, 0xee, 0x4e, 0x6b, 0xd2, 0x85, 0xd0, 0xde, 0x83, 0xaf, 0xb7, 0x5f, 0xbe, 0xbb, 0xd8, 0x6f, 0x00, 0xae, 0xc5, 0x27, 0xf0, 0xb2, 0xb5, 0x85, 0x58, 0xa0, 0x1a, 0x17, 0x07, 0x27, 0x10, 0x0d, 0x15, 0x5f, 0x78};
static int prevDegree=0;
@implementation ViewController

@synthesize moviplayer;

#pragma mark - View Management
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //speech
    
    self.appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [self.appDelegate setupSpeechKitConnection];
    
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    _locationManager.delegate = self;
    [_locationManager requestAlwaysAuthorization];
    _locationManager.pausesLocationUpdatesAutomatically = YES;
    //_locationManager.activityType = CLActivityTypeAutomotiveNavigation;
    //[_locationManager startUpdatingLocation];
    // Do any additional setup after loading the view, typically from a nib.
    
    // To receive messages when Robots connect & disconnect, set RMCore's delegate to self
    [RMCore setDelegate:self];
    
    // Grab a shared instance of the Romo character
    self.Romo = [RMCharacter Romo];
    [RMCore setDelegate:self];
    
    [self addGestureRecognizers];
    
    // Do any additional setup after loading the view, typically from a nib.
    socketQueue = dispatch_queue_create("socketQueue", NULL);
    
    listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:socketQueue];
    
    // Setup an array to store all accepted client connections
    connectedSockets = [[NSMutableArray alloc] initWithCapacity:1];
    
    isRunning = NO;
    
    NSLog(@"%@", [self getIPAddress]);
    
    [self toggleSocketState];   //Statrting the Socket
    
    
    
    
    //Accelerometer
    currentMaxAccelX = 0;
    currentMaxAccelY = 0;
    currentMaxAccelZ = 0;
    
    currentMaxRotX = 0;
    currentMaxRotY = 0;
    currentMaxRotZ = 0;
    
    self.motionManager = [[CMMotionManager alloc] init];
    self.motionManager.accelerometerUpdateInterval = .2;
    self.motionManager.gyroUpdateInterval = .2;
    
    /*[self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue]
     withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
     [self outputAccelertionData:accelerometerData.acceleration];
     if(error){
     
     NSLog(@"%@", error);
     }
     }];*/
    
    [self.motionManager startGyroUpdatesToQueue:[NSOperationQueue currentQueue]
                                    withHandler:^(CMGyroData *gyroData, NSError *error) {
                                        [self outputRotationData:gyroData.rotationRate];
                                    }];
    
    
    
}

- (void)viewWillAppear:(BOOL)animated
{
    // Add Romo's face to self.view whenever the view will appear
    [self.Romo addToSuperview:self.romoView];
    [self.view addSubview:self.recordButton];
    [self.view bringSubviewToFront:self.recordButton];
}

#pragma mark -
#pragma mark Robo Movement

- (NSString *)direction:(NSString *)message {
    
    return @"";
}

-(void)performCommand:(NSString *)command{
    [self perform:command];
}

- (void)perform:(NSString *)command {
    
    NSString *cmd = [command uppercaseString];
    if ([cmd isEqualToString:@"LEFT"]) {
        [self.Romo3 turnByAngle:90 withRadius:0.0 completion:^(BOOL success, float heading) {
            if (success) {
                self.Romo.expression=RMCharacterExpressionProud;
            }
        }];
    } else if ([cmd isEqualToString:@"RIGHT"]) {
        [self.Romo3 turnByAngle:-90 withRadius:0.0 completion:^(BOOL success, float heading) {
            self.Romo.expression=RMCharacterExpressionProud;
        }];
    } else if ([cmd isEqualToString:@"BACK"]) {
        [self.Romo3 driveBackwardWithSpeed:0.3];
    } else if ([cmd isEqualToString:@"GO"]) {
        start=true;
        _endLocation = [[CLLocation alloc] initWithLatitude:[@"39.02641" floatValue] longitude:[@"-94.427865" floatValue]];
        [_locationManager startUpdatingLocation];
        if ([CLLocationManager headingAvailable]) {
            _locationManager.headingFilter = 5;
            [_locationManager startUpdatingHeading];
        }
        //[self.Romo3 driveForwardWithSpeed:0.3];
    } else if ([cmd isEqualToString:@"FAST"]) {
        [self.Romo3 driveForwardWithSpeed:0.6];
    } else if ([cmd isEqualToString:@"SLOW"]) {
        [self.Romo3 driveForwardWithSpeed:0.2];
    } else if ([cmd isEqualToString:@"SMILE"]) {
        self.Romo.expression=RMCharacterExpressionChuckle;
        self.Romo.emotion=RMCharacterEmotionHappy;
    } else if ([cmd isEqualToString:@"CRY"]) {
        self.Romo.expression=RMCharacterExpressionSad;
        self.Romo.emotion=RMCharacterEmotionSad;
    } else if ([cmd isEqualToString:@"SLEEP"]) {
        self.Romo.expression=RMCharacterExpressionExhausted;
        self.Romo.emotion=RMCharacterEmotionSleeping;
    } else if ([cmd isEqualToString:@"SLEEPY"]) {
        self.Romo.expression=RMCharacterExpressionExhausted;
        self.Romo.emotion=RMCharacterEmotionSleepy;
    } else if ([cmd isEqualToString:@"SCARE"]) {
        self.Romo.expression=RMCharacterExpressionEmbarrassed;
        self.Romo.emotion=RMCharacterEmotionScared;
    } else if([cmd isEqualToString:@"STOP"]){
        [self.Romo3 stopDriving];
        start=false;
        
        //additional features
    } else if([cmd isEqualToString:@"PLAY MUSIC"]){
        ///*
        NSURL *sound_file = [[NSURL alloc] initFileURLWithPath: [[NSBundle mainBundle] pathForResource:@"GangnamStyle" ofType:@"mp3" ]];
        
        // Play it
        self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:sound_file error:nil];
        //self.audioPlayer.delegate = self;
        
        [self.audioPlayer prepareToPlay];
        [self.audioPlayer play];
        //*/
    } else if([cmd isEqualToString:@"STOP MUSIC"]){
        [self.audioPlayer stop];
    } else if([cmd isEqualToString:@"PLAY VIDEO"]){
        ///*
        //NSString *videoPath = [[NSBundle mainBundle] pathForResource:@"dsky" ofType:@"mp4"];
        NSURL *streamURL = [[NSURL alloc] initFileURLWithPath: [[NSBundle mainBundle] pathForResource:@"dsky" ofType:@"m4v" ]];
        //[NSURL fileURLWithPath:videoPath];
        moviplayer =[[MPMoviePlayerController alloc] initWithContentURL:streamURL];
        [moviplayer prepareToPlay];
        [moviplayer.view setFrame: self.view.bounds];
        [self.view addSubview: moviplayer.view];
        moviplayer.fullscreen = YES;
        moviplayer.shouldAutoplay = YES;
        moviplayer.repeatMode = MPMovieRepeatModeNone;
        moviplayer.movieSourceType = MPMovieSourceTypeFile;
        [moviplayer play];
        //*/
    } else if([cmd isEqualToString:@"STOP VIDEO"]){
        [moviplayer stop];
        //[moviplayer dealloc];
    } else if([cmd isEqualToString:@"CALL"]){
        ///*
        //NSString *phone_number = _tel.text;
        NSString *phone_number = @"1(816)419-9117";
        // Create a string with the correct format  <tell://> <phone number>
        //NSLog(@"This is number: %@", _tel);
        // Make the call
        
        
        NSString *phonenumber = [@"tel://" stringByAppendingString:phone_number];
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:phonenumber]]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:phonenumber]];
        }
        //*/
    } else if([cmd isEqualToString:@"MESSAGE"]){
        ///*
        MFMessageComposeViewController *controller = [[MFMessageComposeViewController alloc] init];
        if([MFMessageComposeViewController canSendText])
        {
            controller.body = @"D-Sky increment 1 ";
            controller.recipients = [NSArray arrayWithObjects:@"1(660)238-2780",@"1(816)419-9117",@"1(580)878-0413",@"1(469)328-7977", nil];
            controller.messageComposeDelegate = self;
            [self presentViewController:controller animated:YES completion:^{
                //
            }];
        }
        //*/
    } else if([cmd isEqualToString:@"DANCE"]){
        ///*
        [self.Romo3 driveBackwardWithSpeed:0.3];
        self.Romo.expression=RMCharacterExpressionProud;
        [self.Romo3 driveForwardWithSpeed:0.3];
        
        self.Romo.expression=RMCharacterExpressionChuckle;
        self.Romo.emotion=RMCharacterEmotionHappy;
        
        
        
        [self.Romo3 driveForwardWithSpeed:0.2];
        [self.Romo3 driveBackwardWithSpeed:0.2];
        [self.Romo3 driveForwardWithSpeed:0.2];
        [self.Romo3 driveBackwardWithSpeed:0.2];
        
        
        [self.Romo3 turnByAngle:-45 withRadius:0.0 completion:^(BOOL success, float heading) {
            if (success) {
                [self.Romo3 driveForwardWithSpeed:0.2];
            }
        }];
        [self.Romo3 driveBackwardWithSpeed:0.2];
        
        
        [self.Romo3 turnByAngle:45 withRadius:0.0 completion:^(BOOL success, float heading) {
            [self.Romo3 driveForwardWithSpeed:0.2];
        }];
        
        [self.Romo3 driveBackwardWithSpeed:0.2];
        //*/
    } else if([cmd isEqualToString:@"STOP DANCE"]){
        [self.Romo3 stopDriving];
        start=false;
    } else if([cmd isEqualToString:@"STOP VIDEO"]){
        [moviplayer stop];
        //[moviplayer dealloc];
    } else if([cmd isEqualToString:@"STOP VIDEO"]){
        [moviplayer stop];
        //[moviplayer dealloc];
    } else if([cmd isEqualToString:@"STOP VIDEO"]){
        [moviplayer stop];
        //[moviplayer dealloc];
    }

}

#pragma mark - RMCoreDelegate Methods
- (void)robotDidConnect:(RMCoreRobot *)robot
{
    // Currently the only kind of robot is Romo3, so this is just future-proofing
    if ([robot isKindOfClass:[RMCoreRobotRomo3 class]]) {
        self.Romo3 = (RMCoreRobotRomo3 *)robot;
        
        // Change Romo's LED to be solid at 80% power
        [self.Romo3.LEDs setSolidWithBrightness:0.8];
        
        // When we plug Romo in, he get's excited!
        self.Romo.expression = RMCharacterExpressionExcited;
    }
}

- (void)robotDidDisconnect:(RMCoreRobot *)robot
{
    if (robot == self.Romo3) {
        self.Romo3 = nil;
        
        // When we plug Romo in, he get's excited!
        self.Romo.expression = RMCharacterExpressionSad;
    }
}

#pragma mark - Gesture recognizers

- (void)addGestureRecognizers
{
    // Let's start by adding some gesture recognizers with which to interact with Romo
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipedLeft:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:swipeLeft];
    
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipedRight:)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipeRight];
    
    UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipedUp:)];
    swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    [self.view addGestureRecognizer:swipeUp];
    
    UITapGestureRecognizer *tapReceived = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedScreen:)];
    [self.view addGestureRecognizer:tapReceived];
}

- (void)driveLeft {
    
}

- (void)swipedLeft:(UIGestureRecognizer *)sender
{
    [self.Romo3 turnByAngle:-90 withRadius:0.0 completion:NULL];
    // When the user swipes left, Romo will turn in a circle to his left
    //[self.Romo3 driveWithRadius:-1.0 speed:1.0];
}

- (void)swipedRight:(UIGestureRecognizer *)sender
{
    [self.Romo3 turnByAngle:90 withRadius:0.0 completion:NULL];
    // When the user swipes right, Romo will turn in a circle to his right
    //    [self.Romo3 driveWithRadius:1.0 speed:1.0];
}

// Swipe up to change Romo's emotion to some random emotion
- (void)swipedUp:(UIGestureRecognizer *)sender
{
    int numberOfEmotions = 7;
    
    // Choose a random emotion from 1 to numberOfEmotions
    // That's different from the current emotion
    RMCharacterEmotion randomEmotion = 1 + (arc4random() % numberOfEmotions);
    
    self.Romo.emotion = randomEmotion;
}

// Simply tap the screen to stop Romo
- (void)tappedScreen:(UIGestureRecognizer *)sender
{
    [self.Romo3 stopDriving];
}

#pragma mark -
#pragma mark CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{
    CLLocation *crnLoc = [locations lastObject];
    CLLocationDegrees cldlat = crnLoc.coordinate.latitude;
    CLLocationDegrees cldlon = crnLoc.coordinate.longitude;
    // making romo to be in direction of meridian
    
    [self.Romo3 turnByAngle:(self.currentHeading) withRadius:0.5 completion:^(BOOL success, float heading){}];
    
    double degree = [self degreesOfDirectionWithStartLat:cldlat StartLon:cldlon EndLat:_endLocation.coordinate.latitude EndLon:_endLocation.coordinate.longitude];
    if((cldlon == _endLocation.coordinate.longitude) && (cldlat == _endLocation.coordinate.latitude)){
        [self.Romo3 stopDriving];
        [_locationManager stopUpdatingLocation];
    }
    else{
        [self.Romo3 driveForwardWithSpeed:.2f];
        [self.Romo3 turnByAngle:((int)degree-(int)prevDegree) withRadius:0.5 completion:^(BOOL success, float heading) {
            prevDegree = degree;
        }];
    }
    NSLog(@"--->%f",degree);
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
//    if (newHeading.headingAccuracy < 0)
//        return;
    
    // Use the true heading if it is valid.
    CLLocationDirection  theHeading = ((newHeading.trueHeading > 0) ?
                                       newHeading.trueHeading : newHeading.magneticHeading);
    NSLog(@"heading---->%f",theHeading);
    
    self.currentHeading = theHeading;
}

-(double)degreesOfDirectionWithStartLat:(CLLocationDegrees)lat1 StartLon:(CLLocationDegrees)long1 EndLat:(CLLocationDegrees)lat2 EndLon:(CLLocationDegrees)long2 {
    
    //double dLat = (lat2-lat1) * M_PI / 180.0;
    double dLon = (long2-long1) * M_PI / 180.0;
    
    lat1 = lat1 * M_PI / 180.0;
    lat2 = lat2 * M_PI / 180.0;
    
    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1)*sin(lat2) - sin(lat1)*cos(lat2)*cos(dLon);
    
    float brng = (atan2(y, x)) * (180/M_PI);//toDeg(atan2(y, x));
    
    // fix negative degrees
    //    if(brng<0) {
    //        brng=360-fabsf(brng);
    //    }
    
    return brng;
}

#pragma mark -
#pragma mark Socket

- (void)toggleSocketState
{
    if(!isRunning)
    {
        NSError *error = nil;
        if(![listenSocket acceptOnPort:PORT error:&error])
        {
            [self log:FORMAT(@"Error starting server: %@", error)];
            return;
        }
        
        [self log:FORMAT(@"Echo server started on port %hu", [listenSocket localPort])];
        isRunning = YES;
    }
    else
    {
        // Stop accepting connections
        [listenSocket disconnect];
        
        // Stop any client connections
        @synchronized(connectedSockets)
        {
            NSUInteger i;
            for (i = 0; i < [connectedSockets count]; i++)
            {
                // Call disconnect on the socket,
                // which will invoke the socketDidDisconnect: method,
                // which will remove the socket from the list.
                [[connectedSockets objectAtIndex:i] disconnect];
            }
        }
        
        [self log:@"Stopped Echo server"];
        isRunning = false;
    }
}

- (void)log:(NSString *)msg {
    NSLog(@"%@", msg);
}

- (NSString *)getIPAddress
{
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if( temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    
    return address;
}

#pragma mark -
#pragma mark GCDAsyncSocket Delegate

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    // This method is executed on the socketQueue (not the main thread)
    
    @synchronized(connectedSockets)
    {
        [connectedSockets addObject:newSocket];
    }
    
    NSString *host = [newSocket connectedHost];
    UInt16 port = [newSocket connectedPort];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            
            [self log:FORMAT(@"Accepted client %@:%hu", host, port)];
            
        }
    });
    
    NSString *welcomeMsg = @"Welcome to the AsyncSocket Echo Server\r\n";
    NSData *welcomeData = [welcomeMsg dataUsingEncoding:NSUTF8StringEncoding];
    
    [newSocket writeData:welcomeData withTimeout:-1 tag:WELCOME_MSG];
    
    
    [newSocket readDataWithTimeout:READ_TIMEOUT tag:0];
    newSocket.delegate = self;
    
    //    [newSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:READ_TIMEOUT tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    // This method is executed on the socketQueue (not the main thread)
    
    if (tag == ECHO_MSG)
    {
        [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:100 tag:0];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    
    NSLog(@"== didReadData %@ ==", sock.description);
    
    NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    [self log:msg];
    [self performCommand:msg];
    [sock readDataWithTimeout:READ_TIMEOUT tag:0];
}

/**
 * This method is called if a read has timed out.
 * It allows us to optionally extend the timeout.
 * We use this method to issue a warning to the user prior to disconnecting them.
 **/
- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length
{
    if (elapsed <= READ_TIMEOUT)
    {
        NSString *warningMsg = @"Are you still there?\r\n";
        NSData *warningData = [warningMsg dataUsingEncoding:NSUTF8StringEncoding];
        
        [sock writeData:warningData withTimeout:-1 tag:WARNING_MSG];
        
        return READ_TIMEOUT_EXTENSION;
    }
    
    return 0.0;
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    if (sock != listenSocket)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            @autoreleasepool {
                [self log:FORMAT(@"Client Disconnected")];
            }
        });
        
        @synchronized(connectedSockets)
        {
            [connectedSockets removeObject:sock];
        }
    }
}


//
//  ViewController.m
//  GyrosAndAccelerometers
//
//  Created by NSCookbook on 3/25/13.
//  Copyright (c) 2013 NSCookbook. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


-(void)outputAccelertionData:(CMAcceleration)acceleration
{
    
    self.accX.text = [NSString stringWithFormat:@" %.2fg",acceleration.x];
    if(fabs(acceleration.x) > fabs(currentMaxAccelX))
    {
        currentMaxAccelX = acceleration.x;
    }
    self.accY.text = [NSString stringWithFormat:@" %.2fg",acceleration.y];
    if(fabs(acceleration.y) > fabs(currentMaxAccelY))
    {
        currentMaxAccelY = acceleration.y;
    }
    self.accZ.text = [NSString stringWithFormat:@" %.2fg",acceleration.z];
    if(fabs(acceleration.z) > fabs(currentMaxAccelZ))
    {
        currentMaxAccelZ = acceleration.z;
    }
    
    self.maxAccX.text = [NSString stringWithFormat:@" %.2f",currentMaxAccelX];
    self.maxAccY.text = [NSString stringWithFormat:@" %.2f",currentMaxAccelY];
    self.maxAccZ.text = [NSString stringWithFormat:@" %.2f",currentMaxAccelZ];
    
    NSLog(@"X value is : %f", acceleration.x);
    NSLog(@"Y value is : %f", acceleration.y);
    NSLog(@"Z value is : %f", acceleration.z);
    
    if(start){
        if (acceleration.z > -0.2 && (acceleration.z) <= 0.2) {
            speed = 0.4;
            //        [self.Romo3 driveForwardWithSpeed:0.4];
        } else if ((acceleration.z) > -0.4 && (acceleration.z) <= -0.2) {
            speed = 0.5;
            //        [self.Romo3 driveForwardWithSpeed:0.5];
        } else if ((acceleration.z) > -0.6 && (acceleration.z) <= -0.4) {
            speed = 0.55;
            //        [self.Romo3 driveForwardWithSpeed:0.55];
        } else if ((acceleration.z) > -0.8 && (acceleration.z) <= -0.6) {
            speed = 0.6;
            //        [self.Romo3 driveForwardWithSpeed:0.6];
        } else if ((acceleration.z) <= -0.8) {
            speed = 0.7;
            //        [self.Romo3 driveForwardWithSpeed:0.7];
            //these are inclines
        } else if ((acceleration.z) > 0.2 && (acceleration.z) < 0.6) {
            speed = 0.3;
            //        [self.Romo3 driveForwardWithSpeed:0.2];
        } else if ((acceleration.z) > 0.6) {
            speed = 0.2;
            //    [self.Romo3 driveForwardWithSpeed:0.1];
        }
    }
    else{
        speed = 0.0;
        //    [self.Romo3 driveForwardWithSpeed:0.0];
    }
    [self.Romo3 driveForwardWithSpeed:speed];
    
    
    NSLog(@"Speed value is : %f", speed);
    
}
-(void)outputRotationData:(CMRotationRate)rotation
{
    
    self.rotX.text = [NSString stringWithFormat:@" %.2fr/s",rotation.x];
    if(fabs(rotation.x)> fabs(currentMaxRotX))
    {
        currentMaxRotX = rotation.x;
    }
    self.rotY.text = [NSString stringWithFormat:@" %.2fr/s",rotation.y];
    if(fabs(rotation.y) > fabs(currentMaxRotY))
    {
        currentMaxRotY = rotation.y;
    }
    self.rotZ.text = [NSString stringWithFormat:@" %.2fr/s",rotation.z];
    if(fabs(rotation.z) > fabs(currentMaxRotZ))
    {
        currentMaxRotZ = rotation.z;
    }
    
    self.maxRotX.text = [NSString stringWithFormat:@" %.2f",currentMaxRotX];
    self.maxRotY.text = [NSString stringWithFormat:@" %.2f",currentMaxRotY];
    self.maxRotZ.text = [NSString stringWithFormat:@" %.2f",currentMaxRotZ];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)resetMaxValues:(id)sender {
    
    currentMaxAccelX = 0;
    currentMaxAccelY = 0;
    currentMaxAccelZ = 0;
    
    currentMaxRotX = 0;
    currentMaxRotY = 0;
    currentMaxRotZ = 0;
    
}

#pragma mark speechkit
- (IBAction)recordButtonTapped:(id)sender {
    self.recordButton.selected = !self.recordButton.isSelected;
    
    // This will initialize a new speech recognizer instance
    if (self.recordButton.isSelected) {
        self.voiceSearch = [[SKRecognizer alloc] initWithType:SKSearchRecognizerType
                                                    detection:SKShortEndOfSpeechDetection
                                                     language:@"en_US"
                                                     delegate:self];
    }
    
    // This will stop existing speech recognizer processes
    else {
        if (self.voiceSearch) {
            [self.voiceSearch stopRecording];
            [self.voiceSearch cancel];
        }
    }
}


- (void)recognizer:(SKRecognizer *)recognizer didFinishWithResults:(SKRecognition *)results {
    long numOfResults = [results.results count];
    
    if (numOfResults > 0) {
        // update the text of text field with best result from SpeechKit
        NSLog(@"Word %@",[results firstResult]);
        [self performCommand:[results firstResult]];
    }
    
    self.recordButton.selected = !self.recordButton.isSelected;
    
    if (self.voiceSearch) {
        [self.voiceSearch cancel];
    }
}


- (void)recognizer:(SKRecognizer *)recognizer didFinishWithError:(NSError *)error suggestion:(NSString *)suggestion {
    self.recordButton.selected = NO;
    
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                    message:[error localizedDescription]
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

//FI
- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result{
}
@end
