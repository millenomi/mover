//
//  MvrBuffer.h
//  Network+Storage
//
//  Created by ∞ on 05/10/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MvrBuffer : NSObject {
	NSMutableData* backingStore;
	NSUInteger consumptionSize;
}

@property NSUInteger consumptionSize;

- (void) appendData:(NSData*) data;
- (NSData*) consume;

@property(readonly) BOOL canConsume;

@end
