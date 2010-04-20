//
//  MvrItemStorage.h
//  Network
//
//  Created by ∞ on 12/09/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark Directories

// The temporary directory where to store stuff for nonpersistent MvrItemStorage objects.
// Process-wide. Ick but things got ugly quickly otherwise.
// Defaults to NSTemporaryDirectory(). Calling ...Set...(nil) resets to default.
extern NSString* MvrStorageTemporaryDirectory();
extern void MvrStorageSetTemporaryDirectory(NSString* path);

extern NSString* MvrUnusedPathInDirectoryWithExtension(NSString* path, NSString* ext, NSString** name);
extern NSString* MvrUnusedTemporaryFileNameWithPathExtension(NSString* ext);

#pragma mark -
#pragma mark Item storage

enum {
	kMvrItemStorageNoFilenameExtensionForTypeError = 1,
};
extern NSString* const kMvrItemStorageErrorDomain;

enum {
	kMvrStorageDestinationMemory,
	kMvrStorageDestinationDisk,
};
typedef NSUInteger MvrStorageDestination;

@interface MvrItemStorage : NSObject {
	BOOL persistent;
	
	NSData* data;
	NSString* path;
	
	NSOutputStream* lastOutputStream;
	NSString* outputStreamPath;
}

// Creating a new item storage.
+ itemStorage; // a new empty one.
+ itemStorageWithData:(NSData*) data;
+ itemStorageFromFileAtPath:(NSString*) path error:(NSError**) e; // If not in MvrStorageTemporaryDirectory(), it might be copied.
// + itemStorageWithContentsOfStream:(NSInputStream*) stream;

// If NO, the contents will be lost when the item storage is deallocated.
// You cannot set this property. Instead, add an item with this storage to the storage central.
@property(readonly, getter=isPersistent) BOOL persistent;

// The size in bytes of the content of this storage. (See 'Writing' for caveats.)
@property(readonly) unsigned long long contentLength;

// Causes the item storage to clear its cache and remove all in-memory content by offloading it to disk.
- (void) clearCache;

#pragma mark Reading from item storage
// These methods are independent of the actual kind of storage (in memory or on disk) used for this storage.
// The above means that if you call -data and the item was saved on a file on disk, it will be loaded. This is usually not the desired behavior if the item is big. See below for opportunistic reading methods.

@property(copy) NSData* data;

// The whole content of the storage as a NSData object. (For info on setting, see below in the 'Writing' section.)
- (NSData*) data;

// The path to an app-accessible file on disk that contains the item's contents. Exists for as long as this object does if no undue interference happens.
// The path may change from time to time after it has been returned if you interact with this object (notably, if you use the storage central to save it, or if you use -setPathExtension: or -setPathExtensionAssumingType:). KVO'able.
- (NSString*) path;

// YES if this object has written data to a path on disk, NO if it only exists in memory (and would be offloaded by a call to -path).
@property(readonly) BOOL hasPath;

// A new input stream reading from the content of the storage. Always just-constructed and unopened.
- (NSInputStream*) inputStream;

// Opportunistic reading. These methods are used to choose a "good", performance-wise and memory-wise, way to access the storage's content.

// Returns the 'best' way you can access the storage's contents. This is either a NSData or a NSInputStream object. Roughly speaking, if the object is already entirely in memory, it will exploit this by returning the NSData object; but if not, it will instead return a stream to that data on disk (or wherever it is stored).
// If it returns an input stream, it will always return it just-constructed and unopened (just like -inputStream).
- (id) preferredContentObject;

// Returns a NSData object if the contentLength is equal or less to the limit, otherwise nil.
- (NSData*) dataIfLengthIsAtMost:(unsigned long long) maximumLength;

#pragma mark Writing to item storage
// All writing methods clear whatever contents the item storage previously held when called.

// Returns an unopened output stream. Write to this stream to set the contents of the item storage. The size for ...OfAssumedSize: will be used as a hint to the item storage to choose where to store what is written to the stream. Otherwise, if the size is unknown but the order of magnitude is, you can use ...ForStorageIn: to choose where to save the stream yourself.
// Note that being wrong about the size passed to ...OfAssumedSize: may lead to out-of-memory crashes if more data is written on the stream than what was given, so it's important to get it right or at least overestimate conservatively.
// Same with ...ForStorageIn:. If you don't know how big it is, save to disk (kMvrStorageDestinationDisk) or you might run into crashes.
// When you have finished writing to the stream and closed it, you MUST call the -endUsingOutputStream method to let the item storage take ownership of the data you wrote.
// It's a programmer error to use ANY method or access ANY property of this object before calling -endUsingOutputStream (except calling that method, of course) OR to call it before closing the stream. Behavior is undefined in either case.
- (NSOutputStream*) outputStreamForContentOfAssumedSize:(unsigned long long) size;
- (NSOutputStream*) outputStreamForStorageIn:(MvrStorageDestination) destination;
- (void) endUsingOutputStream;

// Setting the .data property causes the whole content of the storage item to be reset to whatever you passed. Depending on the length of the data, it might immediately be written to disk rather than keeping a copy in memory (with similar size limits than those used for outputStreamForContentOfAssumedSize:).
- (void) setData:(NSData*) data;

// The first method below changes the path on disk so that it ends with the specified extension. This is useful for interacting with other libraries that expect the path to end in a certain way (I'm looking at you, MPMoviePlayerController!). Do not include the dot. (eg: @"mp4", @"txt".)
// The extension is kept if the path changes due to some automatic operation of MvrItemStorage (for example, moving an item from temporary to persistent on-disk storage).
// Note that this operation is equivalent to requesting the value of the .path property in terms of timing -- this means that if a path didn't exist yet, data will be written to disk to make one. Use with care.
// The second method is a convenience method that calls the first with the default extension for the given UTI.
- (BOOL) setPathExtension:(NSString*) ext error:(NSError**) e;
- (BOOL) setPathExtensionAssumingType:(id) uti error:(NSError**) e;

@end

#pragma mark Methods for use by the storage central only

#if kMvrItemStorageAllowFriendMethods
@interface MvrItemStorage ()

+ itemStorageFromFileAtPath:(NSString*) path persistent:(BOOL) persistent error:(NSError**) e;

@property(copy, setter=private_setPath:) NSString* path;
@property(assign, setter=private_setPersistent:) BOOL persistent;

@end
#endif
