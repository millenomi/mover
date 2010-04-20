//
//  MvrPacketParser.m
//  Mover
//
//  Created by ∞ on 23/08/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import "MvrPacketParser.h"

@interface MvrPacketParser ()

@property(assign) float progress;

- (void) consumeCurrentBuffer;
@property(assign, setter=private_setState:) MvrPacketParserState state;
@property(copy) NSString* lastSeenMetadataItemTitle;

@property(copy) NSArray* payloadStops;
- (BOOL) setPayloadStopsFromString:(NSString*) string;

@property(copy) NSArray* payloadKeys;
- (BOOL) setPayloadKeysFromString:(NSString*) string;

// code == 0 means that we reset reporting no error (nil).
- (void) resetAndReportError:(NSInteger) code;
- (void) reset;

- (NSInteger) locationOfFirstNullInCurrentBuffer;


// These methods return YES if we can continue consuming, or NO if we need
// to be woken up when more data is available.
- (BOOL) consumeStartOfPacket;
- (BOOL) consumeMetadataItemTitle;
- (BOOL) consumeMetadataItemValue;
- (BOOL) consumeBody;

// These methods do state changes.
- (void) expectMetadataItemTitle;
- (void) expectMetadataItemValueWithTitle:(NSString*) s;
- (void) expectBody; // This starts body consumption.

- (void) processAndReportMetadataItemWithTitle:(NSString*) title value:(NSString*) s;

@end

NSString* const kMvrPacketParserErrorDomain = @"kMvrPacketParserErrorDomain";

@implementation MvrPacketParser

- (id) initWithDelegate:(id <MvrPacketParserDelegate>) d;
{
	if (self = [super init]) {
		delegate = d;
		currentBuffer = [NSMutableData new];
		[self reset];
	}
	
	return self;
}

@synthesize progress;

- (void) dealloc;
{
	[self reset];
	[super dealloc];
}

@synthesize state, lastSeenMetadataItemTitle, payloadStops, payloadKeys;

- (void) appendData:(NSData*) data;
{
	[self appendData:data isKnownStartOfNewPacket:NO];
}

- (void) appendData:(NSData*) data isKnownStartOfNewPacket:(BOOL) reset;
{
	// L0Log(@"Will now restart the parsing machinery with %llu new bytes. (reset? = %d)", (unsigned long long) [data length], (int) reset);
	
	[[self retain] autorelease];
	
	if (reset && !self.expectingNewPacket)
		[self resetAndReportError:0];
	
	[currentBuffer appendData:data];
	
	// An optimization: if we're in the expecting body state and we need to read a body, we only consume every 500 KiB or so.
	if (self.state == kMvrPacketParserExpectingBody) {
		if ([currentBuffer length] < MIN(500 * 1024, toReadForCurrentStop))
			return;
	}
	
	[self consumeCurrentBuffer];
}

- (unsigned long long) expectedSize;
{
	if (self.state != kMvrPacketParserExpectingBody)
		return 0;
	
	return MIN(toReadForCurrentStop - [currentBuffer length], 500 * 1024 - [currentBuffer length]);
}

- (void) consumeCurrentBuffer;
{
	beingReset = NO;
	BOOL shouldContinueParsingForData = YES;
	while ([currentBuffer length] > 0 && shouldContinueParsingForData && !beingReset) {
		// L0Log(@"Let's execute a cycle of parsing! State = %d", (int) self.state);
		// L0Log(@"Bytes to read before cycle = %lu", (unsigned long long) [currentBuffer length]);
		
		switch (self.state) {
			case kMvrPacketParserExpectingStart:
				shouldContinueParsingForData = [self consumeStartOfPacket];
				break;
				
			case kMvrPacketParserExpectingMetadataItemTitle:
				shouldContinueParsingForData = [self consumeMetadataItemTitle];				
				break;
				
			case kMvrPacketParserExpectingMetadataItemValue:
				shouldContinueParsingForData = [self consumeMetadataItemValue];
				break;
				
			case kMvrPacketParserExpectingBody:
				shouldContinueParsingForData = [self consumeBody];				
				break;
				
			default:
				NSAssert(NO, @"Unknown state reached");
				return;
		}
		
		// L0Log(@"Bytes to read after cycle = %llu", (unsigned long long) [currentBuffer length]);
		// L0Log(@"State after cycle: continue parsing for data? = %d, reset? = %d", shouldContinueParsingForData, beingReset);
	}
}

