//
//  MvrPacketBuilder.m
//  Mover
//
//  Created by ∞ on 23/08/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import "MvrPacketBuilder.h"

static inline float MvrProgressFromTo(unsigned long long from, unsigned long long to) {
	return ((float)to - (float)from) / (float)to;
}

@interface MvrPacketBuilder ()

- (void) stopWithoutNotifying;
- (void) startProducingPayload;

@property(assign) float progress;

@end

NSString* const kMvrPacketBuilderErrorDomain = @"kMvrPacketBuilderErrorDomain";

@implementation MvrPacketBuilder

@synthesize running = sealed, runLoop;

- (id) initWithDelegate:(id <MvrPacketBuilderDelegate>) d;
{
	if (self = [super init]) {
		delegate = d;
		metadata = [NSMutableDictionary new];
		payloadOrder = [NSMutableArray new];
		payloadObjects = [NSMutableDictionary new];
		payloadLengths = [NSMutableDictionary new];
		self.runLoop = [NSRunLoop currentRunLoop];
	}
	
	return self;
}

- (void) dealloc;
{
	[self stop];
	[payloadOrder release];
	[payloadObjects release];
	[payloadLengths release];
	[metadata release];

	self.runLoop = nil;
	[super dealloc];
}

- (void) setMetadataValue:(NSString*) v forKey:(NSString*) k;
{
	NSAssert(!sealed, @"You can't modify the metadata while a packet is being built.");
	
	NSCharacterSet* nullCharset = [NSCharacterSet characterSetWithRange:NSMakeRange(0, 1)];
	NSAssert([v rangeOfCharacterFromSet:nullCharset].location == NSNotFound, @"No NULL characters in the value!");
	NSAssert([k rangeOfCharacterFromSet:nullCharset].location == NSNotFound, @"No NULL characters in the key!");
	
	[metadata setObject:v forKey:k];
}

- (void) removeMetadataValueForKey:(NSString*) key;
{
	NSAssert(!sealed, @"You can't modify the metadata while a packet is being built.");
	
	[metadata removeObjectForKey:key];
}

- (void) addPayload:(id) b length:(unsigned long long) length forKey:(NSString*) key;
{
	NSAssert(!sealed, @"You can't modify the payloads while a packet is being built.");
	
	[payloadOrder removeObject:key];
	[payloadOrder addObject:key];
	
	if ([b isKindOfClass:[NSData class]]) {
		[payloadObjects setObject:[[b copy] autorelease] forKey:key];
		[payloadLengths setObject:[NSNumber numberWithUnsignedInteger:[b length]] forKey:key];
	} else if ([b isKindOfClass:[NSInputStream class]]) {
		[payloadObjects setObject:b forKey:key];
		[payloadLengths setObject:[NSNumber numberWithUnsignedLongLong:length] forKey:key];
	} else
		NSAssert(NO, @"Unknown kind of payload object.");
}

- (void) addPayloadWithData:(NSData*) d forKey:(NSString*) key;
{
	[self addPayload:d length:kMvrPacketBuilderDefaultLength forKey:key];
}

- (BOOL) addPayloadByReferencingFile:(NSString*) s forKey:(NSString*) key error:(NSError**) e;
{
	NSAssert(!sealed, @"You can't modify the payloads while a packet is being built.");

	NSDictionary* d = [[NSFileManager defaultManager] attributesOfItemAtPath:s error:e];
	if (!d) return NO;
	
	NSInputStream* is = [NSInputStream inputStreamWithFileAtPath:s];
	[self addPayload:is length:[[d objectForKey:NSFileSize] unsignedLongLongValue] forKey:key];
	return YES;
}

- (void) removePayloadForKey:(NSString*) key;
{
	NSAssert(!sealed, @"You can't modify the payloads while a packet is being built.");
	
	[payloadOrder removeObject:key];
	[payloadObjects removeObjectForKey:key];
	[payloadLengths removeObjectForKey:key];
}

- (void) removeAllPayloads;
{
	NSAssert(!sealed, @"You can't modify the payloads while a packet is being built.");
	
	[payloadOrder removeAllObjects];
	[payloadObjects removeAllObjects];
	[payloadLengths removeAllObjects];
}

- (void) performDelayedStart:(NSTimer*) t;
{
	[self start];
}

