//
//  MvrWiFiOutgoingTransfer.m
//  Mover
//
//  Created by ∞ on 29/08/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import "MvrModernWiFiOutgoing.h"

#import <MuiKit/MuiKit.h>

#import "AsyncSocket.h"
#import "MvrItem.h"
#import "MvrPacketBuilder.h"
#import "MvrModernWiFiChannel.h"
#import "MvrItemStorage.h"

@interface MvrModernWiFiOutgoing ()

- (void) cancel;
- (void) endWithError:(NSError *)e;

- (void) buildPacket;

@property(assign) BOOL finished;
@property(assign) float progress;
@property(retain) NSError* error;

- (NSData*) bestCandidateAddress;

@end


@implementation MvrModernWiFiOutgoing

- (id) initWithItem:(MvrItem*) i toAddresses:(NSArray*) a;
{
	if (self = [super init]) {
		item = [i retain];
		addresses = [a copy];
	}
	
	return self;
}

@synthesize finished, progress, error;

- (void) dealloc;
{
	[self cancel];
	[item release];
	[addresses release];
	[error release];
	[super dealloc];
}

#pragma mark -
#pragma mark Socket and state management.

static BOOL MvrIPv6Allowed = NO;

+ (void) allowIPv6;
{
	MvrIPv6Allowed = YES;
}

- (NSData*) bestCandidateAddress;
{
	// We try to avoid using the BT PAN network interface by looking for an address that does NOT begin with 169.254. (that is, auto-assigned); we only use addresses like that if there's nothing else good available.
	// Also: iPhone OS 3.0 does NOT support IPv6 so we simply ignore all IPv6 addresses. This is, um, questionable for a number of reasons, but it's a thing I don't want to fix right now. This can be changed by using [MvrModernWiFiOutgoing allowIPv6].
	
	NSData* address = nil, * secondBestAddress = nil;
	for (NSData* potentialAddress in addresses) {
		if (!MvrIPv6Allowed && ![potentialAddress socketAddressIsIPAddressOfVersion:kL0IPAddressVersion4])
			continue;
		
		if (!secondBestAddress)
			secondBestAddress = potentialAddress;
		
		// I know it's icky, and yet.
		if (!address && ![[potentialAddress socketAddressStringValue] hasPrefix:@"169.254."])
			address = potentialAddress;
		
		if (address && secondBestAddress) break;
	}
	
	L0Log(@"Picked candidate addresses %@ (best, nil = no best), %@ (second best)", [address socketAddressStringValue], [secondBestAddress socketAddressStringValue]);
	
	if (!address)
		address = secondBestAddress;
	
	return address;
}

- (void) start;
{
	NSData* address = [self bestCandidateAddress];
	
	if (!address) {
		[self cancel];
		return;
	}
	
	NSAssert(!socket, @"No socket before starting");
	socket = [[AsyncSocket alloc] initWithDelegate:self];
	
	NSError* e = nil;
	BOOL done = [socket connectToAddress:address withTimeout:15 error:&e];
	if (!done) {
		L0Log(@"Did not connect: %@", e);
		[self endWithError:e];
		return;
	}
}

- (void) cancel;
{
	[self endWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
}

- (void) endWithError:(NSError*) e;
{
	if (self.finished) return;
	
	L0Log(@"%@", e);
	self.error = e;
	
	[builder stop];
	[builder release]; builder = nil;
	
	[socket setDelegate:nil];
	[socket release]; socket = nil;
	
	[[self retain] autorelease]; // people watching -finished could release us. Prevent nastiness.
	self.finished = YES;
}

- (void) onSocket:(AsyncSocket*) sock didConnectToHost:(NSString*) host port:(UInt16) port;
{
	L0Log(@"%@:%d", host, port);
	[self buildPacket];
}

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err;
{
	if (err)
		[self endWithError:err];
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag;
{
	L0Note();
	[self endWithError:nil];
}

- (void) onSocketDidDisconnect:(AsyncSocket *)sock;
{
	L0Note();
	[self endWithError:nil];
}

#pragma mark -
#pragma mark Packet building.

- (void) buildPacket;
{
	builder = [[MvrPacketBuilder alloc] initWithDelegate:self];
	
	[builder setMetadataValue:item.title forKey:kMvrProtocolMetadataTitleKey];
	[builder setMetadataValue:item.type forKey:kMvrProtocolMetadataTypeKey];
	
	[builder addPayload:[item.storage preferredContentObject] length:item.storage.contentLength forKey:kMvrProtocolExternalRepresentationPayloadKey];
	
	[builder start];
}

- (void) packetBuilderWillStart:(MvrPacketBuilder *)b;
{
	[self willChangeValueForKey:@"progress"];
	self.progress = builder.progress;
	[self didChangeValueForKey:@"progress"];
}

- (void) packetBuilder:(MvrPacketBuilder*) b didProduceData:(NSData*) d;
{
	[socket writeData:d withTimeout:-1 tag:0];

	L0Log(@"Writing %llu bytes, %u chunks now pending", (unsigned long long) [d length], chunksPending);
	
	[self willChangeValueForKey:@"progress"];
	self.progress = builder.progress;
	[self didChangeValueForKey:@"progress"];	
}

- (void) packetBuilder:(MvrPacketBuilder*) b didEndWithError:(NSError*) e;
{	
	[self willChangeValueForKey:@"progress"];
	self.progress = builder.progress;
	[self didChangeValueForKey:@"progress"];
	
	if (e)
		[self endWithError:e];
	
	[socket readDataToLength:1 withTimeout:120 tag:0];
}

@end
