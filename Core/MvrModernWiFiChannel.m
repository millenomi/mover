//
//  MvrModernWiFiChannel.m
//  Network
//
//  Created by ∞ on 12/09/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import "MvrModernWiFiChannel.h"

#import <MuiKit/MuiKit.h>
#import "MvrModernWiFiOutgoing.h"
#import "MvrModernWiFiIncoming.h"

@implementation MvrModernWiFiChannel

#pragma mark Outgoing transfers

- (void) beginSendingItem:(MvrItem*) item;
{
	MvrModernWiFiOutgoing* outgoing = [[MvrModernWiFiOutgoing alloc] initWithItem:item toAddresses:self.netService.addresses];

	[self.dispatcher observe:@"finished" ofObject:outgoing usingSelector:@selector(outgoingTransfer:finishedDidChange:) options:0];
	
	[outgoing start];
	[self.mutableOutgoingTransfers addObject:outgoing];
	[outgoing release];
}

- (void) outgoingTransfer:(MvrModernWiFiOutgoing*) transfer finishedDidChange:(NSDictionary*) change;
{
	if (!transfer.finished)
		return;
	
	[self.dispatcher endObserving:@"finished" ofObject:transfer];
	[self.mutableOutgoingTransfers removeObject:transfer];
}

- (BOOL) supportsStreams;
{
	return YES;
}

#pragma mark Incoming transfers

- (void) addIncomingTransfersObject:(MvrModernWiFiIncoming*) incoming;
{
	[incoming observeUsingDispatcher:self.dispatcher invokeAtItemOrCancelledChange:@selector(incomingTransfer:itemOrCancelledChanged:)];
	[super addIncomingTransfersObject:incoming];
}
	 
- (void) incomingTransfer:(MvrModernWiFiIncoming*) transfer itemOrCancelledChanged:(NSDictionary*) changed;
{
	[transfer endObservingUsingDispatcher:self.dispatcher];
	[self.mutableIncomingTransfers removeObject:transfer];
}

@end
