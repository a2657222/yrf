//
//  Video.m
//  iFrameExtractor
//
//  Created by lajos on 1/10/10.
//  Copyright 2010 www.codza.com. All rights reserved.
//

#import "VideoFrameExtractor.h"
#import "Utilities.h"

@interface VideoFrameExtractor (private)
-(void)convertFrameToRGB;
-(UIImage *)imageFromAVPicture:(AVPicture)pict width:(int)width height:(int)height;
-(void)savePicture:(AVPicture)pFrame width:(int)width height:(int)height index:(int)iFrame;
-(void)setupScaler;
@end

@implementation VideoFrameExtractor

@synthesize outputWidth, outputHeight;

-(void)setOutputWidth:(int)newValue {
	if (outputWidth == newValue) return;
	outputWidth = newValue;
	[self setupScaler];
}

-(void)setOutputHeight:(int)newValue {
	if (outputHeight == newValue) return;
	outputHeight = newValue;
	[self setupScaler];
}

-(UIImage *)currentImage {
	if (!pFrame->data[0]) return nil;

	[self convertFrameToRGB];

	return [self imageFromAVPicture:picture width:outputWidth height:outputHeight];
}

-(double)duration {
	return (double)pFormatCtx->duration / AV_TIME_BASE;
}

-(int)sourceWidth {
	return pCodecCtx->width;
}

-(int)sourceHeight {
	return pCodecCtx->height;
}

-(id)initWithVideo:(NSString *)moviePath {
	if (!(self=[super init])) return nil;
 
    AVCodec         *pCodec;
		
    // Register all formats and codecs
    av_register_all();
	avformat_network_init();
	NSLog(@"1111111111");
    // Open video file
	if(avformat_open_input(&pFormatCtx, [moviePath cStringUsingEncoding:NSASCIIStringEncoding], NULL, NULL)!=0)
        goto initError; // Couldn't open file
	
    // Retrieve stream information
	if(avformat_find_stream_info(pFormatCtx, NULL)<0)
        goto initError; // Couldn't find stream information

	NSLog(@"22222222");	
    // Find the first video stream
    videoStream=-1;
    for(int i=0; i<pFormatCtx->nb_streams; i++)
        if(pFormatCtx->streams[i]->codec->codec_type==AVMEDIA_TYPE_VIDEO)
        {
            videoStream=i;
            break;
        }
    if(videoStream==-1)
        goto initError; // Didn't find a video stream
	
    // Get a pointer to the codec context for the video stream
    pCodecCtx=pFormatCtx->streams[videoStream]->codec;
	pCodecCtx->idct_algo = FF_IDCT_ARM;
	NSLog(@"id :%d",pCodecCtx->codec_id);
    // Find the decoder for the video stream
    pCodec=avcodec_find_decoder(pCodecCtx->codec_id);
    if(pCodec==NULL)
        goto initError; // Codec not found
	
    // Open codec
	if(avcodec_open2(pCodecCtx, pCodec, NULL)<0)
        goto initError; // Could not open codec
	
    // Allocate video frame
    pFrame=avcodec_alloc_frame();
			
	outputWidth = pCodecCtx->width;
	self.outputHeight = pCodecCtx->height;
	
	isRecord = NO;
	NSLog(@"start!!!!!!!!!!!!!!!!!!!!!!");
	
	isRemoveMosaic = NO;
	isDamageGopFrame = NO;
	firstData = [[NSData alloc] init];
	secondData = [[NSData alloc] init];
	thirdData = [[NSData alloc]init];
	updataGrayPercentCount = 0;
	return self;
	
initError:
	[self release];
	return nil;
}


-(void)setupScaler {

	// Release old picture and scaler
	avpicture_free(&picture);
	sws_freeContext(img_convert_ctx);	
	
	// Allocate RGB picture
	avpicture_alloc(&picture, PIX_FMT_RGB24, outputWidth, outputHeight);
	
	// Setup scaler
	static int sws_flags =  SWS_FAST_BILINEAR;
	img_convert_ctx = sws_getContext(pCodecCtx->width, 
									 pCodecCtx->height,
									 pCodecCtx->pix_fmt,
									 outputWidth, 
									 outputHeight,
									 PIX_FMT_RGB24,
									 sws_flags, NULL, NULL, NULL);
	
}

