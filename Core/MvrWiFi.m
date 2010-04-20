//
//  MvrWiFi.m
//  Network
//
//  Created by ∞ on 12/09/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import "MvrWiFi.h"

#import "MvrChannel.h"

#import "MvrModernWiFi.h"
#import "MvrModernWiFiChannel.h"


@interface MvrSyntheticWiFiChannel : NSObject <MvrChannel> {
	MvrModernWiFiChannel* modernChannel;
	
	NSMutableSet* incomingTransfers;
	NSMutableSet* outgoingTransfers;

	L0KVODispatcher* dispatcher;
}

@property(retain) MvrModernWiFiChannel* modernChannel;

- (void) addChannel:(id) chan;
- (BOOL) removeChannelAndReturnIfEmpty:(id) chan;

- askChannelsForKey:(NSString*) key;

@end

@implementation MvrSyntheticWiFiChannel

- (id) init
{
	self = [super init];
	if (self != nil) {
		dispatcher = [[L0KVODispatcher alloc] initWithTarget:self];
	}
	return self;
}

@synthesize modernChannel;

- (void) dealloc;
{
	[dispatcher release];
	
	self.modernChannel = nil;
	
	[super dealloc];
}

- (void) addChannel:(id) chan;
{
	if ([chan isKindOfClass:[MvrModernWiFiChannel class]]) {
		[self willChangeValueForKey:@"supportsStreams"];
		self.modernChannel = chan;
		[self didChangeValueForKey:@"supportsStreams"];
	}else
		return;
}

- (BOOL) removeChannelAndReturnIfEmpty:(id) chan;
{
	if ([chan isEqual:self.modernChannel]) {
		[self willChangeValueForKey:@"supportsStreams"];
		self.modernChannel = nil;
		[self didChangeValueForKey:@"supportsStreams"];
	}

	BOOL willRemove = !self.modernChannel;
	L0Log(@"Empty? = %d", willRemove);
	return willRemove;
}

- (NSString*) description;
{
	return [NSString stringWithFormat:@"%@ { legacy = (%@, %@); modern = %@ }", [super description], @"<no legacy support>", @"<no legacy support>", self.modernChannel];
}

- (NSSet*) incomingTransfers;
{
	return incomingTransfers;
}

- (NSSet*) outgoingTransfers;
{
	return outgoingTransfers;
}

- askChannelsForKey:(NSString*) key;
{
	return [self.modernChannel valueForKey:key];
}

- (NSString*) displayName;
{
	return [self askChannelsForKey:@"displayName"];
}

- (void) beginSendingItem:(MvrItem *)item;
{
	if (self.modernChannel)
		[self.modernChannel beginSendingItem:item];
}

- (BOOL) supportsStreams;
{
	return self.modernChannel && [self.modernChannel supportsStreams];
}

@end



@implementation MvrWiFi

- (id) initWithPlatformInfo:(id <MvrPlatformInfo>) info modernPort:(int) modernPort legacyPort:(int) legacyPort;
{
	self = [super init];
	if (self != nil) {
		self.modernWiFi = [[[MvrModernWiFi alloc] initWithPlatformInfo:info serverPort:modernPort] autorelease];
		
		channelsByIdentifier = [NSMutableDictionary new];
		modernObserver = [[MvrScannerObserver alloc] initWithScanner:self.modernWiFi delegate:self];
		legacyObserver = nil;
	}
	
	return self;
}

@synthesize modernWiFi, legacyWiFi;

- (void) dealloc;
{
	[modernObserver release];
	[legacyObserver release];
	
	self.modernWiFi = nil;
	self.legacyWiFi = nil;
	[channelsByIdentifier release];
	[super dealloc];
}

#pragma mark KVO notifications

- (BOOL) enabled;
{
	return enabled;
}

- (void) scanner:(id <MvrScanner>)s didChangeEnabledKey:(BOOL)en;
{
	[self willChangeValueForKey:@"enabled"];
	enabled = self.modernWiFi.enabled;
	[self didChangeValueForKey:@"enabled"];
}

