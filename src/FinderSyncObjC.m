#import <Cocoa/Cocoa.h>
#import <FinderSync/FinderSync.h>

@interface FinderSync : FIFinderSync
@property NSMutableDictionary<NSNumber *, NSDictionary *> *menuContexts;
@property NSInteger menuContextSerial;
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

- (NSString *)toolbarItemName { return @"AstraCreate"; }

- (NSString *)toolbarItemToolTip {
    return [self isEnglish:[self languageFromSettings:[self settingsObject]]] ? @"Create files and manage this folder" : @"新建文件与文件夹操作";
}

- (NSImage *)toolbarItemImage {
    NSImage *image = [NSImage imageWithSystemSymbolName:@"doc.badge.plus" accessibilityDescription:@"AstraCreate"];
    image.template = YES;
    return image;
}

- (NSMenu *)menuForMenuKind:(FIMenuKind)menuKind {
    [self log:[NSString stringWithFormat:@"menu requested %ld", (long)menuKind]];
    if (menuKind != FIMenuKindContextualMenuForContainer && menuKind != FIMenuKindContextualMenuForItems && menuKind != FIMenuKindToolbarItemMenu) {
        return nil;
    }

    NSDictionary *settings = [self settingsObject];
    NSDictionary<NSString *, NSNumber *> *enabled = [self enabledFeaturesFromSettings:settings];
    NSString *language = [self languageFromSettings:settings];
    NSURL *directory = [self targetDirectory];
    NSArray *selection = menuKind == FIMenuKindContextualMenuForContainer ? @[] : [self selectedPaths];
    // Snapshot the menu's context; a later focus/selection change must not retarget actions.
    NSDictionary *context = @{@"path": directory.path ?: @"", @"selected": selection};
    NSMenu *menu = [[NSMenu alloc] initWithTitle:[self localizedMenuTitleForLanguage:language]];

    // Keep the extension menu compact, without blank separator rows.
    NSNumber *savedGrouping = settings[@"groupNewFiles"];
    BOOL groupNewFiles = ![savedGrouping isKindOfClass:[NSNumber class]] || savedGrouping.boolValue;
    NSMenu *filesMenu = groupNewFiles ? [[NSMenu alloc] initWithTitle:@""] : menu;
    for (NSString *command in @[@"docx", @"xlsx", @"pptx", @"txt", @"md"]) {
        [self addItemToMenu:filesMenu command:command enabled:enabled language:language];
    }
    if (groupNewFiles && filesMenu.numberOfItems > 0) {
        NSString *title = [self isEnglish:language] ? @"New File" : @"新建文件";
        NSMenuItem *parent = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
        parent.submenu = filesMenu;
        [menu addItem:parent];
    }
    for (NSString *command in @[@"terminal", @"vscode", @"cut", @"paste", @"copyPath"]) {
        [self addItemToMenu:menu command:command enabled:enabled language:language];
    }
    if (!self.menuContexts) self.menuContexts = [NSMutableDictionary dictionary];
    self.menuContextSerial += 1;
    self.menuContexts[@(self.menuContextSerial)] = context;
    // Finder copies menu items; tag survives this bridge, representedObject does not.
    if (self.menuContexts.count > 64) {
        NSNumber *oldest = [[self.menuContexts.allKeys sortedArrayUsingSelector:@selector(compare:)] firstObject];
        [self.menuContexts removeObjectForKey:oldest];
    }
    [self configureMenu:menu context:context language:language];
    if (menuKind == FIMenuKindToolbarItemMenu) {
        if (!directory) {
            NSMenuItem *hint = [[NSMenuItem alloc] initWithTitle:[self isEnglish:language] ? @"Open a regular folder to use these actions" : @"请打开普通文件夹后使用" action:nil keyEquivalent:@""];
            hint.enabled = NO;
            [menu insertItem:hint atIndex:0];
        }
        NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:[self isEnglish:language] ? @"AstraCreate Settings…" : @"AstraCreate 设置…" action:@selector(openSettings:) keyEquivalent:@""];
        [menu addItem:settingsItem];
    }
    // Do not leave a placeholder or an empty submenu when everything is off.
    if (menu.numberOfItems == 0) {
        return nil;
    }
    return menu;
}

