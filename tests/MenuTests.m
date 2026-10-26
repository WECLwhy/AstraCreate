#import "../src/FinderSyncObjC.m"

@interface TestFinderSync : FinderSync
@property NSDictionary *testSettings;
@property NSURL *testClipboard;
@property NSArray *testSelection;
@property NSUInteger hostLaunchCount;
@property BOOL testNoDirectory;
@property NSString *lastCommand;
@property NSDictionary *lastContext;
@end
@implementation TestFinderSync
// Menu construction needs no live Finder connection or user's settings.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)init { return self; }
#pragma clang diagnostic pop
- (NSDictionary *)settingsObject { return self.testSettings ?: @{}; }
- (void)log:(NSString *)message {}
- (void)recordEvent:(NSString *)event error:(NSError *)error value:(NSNumber *)value {}
- (NSURL *)targetDirectory { return self.testNoDirectory ? nil : [NSURL fileURLWithPath:@"/private/tmp"]; }
- (NSArray *)selectedPaths { return self.testSelection ?: @[@"/private/tmp/menu-test.txt"]; }
- (NSArray *)pendingCutPaths { return self.testClipboard ? [super pendingCutPaths] : @[@"/private/tmp/menu-test.txt"]; }
- (NSURL *)clipboardFileURL { return self.testClipboard ?: [super clipboardFileURL]; }
- (void)sendToHost:(NSString *)command sender:(id)sender { self.hostLaunchCount++; self.lastCommand = command; self.lastContext = [self contextForSender:sender]; }
@end

