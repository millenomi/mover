//
//  MvrWiFiScanner.m
//  Network
//
//  Created by ∞ on 12/09/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import "MvrWiFiScanner.h"

#import <sys/socket.h>
#import <sys/types.h>
#import <netinet/in.h>
#import <ifaddrs.h>

#if !TARGET_OS_IPHONE
#define SCNetworkReachabilityFlags SCNetworkConnectionFlags
#define kSCNetworkReachabilityFlagsReachable kSCNetworkFlagsReachable
#define kSCNetworkReachabilityFlagsConnectionRequired kSCNetworkFlagsConnectionRequired
#define kSCNetworkReachabilityFlagsIsWWAN 0 // unavailable on Mac OS X
#endif

@interface MvrWiFiScanner ()

- (void) updateNetworkWithFlags:(SCNetworkReachabilityFlags) flags;
- (BOOL) isSelfPublishedService:(NSNetService*) sender;

@end



@implementation MvrWiFiScanner

- (id) init;
{
	if (self = [super init]) {
		netServices = [NSMutableSet new];
		soughtServices = [NSMutableSet new];
		
		browsers = [L0Map new];
		servicesBeingResolved = [NSMutableSet new];
		
		channels = [NSMutableSet new];
	}
	
	return self;
}

- (void) addServiceWithName:(NSString*) name type:(NSString*) type port:(int) port TXTRecord:(NSDictionary*) record;
{
	NSAssert(!enabled, @"Can't change published services without disabling");
	
	NSNetService* service = [[[NSNetService alloc] initWithDomain:@"" type:type name:name port:port] autorelease];
	
	service.delegate = self;
	[service setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:record]];

	[netServices addObject:service];
}

- (void) addBrowserForServicesWithType:(NSString*) type;
{
	[soughtServices addObject:type];
}

@synthesize enabled;
- (void) setEnabled:(BOOL) e;
{
	BOOL wasEnabled = enabled;
	
	if (!wasEnabled && e) {
		[self start];
		[self startMonitoringReachability];
	} else if (wasEnabled && !e) {
		[self stopMonitoringReachability];
		[self stop];
	}
	
	enabled = e;
}

- (void) start;
{
	if (enabled && !jammed)
		return;
	
	for (NSNetService* n in netServices)
		[n publish];
	
	for (NSString* type in soughtServices) {
		NSNetServiceBrowser* browser = [[NSNetServiceBrowser new] autorelease];
		browser.delegate = self;
		[browser searchForServicesOfType:type inDomain:@""];
		[browsers setObject:type forKey:browser];
	}
}

- (void) stop;
{
	if (!enabled)
		return;
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	[self.mutableChannels removeAllObjects];
	
	for (NSNetService* n in netServices)
		[n stop];
	
	for (NSNetService* s in servicesBeingResolved)
		[s stop];
	
	[servicesBeingResolved removeAllObjects];
	
	for (NSNetServiceBrowser* browser in [browsers allKeys])
		[browser stop];
	[browsers removeAllObjects];
}

