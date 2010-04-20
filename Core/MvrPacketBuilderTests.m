//
//  MvrPacketBuilderTest.m
//  Mover
//
//  Created by ∞ on 24/08/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import <OCMock/OCMock.h>

#import "MvrPacketBuilder.h"
#import "MvrPacketParser.h"
#import "MvrPacketTestsCommon.h"

@interface MvrPacketBuilderTests_ParserDelegate : NSObject <MvrPacketParserDelegate>
{
	NSMutableDictionary* metadata;
	NSMutableDictionary* payloads;
	NSError* lastError;
}

@property(readonly) NSMutableDictionary* metadata, * payloads;
@property(retain) NSError* lastError;

@end

@implementation MvrPacketBuilderTests_ParserDelegate

@synthesize metadata, payloads, lastError;

- (void) packetParserDidStartReceiving:(MvrPacketParser*) p;
{
	if (!metadata)
		metadata = [NSMutableDictionary new];
	
	if (!payloads)
		payloads = [NSMutableDictionary new];
	
	[metadata removeAllObjects];
	[payloads removeAllObjects];
	self.lastError = nil;
}

- (void) packetParser:(MvrPacketParser*) p didReceiveMetadataItemWithKey:(NSString*) key value:(NSString*) value;
{
	[metadata setObject:value forKey:key];
}

- (void) packetParser:(MvrPacketParser*) p didReceivePayloadPart:(NSData*) d forKey:(NSString*) key;
{
	NSMutableData* buffer = [payloads objectForKey:key];
	if (!buffer) {
		buffer = [NSMutableData data];
		[payloads setObject:buffer forKey:key];
	}
	
	[buffer appendData:d];
}

// e == nil if no error.
- (void) packetParser:(MvrPacketParser*) p didReturnToStartingStateWithError:(NSError*) e;
{
	self.lastError = e;
}

- (void) packetParser:(MvrPacketParser*) p willReceivePayloadForKey:(NSString*) key size:(unsigned long long) size;
{
	
}

- (void) dealloc;
{
	self.lastError = nil;
	[metadata release];
	[payloads release];
	[super dealloc];
}

@end

@interface MvrPacketBuilderTest_ParsingDelegate : NSObject <MvrPacketBuilderDelegate>
{
	MvrPacketParser* parser;
	NSError* lastError;
	BOOL isNewPacket;
	BOOL didFinish;
}

@property(retain) MvrPacketParser* parser;
@property(retain) NSError* lastError;

- (BOOL) runBuilderToEnd:(MvrPacketBuilder*) b;

@end

@implementation MvrPacketBuilderTest_ParsingDelegate

@synthesize parser;

- (void) packetBuilderWillStart:(MvrPacketBuilder*) builder;
{
	isNewPacket = YES;
	didFinish = NO;
}

- (void) packetBuilder:(MvrPacketBuilder*) builder didProduceData:(NSData*) d;
{
	[parser appendData:d isKnownStartOfNewPacket:isNewPacket];
	isNewPacket = NO;
}

- (void) packetBuilder:(MvrPacketBuilder*) builder didEndWithError:(NSError*) e;
{
	self.lastError = e;
	didFinish = YES;
}

- (void) dealloc;
{
	self.parser = nil;
	self.lastError = nil;
	[super dealloc];
}

@synthesize lastError;

- (BOOL) runBuilderToEnd:(MvrPacketBuilder*) b;
{
	int attempts = 0;
	[b start];
	
	while (!didFinish) {
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
		attempts++;
		if (attempts >= 10) return NO;
	}
	
	return YES;
}

@end



@interface MvrPacketBuilderTest_AccumulatingDelegate : NSObject <MvrPacketBuilderDelegate>
{
	BOOL didStart, didFinish;
	NSMutableData* packetData;
	NSError* finalError;
}

@property(readonly) NSData* packet;
@property(readonly) BOOL didStart, didFinish;
@property(readonly) NSError* finalError;

- (BOOL) runBuilderToEnd:(MvrPacketBuilder*) b;

@end

@implementation MvrPacketBuilderTest_AccumulatingDelegate

- (NSData*) packet;
{
	return packetData;
}

- (id) init;
{
	if (self = [super init])
		packetData = [NSMutableData new];
	
	return self;
}

