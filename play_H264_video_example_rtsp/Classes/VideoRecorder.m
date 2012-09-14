//
//  VideoRecorder.m
//  iFrameExtractor
//
//  Created by yrf on 12-7-28.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "VideoRecorder.h"


@implementation VideoRecorder

-(id)initWithVideoName:(NSString *)videoName videoWidth:(int)width videoHeight:(int)height videoCode:(enum CodecID)codec_id{
	NSLog(@"initWithVideoName");
	self = [super init];
	if (self != nil) {
		
		av_register_all();
		
		videoName = [self documentsPath:videoName];

		NSFileManager *fm = [NSFileManager defaultManager];
		//NSString * sourcePath = [[NSString alloc]initWithFormat:@"%@/%@.mov",docPath,@"source"];
		[fm removeItemAtPath:videoName error:nil];
		[fm createFileAtPath:videoName contents:nil attributes:nil];
		
		outFormatContext = avformat_alloc_context();
		if (outFormatContext == NULL) {
			NSLog(@"outFormatContext NULL");
		}
	
		AVOutputFormat *pOutputFormat = av_guess_format(NULL, [videoName cStringUsingEncoding:NSASCIIStringEncoding], NULL);
		if (pOutputFormat == NULL) {
			NSLog(@"pOutputFormat NULL");
		}
		outFormatContext->oformat = pOutputFormat;
		
		
		AVStream *video_st1 = av_new_stream(outFormatContext, 0);
		
		outCodecContext = video_st1->codec;
		
		outCodecContext->me_range = 16;
		outCodecContext->max_qdiff = 4;
		outCodecContext->qmin = 10;
		outCodecContext->qmax = 51;
		outCodecContext->qcompress = 0.6; 
		
		outCodecContext->codec_id = codec_id;
		outCodecContext->codec_type = AVMEDIA_TYPE_VIDEO;
		//outCodecContext->bit_rate = 1000000;
		outCodecContext->width = width;
		outCodecContext->height = height;
		//outCodecContext->gop_size = 50;	//用于帧间压缩时，比如12，是指12个图片的帧间预测
		if (codec_id == CODEC_ID_H264) {
			outCodecContext->pix_fmt = PIX_FMT_YUVJ420P;	//像素格式，表示屏幕的显示方式
		}else {
			outCodecContext->pix_fmt = PIX_FMT_YUV420P;	//像素格式，表示屏幕的显示方式
		}

		
		outCodecContext->time_base.den = 25;	//跟播放时间有关
		outCodecContext->time_base.num = 1;
		outCodecContext->max_b_frames = 0;
		
		outCodecContext->idct_algo = FF_IDCT_ARM;
		
		if(!strcmp(pOutputFormat->name, "mp4") || !strcmp(pOutputFormat->name, "mov") || !strcmp(pOutputFormat->name, "3gp"))
			outCodecContext->flags |= CODEC_FLAG_GLOBAL_HEADER;
		if(av_set_parameters(outFormatContext, NULL) < 0){
			perror("set parameter");
			return -1;
		}
		//av_dump_format(outFormatContext, 0, [sourcePath cStringUsingEncoding:NSASCIIStringEncoding], 1);
		dump_format(outFormatContext, 0, [videoName cStringUsingEncoding:NSASCIIStringEncoding], 1);
		
		AVCodec *codec;
		//avcodec_register(codec);
		avcodec_register_all();
		codec = avcodec_find_encoder(outCodecContext->codec_id);
		NSLog(@"id:%d",outCodecContext->codec_id);
		if(NULL == codec){
			perror("find encoder");
			return -1;
		}
		
		if(avcodec_open2(outCodecContext, codec ,NULL) < 0){
			NSLog(@"not avcodec_open");
			return -1;
		}
		NSLog(@"avcodec_open");
		if(!(pOutputFormat->flags & AVFMT_NOFILE)){
			if(url_fopen(&outFormatContext->pb, [videoName cStringUsingEncoding:NSASCIIStringEncoding], URL_WRONLY)< 0){
				perror("open file");
				return -1;
			}
		}
		
		int writeResult = avformat_write_header(outFormatContext,NULL);
		
		NSLog(@"start %d",writeResult);
		if (codec_id == CODEC_ID_H264) {
			isKeyFrame= NO;
		}
	}
	return self;
}

-(void)addVideoFrame:(uint8_t*)frameData frameLength:(int)length{

	if (isKeyFrame == NO) {
		[self findKeyFrame:frameData];	//如果不是关键帧开始，就返回，继续等待关键帧
		if (isKeyFrame == NO) {
			return;
		}
	}
	
	AVPacket packet;
	av_init_packet(&packet);
	packet.data = frameData;
	packet.size = length;
	av_write_frame(outFormatContext, &packet);
}

-(void)stopRecord{
	
	av_write_trailer(outFormatContext);
}
- (void) dealloc
{
	avformat_free_context(outFormatContext);
	[super dealloc];
}

-(void)findKeyFrame:(uint8_t*)frameData{
	//通过判断帧数据头部，得到是否为关键帧
	if (frameData[2] == 1 && (frameData[3]&0x1F) == 7) {
		isKeyFrame = YES;
	}else if (frameData[3] == 1 && (frameData[4]&0x1F) == 7) {
		isKeyFrame = YES;
	}
}

-(NSString *)documentsPath:(NSString *)filename {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	return [documentsDirectory stringByAppendingPathComponent:filename];
}
@end