- (void) reset;
{
	L0Log(@"Performing a reset.");
	
	self.lastSeenMetadataItemTitle = nil;
	self.payloadStops = nil;
	self.payloadKeys = nil;
	currentStop = 0;
	toReadForCurrentStop = 0;
	payloadLength = 0;
	read = 0;
	self.progress = kMvrIndeterminateProgress;
	
	self.state = kMvrPacketParserExpectingStart;
}	

- (void) resetAndReportError:(NSInteger) errorCode;
{
	[self reset];
	L0Log(@"Reporting error code %d", errorCode);
	
	NSError* e = nil;
	if (errorCode != 0) 
		e = [NSError errorWithDomain:kMvrPacketParserErrorDomain code:errorCode userInfo:nil];
	[delegate packetParser:self didReturnToStartingStateWithError:e];

	BOOL shouldResetAfterGoodPacket = NO;
	
	if (!e) {
		shouldResetAfterGoodPacket = [delegate respondsToSelector:@selector(packetParserShouldResetAfterCompletingPacket:)]? [delegate packetParserShouldResetAfterCompletingPacket:self] : YES;
	}
	
	if (e || shouldResetAfterGoodPacket) {
		[currentBuffer release];
		currentBuffer = [NSMutableData new];
		
		beingReset = YES;
	}
	
	if (e) {
		if ([delegate respondsToSelector:@selector(packetParserDidResetAfterError:)])
			[delegate packetParserDidResetAfterError:self];
	}
}

- (BOOL) consumeStartOfPacket;
{
	L0Log(@"Consuming the start of a packet...");
	
	if ([currentBuffer length] >= kMvrPacketParserStartingBytesLength) {
		const uint8_t* bytes = (const uint8_t*) [currentBuffer bytes];
		if (memcmp(kMvrPacketParserStartingBytes, bytes,
				   kMvrPacketParserStartingBytesLength) == 0) {

			L0Log(@"Start found. Now expecting metadata item title.");
			[delegate packetParserDidStartReceiving:self];
			[self expectMetadataItemTitle];
			
		} else
			[self resetAndReportError:kMvrPacketParserDidNotFindStartError];
		
		if (!beingReset)
			[currentBuffer replaceBytesInRange:NSMakeRange(0, kMvrPacketParserStartingBytesLength) withBytes:NULL length:0];
		return YES;
	}
	
	return NO;
}

- (void) expectMetadataItemTitle;
{
	self.state = kMvrPacketParserExpectingMetadataItemTitle;
	self.lastSeenMetadataItemTitle = nil;
}

- (BOOL) consumeMetadataItemTitle;
{
	L0Log(@"Looking for metadata item title...");

	NSInteger loc = [self locationOfFirstNullInCurrentBuffer];
	if (loc == NSNotFound)
		return NO;
	
	if (loc != 0) {
		NSString* s = [[NSString alloc] initWithBytes:[currentBuffer bytes] length:loc encoding:NSUTF8StringEncoding];
		
		L0Log(@"Found title: %@ (nil means it's not UTF-8 and we bail out)", s);

		if (!s)
			[self resetAndReportError:kMvrPacketParserNotUTF8StringError];
		else
			[self expectMetadataItemValueWithTitle:s];
		
		[s release];
		
	} else {
		L0Log(@"Found empty title (end of header). Now expecting body.");
		[self expectBody];
	}
	
	if (!beingReset)
		[currentBuffer replaceBytesInRange:NSMakeRange(0, loc + 1) withBytes:NULL length:0];
	return YES;
}