- (void) dealloc;
{
	[packetData release];
	[finalError release];
	[super dealloc];
}

- (void) packetBuilderWillStart:(MvrPacketBuilder*) builder;
{
	didStart = YES;
}

- (void) packetBuilder:(MvrPacketBuilder*) builder didProduceData:(NSData*) d;
{
	[packetData appendData:d];
}

- (void) packetBuilder:(MvrPacketBuilder*) builder didEndWithError:(NSError*) e;
{
	if (e != finalError) {
		[finalError release];
		finalError = [e retain];
		
		if (e) {
			NSLog(@"Did detect an error: %@", e);
		}
	}
	
	didFinish = YES;
}

- (BOOL) runBuilderToEnd:(MvrPacketBuilder*) b;
{
	int attempts = 0;
	[b start];
	
	while (!didFinish) {
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
		attempts++;
		if (attempts >= 10) return NO;
	}
	
	return YES;
}

@synthesize finalError, didStart, didFinish;

@end



#pragma mark -
#pragma mark Actual tests

@interface MvrPacketBuilderTest : SenTestCase
{
}

@end

@implementation MvrPacketBuilderTest

- (void) testConstructingValidPacket;
{
	MvrPacketBuilderTest_AccumulatingDelegate* delegate = 
		[[MvrPacketBuilderTest_AccumulatingDelegate new] autorelease];
	
	MvrPacketBuilder* builder = [[[MvrPacketBuilder alloc] initWithDelegate:delegate] autorelease];
	[builder setMetadataValue:@"A short test packet" forKey:@"Title"];
	[builder setMetadataValue:@"net.infinite-labs.Mover.test-packet" forKey:@"Type"];
	[builder addPayloadWithData:[@"OK" dataUsingEncoding:NSUTF8StringEncoding] forKey:@"okay"];
	[builder addPayloadWithData:[@"WOW" dataUsingEncoding:NSUTF8StringEncoding] forKey:@"wow"];

	STAssertTrue([delegate runBuilderToEnd:builder], @"Does not time out");
	
	STAssertTrue(delegate.didStart, nil);
	STAssertNil(delegate.finalError, nil);
	STAssertEqualObjects(delegate.packet, MvrPacketTestValidPacket(), nil);
}

- (void) testConstructingValidPacketFromFileStreams;
{
	MvrPacketBuilderTest_AccumulatingDelegate* delegate = 
		[[MvrPacketBuilderTest_AccumulatingDelegate new] autorelease];
	
	MvrPacketBuilder* builder = [[[MvrPacketBuilder alloc] initWithDelegate:delegate] autorelease];
	[builder setMetadataValue:@"A short test packet" forKey:@"Title"];
	[builder setMetadataValue:@"net.infinite-labs.Mover.test-packet" forKey:@"Type"];
	
	NSString* resourcesPath = [[NSBundle bundleForClass:[self class]] resourcePath];
	NSError* e = nil;
	STAssertTrue([builder addPayloadByReferencingFile:[resourcesPath stringByAppendingPathComponent:@"OK.data"] forKey:@"okay" error:&e],
				 @"Should not fail with an error: %@", e);
	STAssertTrue([builder addPayloadByReferencingFile:[resourcesPath stringByAppendingPathComponent:@"WOW.data"] forKey:@"wow" error:&e],
				 @"Should not fail with an error: %@", e);
	
	[builder addPayloadWithData:[@"WOW" dataUsingEncoding:NSUTF8StringEncoding] forKey:@"wow"];
	
	STAssertTrue([delegate runBuilderToEnd:builder], @"Does not time out");
	
	STAssertTrue(delegate.didStart, nil);
	STAssertNil(delegate.finalError, nil);
	STAssertEqualObjects(delegate.packet, MvrPacketTestValidPacket(), nil);
}

