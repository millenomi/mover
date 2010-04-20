//
//  MvrGenericItem.h
//  Network+Storage
//
//  Created by ∞ on 13/09/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MvrItem.h"

@interface MvrGenericItem : MvrItem {

}

- (id) initWithStorage:(MvrItemStorage*) s metadata:(NSDictionary*) m;

@end
