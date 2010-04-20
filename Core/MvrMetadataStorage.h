
#import <Foundation/Foundation.h>

// Used by MvrStorageCentral to store and retrieve metadata about objects.

@protocol MvrMetadataStorage <NSObject>

// In Mover 3, keys and objects in this keys are private (except they're all property list objects).
// A metadata storage CAN return the dictionary that Mover1/2 used to save under the @"L0SlidePersistedItems" key in user defaults. If so, the storage may keep using that format or upgrade it to a newer one by setting this property at its discretion at any time.
@property(copy) NSDictionary* metadata;

@end
