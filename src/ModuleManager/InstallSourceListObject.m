//
//  InstallSourceListObject.m
//  Eloquent
//
//  Created by Manfred Bergmann on 10.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <ObjCSword/ObjCSword.h>
#import "InstallSourceListObject.h"


@implementation InstallSourceListObject

// -------------------- getter / setter -------------------
- (SwordInstallSource *)installSource {
    return installSource;
}

- (void)setInstallSource:(SwordInstallSource *)value {
    installSource = value;
}

- (NSString *)moduleType {
    return moduleType;
}

- (void)setModuleType:(NSString *)value {
    moduleType = value;    
}

- (InstallSourceListObjectType)objectType {
    return objectType;
}

- (void)setObjectType:(InstallSourceListObjectType)value {
    objectType = value;
}

- (NSArray *)subInstallSources {
    return subInstallSources;
}

- (void)setSubInstallSources:(NSArray *)value {
    subInstallSources = value;    
}

// -------------------- methods-----------------------

/** convenient allocator */
+ (InstallSourceListObject *)installSourceListObjectForType:(InstallSourceListObjectType)type {
    InstallSourceListObject *object = [[InstallSourceListObject alloc] initWithListObjectType:type];
    return object;
}

- (id)initWithListObjectType:(InstallSourceListObjectType)type {
    self = [super init];
    
    if(self) {
        objectType = type;
    }
    
    return self;
}

- (void)dealloc {
    
    [self setInstallSource:nil];
    [self setSubInstallSources:nil];
    [self setModuleType:nil];
    
}


@end
