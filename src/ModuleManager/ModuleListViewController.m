#import <ObjCSword/ObjCSword.h>
#import "ModuleListViewController.h"
#import "ModuleListObject.h"
#import "InstallSourceListObject.h"
#import "globals.h"
#import "Eloquent-Swift.h"

// table column identifiers
#define TABLECOL_IDENTIFIER_MODNAME @"modname"
#define TABLECOL_IDENTIFIER_MODDESCR @"moddescr"
#define TABLECOL_IDENTIFIER_MODTYPE @"modtype"
#define TABLECOL_IDENTIFIER_MODSTATUS @"modstatus"
#define TABLECOL_IDENTIFIER_MODCIPHERED @"modciphered"
#define TABLECOL_IDENTIFIER_MODRVERSION @"modrversion"
#define TABLECOL_IDENTIFIER_MODLVERSION @"modlversion"
#define TABLECOL_IDENTIFIER_TASK @"task"

@interface ModuleListViewController ()
@property (strong, readwrite) NSDictionary *languageMap;
@property (strong, readwrite) NSArray *moduleData;
@property (strong, readwrite) NSMutableArray *moduleSelection;
@property (strong, readwrite) SwordManager *swordManager;
@end


@implementation ModuleListViewController

- (id)init {
    self = [super init];
    if(self) {
        self.installSources = [NSArray array];
        self.moduleData = [NSArray array];
        self.moduleSelection = [NSMutableArray array];
        self.languageMap = [NSDictionary dictionary];
        [self setLangFilter:NSLocalizedString(@"All", @"")];
        [self updateSwordManager];
    }

    return self;
}


- (void)awakeFromNib {
    [super awakeFromNib];

    [moduleOutlineView setMenu:moduleMenu];
    [self refreshLanguages];
}

- (ModuleListObject *)moduleObjectForClickedRow {
    NSInteger clickedRow = [moduleOutlineView clickedRow];
    if(clickedRow >= 0) {
        return [moduleOutlineView itemAtRow:clickedRow];
    }
    return nil;
}

- (void)updateModuleSelection {
    if([self.moduleSelection count] == 0 || [self.moduleSelection count] == 1) {
        ModuleListObject *clicked = [self moduleObjectForClickedRow];
        if(clicked) {
            [self.moduleSelection removeAllObjects];
            [self.moduleSelection addObject:clicked];
        }
    }
}

- (void)refreshLanguages {
    [self setupLanguagesMap];
    [self setupLanguagesPopup];
}

- (void)setupLanguagesMap {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    NSLocale *loc = [NSLocale systemLocale];

    // collect languages available in modules
    dict[NSLocalizedString(@"All", @"")] = NSLocalizedString(@"All", @"");
    for(ModuleListObject *lo in self.moduleData) {
        SwordModule *mod = [lo module];

        NSString *langString = [loc displayNameForKey:NSLocaleIdentifier value:[mod lang]];
        if(langString != nil) {
            dict[[mod lang]] = langString;
        } else {
            // add the iso code itself
            dict[[mod lang]] = [mod lang];
        }
    }
    
    self.languageMap = [NSDictionary dictionaryWithDictionary:dict];
}

- (void)setupLanguagesPopup {
    [languagesButton removeAllItems];
    [languagesButton addItemWithTitle:NSLocalizedString(@"All", @"")];

    NSArray *list = [self.languageMap.allValues sortedArrayUsingSelector:@selector(compare:)];
    for(NSString *lang in list) {
        [languagesButton addItemWithTitle:lang];
    }
    [languagesButton selectItemWithTitle:[self langFilter]];
}

- (void)updateSwordManager {
    self.swordManager = [SwordManager managerWithPath:[[FolderUtil urlForModulesFolder] path]];
}

