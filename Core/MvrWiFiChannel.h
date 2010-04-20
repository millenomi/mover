//
//  MvrWiFiChannel.h
//  Network+Storage
//
//  Created by ∞ on 15/09/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MvrChannel.h"

@class L0KVODispatcher;

@interface MvrWiFiChannel : NSObject <MvrChannel> {
@private
	NSNetService* netService;
	NSMutableSet* outgoingTransfers;
	NSMutableSet* incomingTransfers;
	
	L0KVODispatcher* dispatcher;
	
	NSString* identifier;
}

- (id) initWithNetService:(NSNetService*) ns identifier:(NSString*) ident;

- (BOOL) hasSameServiceAs:(NSNetService*) n;
- (BOOL) isReachableThroughAddress:(NSData*) address;

@property(readonly) NSString* identifier;

// Subclasses only past this point.

@property(readonly) L0KVODispatcher* dispatcher;
@property(readonly) NSNetService* netService;

// Subclasses should use these to edit the outgoing/incoming sets...
@property(readonly) NSMutableSet* mutableOutgoingTransfers;
@property(readonly) NSMutableSet* mutableIncomingTransfers;

// ... and override these to get notifications for outgoings/incomings being added/removed.
// Make sure to call super on these!

- (void) addOutgoingTransfersObject:(id) transfer;
- (void) removeOutgoingTransfersObject:(id) transfer;

- (void) addIncomingTransfersObject:(id) transfer;
- (void) removeIncomingTransfersObject:(id) transfer;

- (void) beginSendingItem:(MvrItem *)item; // abstract

@end
