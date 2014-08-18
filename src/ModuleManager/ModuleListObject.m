//
//  ModuleListObject.m
//  Eloquent
//
//  Created by Manfred Bergmann on 01.01.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "ModuleListObject.h"
#import "ObjCSword/SwordInstallSource.h"

@implementation ModuleListObject

// ------------------ getter / setter -----------------
- (SwordModule *)module {
    return module;
}

- (void)setModule:(SwordModule *)value {
    if (module != value) {
        module = value;
    }
}

- (SwordInstallSource *)installSource {
    return installSource;
}

- (void)setInstallSource:(SwordInstallSource *)value {
    if (installSource != value) {
        installSource = value;
    }
}

- (ModuleTaskId)taskId {
    return taskId;
}

- (void)setTaskId:(ModuleTaskId)value {
    taskId = value;
}

// ------------------ methods -----------------

- (void)dealloc {
    [self setModule:nil];
    [self setInstallSource:nil];
    
}


- (NSString *)moduleName {
    return [module name];
}
- (NSString *)moduleTypeString {
    return [module typeString];
}
- (NSInteger)moduleStatus {
    return [module status];
}

@end
