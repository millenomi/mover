
#import <Foundation/Foundation.h>

@class MvrItem;

@protocol MvrChannel <NSObject>

- (NSString*) displayName;

- (void) beginSendingItem:(MvrItem*) item;

// Can be KVO'd. Contains id <MvrIncoming>s.
- (NSSet*) incomingTransfers;

// Can be KVO'd. Contains id <MvrOutgoing>s.
- (NSSet*) outgoingTransfers;

// If YES, this channel can send items that require stream support (see MvrItem's comments for details).
// Can be KVO'd. It may change if channel capabilities change.
- (BOOL) supportsStreams;

@end