- (void) testConstructingValidPacketFromLongerFileStreams_FirstIsLonger;
{
	MvrPacketBuilderTest_AccumulatingDelegate* delegate = 
	[[MvrPacketBuilderTest_AccumulatingDelegate new] autorelease];
	
	MvrPacketBuilder* builder = [[[MvrPacketBuilder alloc] initWithDelegate:delegate] autorelease];
	[builder setMetadataValue:@"A short test packet" forKey:@"Title"];
	[builder setMetadataValue:@"net.infinite-labs.Mover.test-packet" forKey:@"Type"];
	
	NSString* resourcesPath = [[NSBundle bundleForClass:[self class]] resourcePath];
	NSError* e = nil;
	
	NSInputStream* ist = [NSInputStream inputStreamWithFileAtPath:[resourcesPath stringByAppendingPathComponent:@"OK-longer.data"]];
	[builder addPayload:ist length:2 forKey:@"okay"];
	
	STAssertTrue([builder addPayloadByReferencingFile:[resourcesPath stringByAppendingPathComponent:@"WOW.data"] forKey:@"wow" error:&e],
				 @"Should not fail with an error: %@", e);
	
	STAssertTrue([delegate runBuilderToEnd:builder], @"Does not time out");
	
	STAssertTrue(delegate.didStart, nil);
	STAssertNil(delegate.finalError, @"Error: %@", delegate.finalError);
	STAssertEqualObjects(delegate.packet, MvrPacketTestValidPacket(), nil);
}

- (void) testConstructingValidPacketFromLongerFileStreams_SecondIsLonger;
{
	MvrPacketBuilderTest_AccumulatingDelegate* delegate = 
	[[MvrPacketBuilderTest_AccumulatingDelegate new] autorelease];
	
	MvrPacketBuilder* builder = [[[MvrPacketBuilder alloc] initWithDelegate:delegate] autorelease];
	[builder setMetadataValue:@"A short test packet" forKey:@"Title"];
	[builder setMetadataValue:@"net.infinite-labs.Mover.test-packet" forKey:@"Type"];
	
	NSString* resourcesPath = [[NSBundle bundleForClass:[self class]] resourcePath];	
	[builder addPayloadWithData:[@"OK" dataUsingEncoding:NSUTF8StringEncoding] forKey:@"okay"];
	
	NSInputStream* ist = [NSInputStream inputStreamWithFileAtPath:[resourcesPath stringByAppendingPathComponent:@"WOW-longer.data"]];
	[builder addPayload:ist length:3 forKey:@"wow"];
	
	[builder addPayloadWithData:[@"WOW" dataUsingEncoding:NSUTF8StringEncoding] forKey:@"wow"];
	
	STAssertTrue([delegate runBuilderToEnd:builder], @"Does not time out");
	
	STAssertTrue(delegate.didStart, nil);
	STAssertNil(delegate.finalError, nil);
	STAssertEqualObjects(delegate.packet, MvrPacketTestValidPacket(), nil);
}

- (void) testConstructingValidPacketFromLongerFileStreams_BothAreLonger;
{
	MvrPacketBuilderTest_AccumulatingDelegate* delegate = 
		[[MvrPacketBuilderTest_AccumulatingDelegate new] autorelease];
	
	MvrPacketBuilder* builder = [[[MvrPacketBuilder alloc] initWithDelegate:delegate] autorelease];
	[builder setMetadataValue:@"A short test packet" forKey:@"Title"];
	[builder setMetadataValue:@"net.infinite-labs.Mover.test-packet" forKey:@"Type"];
	
	NSString* resourcesPath = [[NSBundle bundleForClass:[self class]] resourcePath];
	
	NSInputStream* ist = [NSInputStream inputStreamWithFileAtPath:[resourcesPath stringByAppendingPathComponent:@"OK-longer.data"]];
	[builder addPayload:ist length:2 forKey:@"okay"];
	
	ist = [NSInputStream inputStreamWithFileAtPath:[resourcesPath stringByAppendingPathComponent:@"WOW-longer.data"]];
	[builder addPayload:ist length:3 forKey:@"wow"];
	
	[builder addPayloadWithData:[@"WOW" dataUsingEncoding:NSUTF8StringEncoding] forKey:@"wow"];
	
	STAssertTrue([delegate runBuilderToEnd:builder], @"Does not time out");
	
	STAssertTrue(delegate.didStart, nil);
	STAssertNil(delegate.finalError, nil);
	STAssertEqualObjects(delegate.packet, MvrPacketTestValidPacket(), nil);
}

