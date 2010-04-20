//
//  MvrWiFiIncomingTransfer.m
//  Mover
//
//  Created by ∞ on 25/08/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import "MvrModernWiFiIncoming.h"

#import "AsyncSocket.h"
#import "MvrItemStorage.h"
#import "MvrModernWiFi.h"
#import "MvrModernWiFiChannel.h"
#import "MvrItem.h"
#import "MvrProtocol.h"

#import <MuiKit/MuiKit.h>


@implementation MvrModernWiFiIncoming

- (id) initWithSocket:(AsyncSocket*) s scanner:(MvrModernWiFi*) sc;
{
	if (self = [super init]) {
		socket = [s retain];
		[s setDelegate:self];
		
		parser = [[MvrPacketParser alloc] initWithDelegate:self];
		isNewPacket = YES;
		
		scanner = sc; // It owns us.
		metadata = [NSMutableDictionary new];
	}
	
	return self;
}

- (void) dealloc;
{
	[self cancel];
	[parser release];

	[super dealloc];
}

#pragma mark -
#pragma mark Sockets.

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port;
{
	L0Log(@"%@:%d", host, port);
	channel = [[scanner channelForAddress:[sock connectedHostAddress]] retain];
	if (!channel)
		[self cancel];
	L0Log(@" => %@", channel);
	
	[[channel mutableSetValueForKey:@"incomingTransfers"] addObject:self];
	
	[sock readDataWithTimeout:30 tag:0];
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)d withTag:(long)tag;
{
	L0Log(@"%llu bytes received", (unsigned long long) [d length]);
	
	[parser appendData:d isKnownStartOfNewPacket:isNewPacket];
	isNewPacket = NO;
	
	unsigned long long size = parser.expectedSize;
	L0Log(@"Now expecting %llu bytes. (0 == no limit)", size);
	if (size == 0)
		[sock readDataWithTimeout:15 tag:0];
	else
		[sock readDataToLength:size withTimeout:15 tag:0];
}

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err;
{
	L0Log(@"%@", err);
	[self cancel];
}

#pragma mark -
#pragma mark Cleaning up

- (void) clear;
{
	[channel release]; channel = nil;
	
	[socket disconnect];
	[socket setDelegate:nil];
	[socket release]; socket = nil;
	[super clear];
}

- (void) produceItem;
{
	[socket writeData:[AsyncSocket LFData] withTimeout:-1 tag:0];
	[socket disconnectAfterWriting];
	[super produceItem];
}
	
@end
