
#import <Foundation/Foundation.h>

@protocol MvrScanner <NSObject>

// Turns the scanner on and off. Can be KVO'd.
// The scanner MUST clear its .channels key when off.
@property BOOL enabled;

// Indicates difficulties in scanner use. Exact meaning scanner-dependant. Can be KVO'd.
// Note: only meaningful if enabled == YES.
@property(readonly) BOOL jammed;

// Can be KVO'd. Will fill with id <MvrChannel>s as they're found.
- (NSSet*) channels;

@end