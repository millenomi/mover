//
//  MvrWiFiIncoming.h
//  Network+Storage
//
//  Created by ∞ on 15/09/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MvrIncoming.h"

@class MvrItem, L0KVODispatcher;

@interface MvrGenericIncoming : NSObject <MvrIncoming> {
@private
	float progress;
	
	MvrItem* item;
	BOOL cancelled;
}

@property float progress;

@property(retain) MvrItem* item;
@property BOOL cancelled;

@end

@interface MvrGenericIncoming (MvrKVOUtilityMethods)

- (void) observeUsingDispatcher:(L0KVODispatcher*) d invokeAtItemChange:(SEL) itemSel atCancelledChange:(SEL) cancelSel;
- (void) observeUsingDispatcher:(L0KVODispatcher*) d invokeAtItemOrCancelledChange:(SEL) itemAndCancelSel;
- (void) endObservingUsingDispatcher:(L0KVODispatcher*) d;

@end