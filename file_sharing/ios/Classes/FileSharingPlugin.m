#import "FileSharingPlugin.h"

@implementation FileSharingPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"com.lych/file_sharing_methods"
            binaryMessenger:[registrar messenger]];
  FileSharingPlugin* instance = [[FileSharingPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"share" isEqualToString:call.method]) {
      NSDictionary *arguments = [call arguments];
      
      NSArray *activityItems = [NSArray arrayWithObjects:[NSURL fileURLWithPath:arguments[@"filePath"]], nil];
      UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
      UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
      if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
          [vc presentViewController:activityController animated:YES completion:nil];
      }
      else {
          UIPopoverController *popup = [[UIPopoverController alloc] initWithContentViewController:activityController];
          [popup presentPopoverFromRect:CGRectMake(vc.view.frame.size.width/2, vc.view.frame.size.height/4, 0, 0)inView:vc.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
      }
      result(nil);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

@end
