//
//  MvrWiFi.h
//  Network
//
//  Created by ∞ on 12/09/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MvrScanner.h"

#import "MvrPlatformInfo.h"
#import "MvrScannerObserver.h"

@class MvrModernWiFi, MvrLegacyWiFi, L0KVODispatcher;

@interface MvrWiFi : NSObject <MvrScanner, MvrScannerObserverDelegate> {
	MvrModernWiFi* modernWiFi;
	id legacyWiFi;

	NSMutableDictionary* channelsByIdentifier;
	MvrScannerObserver* modernObserver, * legacyObserver;
	
	BOOL jammed, enabled;
}

- (id) initWithPlatformInfo:(id <MvrPlatformInfo>) info modernPort:(int) port legacyPort:(int) legacyPort;

@property(retain) MvrModernWiFi* modernWiFi;

@property(retain) id legacyWiFi; // In Mover Core 1.3 and later, this property is always nil.

@end
