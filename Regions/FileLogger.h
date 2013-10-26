

@interface FileLogger : NSObject {
    NSFileHandle *logFile;
}
+ (FileLogger *)sharedInstance;
- (void)log:(NSString *)format, ...;
@end

#define FLog(fmt, ...) [[FileLogger sharedInstance] log:fmt, ##__VA_ARGS__]
