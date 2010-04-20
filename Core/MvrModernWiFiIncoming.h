//
//  MvrWiFiIncomingTransfer.h
//  Mover
//
//  Created by ∞ on 25/08/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MvrGenericIncoming.h"

#import "MvrChannel.h"
#import "MvrPacketParser.h"
#import "MvrIncoming.h"

@class AsyncSocket, MvrItemStorage;
@class MvrModernWiFi, MvrModernWiFiChannel;
@class MvrItem;

@class L0KVODispatcher;

#import "MvrStreamedIncoming.h"

@interface MvrModernWiFiIncoming : MvrStreamedIncoming {
	AsyncSocket* socket;
	MvrModernWiFiChannel* channel;
	MvrModernWiFi* scanner;	
}

- (id) initWithSocket:(AsyncSocket*) s scanner:(MvrModernWiFi*) scanner;

@end