- (NSURL *)clipboardFileURL {
    return [[[self settingsFileURL] URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"clipboard.json"];
}

- (NSArray<NSString *> *)pendingCutPaths {
    NSData *data = [NSData dataWithContentsOfURL:[self clipboardFileURL]];
    NSDictionary *payload = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    if (![payload isKindOfClass:[NSDictionary class]] || ![payload[@"operation"] isEqual:@"move"] || ![payload[@"paths"] isKindOfClass:[NSArray class]]) return @[];
    NSMutableArray *paths = [NSMutableArray array];
    for (id path in payload[@"paths"]) {
        if ([path isKindOfClass:[NSString class]]) [paths addObject:path];
    }
    return paths;
}

- (void)configureMenu:(NSMenu *)menu context:(NSDictionary *)context language:(NSString *)language {
    menu.autoenablesItems = NO;
    for (NSMenuItem *item in menu.itemArray) {
        item.tag = self.menuContextSerial;
        item.enabled = [context[@"path"] length] > 0;
        if (item.submenu) [self configureMenu:item.submenu context:context language:language];
        if (item.action == @selector(cutItems:)) {
            item.enabled = [context[@"selected"] count] > 0 && [context[@"path"] length] > 0;
            item.toolTip = [self isEnglish:language] ? @"Mark selected items to move when you paste" : @"记录选中项，粘贴时才移动文件";
        }
        if (item.action == @selector(pasteItems:)) {
            NSUInteger count = [self pendingCutPaths].count;
            item.enabled = item.enabled && count > 0;
            if (count > 0) item.title = [NSString stringWithFormat:[self isEnglish:language] ? @"Move %lu Item(s) Here" : @"将 %lu 项移到此处", (unsigned long)count];
        }
    }
}

- (NSDictionary *)contextForSender:(id)sender {
    if (![sender isKindOfClass:[NSMenuItem class]]) return @{};
    return self.menuContexts[@([sender tag])] ?: @{};
}

- (void)openSettings:(id)sender {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/open"];
    task.arguments = @[@"astracreate://settings"];
    [task launchAndReturnError:NULL];
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
    return ![value isKindOfClass:[NSNumber class]] || value.boolValue;
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
    [self sendToHost:@"docx" sender:sender];
}

- (void)newExcel:(id)sender {
    [self log:@"newExcel clicked"];
    [self sendToHost:@"xlsx" sender:sender];
}

- (void)newPowerPoint:(id)sender {
    [self log:@"newPowerPoint clicked"];
    [self sendToHost:@"pptx" sender:sender];
}

- (void)newText:(id)sender {
    [self log:@"newText clicked"];
    [self sendToHost:@"txt" sender:sender];
}

- (void)newMarkdown:(id)sender {
    [self log:@"newMarkdown clicked"];
    [self sendToHost:@"md" sender:sender];
}

- (void)openTerminal:(id)sender {
    [self log:@"openTerminal clicked"];
    [self sendToHost:@"terminal" sender:sender];
}

- (void)openVSCode:(id)sender {
    [self log:@"openVSCode clicked"];
    [self sendToHost:@"vscode" sender:sender];
}

- (void)cutItems:(id)sender {
    NSArray *selection = [self contextForSender:sender][@"selected"];
    [self log:[NSString stringWithFormat:@"cut action context has %lu selected item(s)", (unsigned long)selection.count]];
    NSMutableArray *paths = [NSMutableArray array];
    for (NSString *path in selection) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) [paths addObject:path];
    }
    if (paths.count == 0) return;
    // No host launch, file movement, reveal, or Finder refresh during cut.
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"operation": @"move", @"paths": paths} options:0 error:NULL];
    NSURL *url = [self clipboardFileURL];
    NSError *error = nil;
    BOOL ready = [[NSFileManager defaultManager] createDirectoryAtURL:[url URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];
    BOOL saved = ready && data && [data writeToURL:url options:NSDataWritingAtomic error:&error];
    [self log:saved ? [NSString stringWithFormat:@"cut recorded %lu item(s) without launching host", (unsigned long)paths.count] : [NSString stringWithFormat:@"cut failed: %@", error]];
}

- (void)pasteItems:(id)sender {
    [self log:@"pasteItems clicked"];
    [self sendToHost:@"paste" sender:sender];
}

- (void)copyAbsolutePath:(id)sender {
    NSDictionary *context = [self contextForSender:sender];
    NSArray<NSString *> *paths = context[@"selected"];
    if (paths.count == 0 && [context[@"path"] length] > 0) paths = @[context[@"path"]];
    if (paths.count == 0) return;
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

- (void)sendToHost:(NSString *)command sender:(id)sender {
    NSDictionary *context = [self contextForSender:sender];
    NSString *path = context[@"path"];
    NSURL *directory = path.length > 0 ? [NSURL fileURLWithPath:path] : nil;
    if (!directory) {
        [self log:@"no target directory"];
        return;
    }

    NSArray<NSString *> *selectedPaths = context[@"selected"] ?: @[];
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
    task.arguments = @[@"-g", url.absoluteString];
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
        return english ? @"Cut (Move on Paste)" : @"剪切（粘贴时移动）";
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

    // No trustworthy current directory (e.g. Recents/search): do not guess
    // from a selection or silently operate in the user's home directory.
    return nil;
}

- (void)log:(NSString *)message {
    // Release builds intentionally do not persist file paths or command URLs.
}

@end
