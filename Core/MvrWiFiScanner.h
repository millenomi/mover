//
//  MvrWiFiScanner.h
//  Network
//
//  Created by ∞ on 12/09/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MuiKit/MuiKit.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import "MvrScanner.h"
#import "MvrChannel.h"

@interface MvrWiFiScanner : NSObject <MvrScanner
#if !TARGET_OS_IPHONE && MAC_OS_X_VERSION_10_6 <= MAC_OS_X_VERSION_MAX_ALLOWED
	, NSNetServiceDelegate, NSNetServiceBrowserDelegate
#endif
> {
	// NSNetService and NSNetServiceBrowser instances.
	NSMutableSet* netServices;
	NSMutableSet* soughtServices;
	
	BOOL enabled;
	L0Map* browsers;
	NSMutableSet* servicesBeingResolved;
	
	SCNetworkReachabilityRef reach;
	BOOL jammed;

	NSMutableSet* channels;
}

@property(assign) BOOL enabled;

// Called when .enabled changes.
- (void) start;
- (void) stop;

// Subclasses use these to set up stuff. Must be done while the scanner is disabled.
- (void) addServiceWithName:(NSString*) name type:(NSString*) type port:(int) port TXTRecord:(NSDictionary*) record;
- (void) addBrowserForServicesWithType:(NSString*) type;

// Called when services are found.
- (void) foundService:(NSNetService*) s;
- (void) lostService:(NSNetService*) s;

// Parsing TXT dictionaries.
- (NSDictionary*) stringsForKeys:(NSSet*) keys inTXTRecordData:(NSData*) data encoding:(NSStringEncoding) enc;

// Reachability. Gets automatically enabled or stopped when .enabled changes. -check forces a check.
- (void) startMonitoringReachability;
- (void) stopMonitoringReachability;
- (void) checkReachability;

// Jamming.
@property BOOL jammed;

// Channels.
@property(readonly) NSMutableSet* mutableChannels;

- (void) addChannelsObject:(id <MvrChannel>) chan;
- (void) removeChannelsObject:(id <MvrChannel>) chan;

@end
