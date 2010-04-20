//
//  MvrGenericItem.m
//  Network+Storage
//
//  Created by ∞ on 13/09/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import "MvrGenericItem.h"

#import "MvrUTISupport.h"
#import "MvrItemStorage.h"

@implementation MvrGenericItem

+ supportedTypes;
{
	return [NSArray arrayWithObject:(id) kUTTypeData];
}

- (id) initWithStorage:(MvrItemStorage*) s metadata:(NSDictionary*) m;
{
	return [self initWithStorage:s type:(id) kUTTypeData metadata:m];
}

- (id) produceExternalRepresentation;
{
	return [self.storage preferredContentObject];
}

- (BOOL) requiresStreamSupport;
{
	return YES;
}

@end
