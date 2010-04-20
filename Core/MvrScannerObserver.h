//
//  MvrScannerObserver.h
//  Network+Storage
//
//  Created by ∞ on 16/09/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import <Foundation/Foundation.h>

@class L0KVODispatcher;

#import "MvrScanner.h"
#import "MvrChannel.h"
#import "MvrIncoming.h"
#import "MvrOutgoing.h"

@protocol MvrScannerObserverDelegate;

@interface MvrScannerObserver : NSObject {
	L0KVODispatcher* kvo;
	id <MvrScanner> scanner;
	id <MvrScannerObserverDelegate> delegate;
	
	NSMutableSet* observedObjects;
}

- (id) initWithScanner:(id <MvrScanner>) scanner delegate:(id <MvrScannerObserverDelegate>) delegate;

@end

@protocol MvrScannerObserverDelegate <NSObject>
@optional

- (void) scanner:(id <MvrScanner>) s didChangeJammedKey:(BOOL) jammed;
- (void) scanner:(id <MvrScanner>) s didChangeEnabledKey:(BOOL) enabled;

- (void) scanner:(id <MvrScanner>) s didAddChannel:(id <MvrChannel>) channel;
- (void) scanner:(id <MvrScanner>) s didRemoveChannel:(id <MvrChannel>) channel;			

- (void) channel:(id <MvrChannel>) c didBeginReceivingWithIncomingTransfer:(id <MvrIncoming>) incoming;
- (void) channel:(id <MvrChannel>) c didBeginSendingWithOutgoingTransfer:(id <MvrOutgoing>) outgoing;
- (void) channel:(id <MvrChannel>) c didChangeSupportsStreamsKey:(BOOL) supportsStreams;

- (void) outgoingTransfer:(id <MvrOutgoing>) outgoing didProgress:(float) progress;
- (void) outgoingTransferDidEndSending:(id <MvrOutgoing>) outgoing;

// i == nil if cancelled.
- (void) incomingTransfer:(id <MvrIncoming>) incoming didEndReceivingItem:(MvrItem*) i;
- (void) incomingTransfer:(id <MvrIncoming>) incoming didProgress:(float) progress;

@end