- (void) setEnabled:(BOOL) e;
{
	self.modernWiFi.enabled = e;
	enabled = e;
}

- (BOOL) jammed;
{
	return jammed;
}

- (void) scanner:(id <MvrScanner>)s didChangeJammedKey:(BOOL)ja;
{
	// ick.
	[self willChangeValueForKey:@"jammed"];
	jammed = self.modernWiFi.jammed;
	[self didChangeValueForKey:@"jammed"];
}

- (NSSet*) channels;
{
	return [NSSet setWithArray:[channelsByIdentifier allValues]];
}

#pragma mark Observer methods

- (void) scanner:(id <MvrScanner>) s didAddChannel:(id <MvrChannel>) channel;
{
	NSString* ident = [(id)channel identifier];
	MvrSyntheticWiFiChannel* syn = [channelsByIdentifier objectForKey:ident];
	
	if (!syn) {		
		syn = [[MvrSyntheticWiFiChannel new] autorelease];
		
		[self willChangeValueForKey:@"channels" withSetMutation:NSKeyValueUnionSetMutation usingObjects:[NSSet setWithObject:syn]];
		
		[syn addChannel:channel];
		[channelsByIdentifier setObject:syn forKey:ident];
		
		[self didChangeValueForKey:@"channels" withSetMutation:NSKeyValueUnionSetMutation usingObjects:[NSSet setWithObject:syn]];
	} else
		[syn addChannel:channel];
}

- (void) scanner:(id <MvrScanner>) s didRemoveChannel:(id <MvrChannel>) channel;			
{
	NSString* ident = [(id)channel identifier];
	MvrSyntheticWiFiChannel* syn = [channelsByIdentifier objectForKey:ident];
	
	if (syn) {
		
		BOOL deleteMe = [syn removeChannelAndReturnIfEmpty:channel];
		if (deleteMe) {
			[self willChangeValueForKey:@"channels" withSetMutation:NSKeyValueMinusSetMutation usingObjects:[NSSet setWithObject:syn]];
			
			[channelsByIdentifier removeObjectForKey:ident];

			[self didChangeValueForKey:@"channels" withSetMutation:NSKeyValueMinusSetMutation usingObjects:[NSSet setWithObject:syn]];
		}
		
	}
}

- (void) channel:(id <MvrChannel>) channel didBeginReceivingWithIncomingTransfer:(id <MvrIncoming>) incoming;
{
	NSString* ident = [(id)channel identifier];
	MvrSyntheticWiFiChannel* syn = [channelsByIdentifier objectForKey:ident];
	[[syn mutableSetValueForKey:@"incomingTransfers"] addObject:incoming];
}

- (void) channel:(id <MvrChannel>) channel didBeginSendingWithOutgoingTransfer:(id <MvrOutgoing>) outgoing;
{
	NSString* ident = [(id)channel identifier];
	MvrSyntheticWiFiChannel* syn = [channelsByIdentifier objectForKey:ident];
	[[syn mutableSetValueForKey:@"outgoingTransfers"] addObject:outgoing];
}

- (void) outgoingTransferDidEndSending:(id <MvrOutgoing>) outgoing;
{
	for (NSString* ident in channelsByIdentifier) {
		MvrSyntheticWiFiChannel* syn = [channelsByIdentifier objectForKey:ident];
		[[syn mutableSetValueForKey:@"outgoingTransfers"] removeObject:outgoing];
	}
}

// i == nil if cancelled.
- (void) incomingTransfer:(id <MvrIncoming>) incoming didEndReceivingItem:(MvrItem*) i;
{
	for (NSString* ident in channelsByIdentifier) {
		MvrSyntheticWiFiChannel* syn = [channelsByIdentifier objectForKey:ident];
		[[syn mutableSetValueForKey:@"incomingTransfers"] removeObject:incoming];
	}
}

@end
