#import <Foundation/Foundation.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

static BOOL ACDiagnosticWrite(int fd, NSData *data) {
    size_t offset = 0;
    while (offset < data.length) {
        ssize_t count = write(fd, (const char *)data.bytes + offset, data.length - offset);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) return NO;
        offset += count;
    }
    return YES;
}

static NSString *ACDiagnosticVersion(NSString *key) {
    id value = [[NSBundle mainBundle] objectForInfoDictionaryKey:key];
    if (![value isKindOfClass:[NSString class]] || [value length] > 32) return @"unknown";
    NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"^[0-9]+(?:\\.[0-9]+)*$" options:0 error:NULL];
    return [pattern numberOfMatchesInString:value options:0 range:NSMakeRange(0, [value length])] == 1 ? value : @"unknown";
}

/// Only fixed event names, numeric values and standard error domains are saved.
static void ACDiagnosticRecord(NSURL *directory, NSString *event, NSError *error, NSNumber *value) {
    NSArray *events = @[@"extensionStarted", @"menuRequested", @"hostLaunchFailed", @"commandEncodingFailed",
                        @"clipboardWriteFailed", @"settingsReadFailed"];
    if (![events containsObject:event]) return;
    @synchronized([NSFileManager defaultManager]) {
        NSMutableDictionary *row = [@{@"schema": @1, @"component": @"extension", @"event": event,
            @"version": ACDiagnosticVersion(@"CFBundleShortVersionString"), @"build": ACDiagnosticVersion(@"CFBundleVersion"),
            @"time": [[[NSISO8601DateFormatter alloc] init] stringFromDate:[NSDate date]]} mutableCopy];
        if (value) row[@"value"] = value;
        if (error) {
            row[@"errorCode"] = @(error.code);
            row[@"errorDomain"] = [@[NSCocoaErrorDomain, NSPOSIXErrorDomain, NSOSStatusErrorDomain] containsObject:error.domain] ? error.domain : @"other";
        }
        NSMutableData *data = [[NSJSONSerialization dataWithJSONObject:row options:NSJSONWritingSortedKeys error:NULL] mutableCopy];
        if (!data) return;
        [data appendBytes:"\n" length:1];
        if (![[NSFileManager defaultManager] createDirectoryAtURL:directory withIntermediateDirectories:YES
            attributes:@{NSFilePosixPermissions: @0700} error:NULL]) return;
        int fd = open([[directory URLByAppendingPathComponent:@"extension.jsonl"].path fileSystemRepresentation], O_CREAT | O_RDWR | O_NOFOLLOW, 0600);
        if (fd < 0) return;
        if (flock(fd, LOCK_EX) != 0) { close(fd); return; }
        struct stat info;
        BOOL valid = fstat(fd, &info) == 0 && S_ISREG(info.st_mode);
        if (valid && info.st_size + data.length > 256 * 1024) {
            off_t start = MAX(0, info.st_size - 128 * 1024);
            NSMutableData *tail = [NSMutableData dataWithLength:128 * 1024];
            ssize_t count = pread(fd, tail.mutableBytes, tail.length, start);
            tail.length = count > 0 ? count : 0;
            if (start > 0 && tail.length > 0) {
                const unsigned char *bytes = tail.bytes;
                NSUInteger index = 0;
                while (index < tail.length && bytes[index] != '\n') index++;
                [tail replaceBytesInRange:NSMakeRange(0, MIN(index + 1, tail.length)) withBytes:NULL length:0];
            }
            valid = ftruncate(fd, 0) == 0 && lseek(fd, 0, SEEK_SET) == 0 && ACDiagnosticWrite(fd, tail);
        } else if (valid) {
            valid = lseek(fd, 0, SEEK_END) >= 0;
        }
        if (valid) ACDiagnosticWrite(fd, data);
        flock(fd, LOCK_UN);
        close(fd);
    }
}