/** update the modules with the modules in the sources list */
- (void)refreshModulesList {
    SwordInstallSourceManager *sis = [SwordInstallSourceManager defaultManager];
    SwordManager *sm = self.swordManager;

    NSMutableArray *arr = [NSMutableArray array];

    for(InstallSourceListObject *listObject in self.installSources) {
        SwordInstallSource *is = [listObject installSource];
        
        // compare install source modules with sword manager modules to get state info
        NSArray *modList = [sis moduleStatusInInstallSource:is baseManager:sm];

        for(SwordModule *mod in modList) {
            // check for language filter
            if([[self langFilter] isEqualToString:NSLocalizedString(@"All", @"")] ||
                    [[self langFilter] isEqualToString:self.languageMap[[mod lang]]]) {

                // check for module type
                if(([listObject objectType] == TypeInstallSource) || 
                   (([listObject objectType] == TypeModuleType) && [[listObject moduleType] isEqualToString:[mod typeString]])) {
                    
                    ModuleListObject *buf = [[ModuleListObject alloc] init];
                    [buf setModule:mod];
                    [buf setInstallSource:is];
                    [arr addObject:buf];
                }
            }
        }
    }
    self.moduleData = arr;
    [moduleOutlineView reloadData];

    [self refreshLanguages];
}

#pragma mark - Menu validation

