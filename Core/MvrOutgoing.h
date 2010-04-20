
#import <Foundation/Foundation.h>

@class MvrItem;

@protocol MvrOutgoing <NSObject>

// If non-nil after finished == YES, there was an error that prevented this transfer from finishing.
- (NSError*) error;


// All KVOable past this point. All could be set on first appaerance, so use NSKeyValueObservingOptionInitial or something.

// When finished == YES, the item was sent.
- (BOOL) finished;

@optional
// Can be 0.0..1.0 or kMvrIndeterminateProgress. KVOable.
- (float) progress;

@end