- (void) dealloc;
{
	[self stop];
	
	[soughtServices release];
	
	for (NSNetService* s in netServices)
		s.delegate = nil;
	
	[netServices release];
	
	for (NSNetServiceBrowser* s in [browsers allKeys])
		s.delegate = nil;

	[browsers release];
	[channels release];
	[servicesBeingResolved release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Searching

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing;
{
	[servicesBeingResolved addObject:aNetService];
	aNetService.delegate = self;
	[aNetService resolveWithTimeout:20];
}

- (BOOL) isSelfPublishedService:(NSNetService*) sender;
{
//	BOOL isSelf = NO;
//	
//	struct ifaddrs* interface;
//	if (getifaddrs(&interface) == 0) {
//		struct ifaddrs* allInterfaces = interface;
//		while (interface != NULL) {
//			const struct sockaddr_in* address = (const struct sockaddr_in*) interface->ifa_addr;
//			
//			for (NSData* senderAddressData in [sender addresses]) {
//				const struct sockaddr* senderAddress = (const struct sockaddr*) [senderAddressData bytes];
//				if (senderAddress->sa_family != AF_INET)
//					continue;
//				
//				const struct sockaddr_in* senderIPAddress = (const struct sockaddr_in*) senderAddress;
//				if (address->sin_addr.s_addr == senderIPAddress->sin_addr.s_addr) {
//					isSelf = YES;
//					break;
//				}
//			}
//			
//			if (isSelf) break;
//			interface = interface->ifa_next;
//		}
//		
//		freeifaddrs(allInterfaces);
//	}
	
	for (NSNetService* s in netServices) {
		if ([s.type isEqual:sender.type] && [s.name isEqual:sender.name])
			return YES;
	}
	
	return NO;
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender;
{
	L0Log(@"For service %@:", sender);
	for (NSData* d in [sender addresses])
		L0Log(@"Found address: %@", [d socketAddressStringValue]);
	
	BOOL isSelf = [self isSelfPublishedService:sender];
	if (!isSelf)
		[self foundService:sender];

	[servicesBeingResolved removeObject:sender];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing;
{
	[self lostService:aNetService];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didNotSearch:(NSDictionary *)errorDict;
{
	L0Log(@"An error happened while trying to search, will auto-retry: %@", errorDict);
	[self performSelector:@selector(restartBrowser:) withObject:aNetServiceBrowser afterDelay:2.0];
}

- (void) restartBrowser:(NSNetServiceBrowser*) browser;
{
	NSString* type = [browsers objectForKey:browser];
	if (type)
		[browser searchForServicesOfType:type inDomain:@""];
}

- (void) foundService:(NSNetService*) s;
{
	L0AbstractMethod();
}

- (void) lostService:(NSNetService*) s;
{
	L0AbstractMethod();
}

- (NSDictionary*) stringsForKeys:(NSSet*) keys inTXTRecordData:(NSData*) data encoding:(NSStringEncoding) enc;
{
	NSDictionary* d = [NSNetService dictionaryFromTXTRecordData:data];
	NSMutableDictionary* result = [NSMutableDictionary dictionary];
	
	for (NSString* key in keys) {
		id o = [d objectForKey:key];
		if ([o isKindOfClass:[NSString class]])
			[result setObject:o forKey:key];
		else if ([o isKindOfClass:[NSData class]]) {
			NSString* s = [[NSString alloc] initWithData:o encoding:enc];
			if (s) {
				[result setObject:s forKey:key];
				[s release];
			}
		}
	}
	
	return result;
}


#pragma mark -
#pragma mark Publishing

- (NSMutableSet*) mutableChannels;
{
	return [self mutableSetValueForKey:@"channels"];
}

- (void) addChannelsObject:(id <MvrChannel>) chan;
{
	[channels addObject:chan];
}

- (void) removeChannelsObject:(id <MvrChannel>) chan;
{
	[channels removeObject:chan];
}

- (NSSet*) channels;
{
	return channels;
}

#pragma mark -
#pragma mark Reachability.

static void L0MoverWiFiNetworkStateChanged(SCNetworkReachabilityRef reach, SCNetworkReachabilityFlags flags, void* meAsPointer) {
	MvrWiFiScanner* myself = (MvrWiFiScanner*) meAsPointer;
	[NSObject cancelPreviousPerformRequestsWithTarget:myself selector:@selector(checkReachability) object:nil];
	[myself updateNetworkWithFlags:flags];
}

- (void) startMonitoringReachability;
{
	if (reach)
		return;
	
	// What follows comes from Reachability.m.
	// Basically, we look for reachability for the link-local address --
	// and filter for WWAN or connection-required responses in -updateNetworkWithFlags:.
	
	// Build a sockaddr_in that we can pass to the address reachability query.
	struct sockaddr_in sin;
	bzero(&sin, sizeof(sin));
	sin.sin_len = sizeof(sin);
	sin.sin_family = AF_INET;
	
	// IN_LINKLOCALNETNUM is defined in <netinet/in.h> as 169.254.0.0
	sin.sin_addr.s_addr = htonl(IN_LINKLOCALNETNUM);
	
	reach = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*) &sin);
	
	SCNetworkReachabilityContext selfContext = {0, self, NULL, NULL, &CFCopyDescription};
	SCNetworkReachabilitySetCallback(reach, &L0MoverWiFiNetworkStateChanged, &selfContext);
	SCNetworkReachabilityScheduleWithRunLoop(reach, [[NSRunLoop currentRunLoop] getCFRunLoop], kCFRunLoopDefaultMode);
	
	SCNetworkReachabilityFlags flags;
	if (!SCNetworkReachabilityGetFlags(reach, &flags))
		[self performSelector:@selector(checkReachability) withObject:nil afterDelay:0.5];
	else
		[self updateNetworkWithFlags:flags];
}

- (void) stopMonitoringReachability;
{
	if (!reach)
		return;
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkReachability) object:nil];
	
	SCNetworkReachabilityUnscheduleFromRunLoop(reach, [[NSRunLoop currentRunLoop] getCFRunLoop], kCFRunLoopDefaultMode);
	CFRelease(reach); reach = NULL;
}

- (void) checkReachability;
{
	if (!reach)
		return;
	
	SCNetworkReachabilityFlags flags;
	if (SCNetworkReachabilityGetFlags(reach, &flags))
		[self updateNetworkWithFlags:flags];
}

- (void) updateNetworkWithFlags:(SCNetworkReachabilityFlags) flags;
{
	BOOL habemusNetwork = 
		(flags & kSCNetworkReachabilityFlagsReachable) &&
		!(flags & kSCNetworkReachabilityFlagsConnectionRequired) &&
		!(flags & kSCNetworkReachabilityFlagsIsWWAN);
	// note that unlike Reachability.m we don't want WWANs.
	
	self.jammed = !habemusNetwork;	
}

@synthesize jammed;
- (void) setJammed:(BOOL) j;
{
	BOOL wasJammed = jammed;
	
	if (self.enabled) {
		if (j && !wasJammed)
			[self stop];
		else if (!j && wasJammed)
			[self start];
	}
	
	jammed = j;
}

@end
