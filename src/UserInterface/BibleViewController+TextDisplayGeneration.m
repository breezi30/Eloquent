//
//  BibleViewController+TextDisplayGeneration.m
//  Eloquent
//
//  Created by Manfred Bergmann on 19.02.10.
//  Copyright 2010 Software by MABE. All rights reserved.
//

#import "HostableViewController.h"
#import "ContentDisplayingViewController.h"
#import "ModuleCommonsViewController.h"
#import "BibleViewController+TextDisplayGeneration.h"
#import "MBPreferenceController.h"
#import "globals.h"
#import "ObjCSword/SwordModuleTextEntry.h"
#import "ObjCSword/SwordBibleTextEntry.h"
#import "NSUserDefaults+Additions.h"
#import "ObjCSword/SwordManager.h"
#import "ObjCSword/SwordBible.h"
#import "SearchResultEntry.h"
#import "Highlighter.h"
#import "Bookmark.h"
#import "BookmarkManager.h"
#import "ObjCSword/SwordVerseKey.h"
#import "CacheObject.h"

@implementation BibleViewController (TextDisplayGeneration)

#pragma mark - HTML generation from search result

- (NSAttributedString *)displayableHTMLForIndexedSearchResults:(NSArray *)searchResults {
    NSMutableAttributedString *ret = [[NSMutableAttributedString alloc] initWithString:@""];
    
    if(searchResults && [searchResults count] > 0) {
        NSAttributedString *newLine = [[NSAttributedString alloc] initWithString:@"\n"];
        
        NSFont *normalDisplayFont = [[MBPreferenceController defaultPrefsController] normalDisplayFontForModuleName:[[self module] name]];
        NSFont *boldDisplayFont = [[MBPreferenceController defaultPrefsController] boldDisplayFontForModuleName:[[self module] name]];
        NSFont *keyFont = [NSFont fontWithName:[boldDisplayFont familyName]
                                          size:(int)customFontSize];
        NSFont *contentFont = [NSFont fontWithName:[normalDisplayFont familyName] 
                                              size:(int)customFontSize];
        
        NSMutableDictionary *keyAttributes = [@{NSFontAttributeName : keyFont} mutableCopy];
        NSMutableDictionary *contentAttributes = [@{NSFontAttributeName : contentFont} mutableCopy];
        contentAttributes[NSForegroundColorAttributeName] = [UserDefaults colorForKey:DefaultsTextForegroundColor];
        
        // strip search tokens
        NSString *searchQuery = [NSString stringWithString:[Highlighter stripSearchQuery:searchString]];
        
        for(SearchResultEntry *searchResultEntry in searchResults) {            
            if([searchResultEntry keyString] != nil) {
                NSArray *content = [(SwordBible *)module strippedTextEntriesForRef:[searchResultEntry keyString] context:(int)textContext];
                for(SwordModuleTextEntry *textEntry in content) {
                    // get data
                    NSString *keyStr = [textEntry key];
                    NSString *contentStr = [textEntry text];                    
                    
                    // prepare verse URL link
                    NSString *keyLink = [NSString stringWithFormat:@"sword://%@/%@", [module name], keyStr];
                    NSURL *keyURL = [NSURL URLWithString:[keyLink stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                    
                    // add attributes
                    keyAttributes[NSLinkAttributeName] = keyURL;
                    keyAttributes[TEXT_VERSE_MARKER] = keyStr;
                    
                    // prepare output
                    NSAttributedString *keyString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@: ", keyStr]
                                                                                    attributes:keyAttributes];
                    NSAttributedString *contentString = nil;
                    if([keyStr isEqualToString:[searchResultEntry keyString]]) {
                        contentString = [Highlighter highlightText:contentStr 
                                                         forTokens:searchQuery 
                                                        attributes:contentAttributes];                        
                    } else {
                        contentString = [[NSAttributedString alloc] initWithString:contentStr attributes:contentAttributes];
                    }
                    [ret appendAttributedString:keyString];
                    [ret appendAttributedString:contentString];
                    [ret appendAttributedString:newLine];
                }
            }                
        }

        CocoLog(LEVEL_DEBUG, @"apply writing direction...");
        [self applyWritingDirection:ret];
        CocoLog(LEVEL_DEBUG, @"apply writing direction...done");
    }
    CocoLog(LEVEL_DEBUG, @"prepare search results...done");
        
    return ret;
}

#pragma mark - HTML generation from verse data

- (NSAttributedString *)displayableHTMLForReferenceLookup {

    CocoLog(LEVEL_DEBUG, @"start creating HTML string...");
    NSString *htmlString = [self createHTMLStringWithMarkers];
    CocoLog(LEVEL_DEBUG, @"start creating HTML string...done");

    // replace all zwsp'es with normal spaces
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"\u200B" withString:@""];
    
    CocoLog(LEVEL_DEBUG, @"start generating attr string...");
    NSMutableAttributedString *attrString = [self generateAttributedString:htmlString];
    CocoLog(LEVEL_DEBUG, @"start generating attr string...done");
    
    CocoLog(LEVEL_DEBUG, @"setting pointing hand cursor...");
    [self applyLinkCursorToLinks:attrString];
    CocoLog(LEVEL_DEBUG, @"setting pointing hand cursor...done");
    
    CocoLog(LEVEL_DEBUG, @"start replacing markers...");
    [self replaceVerseMarkers:attrString];
    CocoLog(LEVEL_DEBUG, @"start replacing markers...done");
    
    CocoLog(LEVEL_DEBUG, @"apply writing direction...");
    [self applyWritingDirection:attrString];
    CocoLog(LEVEL_DEBUG, @"apply writing direction...done");        
    
    return attrString;
}

