#import <Cocoa/Cocoa.h>
#import <FinderSync/FinderSync.h>

@interface FinderSync : FIFinderSync
@end

@implementation FinderSync

- (instancetype)init {
    self = [super init];
    if (self) {
        [FIFinderSyncController defaultController].directoryURLs = [NSSet setWithObject:[NSURL fileURLWithPath:@"/"]];
        [self log:@"init"];
    }
    return self;
}

- (NSMenu *)menuForMenuKind:(FIMenuKind)menuKind {
    [self log:[NSString stringWithFormat:@"menu requested %ld", (long)menuKind]];
    if (menuKind != FIMenuKindContextualMenuForContainer && menuKind != FIMenuKindContextualMenuForItems) {
        return nil;
    }

    NSDictionary *settings = [self settingsObject];
    NSDictionary<NSString *, NSNumber *> *enabled = [self enabledFeaturesFromSettings:settings];
    NSString *language = [self languageFromSettings:settings];
    NSMenu *menu = [[NSMenu alloc] initWithTitle:[self localizedMenuTitleForLanguage:language]];

    BOOL addedFiles = NO;
    addedFiles = [self addItemToMenu:menu command:@"docx" enabled:enabled language:language] || addedFiles;
    addedFiles = [self addItemToMenu:menu command:@"xlsx" enabled:enabled language:language] || addedFiles;
    addedFiles = [self addItemToMenu:menu command:@"pptx" enabled:enabled language:language] || addedFiles;
    addedFiles = [self addItemToMenu:menu command:@"txt" enabled:enabled language:language] || addedFiles;
    addedFiles = [self addItemToMenu:menu command:@"md" enabled:enabled language:language] || addedFiles;

    BOOL wantsOpeners = [self isCommand:@"terminal" enabledIn:enabled] || [self isCommand:@"vscode" enabledIn:enabled];
    BOOL wantsOperations = [self isCommand:@"cut" enabledIn:enabled] || [self isCommand:@"paste" enabledIn:enabled] || [self isCommand:@"copyPath" enabledIn:enabled];
    BOOL addedOpeners = NO;
    if (addedFiles && (wantsOpeners || wantsOperations)) {
        [menu addItem:[NSMenuItem separatorItem]];
    }
    addedOpeners = [self addItemToMenu:menu command:@"terminal" enabled:enabled language:language] || addedOpeners;
    addedOpeners = [self addItemToMenu:menu command:@"vscode" enabled:enabled language:language] || addedOpeners;

    BOOL addedOperations = NO;
    if ((addedFiles || addedOpeners) && wantsOperations) {
        [menu addItem:[NSMenuItem separatorItem]];
    }
    addedOperations = [self addItemToMenu:menu command:@"cut" enabled:enabled language:language] || addedOperations;
    addedOperations = [self addItemToMenu:menu command:@"paste" enabled:enabled language:language] || addedOperations;
    addedOperations = [self addItemToMenu:menu command:@"copyPath" enabled:enabled language:language] || addedOperations;

    if (!addedFiles && !addedOpeners && !addedOperations) {
        NSMenuItem *disabled = [[NSMenuItem alloc] initWithTitle:[self localizedDisabledTitleForLanguage:language] action:nil keyEquivalent:@""];
        disabled.enabled = NO;
        [menu addItem:disabled];
    }
    return menu;
}

- (BOOL)addItemToMenu:(NSMenu *)menu command:(NSString *)command enabled:(NSDictionary<NSString *, NSNumber *> *)enabled language:(NSString *)language {
    if (![self isCommand:command enabledIn:enabled]) {
        return NO;
    }

    [menu addItem:[self itemWithTitle:[self localizedTitleForCommand:command language:language] command:command]];
    return YES;
}

- (BOOL)isCommand:(NSString *)command enabledIn:(NSDictionary<NSString *, NSNumber *> *)enabled {
    NSNumber *value = enabled[command];
    return !value || value.boolValue;
}

- (NSMenuItem *)itemWithTitle:(NSString *)title command:(NSString *)command {
    SEL action = @selector(newText:);
    if ([command isEqualToString:@"docx"]) {
        action = @selector(newWord:);
    } else if ([command isEqualToString:@"xlsx"]) {
        action = @selector(newExcel:);
    } else if ([command isEqualToString:@"pptx"]) {
        action = @selector(newPowerPoint:);
    } else if ([command isEqualToString:@"md"]) {
        action = @selector(newMarkdown:);
    } else if ([command isEqualToString:@"terminal"]) {
        action = @selector(openTerminal:);
    } else if ([command isEqualToString:@"vscode"]) {
        action = @selector(openVSCode:);
    } else if ([command isEqualToString:@"cut"]) {
        action = @selector(cutItems:);
    } else if ([command isEqualToString:@"paste"]) {
        action = @selector(pasteItems:);
    } else if ([command isEqualToString:@"copyPath"]) {
        action = @selector(copyAbsolutePath:);
    }
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""];
    return item;
}