- (void) start;
{
	L0Note();
	
	if (sealed) return;
	NSAssert(self.runLoop == [NSRunLoop currentRunLoop], @"Do not call -start on a thread other than the one where you scheduled the builder. Either call -start on the thread where you created the object, or use the .runLoop property to change what run loop to use to schedule stuff.");
	
	
	cancelled = NO;
	isWorkingOnStreamPayload = NO;
	paused = NO;
	
	NSMutableArray* stringVersionsOfPayloadStops = [NSMutableArray array];
	unsigned long long current = 0;
	for (NSString* key in payloadOrder) {
		NSNumber* n = [payloadLengths objectForKey:key];
		current += [n unsignedLongLongValue];
		[stringVersionsOfPayloadStops addObject:[NSString stringWithFormat:@"%llu", current]];
	}
	
	payloadsLength = current;
	sent = 0;
	
	[self setMetadataValue:[stringVersionsOfPayloadStops componentsJoinedByString:@" "] forKey:kMvrProtocolPayloadStopsKey];
	[self setMetadataValue:[payloadOrder componentsJoinedByString:@" "] forKey:kMvrProtocolPayloadKeysKey];
	
	sealed = YES;
	self.progress = 0.0;

	NSMutableData* headerData = [NSMutableData data];
	
	if ([delegate respondsToSelector:@selector(packetBuilderWillStart:)])
		[delegate packetBuilderWillStart:self];
	if (cancelled) return;
	
	// The header.
	NSData* d = [NSData dataWithBytesNoCopy:(void*) kMvrPacketParserStartingBytes length:kMvrPacketParserStartingBytesLength freeWhenDone:NO];
	self.progress = 0.05 / 2;
	[headerData appendData:d];
	
	// The metadata.
	const uint8_t nullCharacter = 0;
	// This 'canonicalizes' the packets so that two packets with same metadata and same payloads are byte-for-byte equal, by sorting the metadata by key via compare:.
	NSMutableArray* orderedMetadata = [NSMutableArray arrayWithArray:[metadata allKeys]];
	[orderedMetadata sortUsingSelector:@selector(compare:)];
	for (NSString* k in orderedMetadata) {
		[headerData appendData:[k dataUsingEncoding:NSUTF8StringEncoding]];
		[headerData appendBytes:&nullCharacter length:1];
		[headerData appendData:[[metadata objectForKey:k] dataUsingEncoding:NSUTF8StringEncoding]];
		[headerData appendBytes:&nullCharacter length:1];
	}
	
	[headerData appendBytes:&nullCharacter length:1];
	
	self.progress = 0.05;
	[delegate packetBuilder:self didProduceData:headerData];
	if (cancelled) return;
	 
	currentPayloadIndex = 0;
	[self startProducingPayload];
}

- (void) startProducingPayload;
{
	while (!cancelled && currentPayloadIndex < [payloadOrder count]) {
		
		NSString* key = [payloadOrder objectAtIndex:currentPayloadIndex];
		id payload = [payloadObjects objectForKey:key];
		
		if ([payload isKindOfClass:[NSData class]]) {
			
			isWorkingOnStreamPayload = NO;
			sent += [payload length];
			self.progress = 0.95 * MvrProgressFromTo(sent, payloadsLength);
			[delegate packetBuilder:self didProduceData:payload];
			
		} else if ([payload isKindOfClass:[NSInputStream class]]) {
			
			isWorkingOnStreamPayload = YES;
			toBeRead = [[payloadLengths objectForKey:key] unsignedLongLongValue];
			[payload scheduleInRunLoop:self.runLoop forMode:NSRunLoopCommonModes];
			[payload setDelegate:self];
			[payload open];
			return;
			
		}
		
		currentPayloadIndex++;
	}
	
	if (!cancelled) {
		currentPayloadIndex--;
		[self stopWithoutNotifying];
		[delegate packetBuilder:self didEndWithError:nil];
	}
}

#define kMvrPacketBuilderBufferSize 500 * 1024

- (void) producePayloadFromAvailableBytesOfStream:(NSInputStream*) aStream;
{
	uint8_t* buffer; NSUInteger bufferSize;
	
	if (![aStream getBuffer:&buffer length:&bufferSize]) {
		buffer = malloc(kMvrPacketBuilderBufferSize);
		bufferSize = [aStream read:buffer maxLength:kMvrPacketBuilderBufferSize];
	}
	
	bufferSize = MIN(bufferSize, toBeRead);
	toBeRead -= bufferSize;

	sent += bufferSize;
	self.progress = 0.95 * MvrProgressFromTo(sent, payloadsLength);
	
	[delegate packetBuilder:self didProduceData:[NSData dataWithBytesNoCopy:buffer length:bufferSize freeWhenDone:YES]];
	if (cancelled) return;
	
	if (toBeRead == 0) {
		[aStream setDelegate:nil];
		[aStream close];
		currentPayloadIndex++;
		[self startProducingPayload];
	}
}

- (void) stream:(NSInputStream*) aStream handleEvent:(NSStreamEvent) eventCode;
{
	switch (eventCode) {
		case NSStreamEventHasBytesAvailable: {
			if (!self.paused)
				[self producePayloadFromAvailableBytesOfStream:aStream];
		}
			break;
			
		case NSStreamEventErrorOccurred: {
			[delegate packetBuilder:self didEndWithError:[aStream streamError]];
			[self stopWithoutNotifying];
		}
			break;
			
		case NSStreamEventEndEncountered: {
			if (sealed) {
				NSError* e = nil;
				if (toBeRead > 0)
					e = [NSError errorWithDomain:kMvrPacketBuilderErrorDomain code:kMvrPacketBuilderNotEnoughDataInStreamError userInfo:nil];
				[delegate packetBuilder:self didEndWithError:e];
				[self stopWithoutNotifying];
			}
		}
			break;
			
		default:
			break;
	}
}

- (void) stop;
{
	if (!sealed) return;
	[self stopWithoutNotifying];
	[delegate packetBuilder:self didEndWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
}

- (void) stopWithoutNotifying;
{
	if (!sealed) return;
	cancelled = YES;
	paused = NO;
	
	if (isWorkingOnStreamPayload) {
		id body = [payloadObjects objectForKey:[payloadOrder objectAtIndex:currentPayloadIndex]];
		if ([body isKindOfClass:[NSInputStream class]]) {
			[body setDelegate:nil];
			[body close];
		}
	}
	
	sealed = NO;
}

@synthesize paused;
- (void) setPaused:(BOOL) p;
{
	BOOL wasPaused = paused;
	paused = p;
	if (wasPaused && !paused && sealed && isWorkingOnStreamPayload) {
		NSInputStream* is = [payloadObjects objectForKey:[payloadOrder objectAtIndex:currentPayloadIndex]];
		if ([is hasBytesAvailable])
			[self producePayloadFromAvailableBytesOfStream:is];
	}
}

@synthesize progress;

@end
