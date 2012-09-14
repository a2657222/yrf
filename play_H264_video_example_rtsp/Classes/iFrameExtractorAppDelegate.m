//
//  iFrameExtractorAppDelegate.m
//  iFrameExtractor
//
//  Created by lajos on 1/8/10.
//
//  Copyright 2010 Lajos Kamocsay
//
//  lajos at codza dot com
//
//  iFrameExtractor is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
// 
//  iFrameExtractor is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//  Lesser General Public License for more details.
//

#import "iFrameExtractorAppDelegate.h"
#import "VideoFrameExtractor.h"
#import "Utilities.h"


NSString *githubTest;
NSString * const VIDEO_NAME = @"rtsp://180.95.129.243:5546/server?userId=C193FBB9FF75591A8B133C7B5D1668FB&PuId-ChannelNo=280000000000000000111000006-1&PuProperty=0&StreamingType=2&VauPtzAdd=180.95.129.243&VauPtzPort=5066&VauRtspAdd=180.95.129.243&VauRtspPort=5546&PuName=%E5%8D%97%E5%85%B3%E4%BB%80%E5%AD%97&PlayMethod=0";
//NSString * const VIDEO_NAME = @"rtsp://218.204.223.237:554/live/1/66251FC11353191F/e7ooqwcfbqjoo80j.sdp";
//NSString * const VIDEO_NAME = @"rtsp://172.16.20.129:8554/h264ESVideoTest";
//NSString * const VIDEO_NAME = @"rtsp://180.95.129.243:5546/server?UserId=C193FBB9FF75591A8B133C7B5D1668FB&PuId-ChannelNo=280000000000000000111000004-1&PuProperty=1&StreamingType=1&VauPtzAdd=180.95.129.243&VauPtzPort=5066&VauRtspAdd=180.95.129.243&VauRtspPort=5546&PuName=%E9%BB%84%E6%B2%B3%E5%A4%A7%E6%A1%A5&PlayMethod=0";

@implementation iFrameExtractorAppDelegate
@synthesize window, imageView, label, playButton, video ,recordVideo;

- (void)dealloc {
	[video release];
	[imageView release];
	[label release];
	[playButton release];
    [window release];
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {
   
	self.video = [[VideoFrameExtractor alloc] initWithVideo:VIDEO_NAME];
	[video release]; 
	
	self.video.outputWidth = 320;
	self.video.outputHeight = 240;

	
	decodeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/30
												   target:self
												 selector:@selector(displayNextFrame:)
												 userInfo:nil
												  repeats:YES];

    [window makeKeyAndVisible];
}

-(IBAction)startOrStopRecord{
	NSLog(@"startOrStopRecord");	if (recordButton.selected == NO) {
		[video startRecord];
	}else {
		[video stopRecord];
	}

	recordButton.selected = !recordButton.selected;
	
}
-(IBAction)playRecord{
	NSLog(@"playRecord");
	self.recordVideo = [[VideoFrameExtractor alloc] initWithVideo:[Utilities documentsPath:@"test15.3gp"]];
	[recordVideo release];
	
	self.recordVideo.outputWidth = 320;
	self.recordVideo.outputHeight = 200;
	
	[NSTimer scheduledTimerWithTimeInterval:1.0/30
									 target:self
								   selector:@selector(displayRecordNextFrame:)
								   userInfo:nil
									repeats:YES];
}

-(IBAction)playButtonAction:(id)sender {

	if (decodeTimer) {

		self.video = [[VideoFrameExtractor alloc] initWithVideo:VIDEO_NAME];
		[video release];
		
		self.video.outputWidth = 320;
		self.video.outputHeight = 200;
	}

	decodeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/30
									 target:self
								   selector:@selector(displayNextFrame:)
								   userInfo:nil
									repeats:YES];
}

#define LERP(A,B,C) ((A)*(1.0-C)+(B)*C)

-(void)displayRecordNextFrame:(NSTimer *)timer {
	if (![recordVideo stepFrame]) {
		[timer invalidate];
		[playButton setEnabled:YES];
		return;
	}
	NSLog(@"displayRecordNextFrame");
	recordImageView.image = recordVideo.currentImage;
}

-(void)displayNextFrame:(NSTimer *)timer {

	if (![video stepFrame]) {
		[timer invalidate];
		[playButton setEnabled:YES];
		return;
	}
	UIImage *image = video.currentImage;
	loadLabel.text = @"正在载入...";
	if (image != nil) {
		loadLabel.text = @"";
		imageView.image = image;
	}
	
}

@end
