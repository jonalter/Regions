

#import "FileLogger.h"

@implementation FileLogger
- (void)dealloc {
    [logFile release]; logFile = nil;
    [super dealloc];
}

- (id) init {
    if (self == [super init]) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"application.log"];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:filePath])
            [fileManager createFileAtPath:filePath
                                 contents:nil
                               attributes:nil];
        logFile = [[NSFileHandle fileHandleForWritingAtPath:filePath] retain];
        [logFile seekToEndOfFile];
    }
    
    return self;
}

- (void)log:(NSString *)format, ... {
    va_list ap;
    va_start(ap, format);
    
    NSString *message = [[NSString alloc] initWithFormat:format arguments:ap];
    NSLog(message);
    [logFile writeData:[[message stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [logFile synchronizeFile];
    
    [message release];
}

+ (FileLogger *)sharedInstance {
    static FileLogger *instance = nil;
    if (instance == nil) instance = [[FileLogger alloc] init];
    return instance;
}
@end