- (void) expectMetadataItemValueWithTitle:(NSString*) s;
{
	self.lastSeenMetadataItemTitle = s;
	self.state = kMvrPacketParserExpectingMetadataItemValue;	
}

- (BOOL) consumeMetadataItemValue;
{
	L0Log(@"Looking for metadata item value...");

	NSInteger loc = [self locationOfFirstNullInCurrentBuffer];
	if (loc == NSNotFound)
		return NO;
	
	NSString* s = [[NSString alloc] initWithBytes:[currentBuffer bytes] length:loc encoding:NSUTF8StringEncoding];
	L0Log(@"Found value: %@ (nil means it's not UTF-8 and we bail out)", s);

	if (!s)
		[self resetAndReportError:kMvrPacketParserNotUTF8StringError];
	else {
		L0Log("Found metadata item with key: %@ value: %@", self.lastSeenMetadataItemTitle, s);
		[self processAndReportMetadataItemWithTitle:self.lastSeenMetadataItemTitle value:s];
		[self expectMetadataItemTitle];
	}
	[s release];
	
	if (!beingReset)
		[currentBuffer replaceBytesInRange:NSMakeRange(0, loc + 1) withBytes:NULL length:0];
	return YES;
}

- (void) processAndReportMetadataItemWithTitle:(NSString*) title value:(NSString*) s;
{	
	if ([title isEqual:kMvrProtocolPayloadStopsKey]) {
		if (![self setPayloadStopsFromString:s])
			return;
	}
	
	if ([title isEqual:kMvrProtocolPayloadKeysKey]) {
		if (![self setPayloadKeysFromString:s])
			return;
	}
	
	[delegate packetParser:self didReceiveMetadataItemWithKey:title value:s];
}

- (BOOL) setPayloadStopsFromString:(NSString*) string;
{
	L0Log(@"Setting payload stops from '%@'", string);
	
	NSScanner* s = [NSScanner scannerWithString:string];
	[s setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@" "]];
	
	NSMutableArray* stops = [NSMutableArray array];
	
	long long max = -1;
	while (![s isAtEnd]) {
		long long stop;
		if (![s scanLongLong:&stop] || stop < 0 || stop < max) {
			[self resetAndReportError:kMvrPacketParserHasInvalidStopsStringError];
			return NO;
		} else {
			[stops addObject:[NSNumber numberWithLongLong:stop]];
			max = stop;
		}
	}
	
	if ([stops count] == 0) {
		[self resetAndReportError:kMvrPacketParserHasInvalidStopsStringError];
		return NO;
	}
	
	if (self.payloadKeys && [self.payloadKeys count] != [stops count]) {
		[self resetAndReportError:kMvrPacketParserKeysAndStopsDoNotMatchError];
		return NO;
	}

	payloadLength = max;
	self.payloadStops = stops;
	L0Log(@"Found length = %llu, stops = %@", payloadLength, stops);
	
	return YES;
}

- (BOOL) setPayloadKeysFromString:(NSString*) string;
{
	L0Log(@"Setting payload keys from '%@'", string);
	NSMutableArray* keys = [NSMutableArray arrayWithArray:
							 [string componentsSeparatedByString:@" "]];
	
	NSUInteger index;
	while ((index = [keys indexOfObject:@""]) != NSNotFound)
		[keys removeObjectAtIndex:index];
	
	if ([keys count] == 0) {
		[self resetAndReportError:kMvrPacketParserHasInvalidKeysStringError];
		return NO;
	}
	
	if (self.payloadStops && [self.payloadStops count] != [keys count]) {
		[self resetAndReportError:kMvrPacketParserKeysAndStopsDoNotMatchError];
		return NO;
	}
	
	if ([[NSSet setWithArray:keys] count] != [keys count]) {
		[self resetAndReportError:kMvrPacketParserHasDuplicateKeysError];
		return NO;
	}
	
	self.payloadKeys = keys;
	L0Log(@"Found keys = %@", keys);
	return YES;
}