/**
 \brief validate menu
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if([menuItem action] == @selector(languageFilter:)) {
        return YES;
    }
    
    BOOL ret = NO;
    NSInteger selectedModuleCount = [self.moduleSelection count];
	if(selectedModuleCount > 1) {
		ret = YES;
	} else {
	
		// begin fix for MACSW-172 (draymer)
		ModuleListObject *selectedObj = nil;
		ModuleListObject *accessedObj;
		ModuleListObject *modObj;
		
		// need to check to see if the module being modified is that same as the
		// module being selected.
		accessedObj = [self moduleObjectForClickedRow];	
		if(selectedModuleCount == 1) {
			selectedObj = self.moduleSelection[0];
		}
		
		modObj = (selectedObj == accessedObj ? selectedObj : accessedObj);
		
		// end fix for MACSW-172
		
		if(modObj != nil) {
			
			CocoLog(LEVEL_DEBUG, @"selected module: %x", (unsigned int)modObj);
			
			NSInteger tag = [menuItem tag];
			
			if(tag == TaskInstall) {
				// install should only be active if it is not installed
				if(([[modObj module] status] & ModStatNew) > 0) {
					ret = YES;
				}
			} else if(tag == TaskRemove) {
				// remove only if module is installed
				if(([[modObj module] status] & ModStatNew) == 0) {
					ret = YES;
				}
			} else if(tag == TaskUpdate) {
				// update only if module is updateable
				if(([[modObj module] status] & ModStatUpdated) > 0) {
					ret = YES;
				}
			} else if(tag == TaskNone) {
				return YES;
			}
		}
    } 
    
    return ret;
}

#pragma mark - Actions

- (IBAction)search:(id)sender {
}

- (IBAction)languageFilter:(id)sender {
    [self setLangFilter:[(NSMenuItem *)sender title]];
    
    [self refreshModulesList];
}

- (IBAction)noneTask:(id)sender {
    [self updateModuleSelection];
    
    // get current selected module
    if([self.moduleSelection count] > 0) {
        for(ModuleListObject *modObj in self.moduleSelection) {
            // set taskid
            [modObj setTaskId:TaskNone];
            
            // unregister module from installation or removal
            if(self.delegate) {
                if([self.delegate respondsToSelector:@selector(unregister:)]) {
                    [self.delegate performSelector:@selector(unregister:) withObject:modObj];
                }
            }
        }                
        [moduleOutlineView reloadData];
    } else {
        CocoLog(LEVEL_ERR, @"no module selected!");
    }    
}

- (IBAction)installModule:(id)sender {
    [self updateModuleSelection];
    
    if([self.moduleSelection count] > 0) {
        for(ModuleListObject *modObj in self.moduleSelection) {
            // only modules that are not installed can be registered for installation
            
            // check if module is installed already
            if((([[modObj module] status] & ModStatNew) > 0) || (([[modObj module] status] & ModStatUpdated) > 0)) {
                [modObj setTaskId:TaskInstall];
                
                // register module for installation
                if(self.delegate) {
                    if([self.delegate respondsToSelector:@selector(registerForInstall:)]) {
                        [self.delegate performSelector:@selector(registerForInstall:) withObject:modObj];
                    }
                }
            } else {
                CocoLog(LEVEL_WARN, @"module is already installed!");
            }
        }
        [moduleOutlineView reloadData];
    } else {
        CocoLog(LEVEL_ERR, @"no module selected!");
    }    
}

- (IBAction)removeModule:(id)sender {
    [self updateModuleSelection];
    
    if([self.moduleSelection count] > 0) {
        for(ModuleListObject *modObj in self.moduleSelection) {
            // only modules that are installed can be removed
            
            // check if module is really installed
            if(([[modObj module] status] & ModStatNew) == 0) {
                [modObj setTaskId:TaskRemove];
                
                // register module for removal
                if(self.delegate) {
                    if([self.delegate respondsToSelector:@selector(registerForRemove:)]) {
                        [self.delegate performSelector:@selector(registerForRemove:) withObject:modObj];
                    }
                }
            } else {
                CocoLog(LEVEL_WARN, @"module is not installed!");
            }
        }
        [moduleOutlineView reloadData];
    } else {
        CocoLog(LEVEL_ERR, @"no module selected!");
    }
}

- (IBAction)updateModule:(id)sender {
    [self updateModuleSelection];
    
    if([self.moduleSelection count] > 0) {
        for(ModuleListObject *modObj in self.moduleSelection) {
            // only module that are updateable can be updated
            
            // check if module is new version
            if(([[modObj module] status] & ModStatUpdated) > 0) {
                [modObj setTaskId:TaskUpdate];
                
                // register module for update
                if(self.delegate) {
                    if([self.delegate respondsToSelector:@selector(registerForUpdate:)]) {
                        [self.delegate performSelector:@selector(registerForUpdate:) withObject:modObj];
                    }
                }
            } else {
                CocoLog(LEVEL_INFO, @"current version of module installed!");
            }
        }        
        [moduleOutlineView reloadData];
    } else {
        CocoLog(LEVEL_ERR, @"no module selected!");
    }
}

#pragma mark - Notifications

- (void)controlTextDidChange:(NSNotification *)aNotification {
    if(aNotification != nil) {
        NSSearchField *sf = [aNotification object];
        
        // get text
        NSString *searchStr = [sf stringValue];
        
        if([searchStr length] > 0) {
            // create result array
            NSMutableArray *resultArray = [NSMutableArray array];
            
            // init Reg ex
            Regex *regex = [Regex regexWithPattern:searchStr];
            [regex setCaseSensitive:NO];

            for(ModuleListObject *mod in self.moduleData) {
                // try to match against name of module
                if([regex matchIn:[[mod module] name] matchResult:nil] == RegexMatch) {
                    [resultArray addObject:mod];
                }
            }
            [self setModuleData:resultArray];
            
            [moduleOutlineView reloadData];
        } else {
            [self refreshModulesList];
        }
    }
}

#pragma mark - NSOutlineView delegates

/**
 \brief Notification is called when the selection has changed 
 */
- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
	if(notification != nil) {
		NSOutlineView *oview = [notification object];
		if(oview != nil) {
            
            // remove any old selection
            [self.moduleSelection removeAllObjects];
            
			NSIndexSet *selectedRows = [oview selectedRowIndexes];
			NSUInteger len = [selectedRows count];
            ModuleListObject *mlo;
			if(len > 0) {
				NSUInteger indexes[len];
				[selectedRows getIndexes:indexes maxCount:len inIndexRange:nil];
				
				for(int i = 0;i < len;i++) {
					mlo = [oview itemAtRow:indexes[i]];
                    [self.moduleSelection addObject:mlo];
				}				
            }
		} else {
			CocoLog(LEVEL_WARN, @"have a nil notification object!");
		}
	} else {
		CocoLog(LEVEL_WARN, @"have a nil notification!");
	}
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	if(item == nil) {
        return [self.moduleData count];
	}
	return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
	if(item == nil) {
        return self.moduleData[(NSUInteger) index];
	}
    return nil;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    id ret = (NSString *)@"";
    
    ModuleListObject *mod = (ModuleListObject *)item;
    if([[tableColumn identifier] isEqualToString:TABLECOL_IDENTIFIER_MODNAME]) {
        ret = [[mod module] name];
    } else if([[tableColumn identifier] isEqualToString:TABLECOL_IDENTIFIER_MODSTATUS]) {
        int stat = [[mod module] status];
        if((stat & ModStatSameVersion) == ModStatSameVersion) {
            ret = NSLocalizedString(@"ModStatSameVersion", @"");
        } else if((stat & ModStatNew) == ModStatNew) {
            ret = NSLocalizedString(@"ModStatNew", @"");
        } else if((stat & ModStatUpdated) == ModStatUpdated) {
            ret = NSLocalizedString(@"ModStatUpdated", @"");
        } else if((stat & ModStatOlder) == ModStatOlder) {
            ret = NSLocalizedString(@"ModStatOlder", @"");
        }
    } else if([[tableColumn identifier] isEqualToString:TABLECOL_IDENTIFIER_MODCIPHERED]) {
        if(([[mod module] status] & ModStatCiphered) == ModStatCiphered) {
            ret = @YES;
        } else {
            ret = @NO;
        }
    } else if([[tableColumn identifier] isEqualToString:TABLECOL_IDENTIFIER_TASK]) {
        // for the cell we return the index number
        ret = @([mod taskId]);
    } else if([[tableColumn identifier] isEqualToString:TABLECOL_IDENTIFIER_MODTYPE]) {
        ret = [[mod module] typeString];
    } else if([[tableColumn identifier] isEqualToString:TABLECOL_IDENTIFIER_MODRVERSION]) {
        ret = [[mod module] version];
    } else if([[tableColumn identifier] isEqualToString:TABLECOL_IDENTIFIER_MODLVERSION]) {
        // if the module is installed, show installed version
        if(([[mod module] status] & ModStatNew) > 0) {
            // this module is not installed
            ret = @"";
        } else {
            ret = [[self.swordManager moduleWithName:[mod moduleName]] version];
        }
    } else if([[tableColumn identifier] isEqualToString:TABLECOL_IDENTIFIER_MODDESCR]) {
        ret = [[mod module] descr];
    }
    
    return ret;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return NO;
}

- (void)outlineView:(NSOutlineView *)aOutlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	// display call with std font
	NSFont *font = FontStd;
	[cell setFont:font];
	// set row height according to used font
	// get font height
	//float imageHeight = [[(CombinedImageTextCell *)cell image] size].height; 
	CGFloat pointSize = [font pointSize];
	[aOutlineView setRowHeight:pointSize+6];
	//[aOutlineView setRowHeight:imageHeight];
}

- (void)outlineView:(NSOutlineView *)outlineView sortDescriptorsDidChange:(NSArray *)oldDescriptors {
    NSArray *newDescriptors = [outlineView sortDescriptors];
    NSMutableArray *arr = [self.moduleData mutableCopy];
    [arr sortUsingDescriptors:newDescriptors];
    self.moduleData = arr;
    [moduleOutlineView reloadData];    
}

- (NSString *)outlineView:(NSOutlineView *)outlineView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tc item:(id)item mouseLocation:(NSPoint)mouseLocation {
    ModuleListObject *mod = (ModuleListObject *)item;
    return [[mod module] descr];
}

@end
