//
//  VideoRecorder.h
//  iFrameExtractor
//
//  Created by yrf on 12-7-28.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "libavformat/avformat.h"

@interface VideoRecorder : NSObject {
	AVFormatContext *outFormatContext;
	AVCodecContext *outCodecContext;
	
	BOOL isKeyFrame;
}

-(id)initWithVideoName:(NSString *)videoName videoWidth:(int)width videoHeight:(int)height videoCode:(enum CodecID)codec_id;
/*
 初始化视频参数
 参数：
 videoName:视频的名字。比如你要保存成3gp格式，@“test.3pg”,默认视频保存在应用程序Documents目录下
 width：视频的宽度
 height：视频的高度
 codec_id：视频的编码方式
 返回:
 返回一个VideoRecorder对象
 说明：
 每次录制视频之前都需要初始化一次
 */
-(void)addVideoFrame:(uint8_t*)frameData frameLength:(int)length;
/*
加入一帧视频数据，保存到文件中
参数：
videoData:帧数据
length:视频长度
说明：如果一开始的时候加入的是非关键帧，那么函数不会把这帧数据加入到文件中，因为这会影响视频质量。
系统会等到一个关键帧的时候才开始把帧数据加入到文件中。
目前此机制，只支持H264编码的视频数据
*/
-(void)stopRecord;
/*
录像完成之后，需要调用此函数才能成功保存录像
说明：调用此函数之后，请release掉对象
 */
@end
