//
//  MvrModernWiFi.h
//  Network
//
//  Created by ∞ on 12/09/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MvrWiFiScanner.h"
#import "MvrPlatformInfo.h"

#define kMvrModernWiFiDifficultyStartingListenerNotification @"MvrModernWiFiDifficultyStartingListenerNotification"

#define kMvrModernWiFiBonjourServiceType @"_x-mover3._tcp."
#define kMvrModernWiFiPort (25252)

#define kMvrModernWiFiPeerIdentifierKey @"MvrID"

@class L0KVODispatcher;

@class AsyncSocket, MvrModernWiFiChannel;

@interface MvrModernWiFi : MvrWiFiScanner {
	AsyncSocket* serverSocket;
	int serverPort;
	
	NSMutableSet* incomingTransfers;
	L0KVODispatcher* dispatcher;
}

- (id) initWithPlatformInfo:(id <MvrPlatformInfo>) info serverPort:(int) port;
- (MvrModernWiFiChannel*) channelForAddress:(NSData*) address;

@end
