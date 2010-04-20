//
//  MvrModernWiFi.m
//  Network
//
//  Created by ∞ on 12/09/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import "MvrModernWiFi.h"

#import "MvrModernWiFiChannel.h"
#import "AsyncSocket.h"
#import "MvrModernWiFiIncoming.h"

#import <MuiKit/MuiKit.h>

@interface MvrModernWiFi ()
- (void) startListening;
@end


@implementation MvrModernWiFi

- (id) initWithPlatformInfo:(id <MvrPlatformInfo>) info serverPort:(int) port;
{
	self = [super init];
	if (self != nil) {
		NSDictionary* record = [NSDictionary dictionaryWithObjectsAndKeys:
								/* TODO */
								[info.identifierForSelf stringValue], kMvrModernWiFiPeerIdentifierKey,
								nil];
		
		[self addServiceWithName:[info displayNameForSelf] type:kMvrModernWiFiBonjourServiceType port:port TXTRecord:record];
		[self addBrowserForServicesWithType:kMvrModernWiFiBonjourServiceType];
		
		incomingTransfers = [NSMutableSet new];
		dispatcher = [[L0KVODispatcher alloc] initWithTarget:self];
		
		serverPort = port;
 	}

	return self;
}

- (void) start;
{
	serverSocket = [[AsyncSocket alloc] initWithDelegate:self];
	[self startListening];
	[super start];	
}

- (void) startListening;
{
	NSError* e;
	if (![serverSocket acceptOnPort:serverPort error:&e]) {		
		L0LogAlways(@"Having difficulty accepting modern connections on port %d, retrying shortly: %@", serverPort, e);
		[[NSNotificationCenter defaultCenter] postNotificationName:kMvrModernWiFiDifficultyStartingListenerNotification object:self];
		[self performSelector:@selector(startListening) withObject:nil afterDelay:1.0];
	}
}

- (void) stop;
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startListening) object:nil];
	[super stop];
	[serverSocket disconnect];
	[serverSocket release]; serverSocket = nil;
}

- (void) dealloc
{
	[dispatcher release];
	[incomingTransfers release];
	[super dealloc];
}


#pragma mark -
#pragma mark Channel management

- (MvrModernWiFiChannel*) channelForAddress:(NSData*) address;
{
	for (MvrModernWiFiChannel* chan in [[channels copy] autorelease]) {
		if ([chan isReachableThroughAddress:address])
			return chan;
	}
	
	return nil;
}

- (void) foundService:(NSNetService *)s;
{
	L0Log(@"%@", s);
	
	NSDictionary* idents = [self stringsForKeys:[NSSet setWithObject:kMvrModernWiFiPeerIdentifierKey] inTXTRecordData:[s TXTRecordData] encoding:NSASCIIStringEncoding];
	NSString* ident = [idents objectForKey:kMvrModernWiFiPeerIdentifierKey];
	
	if (!ident) {
		L0Log(@"Service %@ has its UUID missing, so we don't display it.", s);
		return;
	}
	
	MvrModernWiFiChannel* chan = [[MvrModernWiFiChannel alloc] initWithNetService:s identifier:ident];
	[self.mutableChannels addObject:chan];
	[chan release];
}

- (void) lostService:(NSNetService *)s;
{
	L0Log(@"%@", s);
	
	for (MvrModernWiFiChannel* chan in [[channels copy] autorelease]) {
		if ([chan hasSameServiceAs:s])
			[self.mutableChannels removeObject:chan];
	}
}

#pragma mark -
#pragma mark Server sockets

- (void) onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket;
{
	MvrModernWiFiIncoming* incoming = [[MvrModernWiFiIncoming alloc] initWithSocket:newSocket scanner:self];
	[incomingTransfers addObject:incoming];
	
	[incoming observeUsingDispatcher:dispatcher invokeAtItemChange:@selector(itemOrCancelledOfTransfer:changed:) atCancelledChange:@selector(itemOrCancelledOfTransfer:changed:)];
	
	[incoming release];
}

- (void) itemOrCancelledOfTransfer:(MvrModernWiFiIncoming*) transfer changed:(NSDictionary*) changed;
{
	if (transfer.item || transfer.cancelled) {
		[transfer endObservingUsingDispatcher:dispatcher];
		[incomingTransfers removeObject:transfer];
	}
}

@end