-(void)seekTime:(double)seconds {
	AVRational timeBase = pFormatCtx->streams[videoStream]->time_base;
	int64_t targetFrame = (int64_t)((double)timeBase.den / timeBase.num * seconds);
	avformat_seek_file(pFormatCtx, videoStream, targetFrame, targetFrame, targetFrame, AVSEEK_FLAG_FRAME);
	avcodec_flush_buffers(pCodecCtx);
}

-(void)dealloc {
	// Free scaler
	sws_freeContext(img_convert_ctx);	

	// Free RGB picture
	avpicture_free(&picture);
	
    // Free the YUV frame
    av_free(pFrame);
	
    // Close the codec
    if (pCodecCtx) avcodec_close(pCodecCtx);
	
    // Close the video file
    if (pFormatCtx) av_close_input_file(pFormatCtx);
	
	[super dealloc];
}

-(void)startRecord{
	NSLog(@"start %d",pCodecCtx->codec_id);
	videoRecoder = [[VideoRecorder alloc]initWithVideoName:@"test15.mp4" videoWidth:pCodecCtx->width videoHeight:pCodecCtx->height videoCode:pCodecCtx->codec_id];
	isRecord = YES;
	
}
-(void)stopRecord{
	isRecord = NO;
	[videoRecoder stopRecord];
}
BOOL isKeyFrame = NO;
-(BOOL)stepFrame {
	AVPacket packet;
    int frameFinished=0;

    while(!frameFinished && av_read_frame(pFormatCtx, &packet)>=0) {
        // Is this a packet from the video stream?
        if(packet.stream_index==videoStream) {

			if (isRecord) {
				[videoRecoder addVideoFrame:packet.data frameLength:packet.size];
			}
			//NSLog(@"%@",[NSData dataWithBytes:packet.data length:packet.size]);
			avcodec_decode_video2(pCodecCtx, pFrame, &frameFinished, &packet);
			//NSLog(@"%d",pFrame->pict_type);
			//NSLog(@"%d %d",packet.data[3]&0x1F,isDamageFrame);
			if (packet.data[3]&0x1F == 7 && isDamageFrame == 0) {
				isDamageGopFrame = NO;
			}
			if (isDamageFrame == 1) {
				isDamageGopFrame = YES;
			}
			if (isDamageGopFrame == YES) {
				isRemoveMosaic = NO;
			}else {
				//NSLog(@"isRemoveMosaic = YES;");
				isRemoveMosaic = YES;
			}
        }

        av_free_packet(&packet);

	}
	return frameFinished;
}

-(void)convertFrameToRGB {	
	sws_scale (img_convert_ctx, pFrame->data, pFrame->linesize,
			   0, pCodecCtx->height,
			   picture.data, picture.linesize);	
}
int rgb_count = 0;
float minGrayPercent = 0;

