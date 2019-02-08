#import "VideoConverterPlugin.h"
#import <AVFoundation/AVFoundation.h>

#define WEAK_SELF_INIT __weak __typeof(self) wself = self;

@interface NSError (FlutterError)
@property(readonly, nonatomic) FlutterError *flutterError;
@end

@implementation NSError (FlutterError)
- (FlutterError *)flutterError {
    return [FlutterError errorWithCode:[NSString stringWithFormat:@"Error %d", (int)self.code]
                               message:self.domain
                               details:self.localizedDescription];
}
@end

@interface VideoConverterPlugin () <FlutterStreamHandler>
@end

@implementation VideoConverterPlugin {
    FlutterEventSink _eventSink;
    AVAssetExportSession *_exportSession;
    NSString *_currentFilePath;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"com.lych/video_converter_methods"
            binaryMessenger:[registrar messenger]];
    VideoConverterPlugin* instance = [[VideoConverterPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];

    FlutterEventChannel* streamChannel =
    [FlutterEventChannel eventChannelWithName:@"com.lych/video_converter_events"
                              binaryMessenger:[registrar messenger]];
    [streamChannel setStreamHandler:instance];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"convert" isEqualToString:call.method]) {
      if (_exportSession != nil) {
          NSError *error =
          [NSError errorWithDomain:NSCocoaErrorDomain
                              code:NSURLErrorResourceUnavailable
                          userInfo:@{NSLocalizedDescriptionKey:@"Another video is converting!"}];
          result([error flutterError]);
      }
      NSDictionary *arguments = [call arguments];
      _currentFilePath = arguments[@"filePath"];
      NSURL *fileUrl = [NSURL fileURLWithPath:_currentFilePath];
      
      AVURLAsset *anAsset = [[AVURLAsset alloc] initWithURL:fileUrl
                                                    options:@{AVURLAssetPreferPreciseDurationAndTimingKey:@YES}];
      NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:anAsset];
      if ([compatiblePresets containsObject:AVAssetExportPresetLowQuality]) {
          NSString *newFileName = [NSString stringWithFormat:@"c_%@", [fileUrl lastPathComponent]];
          
          NSURL *convertedFilesDirectoryURL = [[fileUrl URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"converted"];
          NSURL *outputFileURL = [convertedFilesDirectoryURL URLByAppendingPathComponent:newFileName];
          
          [[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:nil];
          [[NSFileManager defaultManager] createDirectoryAtURL:convertedFilesDirectoryURL
                                   withIntermediateDirectories:YES attributes:nil error:nil];
        
          _exportSession = [[AVAssetExportSession alloc] initWithAsset:anAsset presetName:AVAssetExportPresetHighestQuality];
          _exportSession.outputURL = outputFileURL;
          _exportSession.outputFileType = AVFileTypeMPEG4;
          
          CMTime start = CMTimeMakeWithSeconds(1.0, 600);
          CMTime duration = CMTimeMakeWithSeconds(5.0, 600);
          CMTimeRange range = CMTimeRangeMake(start, duration);
          _exportSession.timeRange = range;
          
          WEAK_SELF_INIT
          [_exportSession exportAsynchronouslyWithCompletionHandler:^{
              self->_eventSink([wself statusFromExportSession:self->_exportSession]);
              self->_exportSession = nil;
          }];
          
          _eventSink(@{@"status": @"inProcess",
                       @"filePath": _currentFilePath});
      }
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (NSDictionary *)statusFromExportSession:(AVAssetExportSession *)exportSession {
    switch ([exportSession status]) {
        case AVAssetExportSessionStatusFailed:
            return @{@"status": @"failed",
                     @"filePath": _currentFilePath,
                     @"errorDescription": [[exportSession error] localizedDescription]};
            break;
        case AVAssetExportSessionStatusCompleted:
            return @{@"status": @"success",
                     @"filePath": _currentFilePath,
                     @"outputFilePath": [exportSession.outputURL absoluteString]};
            break;
         default:
             break;
    }
    return @{@"status": @"failed",
             @"filePath": _currentFilePath,
             @"errorDescription": [[exportSession error] localizedDescription]};
}

#pragma mark - <FlutterStreamHandler>

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
    _eventSink = eventSink;
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    _eventSink = nil;
    return nil;
}

@end
