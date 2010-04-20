//
//  MvrStorageCentral.m
//  Network+Storage
//
//  Created by ∞ on 16/09/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import "MvrStorageCentral.h"

#import <MuiKit/MuiKit.h>

#define kMvrItemStorageAllowFriendMethods 1
#import "MvrItemStorage.h"
#import "MvrItem.h"

@interface MvrStorageCentral ()

- (void) saveMetadata;

@end


@implementation MvrStorageCentral

- (id) initWithPersistentDirectory:(NSString*) dir metadataStorage:(id <MvrMetadataStorage>) meta;
{
	if (self = [super init]) {
		metadataStorage = [meta retain];
		persistentDirectory = [dir copy];
		
		metadata = [NSMutableDictionary new];
		dispatcher = [[L0KVODispatcher alloc] initWithTarget:self];
	}
	
	return self;
}

- (void) dealloc;
{
	[dispatcher release];
	
	[metadata release];
	[storedItems release];
	
	[persistentDirectory release];
	[metadataStorage release];
	
	[super dealloc];
}

+ (NSString*) unusedTemporaryFileNameWithPathExtension:(NSString*) ext;
{
	return MvrUnusedTemporaryFileNameWithPathExtension(ext);
}

+ (NSString*) unusedPathInDirectory:(NSString*) path withPathExtension:(NSString*) ext fileName:(NSString**) name;
{
	return MvrUnusedPathInDirectoryWithExtension(path, ext, name);
}

- (NSMutableSet*) mutableStoredItems;
{
	return [self mutableSetValueForKey:@"storedItems"];
}

- (NSSet*) storedItems;
{
	if (storedItems)
		return storedItems;
	
	storedItems = [NSMutableSet new];
	[metadata removeAllObjects];
	
	//NSDictionary* storedMetadata = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"L0SlidePersistedItems"];
	NSDictionary* storedMetadata = metadataStorage.metadata;
	if (!storedMetadata)
		return storedItems; // empty
	
	for (NSString* name in storedMetadata) {
		NSDictionary* itemInfo = [storedMetadata objectForKey:name];
		if (![itemInfo isKindOfClass:[NSDictionary class]])
			continue;
		
		NSString* type = [itemInfo objectForKey:@"Type"];
		
		NSDictionary* moreMeta = [itemInfo objectForKey:@"Metadata"];
		if (!moreMeta || ![moreMeta isKindOfClass:[NSDictionary class]]) {
			NSString* title = [itemInfo objectForKey:@"Title"];
			
			if (title)
				moreMeta = [NSDictionary dictionaryWithObject:title forKey:kMvrItemTitleMetadataKey];
		}

		if (!moreMeta || !type)
			continue;
		
		NSString* path = [persistentDirectory stringByAppendingPathComponent:name];
		
		NSError* e;
		MvrItemStorage* itemStorage = [MvrItemStorage itemStorageFromFileAtPath:path persistent:YES error:&e];
		if (!itemStorage) {
			L0LogAlways(@"%@", e);
		} else {
			MvrItem* item = [MvrItem itemWithStorage:itemStorage type:type metadata:moreMeta];
			if (item) {
				NSDictionary* d = [itemInfo objectForKey:@"Notes"];
				if (d && [d isKindOfClass:[NSDictionary class]])
					item.itemNotes = d;
				
				[storedItems addObject:item];
				[metadata setObject:[NSDictionary dictionaryWithObjectsAndKeys:
									 type, @"Type",
									 moreMeta, @"Metadata",
									 d, @"Notes",
									 nil] forKey:name];
				[dispatcher observe:@"path" ofObject:itemStorage usingSelector:@selector(pathOfItemStorage:changed:) options:0];
				[dispatcher observe:@"metadata" ofObject:item usingSelector:@selector(metadataOfItem:changed:) options:0];
				[dispatcher observe:@"itemNotes" ofObject:item usingSelector:@selector(metadataOfItem:changed:) options:0];
			}
		}
	}
	
	return storedItems;
}

- (void) addStoredItemsObject:(MvrItem *)item;
{
	if ([self.storedItems containsObject:item])
		return;
	
	MvrItemStorage* storage = [item storage];
	NSString* path, * name;
	path = [[self class] unusedPathInDirectory:persistentDirectory withPathExtension:[storage.path pathExtension] fileName:&name];
	
	L0Log(@"Older path of storage about to be made persistent: %@", storage.hasPath? @"(none)" : storage.path);
	
	NSError* e;
	BOOL done = [[NSFileManager defaultManager] moveItemAtPath:storage.path toPath:path error:&e];
	if (!done) {
		L0LogAlways(@"%@", e);
		return;
	}
	
	[metadata setObject:[NSDictionary dictionaryWithObjectsAndKeys:
						 item.metadata, @"Metadata",
						 item.type, @"Type",
						 item.itemNotes, @"Notes",
						 nil] forKey:name];
	[self saveMetadata];
	
	storage.path = path;
	storage.persistent = YES;
	
	L0Log(@"Item made persistent: %@ (%@)", item, storage);
	
	[storedItems addObject:item];
	
	[dispatcher observe:@"path" ofObject:storage usingSelector:@selector(pathOfItemStorage:changed:) options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld];
}

- (void) pathOfItemStorage:(MvrItemStorage*) storage changed:(NSDictionary*) change;
{
	NSString* oldPath = L0KVOPreviousValue(change);
	
	if (!storage.persistent || ![storedItems containsObject:storage] || !storage.path || !oldPath)
		return;
	
	NSString* oldItemName = [oldPath lastPathComponent];
	id oldMetadata;
	if ((oldMetadata = [metadata objectForKey:oldItemName])) {
		[metadata setObject:oldMetadata forKey:[storage.path lastPathComponent]];
		[metadata removeObjectForKey:oldPath];
		[self saveMetadata];
	}
}

- (void) metadataOfItem:(MvrItem*) item changed:(NSDictionary*) change;
{
	NSString* name = [item.storage.path lastPathComponent];
	[metadata setObject:[NSDictionary dictionaryWithObjectsAndKeys:
						 item.metadata, @"Metadata",
						 item.type, @"Type",
						 item.itemNotes, @"Notes",
						 nil] forKey:name];
	[self saveMetadata];
}

- (void) removeStoredItemsObject:(MvrItem*) item;
{
	[dispatcher endObserving:@"path" ofObject:item.storage];
	[dispatcher endObserving:@"metadata" ofObject:item];
	[dispatcher endObserving:@"itemNotes" ofObject:item];
	
	if (![self.storedItems containsObject:item])
		return;
		
	MvrItemStorage* storage = [item storage];
	if (storage.hasPath) {
		NSString* path = storage.path, * name = [path lastPathComponent],
		* newPath = [[self class] unusedTemporaryFileNameWithPathExtension:[storage.path pathExtension]];
		
		[metadata removeObjectForKey:name];
		[self saveMetadata];
		
		NSError* e;
		BOOL done = [[NSFileManager defaultManager] moveItemAtPath:path toPath:newPath error:&e];
		if (!done)
			L0LogAlways(@"%@", e);
		else
			storage.path = newPath;
	}
	
	storage.persistent = NO;
	
	[storedItems removeObject:item];
}

- (void) saveMetadata;
{
	metadataStorage.metadata = metadata;
}

- (void) clearCache;
{
	[self.storedItems makeObjectsPerformSelector:@selector(clearCache)];
}

@end
