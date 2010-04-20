//
//  MvrStorageCentral.h
//  Network+Storage
//
//  Created by ∞ on 16/09/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MvrMetadataStorage.h"

@class L0KVODispatcher;

@interface MvrStorageCentral : NSObject {
	NSMutableSet* storedItems;
	NSMutableDictionary* metadata;
	L0KVODispatcher* dispatcher;
	
	NSString* persistentDirectory;
	id <MvrMetadataStorage> metadataStorage;
}

- (id) initWithPersistentDirectory:(NSString*) dir metadataStorage:(id <MvrMetadataStorage>) meta;

// Add an item here to save it to persistent storage. Remove it from here to remove it from persistent storage. The item storage object used by this item will be made persistent on addition and nonpersistent on removal.
// The item may be asked to immediately clear its cache. You should access the item (eg to produce thumbnails) BEFORE putting it into storage, to avoid the item's content being needlessly reloaded from disk.
@property(readonly) NSMutableSet* mutableStoredItems;
@property(readonly) NSSet* storedItems;

// Clears the cache on all stored items.
- (void) clearCache;

@end