- (NSString *)createHTMLStringWithMarkers {
    
    NSMutableString *htmlString = [NSMutableString string];
    // background color cannot be set this way
    CGFloat fr, fg, fb = 0.0;
    NSColor *fCol = [UserDefaults colorForKey:DefaultsTextForegroundColor];
    [fCol getRed:&fr green:&fg blue:&fb alpha:NULL];

    [htmlString appendFormat:@"\
     <style>\
     body {\
        color:rgb(%i%%, %i%%, %i%%);\
     }\
     </style>\n",
     (int)(fr * 100.0), (int)(fg * 100.0), (int)(fb * 100.0)];
    
    lastChapter = -1;
    lastBook = -1;

    [module lockModuleAccess];

    NSMutableDictionary *duplicateChecker = [NSMutableDictionary dictionary];

    NSArray *textEntries = [(SwordBible *) [self module] renderedTextEntriesForRef:searchString context:(int)textContext];
    int numberOfVerses = (int)[textEntries count];

    for(SwordBibleTextEntry *te in textEntries) {
        [self handleTextEntry:te duplicateDict:duplicateChecker htmlString:htmlString];
    }

    [module unlockModuleAccess];
    [contentCache setCount:numberOfVerses];
    
    return htmlString;
}

/**
 Handles a verse entry.
 The rendered verse text is appended to htmlString.
 In case a context setting is set in the UI the duplicateDict will make sure we don't add verses twice.
 */
- (void)handleTextEntry:(SwordBibleTextEntry *)entry duplicateDict:(NSMutableDictionary *)duplicateDict htmlString:htmlString {
    if(entry && (duplicateDict[[entry key]] == nil)) {
        duplicateDict[[entry key]] = entry;

        BOOL collectPreverseHeading = ([[SwordManager defaultManager] globalOption:SW_OPTION_HEADINGS] && [module hasFeature:SWMOD_FEATURE_HEADINGS]);
        if(collectPreverseHeading) {
            NSString *preverseHeading = [module entryAttributeValuePreverse];
            if(preverseHeading && [preverseHeading length] > 0) {
                [entry setPreVerseHeading:preverseHeading];
            }
        }
        
        [self applyBookmarkHighlightingOnTextEntry:entry];
        [self appendHTMLFromTextEntry:entry atHTMLString:htmlString];        
    }
}

/**
 Highlight is this is a bookmark.
 */
