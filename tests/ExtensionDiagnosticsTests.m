#import "../src/DiagnosticLog.h"

int main(void) {
    @autoreleasepool {
        NSURL *root = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString];
        NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:513 userInfo:@{NSLocalizedDescriptionKey: @"/Users/private/secret.docx"}];
        ACDiagnosticRecord(root, @"hostLaunchFailed", error, @7);
        NSURL *log = [root URLByAppendingPathComponent:@"extension.jsonl"];
        NSString *text = [NSString stringWithContentsOfURL:log encoding:NSUTF8StringEncoding error:NULL];
        NSCAssert([text containsString:@"513"] && ![text containsString:@"secret"] && ![text containsString:@"/Users"], @"Privacy violation");
        for (int i = 0; i < 3500; i++) ACDiagnosticRecord(root, @"menuRequested", nil, @(i));
        NSData *data = [NSData dataWithContentsOfURL:log];
        NSCAssert(data.length <= 256 * 1024, @"Unbounded log");
        for (NSString *line in [[NSString stringWithContentsOfURL:log encoding:NSUTF8StringEncoding error:NULL] componentsSeparatedByString:@"\n"]) {
            if (!line.length) continue;
            NSCAssert([NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL] != nil, @"Broken rotation record");
        }
        ACDiagnosticRecord(root, @"/Users/private/secret.docx", nil, nil);
        NSCAssert([[NSData dataWithContentsOfURL:log] isEqualToData:data], @"Unknown event accepted");
        [[NSFileManager defaultManager] removeItemAtURL:root error:NULL];
        puts("Passed extension diagnostic error metadata, privacy allowlist and bounded retention checks.");
    }
    return 0;
}