- (void) expectBody;
{
	if (!self.payloadStops) {
		[self resetAndReportError:kMvrPacketParserMetadataDidNotIncludeStopsError];
		return;
	}
	
	if (!self.payloadKeys) {
		[self resetAndReportError:kMvrPacketParserMetadataDidNotIncludeKeysError];
		return;
	}
	
	if ([self.payloadStops count] == 1 && [[self.payloadStops objectAtIndex:0] isEqual:[NSNumber numberWithInt:0]]) {
		// we'd grab the body here, but since the body is empty, we go on.
		self.progress = 1.0;
		NSString* key = [self.payloadKeys objectAtIndex:0];
		[delegate packetParser:self willReceivePayloadForKey:key size:[[self.payloadStops objectAtIndex:0] unsignedLongLongValue]];
		[delegate packetParser:self didReceivePayloadPart:[NSData data] forKey:key];
		[self resetAndReportError:kMvrPacketParserNoError];
	} else {
		currentStop = 0;
		toReadForCurrentStop = [[self.payloadStops objectAtIndex:currentStop] longLongValue];
		self.state = kMvrPacketParserExpectingBody;
		[delegate packetParser:self willReceivePayloadForKey:[self.payloadKeys objectAtIndex:0] size:toReadForCurrentStop];
	}
}

- (BOOL) consumeBody;
{		
	L0Log(@"Looking for a body portion...");
	
	NSUInteger lengthOfNewDataForCurrentStop =
		MIN([currentBuffer length], toReadForCurrentStop);
	
	L0Log(@"Consuming %llu bytes (out of %llu remaining) for payload with key %@.", (unsigned long long) lengthOfNewDataForCurrentStop, (unsigned long long) toReadForCurrentStop, [self.payloadKeys objectAtIndex:currentStop]);
	
	read += lengthOfNewDataForCurrentStop;
	self.progress = (float) read / (float) payloadLength;
	
	NSRange rangeOfPayloadPart = NSMakeRange(0, lengthOfNewDataForCurrentStop);
	NSData* payloadPart = [currentBuffer subdataWithRange:rangeOfPayloadPart];
	[delegate packetParser:self didReceivePayloadPart:payloadPart forKey:[self.payloadKeys objectAtIndex:currentStop]];
	
	[currentBuffer replaceBytesInRange:rangeOfPayloadPart withBytes:NULL length:0];
	toReadForCurrentStop -= lengthOfNewDataForCurrentStop;
	
	if (toReadForCurrentStop == 0) {
		L0Log(@"Advancing to next payload...");
		currentStop++;
		if (currentStop >= [self.payloadStops count]) {
			L0Log(@"Uh, I'm out of payloads. Done!");
			[self resetAndReportError:kMvrPacketParserNoError];
		} else {
			toReadForCurrentStop = [[self.payloadStops objectAtIndex:currentStop] unsignedLongLongValue] - [[self.payloadStops objectAtIndex:currentStop - 1] unsignedLongLongValue];
			[delegate packetParser:self willReceivePayloadForKey:[self.payloadKeys objectAtIndex:currentStop] size:toReadForCurrentStop];
			L0Log(@"Now expecting payload with key %@, long %llu", [self.payloadKeys objectAtIndex:currentStop], toReadForCurrentStop);
		}
	}
	
	return YES;
}

- (NSInteger) locationOfFirstNullInCurrentBuffer;
{
	const size_t length = [currentBuffer length];
	const char* bytes = (const char*) [currentBuffer bytes];
	size_t i; for (i = 0; i < length; i++) {
		if (bytes[i] == 0)
			return i;
	}
	
	return NSNotFound;
}

- (BOOL) expectingNewPacket;
{
	return self.state == kMvrPacketParserStartingState && [currentBuffer length] == 0;
}

@end
