//
//  MvrStreamedIncoming.h
//  Network+Storage
//
//  Created by ∞ on 06/10/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import "MvrGenericIncoming.h"
#import "MvrPacketParser.h"

@class MvrItemStorage;

@interface MvrStreamedIncoming : MvrGenericIncoming <MvrPacketParserDelegate> {
	MvrPacketParser* parser;
	BOOL isNewPacket;
	BOOL hasCheckedForMetadata;
	
	MvrItemStorage* itemStorage;
	NSOutputStream* itemStorageStream;
	
	NSMutableDictionary* metadata;
}

- (void) didReceiveData:(NSData*) data;

- (void) checkMetadataIfNeeded;
- (void) cancel;
- (void) produceItem;
- (void) clear;

- (void) appendData:(NSData*) data;

@end