- (void)applyBookmarkHighlightingOnTextEntry:(SwordBibleTextEntry *)anEntry {
    BOOL isHighlightBookmarks = [displayOptions[DefaultsBibleTextHighlightBookmarksKey] boolValue];
    if(isHighlightBookmarks) {
        Bookmark *bm = [[BookmarkManager defaultManager] bookmarkForReference:[SwordVerseKey verseKeyWithRef:[anEntry key]]];
        if(bm && [bm highlight]) {
            CGFloat br = 1.0, bg = 1.0, bb = 1.0;
            CGFloat fr, fg, fb = 0.0;
            NSColor *bCol = [[bm backgroundColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
            NSColor *fCol = [[bm foregroundColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
            [bCol getRed:&br green:&bg blue:&bb alpha:NULL];
            [fCol getRed:&fr green:&fg blue:&fb alpha:NULL];
            
            // apply colors
            [anEntry setText:
             [NSString stringWithFormat:@"<span style=\"color:rgb(%i%%, %i%%, %i%%); background-color:rgb(%i%%, %i%%, %i%%);\">%@</span>",
              (int)(fr * 100.0), (int)(fg * 100.0), (int)(fb * 100.0),
              (int)(br * 100.0), (int)(bg * 100.0), (int)(bb * 100.0),
              [anEntry text]]];
        }
    }
}

/**
 Create the HTML string from the verse entry and append it to aString.
 */
- (void)appendHTMLFromTextEntry:(SwordBibleTextEntry *)anEntry atHTMLString:(NSMutableString *)aString {
    NSString *bookName;
    int book, chapter, verse;

    SwordVerseKey *verseKey = [SwordVerseKey verseKeyWithRef:[anEntry key] v11n:[module versification]];
    bookName = [verseKey bookName];
    book = [verseKey book];
    chapter = [verseKey chapter];
    verse = [verseKey verse];
    
    NSString *verseMarkerInfo = [NSString stringWithFormat:@"%@|%i|%i", bookName, chapter, verse];
    
    BOOL isVersesOnOneLine = [displayOptions[DefaultsBibleTextVersesOnOneLineKey] boolValue];
    int verseNumbering = [displayOptions[DefaultsBibleTextVerseNumberingTypeKey] intValue];
    BOOL isShowVerseNumbersOnly = (verseNumbering == VerseNumbersOnly);
    BOOL hideVerseNumbering = (verseNumbering == NoVerseNumbering);
    
    // headings fg color
    CGFloat hr, hg, hb = 0.0;
    NSColor *hfCol = [UserDefaults colorForKey:DefaultsHeadingsForegroundColor];
    [hfCol getRed:&hr green:&hg blue:&hb alpha:NULL];    
    NSString *headingsFGColorStyle = [NSString stringWithFormat:@"color:rgb(%i%%, %i%%, %i%%);",
      (int)(hr * 100.0), (int)(hg * 100.0), (int)(hb * 100.0)];
    
    // book introductions
    SwordBibleBook *bibleBook = [(SwordBible *)module bookForName:bookName];
    if(book != lastBook) {
        if([modDisplayOptions[SW_OPTION_HEADINGS] isEqualToString:SW_ON]) {
            NSString *bookIntro = [(SwordBible *)module bookIntroductionFor:bibleBook];
            if(bookIntro && [bookIntro length] > 0) {
                [aString appendFormat:@"<p><i><span style=\"%@\">%@</span></i></p>", headingsFGColorStyle, bookIntro];
            }
        }
    }
    
    // pre-verse heading ?
    if([modDisplayOptions[SW_OPTION_HEADINGS] isEqualToString:SW_ON] && [anEntry preVerseHeading].length > 0) {
        [aString appendFormat:@"<br /><p><i><span style=\"%@\">%@</span></i></p>", headingsFGColorStyle, [anEntry preVerseHeading]];
    }
    
    // text get marked with ";;;<verseMarkerInfo>;;;" which is replaced later on with a marker
    if(!isVersesOnOneLine) {
        // new chapter or same chapter in another book
        if((chapter != lastChapter) || (book != lastBook)) {
            if([modDisplayOptions[SW_OPTION_HEADINGS] isEqualToString:SW_ON]) {
                NSString *chapIntro = [(SwordBible *)module chapterIntroductionIn:bibleBook forChapter:chapter];
                if(chapIntro && [chapIntro length] > 0) {
                    [aString appendFormat:@"<br /><p><i><span style=\"%@\">%@</span></i></p>", headingsFGColorStyle, chapIntro];
                }
            }
            if(!hideVerseNumbering) {
                [aString appendFormat:@"<br /><b>%@ %i:</b><br />\n", bookName, chapter];
            }
        }
        [aString appendFormat:@";;;%@;;; %@\n", verseMarkerInfo, [anEntry text]];   // verse marker
    } else {
        // new chapter or same chapter in another book
        if((chapter != lastChapter) || (book != lastBook)) {
            if([modDisplayOptions[SW_OPTION_HEADINGS] isEqualToString:SW_ON]) {
                NSString *chapIntro = [(SwordBible *)module chapterIntroductionIn:bibleBook forChapter:chapter];
                if(chapIntro && [chapIntro length] > 0) {
                    [aString appendFormat:@"<br /><p><i><span style=\"%@\">%@</span></i></p>", headingsFGColorStyle, chapIntro];
                }
            }
            if(isShowVerseNumbersOnly && !hideVerseNumbering) {
                if(chapter == 1) {
                    [aString appendFormat:@"<b>%@ %i:</b><br />\n", bookName, chapter];
                } else {
                    [aString appendFormat:@"<br /><b>%@ %i:</b><br />\n", bookName, chapter];
                }
            }
        }
        [aString appendFormat:@"<b>;;;%@;;;</b>", verseMarkerInfo];    // verse marker
        // the actual verse text
        [aString appendFormat:@"%@<br />\n", [anEntry text]];
    }
    
    lastChapter = chapter;
    lastBook = book;
}

/**
 Generate Attributed string
 */
- (NSMutableAttributedString *)generateAttributedString:(NSString *)aString {
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    options[NSCharacterEncodingDocumentOption] = @(NSUTF8StringEncoding);

    WebPreferences *webPrefs = [[MBPreferenceController defaultPrefsController] defaultWebPreferencesForModuleName:[[self module] name]];
    [webPrefs setDefaultFontSize:(int) [self customFontSize]];
    options[NSWebPreferencesDocumentOption] = webPrefs;
    
    NSFont *normalDisplayFont = [[MBPreferenceController defaultPrefsController] normalDisplayFontForModuleName:[[self module] name]];
    NSFont *font = [NSFont fontWithName:[normalDisplayFont familyName] size:[self customFontSize]];

    NSData *data = [aString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithHTML:data
                                                                                    options:options
                                                                         documentAttributes:NULL];

    CGFloat paraSpacing = [[UserDefaults objectForKey:DefaultsParagraphSpacingKey] floatValue];
    CGFloat lineSpacing = [[UserDefaults objectForKey:DefaultsLineSpacingKey] floatValue];
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    [style setLineSpacing:lineSpacing];
    [style setParagraphSpacing:paraSpacing];
    [attrString addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0, [attrString length])];
    
    [[self scrollView] setLineScroll:[[[self textView] layoutManager] defaultLineHeightForFont:font]];
    
    return attrString;
}

- (void)applyLinkCursorToLinks:(NSMutableAttributedString *)attrString {
    NSRange effectiveRange;
	NSUInteger i = 0;
	while (i < [attrString length]) {
        NSDictionary *attrs = [attrString attributesAtIndex:i effectiveRange:&effectiveRange];
		if(attrs[NSLinkAttributeName] != nil) {
            attrs = [attrs mutableCopy];
            ((NSMutableDictionary *) attrs)[NSCursorAttributeName] = [NSCursor pointingHandCursor];
            [attrString setAttributes:attrs range:effectiveRange];
		}
		i += effectiveRange.length;
	}
}

- (void)replaceVerseMarkers:(NSMutableAttributedString *)attrString {
    BOOL showBookNames = [UserDefaults boolForKey:DefaultsBibleTextShowBookNameKey];
    BOOL showBookAbbr = [UserDefaults boolForKey:DefaultsBibleTextShowBookAbbrKey];
    BOOL isVersesOnOneLine = [displayOptions[DefaultsBibleTextVersesOnOneLineKey] boolValue];
    int verseNumbering = [displayOptions[DefaultsBibleTextVerseNumberingTypeKey] intValue];
    BOOL isShowVerseNumbersOnly = (verseNumbering == VerseNumbersOnly);
    BOOL isShowFullVerseNumbering = (verseNumbering == FullVerseNumbering);
    
    NSRange replaceRange = NSMakeRange(0,0);
    BOOL found = YES;
    NSString *text = [attrString string];
    while(found) {
        int tLen = (int) [text length];
        NSRange start = [text rangeOfString:@";;;" options:0 range:NSMakeRange(replaceRange.location, (NSUInteger) (tLen-replaceRange.location))];
        if(start.location != NSNotFound) {
            NSRange stop = [text rangeOfString:@";;;" options:0 range:NSMakeRange(start.location+3, (NSUInteger) (tLen-(start.location+3)))];
            if(stop.location != NSNotFound) {
                replaceRange.location = start.location;
                replaceRange.length = stop.location + 3 - start.location;
                
                // create marker
                NSString *marker = [text substringWithRange:NSMakeRange(replaceRange.location + 3, replaceRange.length - 6)];
                
                NSArray *comps = [marker componentsSeparatedByString:@"|"];
                if([comps count] == 2) {         
                    NSString *verseMarker = [NSString stringWithFormat:@"%@ %@", comps[0], comps[1]];
                    
                    NSRange linkRange;
                    linkRange.length = 9;
                    linkRange.location = replaceRange.location;
                    
                    NSMutableDictionary *markerOpts = [NSMutableDictionary dictionaryWithCapacity:3];
                    markerOpts[TEXT_VERSE_MARKER] = verseMarker;
                    
                    [attrString replaceCharactersInRange:replaceRange withString:verseMarker];
                    [attrString addAttributes:markerOpts range:linkRange];
                } else {
                    NSString *verseMarker = [NSString stringWithFormat:@"%@ %@:%@", comps[0], comps[1], comps[2]];
                    
                    NSString *visible = @"";
                    NSRange linkRange;
                    linkRange.length = 0;
                    linkRange.location = NSNotFound;
                    if(showBookNames) {
                        if(isVersesOnOneLine && isShowFullVerseNumbering) {
                            visible = [NSString stringWithFormat:@"%@ %@:%@: ", comps[0], comps[1], comps[2]];
                            linkRange.location = replaceRange.location;
                            linkRange.length = [visible length] - 2;                            
                        } else if((isVersesOnOneLine && isShowVerseNumbersOnly) || isShowVerseNumbersOnly) {
                            visible = [NSString stringWithFormat:@"%@ ", comps[2]];
                            linkRange.location = replaceRange.location;
                            linkRange.length = [visible length] - 1;
                        }
                    } else if(showBookAbbr) {
                        // TODO: show abbrevation
                    }
                    NSString *verseLink = [NSString stringWithFormat:@"sword://%@/%@", [module name], verseMarker];
                    NSURL *verseURL = [NSURL URLWithString:[verseLink stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                    
                    NSMutableDictionary *markerOpts = [NSMutableDictionary dictionaryWithCapacity:3];
                    markerOpts[TEXT_VERSE_MARKER] = verseMarker;
                    markerOpts[NSCursorAttributeName] = [NSCursor pointingHandCursor];
                    markerOpts[NSLinkAttributeName] = verseURL;
                    
                    [attrString replaceCharactersInRange:replaceRange withString:visible];
                    [attrString addAttributes:markerOpts range:linkRange];
                    
                    replaceRange.location += [visible length];
                }
            }
        } else {
            found = NO;
        }
    }
}

- (void)applyWritingDirection:(NSMutableAttributedString *)attrString {
    if([module isRTL]) {
        [attrString setBaseWritingDirection:NSWritingDirectionRightToLeft range:NSMakeRange(0, [attrString length])];
    } else {
        [attrString setBaseWritingDirection:NSWritingDirectionNatural range:NSMakeRange(0, [attrString length])];
    }    
}

@end
