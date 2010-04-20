
#import <Foundation/Foundation.h>

@class MvrItem;

@protocol MvrIncoming <NSObject>

// All KVOable past this point. All could be set on first appaerance, so use NSKeyValueObservingOptionInitial or something.

// These can be set if they're found during the transfer but before it finishes.
// - (NSString*) type;
// - (NSString*) title;

// Can be 0.0..1.0 or kMvrIndeterminateProgress.
- (float) progress;

// When item != nil or cancelled == YES, the transfer is over.
- (MvrItem*) item;
- (BOOL) cancelled;

@end
