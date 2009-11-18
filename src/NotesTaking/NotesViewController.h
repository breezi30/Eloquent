//
//  NotesViewController.h
//  MacSword2
//
//  Created by Manfred Bergmann on 17.11.09.
//  Copyright 2009 Software by MABE. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CocoLogger/CocoLogger.h>
#import <ContentDisplayingViewController.h>

@class FileRepresentation;

@interface NotesViewController : ContentDisplayingViewController {
    IBOutlet NSTextView *textView;
    FileRepresentation *fileRep;
}

@property (readwrite, retain) FileRepresentation *fileRep;

- (id)initWithDelegate:(id)aDelegate;
- (id)initWithDelegate:(id)aDelegate hostingDelegate:(id)aHostingDelegate;
- (id)initWithDelegate:(id)aDelegate hostingDelegate:(id)aHostingDelegate fileRep:(FileRepresentation *)aFileRep;

// methods
- (void)displayText;

@end
