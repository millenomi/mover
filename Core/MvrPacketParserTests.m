//
//  MvrPacketParserTests.m
//  Mover
//
//  Created by ∞ on 23/08/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import <OCMock/OCMock.h>

#import "MvrPacketParser.h"

@interface MvrPacketParserTests : SenTestCase
{
}

- (NSData*) validPacket;
- (void) makeMockObjectExpectValidPacketMessages:(OCMockObject*) delegate;

@end


@implementation MvrPacketParserTests

- (NSData*) validPacket;
{
	NSMutableData* data = [NSMutableData data];
	const char* header = "MOVR2";
	[data appendBytes:header length:5];
	
	const uint8_t nullCharacter = 0;
	[data appendData:[@"Title" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendBytes:&nullCharacter length:1];
	[data appendData:[@"A short test packet" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendBytes:&nullCharacter length:1];

	[data appendData:[@"Type" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendBytes:&nullCharacter length:1];
	[data appendData:[@"net.infinite-labs.Mover.test-packet" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendBytes:&nullCharacter length:1];
	
	[data appendData:[@"Payload-Stops" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendBytes:&nullCharacter length:1];
	[data appendData:[@"2 5" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendBytes:&nullCharacter length:1];	

	[data appendData:[@"Payload-Keys" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendBytes:&nullCharacter length:1];
	[data appendData:[@"okay wow" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendBytes:&nullCharacter length:1];	
	
	[data appendBytes:&nullCharacter length:1];
	
	[data appendData:[@"OK" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendData:[@"WOW" dataUsingEncoding:NSUTF8StringEncoding]];
	
	return data;
}

- (void) makeMockObjectExpectValidPacketMessages:(OCMockObject*) delegate;
{
	[[delegate expect] packetParserDidStartReceiving:[OCMArg any]];
	[[delegate expect] packetParser:[OCMArg any] didReceiveMetadataItemWithKey:@"Title" value:@"A short test packet"];
	[[delegate expect] packetParser:[OCMArg any] didReceiveMetadataItemWithKey:@"Type" value:@"net.infinite-labs.Mover.test-packet"];
	[[delegate expect] packetParser:[OCMArg any] didReceiveMetadataItemWithKey:@"Payload-Stops" value:@"2 5"];
	[[delegate expect] packetParser:[OCMArg any] didReceiveMetadataItemWithKey:@"Payload-Keys" value:@"okay wow"];

	[[delegate expect] packetParser:[OCMArg any] willReceivePayloadForKey:@"okay" size:2];
	[[delegate expect] packetParser:[OCMArg any] didReceivePayloadPart:[OCMArg checkWithSelector:@selector(isSameDataAsOKEncoded:) onObject:self] forKey:@"okay"];
	
	[[delegate expect] packetParser:[OCMArg any] willReceivePayloadForKey:@"wow" size:3];
	[[delegate expect] packetParser:[OCMArg any] didReceivePayloadPart:[OCMArg checkWithSelector:@selector(isSameDataAsWOWEncoded:) onObject:self] forKey:@"wow"];
	[[delegate expect] packetParser:[OCMArg any] didReturnToStartingStateWithError:[OCMArg isNil]];
	[[[delegate stub] andReturnValue:[NSNumber numberWithBool:YES]] packetParserShouldResetAfterCompletingPacket:[OCMArg any]];
}

- (void) testParsingValidPacket;
{
	NSData* data = [self validPacket];
	OCMockObject* delegate = [OCMockObject mockForProtocol:@protocol(MvrPacketParserDelegate)];
	[self makeMockObjectExpectValidPacketMessages:delegate];
	
	MvrPacketParser* parser = [[[MvrPacketParser alloc] initWithDelegate:(id <MvrPacketParserDelegate>) delegate] autorelease];
	[parser appendData:data];
	[delegate verify];
}

- (void) testGarbagePacket;
{
	NSData* garbage = [@"orow rowo o" dataUsingEncoding:NSUTF8StringEncoding];
	
	OCMockObject* delegate = [OCMockObject mockForProtocol:@protocol(MvrPacketParserDelegate)];
	[[delegate expect] packetParser:[OCMArg any] didReturnToStartingStateWithError:[OCMArg checkWithSelector:@selector(isMissingHeaderError:) onObject:self]];
	[[delegate expect] packetParserDidResetAfterError:[OCMArg any]];
	
	MvrPacketParser* parser = [[[MvrPacketParser alloc] initWithDelegate:(id <MvrPacketParserDelegate>) delegate] autorelease];
	[parser appendData:garbage];
	[delegate verify];
}

// Should the packet parser accumulate data after an error happens?
// If the data we have appended is known bad, should we drop subsequent good data?
// Methinks the client knows, so we should fix by having a flag that says we want
// to reset stuff when we know it's a new communication starting.
- (void) testGarbagePacketBeforeAndAfterValid;
{
	NSData* garbage = [@"orow rowo o" dataUsingEncoding:NSUTF8StringEncoding];
	
	OCMockObject* delegate = [OCMockObject mockForProtocol:@protocol(MvrPacketParserDelegate)];
	[self makeMockObjectExpectValidPacketMessages:delegate];
	[[delegate expect] packetParser:[OCMArg any] didReturnToStartingStateWithError:[OCMArg checkWithSelector:@selector(isMissingHeaderError:) onObject:self]];
	[[delegate expect] packetParserDidResetAfterError:[OCMArg any]];
	[self makeMockObjectExpectValidPacketMessages:delegate];
	
	MvrPacketParser* parser = [[[MvrPacketParser alloc] initWithDelegate:(id <MvrPacketParserDelegate>) delegate] autorelease];
	STAssertTrue(parser.expectingNewPacket, nil);

	[parser appendData:[self validPacket] isKnownStartOfNewPacket:YES];
	STAssertTrue(parser.expectingNewPacket, nil);
	
	[parser appendData:garbage isKnownStartOfNewPacket:YES];
	STAssertTrue(parser.expectingNewPacket, nil);
	
	[parser appendData:[self validPacket] isKnownStartOfNewPacket:YES];
	STAssertTrue(parser.expectingNewPacket, nil);

	[delegate verify];
}

- (void) testNotUTF8PacketInMetadataKey;
{
	NSMutableData* data = [NSMutableData data];
	[data appendData:[@"MOVR2" dataUsingEncoding:NSUTF8StringEncoding]];
	
	const uint8_t utf8garbage[] = { 0xFF, 0xFE, 0xEF, 0x0 };
	[data appendBytes:&utf8garbage length:4];
	
	OCMockObject* delegate = [OCMockObject mockForProtocol:@protocol(MvrPacketParserDelegate)];
	[[delegate expect] packetParserDidStartReceiving:[OCMArg any]];
	[[delegate expect] packetParser:[OCMArg any] didReturnToStartingStateWithError:[OCMArg checkWithSelector:@selector(isNotUTF8Error:) onObject:self]];
	[[delegate expect] packetParserDidResetAfterError:[OCMArg any]];
	
	MvrPacketParser* parser = [[[MvrPacketParser alloc] initWithDelegate:(id <MvrPacketParserDelegate>) delegate] autorelease];
	[parser appendData:data];
	[delegate verify];
}

- (void) testNotUTF8PacketInMetadataValue;
{
	NSMutableData* data = [NSMutableData data];
	[data appendData:[@"MOVR2" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendData:[@"Valid key" dataUsingEncoding:NSUTF8StringEncoding]];
	
	const uint8_t nullCharacter = 0;
	[data appendBytes:&nullCharacter length:1];

	const uint8_t utf8garbage[] = { 0xFF, 0xFE, 0xEF, 0x0 };
	[data appendBytes:&utf8garbage length:4];
	
	OCMockObject* delegate = [OCMockObject mockForProtocol:@protocol(MvrPacketParserDelegate)];
	[[delegate expect] packetParserDidStartReceiving:[OCMArg any]];
	[[delegate expect] packetParser:[OCMArg any] didReturnToStartingStateWithError:[OCMArg checkWithSelector:@selector(isNotUTF8Error:) onObject:self]];
	[[delegate expect] packetParserDidResetAfterError:[OCMArg any]];
	
	MvrPacketParser* parser = [[[MvrPacketParser alloc] initWithDelegate:(id <MvrPacketParserDelegate>) delegate] autorelease];
	[parser appendData:data];
	[delegate verify];
}

- (void) testNotUTF8PacketInMetadataKeyBeforeAndAfterValid;
{
	NSMutableData* data = [NSMutableData data];
	[data appendData:[@"MOVR2" dataUsingEncoding:NSUTF8StringEncoding]];
	
	const uint8_t utf8garbage[] = { 0xFF, 0xFE, 0xEF, 0x0 };
	[data appendBytes:&utf8garbage length:4];
	
	OCMockObject* delegate = [OCMockObject mockForProtocol:@protocol(MvrPacketParserDelegate)];
	[self makeMockObjectExpectValidPacketMessages:delegate];
	[[delegate expect] packetParserDidStartReceiving:[OCMArg any]];
	[[delegate expect] packetParser:[OCMArg any] didReturnToStartingStateWithError:[OCMArg checkWithSelector:@selector(isNotUTF8Error:) onObject:self]];
	[[delegate expect] packetParserDidResetAfterError:[OCMArg any]];

	[self makeMockObjectExpectValidPacketMessages:delegate];
	
	MvrPacketParser* parser = [[[MvrPacketParser alloc] initWithDelegate:(id <MvrPacketParserDelegate>) delegate] autorelease];
	[parser appendData:[self validPacket]];
	[parser appendData:data];
	[parser appendData:[self validPacket]];
	[delegate verify];
}

- (void) testNotUTF8PacketInMetadataValueBeforeAndAfterValid;
{
	NSMutableData* data = [NSMutableData data];
	[data appendData:[@"MOVR2" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendData:[@"Valid key" dataUsingEncoding:NSUTF8StringEncoding]];
	
	const uint8_t nullCharacter = 0;
	[data appendBytes:&nullCharacter length:1];
	
	const uint8_t utf8garbage[] = { 0xFF, 0xFE, 0xEF, 0x0 };
	[data appendBytes:&utf8garbage length:4];
	
	OCMockObject* delegate = [OCMockObject mockForProtocol:@protocol(MvrPacketParserDelegate)];
	[self makeMockObjectExpectValidPacketMessages:delegate];
	[[delegate expect] packetParserDidStartReceiving:[OCMArg any]];
	[[delegate expect] packetParser:[OCMArg any] didReturnToStartingStateWithError:[OCMArg checkWithSelector:@selector(isNotUTF8Error:) onObject:self]];
	[self makeMockObjectExpectValidPacketMessages:delegate];
	[[delegate expect] packetParserDidResetAfterError:[OCMArg any]];
	
	MvrPacketParser* parser = [[[MvrPacketParser alloc] initWithDelegate:(id <MvrPacketParserDelegate>) delegate] autorelease];
	[parser appendData:[self validPacket]];
	[parser appendData:data];
	[parser appendData:[self validPacket]];
	[delegate verify];
}

- (BOOL) isSameDataAsOKEncoded:(NSData*) d;
{
	return [d isEqualToData:[@"OK" dataUsingEncoding:NSUTF8StringEncoding]];
}

- (BOOL) isSameDataAsWOWEncoded:(NSData*) d;
{
	return [d isEqualToData:[@"WOW" dataUsingEncoding:NSUTF8StringEncoding]];
}

- (BOOL) isSameDataAsOEncoded:(NSData*) d;
{
	const char* s = [d bytes];
	return [d length] == 1 && *s == 'O';
}

- (BOOL) isSameDataAsKEncoded:(NSData*) d;
{
	const char* s = [d bytes];
	return [d length] == 1 && *s == 'K';
}

- (BOOL) isSameDataAsWEncoded:(NSData*) d;
{
	const char* s = [d bytes];
	return [d length] == 1 && *s == 'W';
}

- (BOOL) isMissingHeaderError:(NSError*) e;
{
	return [[e domain] isEqual:kMvrPacketParserErrorDomain] && [e code] == kMvrPacketParserDidNotFindStartError;
}

- (BOOL) isNotUTF8Error:(NSError*) e;
{
	return [[e domain] isEqual:kMvrPacketParserErrorDomain] && [e code] == kMvrPacketParserNotUTF8StringError;
}

@end