- (void)newWord:(id)sender {
    [self log:@"newWord clicked"];
    [self sendToHost:@"docx"];
}

- (void)newExcel:(id)sender {
    [self log:@"newExcel clicked"];
    [self sendToHost:@"xlsx"];
}

- (void)newPowerPoint:(id)sender {
    [self log:@"newPowerPoint clicked"];
    [self sendToHost:@"pptx"];
}

- (void)newText:(id)sender {
    [self log:@"newText clicked"];
    [self sendToHost:@"txt"];
}

- (void)newMarkdown:(id)sender {
    [self log:@"newMarkdown clicked"];
    [self sendToHost:@"md"];
}

- (void)openTerminal:(id)sender {
    [self log:@"openTerminal clicked"];
    [self sendToHost:@"terminal"];
}

- (void)openVSCode:(id)sender {
    [self log:@"openVSCode clicked"];
    [self sendToHost:@"vscode"];
}

- (void)cutItems:(id)sender {
    [self log:@"cutItems clicked"];
    [self sendToHost:@"cut"];
}

- (void)pasteItems:(id)sender {
    [self log:@"pasteItems clicked"];
    [self sendToHost:@"paste"];
}

- (void)copyAbsolutePath:(id)sender {
    NSArray<NSString *> *paths = [self selectedPaths];
    if (paths.count == 0) {
        NSURL *directory = [self targetDirectory];
        paths = directory ? @[directory.path] : @[];
    }
    NSString *text = [paths componentsJoinedByString:@"\n"];
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:text forType:NSPasteboardTypeString];
    [self log:[NSString stringWithFormat:@"copied paths %@", text]];
}

- (NSURL *)uniqueFileInDirectory:(NSURL *)directory base:(NSString *)base ext:(NSString *)ext {
    NSUInteger index = 1;
    while (YES) {
        NSString *suffix = index == 1 ? @"" : [NSString stringWithFormat:@" %lu", (unsigned long)index];
        NSURL *candidate = [directory URLByAppendingPathComponent:[NSString stringWithFormat:@"%@%@.%@", base, suffix, ext]];
        if (![[NSFileManager defaultManager] fileExistsAtPath:candidate.path]) {
            return candidate;
        }
        index += 1;
    }
}

- (void)sendToHost:(NSString *)command {
    NSURL *directory = [self targetDirectory];
    if (!directory) {
        [self log:@"no target directory"];
        return;
    }

    NSArray<NSString *> *selectedPaths = [self selectedPaths];
    NSError *encodeError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:selectedPaths options:0 error:&encodeError];
    if (!data) {
        [self log:[NSString stringWithFormat:@"failed to encode selected paths: %@", encodeError]];
        return;
    }

    NSString *selectedPathsJSON = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!selectedPathsJSON) {
        [self log:@"failed to convert selected paths json"];
        return;
    }

    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.scheme = @"astracreate";
    components.host = @"run";
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"command" value:command],
        [NSURLQueryItem queryItemWithName:@"path" value:directory.path],
        [NSURLQueryItem queryItemWithName:@"selected" value:selectedPathsJSON]
    ];
    NSURL *url = components.URL;
    if (!url) {
        [self log:@"failed to build command url"];
        return;
    }

    [self log:[NSString stringWithFormat:@"open command url %@ %@", command, directory.path]];
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/open"];
    task.arguments = @[url.absoluteString];
    [self log:[NSString stringWithFormat:@"open url %@", url.absoluteString]];

    NSError *error = nil;
    if (![task launchAndReturnError:&error]) {
        [self log:[NSString stringWithFormat:@"failed to open command url: %@", error]];
    }
}

- (NSURL *)settingsFileURL {
    return [[[[NSFileManager defaultManager] homeDirectoryForCurrentUser]
             URLByAppendingPathComponent:@"Library/Application Support/AstraCreate" isDirectory:YES]
            URLByAppendingPathComponent:@"settings.json"];
}