- (void) testFailingWhenStreamIsTooShort;
{
	MvrPacketBuilderTest_AccumulatingDelegate* delegate = 
		[[MvrPacketBuilderTest_AccumulatingDelegate new] autorelease];
	
	MvrPacketBuilder* builder = [[[MvrPacketBuilder alloc] initWithDelegate:delegate] autorelease];
	[builder setMetadataValue:@"A short test packet" forKey:@"Title"];
	[builder setMetadataValue:@"net.infinite-labs.Mover.test-packet" forKey:@"Type"];
	
	NSString* resourcesPath = [[NSBundle bundleForClass:[self class]] resourcePath];
	
	[builder addPayloadWithData:[@"OK" dataUsingEncoding:NSUTF8StringEncoding] forKey:@"okay"];
		
	NSInputStream* ist = [NSInputStream inputStreamWithFileAtPath:[resourcesPath stringByAppendingPathComponent:@"WOW-tooshort.data"]];
	[builder addPayload:ist length:3 forKey:@"wow"];
	
	STAssertTrue([delegate runBuilderToEnd:builder], @"Does not time out");
	
	STAssertTrue(delegate.didStart, nil);
	STAssertNotNil(delegate.finalError, nil);
}

- (void) testBuildingAndParsing;
{
	MvrPacketBuilderTests_ParserDelegate* parserDelegate = [[MvrPacketBuilderTests_ParserDelegate new] autorelease];
	MvrPacketParser* parser = [[(MvrPacketParser*)[MvrPacketParser alloc] initWithDelegate:parserDelegate] autorelease];	
	MvrPacketBuilderTest_ParsingDelegate* builderDelegate = [[MvrPacketBuilderTest_ParsingDelegate new] autorelease];
	MvrPacketBuilder* builder = [[[MvrPacketBuilder alloc] initWithDelegate:builderDelegate] autorelease];
	builderDelegate.parser = parser;

	NSString* lipsum = @"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vestibulum vulputate fermentum elit, non tincidunt sem ultrices mattis. Mauris ullamcorper gravida tellus sed luctus. Vivamus non diam quam. Praesent consequat cursus arcu, et iaculis ipsum egestas sit amet. Nulla dapibus blandit urna, tristique blandit elit luctus nec. Mauris vel neque tellus. Etiam molestie fringilla odio, a imperdiet erat cursus quis. In hac habitasse platea dictumst. In hac habitasse platea dictumst. Sed aliquet nisi ut risus sollicitudin rhoncus. Donec lectus mauris, lobortis non gravida sit amet, egestas vitae ante. Aliquam et mi velit.";
	
	[builder setMetadataValue:@"A" forKey:@"Test One"];
	[builder setMetadataValue:@"B" forKey:@"Test Two"];
	[builder setMetadataValue:lipsum forKey:@"Overlong value"];
	
	[builder addPayloadWithData:[lipsum dataUsingEncoding:NSUTF8StringEncoding] forKey:@"lipsum"];
	[builder addPayloadWithData:[@"Shorter" dataUsingEncoding:NSUTF8StringEncoding] forKey:@"shorter"];
	
	STAssertTrue([builderDelegate runBuilderToEnd:builder], @"Did not time up");
	STAssertNil(builderDelegate.lastError, nil);
	
	// 3 plus Payload-Stops, Payload-Keys.
	STAssertTrue([parserDelegate.metadata count] == 5, nil);
	STAssertEqualObjects([parserDelegate.metadata objectForKey:@"Test One"], @"A", nil);
	STAssertEqualObjects([parserDelegate.metadata objectForKey:@"Test Two"], @"B", nil);
	STAssertEqualObjects([parserDelegate.metadata objectForKey:@"Overlong value"], lipsum, nil);
	STAssertTrue([parserDelegate.payloads count] == 2, nil);
	STAssertTrue([[parserDelegate.payloads objectForKey:@"lipsum"] isEqualToData:[lipsum dataUsingEncoding:NSUTF8StringEncoding]], nil);
	STAssertTrue([[parserDelegate.payloads objectForKey:@"shorter"] isEqualToData:[@"Shorter" dataUsingEncoding:NSUTF8StringEncoding]], nil);
	
	STAssertNil(parserDelegate.lastError, nil);
}

@end