static void check(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "%s\n", message.UTF8String);
        exit(1);
    }
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        TestFinderSync *extension = [TestFinderSync new];
        NSArray *commands = @[@"docx", @"xlsx", @"pptx", @"txt", @"md", @"terminal", @"vscode", @"cut", @"paste", @"copyPath"];
        NSArray *actions = @[@"newWord:", @"newExcel:", @"newPowerPoint:", @"newText:", @"newMarkdown:", @"openTerminal:", @"openVSCode:", @"cutItems:", @"pasteItems:", @"copyAbsolutePath:"];
        NSUInteger cases = 0;
        for (NSString *language in @[@"zh", @"en"]) {
            for (NSNumber *grouping in @[@YES, @NO]) {
                for (NSUInteger mask = 0; mask < (1 << commands.count); mask++) {
                    NSMutableDictionary *enabled = [NSMutableDictionary dictionary];
                    NSMutableArray *expected = [NSMutableArray array];
                    NSUInteger files = 0, operations = 0;
                    for (NSUInteger i = 0; i < commands.count; i++) {
                        BOOL on = (mask & (1 << i)) != 0;
                        enabled[commands[i]] = @(on);
                        if (on) {
                            [expected addObject:actions[i]];
                            if (i < 5) files++; else operations++;
                        }
                    }
                    extension.testSettings = @{@"enabled": enabled, @"language": language, @"groupNewFiles": grouping};
                    for (NSNumber *kind in @[@(FIMenuKindContextualMenuForContainer), @(FIMenuKindContextualMenuForItems), @(FIMenuKindToolbarItemMenu)]) {
                        NSMenu *menu = [extension menuForMenuKind:kind.integerValue];
                        check((menu == nil) == (mask == 0 && kind.integerValue != FIMenuKindToolbarItemMenu), @"All-off menu must be absent");
                        NSUInteger count = operations + (grouping.boolValue && files ? 1 : files) + (kind.integerValue == FIMenuKindToolbarItemMenu ? 1 : 0);
                        check(menu.numberOfItems == count, @"Unexpected top-level item count");
                        NSMutableArray *actual = [NSMutableArray array];
                        for (NSMenuItem *item in menu.itemArray) {
                            if (item.action == @selector(openSettings:)) continue;
                            check(!item.isSeparatorItem && item.title.length > 0, @"Blank top-level row");
                            if (item.submenu) {
                                check(grouping.boolValue && item == menu.itemArray.firstObject && files > 0, @"Unexpected submenu");
                                check([item.title isEqualToString:[language isEqual:@"en"] ? @"New File" : @"新建文件"], @"Submenu localization");
                                check(item.submenu.numberOfItems == files, @"Submenu feature filtering");
                                for (NSMenuItem *child in item.submenu.itemArray) {
                                    check(!child.isSeparatorItem && child.title.length > 0 && child.action != NULL, @"Invalid child");
                                    [actual addObject:NSStringFromSelector(child.action)];
                                }
                            } else {
                                check(item.action != NULL, @"Missing action");
                                [actual addObject:NSStringFromSelector(item.action)];
                            }
                        }
                        check([actual isEqual:expected], @"Action routing or ordering changed");
                        cases++;
                    }
                }
            }
        }
        for (NSDictionary *settings in @[@{}, @{@"enabled": @{@"txt": @NO}, @"language": @"en"}, @{@"enabled": @{@"docx": [NSNull null]}, @"groupNewFiles": [NSNull null]}]) {
            extension.testSettings = settings;
            NSMenu *menu = [extension menuForMenuKind:FIMenuKindContextualMenuForContainer];
            check(menu.itemArray.firstObject.submenu != nil, @"Legacy/invalid settings must default to grouped menu");
        }
        NSArray *developerCommands = @[@"json", @"js", @"ts", @"vue", @"html", @"css", @"yaml"];
        NSArray *developerActions = @[@"newJSON:", @"newJavaScript:", @"newTypeScript:", @"newVue:", @"newHTML:", @"newCSS:", @"newYAML:"];
        NSArray *developerNames = @[@"JSON", @"JavaScript", @"TypeScript", @"Vue", @"HTML", @"CSS", @"YAML"];
        NSUInteger developerCases = 0;
        for (NSString *language in @[@"zh", @"en"]) {
            for (NSNumber *grouping in @[@YES, @NO]) {
                for (NSUInteger mask = 0; mask < (1 << developerCommands.count); mask++) {
                    NSMutableDictionary *enabled = [NSMutableDictionary dictionary];
                    for (NSString *command in commands) enabled[command] = @NO;
                    NSMutableArray *expected = [NSMutableArray array];
                    for (NSUInteger i = 0; i < developerCommands.count; i++) {
                        enabled[developerCommands[i]] = @((mask & (1 << i)) != 0);
                        if ([enabled[developerCommands[i]] boolValue]) [expected addObject:developerActions[i]];
                    }
                    extension.testSettings = @{@"enabled": enabled, @"language": language, @"groupNewFiles": grouping};
                    for (NSNumber *kind in @[@(FIMenuKindContextualMenuForContainer), @(FIMenuKindContextualMenuForItems), @(FIMenuKindToolbarItemMenu)]) {
                        NSMenu *menu = [extension menuForMenuKind:kind.integerValue];
                        NSMutableArray *actual = [NSMutableArray array];
                        for (NSMenuItem *item in menu.itemArray) {
                            if (item.action == @selector(openSettings:)) continue;
                            for (NSMenuItem *child in item.submenu ? item.submenu.itemArray : @[item]) {
                                [actual addObject:NSStringFromSelector(child.action)];
                                NSUInteger index = [developerActions indexOfObject:NSStringFromSelector(child.action)];
                                check(index != NSNotFound, @"Unexpected or PDF developer action");
                                NSString *title = [NSString stringWithFormat:[language isEqual:@"en"] ? @"New %@ File" : @"新建 %@ 文件", developerNames[index]];
                                check([child.title isEqual:title] && child.enabled, @"Developer localization or availability");
                                NSMenuItem *finderCopy = [[NSMenuItem alloc] initWithTitle:child.title action:child.action keyEquivalent:@""];
                                finderCopy.tag = child.tag;
                                void (*invoke)(id, SEL, id) = (void *)[extension methodForSelector:child.action];
                                invoke(extension, child.action, finderCopy);
                                check([extension.lastCommand isEqual:developerCommands[index]], @"Developer command routed incorrectly");
                                check([extension.lastContext[@"path"] isEqual:@"/private/tmp"], @"Copied developer item lost its directory snapshot");
                            }
                        }
                        check([actual isEqual:expected], @"Developer feature filtering/order");
                        check((menu == nil) == (mask == 0 && kind.integerValue != FIMenuKindToolbarItemMenu), @"Disabled developer formats left an empty menu");
                        developerCases++;
                    }
                }
            }
        }
        // All old and new features together, plus a missing/null opt-in value.
        NSMutableDictionary *all = [NSMutableDictionary dictionary];
        for (NSString *command in commands) all[command] = @YES;
        for (NSString *command in developerCommands) all[command] = @YES;
        extension.testSettings = @{@"enabled": all};
        NSMenu *allMenu = [extension menuForMenuKind:FIMenuKindContextualMenuForContainer];
        check(allMenu.itemArray.firstObject.submenu.numberOfItems == 12 && allMenu.numberOfItems == 6, @"All-enabled feature set missing formats or actions");
        all[@"json"] = [NSNull null];
        [all removeObjectForKey:@"js"];
        extension.testSettings = @{@"enabled": all};
        check([extension menuForMenuKind:FIMenuKindContextualMenuForContainer].itemArray.firstObject.submenu.numberOfItems == 10, @"Missing or invalid new settings must stay off");
        extension.hostLaunchCount = 0;
        printf("Passed %lu developer-format menu combinations and copied-item command routing; new formats opt-in and no PDF.\n", (unsigned long)developerCases);
        check(extension.toolbarItemImage != nil && extension.toolbarItemName.length > 0, @"Toolbar identity missing");
        check([extension menuForMenuKind:FIMenuKindContextualMenuForSidebar] == nil, @"Unsupported menu kind");
        NSURL *scratch = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString];
        [[NSFileManager defaultManager] createDirectoryAtURL:scratch withIntermediateDirectories:YES attributes:nil error:NULL];
        NSURL *source = [scratch URLByAppendingPathComponent:@"cut-probe.txt"];
        NSData *original = [@"do not change this file" dataUsingEncoding:NSUTF8StringEncoding];
        [original writeToURL:source atomically:YES];
        extension.testClipboard = [scratch URLByAppendingPathComponent:@"clipboard.json"];
        extension.testSelection = @[source.path];
        extension.testSettings = @{};
        NSMenu *contextMenu = [extension menuForMenuKind:FIMenuKindContextualMenuForItems];
        NSMenuItem *cutItem = nil;
        NSMenuItem *pasteItem = nil;
        for (NSMenuItem *item in contextMenu.itemArray) {
            if (item.action == @selector(cutItems:)) cutItem = item;
            if (item.action == @selector(pasteItems:)) pasteItem = item;
        }
        check(cutItem.enabled && !pasteItem.enabled, @"Empty clipboard or selection enabled state");
        extension.testSelection = @[]; // Simulate Finder selection changing after the menu opens.
        NSMenuItem *finderCopy = [[NSMenuItem alloc] initWithTitle:cutItem.title action:cutItem.action keyEquivalent:@""];
        finderCopy.tag = cutItem.tag; // Finder transfers supported fields only.
        check(finderCopy.representedObject == nil, @"Test must simulate loss of representedObject");
        [extension cutItems:finderCopy];
        check(extension.hostLaunchCount == 0, @"Cut must not launch the host");
        check([[NSData dataWithContentsOfURL:source] isEqual:original], @"Cut changed file contents");
        check([[extension pendingCutPaths] isEqual:@[source.path]], @"Cut did not retain the menu selection snapshot");
        NSMenu *toolbarMenu = [extension menuForMenuKind:FIMenuKindToolbarItemMenu];
        for (NSMenuItem *item in toolbarMenu.itemArray) {
            if (item.action == @selector(cutItems:)) check(!item.enabled, @"Cut enabled without selection");
            if (item.action == @selector(pasteItems:)) check(item.enabled && [item.title containsString:@"1"], @"Pending move count missing");
        }
        extension.testNoDirectory = YES;
        NSMenu *unavailable = [extension menuForMenuKind:FIMenuKindToolbarItemMenu];
        for (NSMenuItem *item in unavailable.itemArray) {
            check(item.action == @selector(openSettings:) ? item.enabled : !item.enabled, @"Toolbar actions must be disabled without a known directory");
        }
        [[NSFileManager defaultManager] removeItemAtURL:scratch error:NULL];
        printf("Passed %lu menu combinations plus legacy/invalid settings and unsupported context checks.\n", (unsigned long)cases);
    }
    return 0;
}
