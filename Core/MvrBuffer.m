//
//  MvrBuffer.m
//  Network+Storage
//
//  Created by ∞ on 05/10/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import "MvrBuffer.h"


@implementation MvrBuffer

- (id) init
{
	self = [super init];
	if (self != nil) {
		backingStore = [NSMutableData new];
	}
	return self;
}

@synthesize consumptionSize;

- (void) dealloc
{
	[backingStore release];
	[super dealloc];
}


- (void) appendData:(NSData*) data;
{
	[backingStore appendData:data];
}

- (NSData*) consume;
{
	if ([backingStore length] == 0)
		return nil;
	
	if ([backingStore length] <= self.consumptionSize) {
		NSData* oldStore = [[backingStore retain] autorelease];
		backingStore = [NSMutableData new];
		return [oldStore autorelease];
	} else {
		NSRange range = NSMakeRange(0, self.consumptionSize);
		NSData* part = [backingStore subdataWithRange:range];
		[backingStore replaceBytesInRange:range withBytes:NULL length:0];
		return part;
	}
}

- (BOOL) canConsume;
{
	return [backingStore length] == 0;
}

@end
