/* MBPreferenceController */

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <CocoLogger/CocoLogger.h>

#define PREFERENCE_CONTROLLER_NIB_NAME          @"Preferences"

// UserDefault defines

// bible display
#define DefaultsBibleTextShowBookNameKey            @"DefaultsBibleTextShowBookNameKey"
#define DefaultsBibleTextShowBookAbbrKey            @"DefaultsBibleTextShowBookAbbrKey"
#define DefaultsBibleTextVersesOnOneLineKey         @"DefaultsBibleTextVersesOnOneLineKey"
#define DefaultsBibleTextDisplayFontFamilyKey       @"DefaultsBibleTextDisplayFontFamilyKey"
#define DefaultsBibleTextDisplayBoldFontFamilyKey   @"DefaultsBibleTextDisplayBoldFontFamilyKey"
#define DefaultsBibleTextDisplayFontSizeKey         @"DefaultsBibleTextDisplayFontSizeKey"
#define DefaultsHeaderViewFontFamilyKey             @"DefaultsHeaderViewFontFamilyKey"
#define DefaultsHeaderViewFontSizeKey               @"DefaultsHeaderViewFontSizeKey"
#define DefaultsHeaderViewFontSizeBigKey            @"DefaultsHeaderViewFontSizeBigKey"

// define some userdefaults keys
#define DEFAULTS_SWMODULE_PATH_KEY      @"SwordModulePath"
#define DEFAULTS_SWINSTALLMGR_PATH_KEY  @"SwordInstallMgrPath"
#define DEFAULTS_SWINDEX_PATH_KEY       @"SwordIndexPath"

// default bible
#define DefaultsBibleModule             @"DefaultsBibleModule"
#define DefaultsStrongsHebrewModule     @"DefaultsStrongsHebrewModule"
#define DefaultsStrongsGreekModule      @"DefaultsStrongsGreekModule"

@class SwordManager;

@interface MBPreferenceController : NSWindowController {
	// global stuff
	IBOutlet NSButton *okButton;
	IBOutlet NSTabView *prefsTabView;
	
	// the controllers
	IBOutlet NSView *generalView;
    NSRect generalViewRect;
	
    // WebPreferences for display
    WebPreferences *webPreferences;
    
	// the window the sheet shall come up
	NSWindow *sheetWindow;
    
	// set delegate
	id delegate;
	
	// return code of sheet
	int sheetReturnCode;
	
	// margins
	int northMargin;
	int southMargin;
	int sideMargin;
	int topTabViewMargin;
}

@property (readwrite) id delegate;
@property (readwrite) NSWindow *sheetWindow;
@property (readwrite) WebPreferences *webPreferences;

// the default prefs controller
+ (MBPreferenceController *)defaultPrefsController;

- (NSArray *)moduleNamesOfTypeBible;
- (NSArray *)moduleNamesOfTypeStrongsGreek;
- (NSArray *)moduleNamesOfTypeStrongsHebrew;

// begin sheet
- (void)beginSheetForWindow:(NSWindow *)docWindow;
- (void)endSheet;

// sheet return code
- (int)sheetReturnCode;

// end sheet callback
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

// recalculate frame rect
//- (NSRect)frameRectForTabViewItem:(NSTabViewItem *)item;

// actions
- (IBAction)okButton:(id)sender;

@end