- (NSDictionary *)settingsObject {
    NSURL *url = [self settingsFileURL];
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data) {
        return @{};
    }

    NSError *error = nil;
    NSDictionary *object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (![object isKindOfClass:[NSDictionary class]]) {
        [self log:[NSString stringWithFormat:@"failed to load settings: %@", error]];
        return @{};
    }
    return object;
}

- (NSDictionary<NSString *, NSNumber *> *)enabledFeaturesFromSettings:(NSDictionary *)settings {
    NSDictionary *enabled = settings[@"enabled"];
    if (![enabled isKindOfClass:[NSDictionary class]]) {
        return @{};
    }
    return enabled;
}

- (NSString *)languageFromSettings:(NSDictionary *)settings {
    NSString *language = settings[@"language"];
    if ([language isKindOfClass:[NSString class]] && [language isEqualToString:@"en"]) {
        return @"en";
    }
    return @"zh";
}

- (BOOL)isEnglish:(NSString *)language {
    return [language isEqualToString:@"en"];
}

- (NSString *)localizedMenuTitleForLanguage:(NSString *)language {
    return [self isEnglish:language] ? @"New Files" : @"新建常用文件";
}

- (NSString *)localizedDisabledTitleForLanguage:(NSString *)language {
    return [self isEnglish:language] ? @"AstraCreate is disabled" : @"AstraCreate 已关闭";
}

- (NSString *)localizedTitleForCommand:(NSString *)command language:(NSString *)language {
    BOOL english = [self isEnglish:language];
    if ([command isEqualToString:@"docx"]) {
        return english ? @"New Word Document" : @"新建 Word 文档";
    }
    if ([command isEqualToString:@"xlsx"]) {
        return english ? @"New Excel Workbook" : @"新建 Excel 表格";
    }
    if ([command isEqualToString:@"pptx"]) {
        return english ? @"New PowerPoint Presentation" : @"新建 PowerPoint 演示文稿";
    }
    if ([command isEqualToString:@"txt"]) {
        return english ? @"New Text File" : @"新建文本文件";
    }
    if ([command isEqualToString:@"md"]) {
        return english ? @"New Markdown File" : @"新建 Markdown 文件";
    }
    if ([command isEqualToString:@"terminal"]) {
        return english ? @"Open Terminal Here" : @"在此处打开终端";
    }
    if ([command isEqualToString:@"vscode"]) {
        return english ? @"Open Current Folder in VS Code" : @"在 VS Code 打开当前文件夹";
    }
    if ([command isEqualToString:@"cut"]) {
        return english ? @"Cut" : @"剪贴";
    }
    if ([command isEqualToString:@"paste"]) {
        return english ? @"Paste" : @"粘贴";
    }
    if ([command isEqualToString:@"copyPath"]) {
        return english ? @"Copy Absolute Path" : @"复制绝对路径";
    }
    return command;
}

- (NSArray<NSString *> *)selectedPaths {
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    NSArray<NSURL *> *selected = [[FIFinderSyncController defaultController] selectedItemURLs];
    for (NSURL *url in selected) {
        if (url.path.length > 0) {
            [paths addObject:url.path];
        }
    }
    return paths;
}

- (NSURL *)targetDirectory {
    NSURL *url = [[FIFinderSyncController defaultController] targetedURL];
    if (url) {
        [self log:[NSString stringWithFormat:@"targetedURL %@", url.path]];
        BOOL isDirectory = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:url.path isDirectory:&isDirectory] && isDirectory) {
            return url;
        }
        return [url URLByDeletingLastPathComponent];
    }

    NSArray<NSURL *> *selected = [[FIFinderSyncController defaultController] selectedItemURLs];
    [self log:[NSString stringWithFormat:@"selected count %lu", (unsigned long)selected.count]];
    NSURL *first = selected.firstObject;
    if (first) {
        BOOL isDirectory = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:first.path isDirectory:&isDirectory] && isDirectory) {
            return first;
        }
        return [first URLByDeletingLastPathComponent];
    }

    return [NSFileManager defaultManager].homeDirectoryForCurrentUser;
}

- (void)log:(NSString *)message {
    NSLog(@"AstraCreateFinderExtension: %@", message);
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], message];
    NSURL *url = [[[[NSFileManager defaultManager] homeDirectoryForCurrentUser]
                   URLByAppendingPathComponent:@"Library/Application Support/AstraCreate" isDirectory:YES]
                  URLByAppendingPathComponent:@"extension.log"];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    [[NSFileManager defaultManager] createDirectoryAtURL:[url URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingToURL:url error:nil];
        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle closeFile];
    } else {
        [data writeToURL:url atomically:YES];
    }
}

@end
