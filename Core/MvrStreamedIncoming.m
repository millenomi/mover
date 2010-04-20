//
//  MvrStreamedIncoming.m
//  Network+Storage
//
//  Created by ∞ on 06/10/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import "MvrStreamedIncoming.h"

#import "MvrItemStorage.h"
#import "MvrProtocol.h"
#import "MvrItem.h"

#import <unistd.h>

static BOOL MvrWriteDataToOutputStreamSynchronously(NSOutputStream* stream, NSData* data, NSError** e) {
	
	NSInteger written = 0; const void* bytes = [data bytes];
	while (written < [data length]) {
		
		if ([stream hasSpaceAvailable]) {
			NSInteger newlyWritten = [stream write:(bytes + written) maxLength:([data length] - written)];
			
			if (newlyWritten == -1) {
				if (e) *e = [stream streamError];
				return NO;
			}
			
			written += newlyWritten;
			
		}
		
		usleep(50 * 1000);
	}
	
	return YES;
	
}

@implementation MvrStreamedIncoming

- (id) init
{
	self = [super init];
	if (self != nil) {
		parser = [[MvrPacketParser alloc] initWithDelegate:self];
		metadata = [NSMutableDictionary new];
	}
	return self;
}

- (void) dealloc
{
	[self clear];
	[super dealloc];
}



- (void) packetParserDidStartReceiving:(MvrPacketParser*) p;
{
	self.progress = p.progress;
}

- (void) packetParser:(MvrPacketParser*) p didReceiveMetadataItemWithKey:(NSString*) key value:(NSString*) value;
{
	if (self.cancelled) return;
	
	self.progress = p.progress;
	[metadata setObject:value forKey:key];
}

- (void) packetParser:(MvrPacketParser*) p willReceivePayloadForKey:(NSString*) key size:(unsigned long long) size;
{
	if (![key isEqual:kMvrProtocolExternalRepresentationPayloadKey])
		return;
	
	NSAssert(!itemStorage, @"No item storage must have been created");
	NSAssert(!itemStorageStream, @"No item storage stream must have been created");
	
	itemStorage = [[MvrItemStorage itemStorage] retain];
	itemStorageStream = [[itemStorage outputStreamForContentOfAssumedSize:size] retain];
	[itemStorageStream open];
}

- (void) packetParser:(MvrPacketParser*) p didReceivePayloadPart:(NSData*) d forKey:(NSString*) key;
{
	if (self.cancelled) return;
	
	[self checkMetadataIfNeeded];
	if (self.cancelled) return; // could cancel in checkMetadata...
	
	if (![key isEqual:kMvrProtocolExternalRepresentationPayloadKey])
		return;
	
	self.progress = p.progress;
	NSAssert(itemStorageStream && [itemStorageStream streamStatus] != NSStreamStatusNotOpen, @"We have a stream and it's open.");
	
	L0Log(@"Incoming item progressing at %f", p.progress);
	
	NSError* e;
	if (!MvrWriteDataToOutputStreamSynchronously(itemStorageStream, d, &e)) {
		L0LogAlways(@"Got an error while writing to the offloading stream: %@", e);
		[self cancel];
	}
	
	[self didReceiveData:d];
}

- (void) didReceiveData:(NSData*) data;
{	
}

// e == nil if no error.
- (void) packetParser:(MvrPacketParser*) p didReturnToStartingStateWithError:(NSError*) e;
{
	if (e) {
		L0Log(@"An error happened while parsing: %@", e);
		[self cancel];
	} else
		[self produceItem];
}

- (void) checkMetadataIfNeeded;
{
	if (![metadata objectForKey:kMvrProtocolMetadataTitleKey] || ![metadata objectForKey:kMvrProtocolMetadataTypeKey])
		[self cancel];
}


#pragma mark -
#pragma mark Flow control.

- (void) cancel;
{
	self.item = nil;
	self.cancelled = YES;
	[self clear];
}

- (void) produceItem;
{
	self.progress = 1.0;
	
	NSString* title = [metadata objectForKey:kMvrProtocolMetadataTitleKey], 
	* type = [metadata objectForKey:kMvrProtocolMetadataTypeKey];
	
	[itemStorageStream close]; 
	[itemStorageStream release]; itemStorageStream = nil;
	[itemStorage endUsingOutputStream];
	
	MvrItem* i = [MvrItem itemWithStorage:itemStorage type:type metadata:[NSDictionary dictionaryWithObject:title forKey:kMvrItemTitleMetadataKey]];
	
	self.item = i;
	self.cancelled = (i == nil);
	
	[self clear];
}

- (void) clear;
{
	self.progress = kMvrIndeterminateProgress;
	
	[parser release]; parser = nil;
	
	[metadata release]; metadata = nil;
	
	if (itemStorageStream) {
		[itemStorageStream close];
		[itemStorage endUsingOutputStream];
		[itemStorageStream release];
		itemStorageStream = nil;
	}
	
	if (itemStorage) {
		[itemStorage release];
		itemStorage = nil;
	}	
}

- (void) appendData:(NSData*) data;
{
	[parser appendData:data];
}

@end