-(void)makePictureBecomeGood:(CFDataRef)data{
	NSData *rgbData = (NSData *)data;
	char *ch = [rgbData bytes];
	float grayCount = 0,allColorCount = [rgbData length]/3.0;
	float maxGrayCount = 210,minGrayCount = 90;
	//找出图像中灰色的像素数目
	for (int i = 0; i < allColorCount*3; i += 3) {
		unsigned int a1 = ((unsigned int)ch[i] + 256)%256;
		unsigned int b1 = ((unsigned int)ch[i+1] + 256)%256;
		unsigned int c1 = ((unsigned int)ch[i+2] + 256)%256;
		
		if (a1 >= minGrayCount && a1 <= maxGrayCount && b1 >= minGrayCount && b1 <= maxGrayCount && c1 >= minGrayCount && c1 <= maxGrayCount) {
			grayCount++;
			
		}
		
	}
	updataGrayPercentCount++;
	if (updataGrayPercentCount > 1800) {	//大约每三分钟更新一次灰度值
		NSLog(@"updata");
		minGrayPercent = 0;
		updataGrayPercentCount = 0;
	}

	if (minGrayPercent == 0) {
		minGrayPercent = grayCount/allColorCount;
	}
	if (minGrayPercent > grayCount/allColorCount) {
		
		firstData = [[NSData alloc] initWithBytes:[secondData bytes] length:[secondData length]];
		secondData = [[NSData alloc] initWithBytes:[thirdData bytes] length:[thirdData length]];
		thirdData = [[NSData alloc] initWithBytes:[rgbData bytes] length:[rgbData length]];
		
	}
	
	NSLog(@"yyy %f %f %f",minGrayPercent,grayCount/allColorCount,minGrayPercent - grayCount/allColorCount);
	//如果确定为画质不好的图像，那么会用原来好的图像的一部分像素进行填充
	if (grayCount/allColorCount > 0.70 && grayCount/allColorCount -  minGrayPercent> 0.03) {//判断是否为画质差的图像
		
		char *ch = [rgbData bytes];
		
		if ([firstData length] > 0 && [secondData length] > 0) {
			unsigned char *ch1 = [firstData bytes];
			unsigned char *ch2 = [secondData bytes];
			for (int i = 0 ; i < [rgbData length]; i += 3) {
				unsigned int a1 = (unsigned int)ch1[i];
				unsigned int b1 = (unsigned int)ch1[i+1];
				unsigned int c1 = (unsigned int)ch1[i+2];
				
				unsigned int a2 = (unsigned int)ch2[i];
				unsigned int b2 = (unsigned int)ch2[i+1];
				unsigned int c2 = (unsigned int)ch2[i+2];
				if (abs(a1 - a2) < 15 && abs(b1 - b2) < 15 && abs(c1 - c2) < 15) {//替换掉像素
					ch[i] = ch1[i];
					ch[i+1] = ch1[i+1];
					ch[i+2] = ch1[i+2];
				}else {
					unsigned int a1 = ((unsigned int)ch[i] + 256)%256;
					unsigned int b1 = ((unsigned int)ch[i+1] + 256)%256;
					unsigned int c1 = ((unsigned int)ch[i+2] + 256)%256;
					
					if (a1 >= 110 && a1 <= 150 && b1 >= 110 && b1 <= 150 && c1 >= 110 && c1 <= 150) {
						continue;
						
					}
					i += 40*3;
				}
				
			}
		}
	}
	if (minGrayPercent > grayCount/allColorCount) {
		minGrayPercent = grayCount/allColorCount;
	}
}

-(UIImage *)imageFromAVPicture:(AVPicture)pict width:(int)width height:(int)height {
	CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
	CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, pict.data[0], pict.linesize[0]*height,kCFAllocatorNull);
	
	[self makePictureBecomeGood:data];
	
	CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGImageRef cgImage = CGImageCreate(width, 
									   height, 
									   8, 
									   24, 
									   pict.linesize[0], 
									   colorSpace, 
									   bitmapInfo, 
									   provider, 
									   NULL, 
									   NO, 
									   kCGRenderingIntentDefault);
	CGColorSpaceRelease(colorSpace);
	UIImage *image = [UIImage imageWithCGImage:cgImage];
	CGImageRelease(cgImage);
	CGDataProviderRelease(provider);
	CFRelease(data);
	
	return image;
}

-(void)savePPMPicture:(AVPicture)pict width:(int)width height:(int)height index:(int)iFrame {
    FILE *pFile;
	NSString *fileName;
    int  y;
	
	fileName = [Utilities documentsPath:[NSString stringWithFormat:@"image%04d.ppm",iFrame]];
    // Open file
    NSLog(@"write image file: %@",fileName);
    pFile=fopen([fileName cStringUsingEncoding:NSASCIIStringEncoding], "wb");
    if(pFile==NULL)
        return;
	
    // Write header
    fprintf(pFile, "P6\n%d %d\n255\n", width, height);
	
    // Write pixel data
    for(y=0; y<height; y++)
        fwrite(pict.data[0]+y*pict.linesize[0], 1, width*3, pFile);
	
    // Close file
    fclose(pFile);
}

@end
