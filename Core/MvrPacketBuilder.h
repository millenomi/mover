//
//  MvrPacketBuilder.h
//  Mover
//
//  Created by ∞ on 23/08/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MvrProtocol.h"

enum {
	// use with addPayload:length:forKey:'s second parameter if the first parameter is a NSData object (or just use addPayloadWithData:forKey: instead).
	kMvrPacketBuilderDefaultLength = 0,
};

extern NSString* const kMvrPacketBuilderErrorDomain;
enum {
	kMvrPacketBuilderNotEnoughDataInStreamError = 1,
};

@class MvrPacketBuilder;
@protocol MvrPacketBuilderDelegate <NSObject>

@optional
- (void) packetBuilderWillStart:(MvrPacketBuilder*) builder;

@required
- (void) packetBuilder:(MvrPacketBuilder*) builder didProduceData:(NSData*) d;
- (void) packetBuilder:(MvrPacketBuilder*) builder didEndWithError:(NSError*) e;

@end

@interface MvrPacketBuilder : NSObject {
	id <MvrPacketBuilderDelegate> delegate;
	NSMutableDictionary* metadata;
	NSMutableArray* payloadOrder;
	NSMutableDictionary* payloadObjects;
	NSMutableDictionary* payloadLengths;
	unsigned long long toBeRead;
	
	BOOL isWorkingOnStreamPayload;
	NSUInteger currentPayloadIndex;
	
	BOOL sealed, cancelled;
	BOOL paused;
	
	NSRunLoop* runLoop;
	
	unsigned long long payloadsLength;
	unsigned long long sent;
	float progress;
}

- (id) initWithDelegate:(id <MvrPacketBuilderDelegate>) d;

// The run loop this builder will build packets on.
// Delegate calls will be dispatched on the thread for this run loop, and input streams will be scheduled on this run loop in the common modes. If -start is called on a thread whose run loop is not this one, then a call to -start will be enqueued on this run loop instead (effectively backgrounding the operation). Note that the builder is not otherwise thread-safe -- if you need to stop or pause, always do so on the same thread that runs this run loop.
@property(retain) NSRunLoop* runLoop;

// ----------------
// MUTATION METHODS
// ----------------

// These methods can only be called while the builder is not producing the packet (so, before willStart: and after didEndWithError:). They'll thrown an exception if called during building.

// Sets a value for the given key in the metadata header of this packet. Works exactly like -setObject:forKey: in NSDictionary.
// Keys are sorted lexicographically before being written into the header, so that packets with the same metadata keys and values and the same payloads will produce byte-for-byte equal packets.
// Note that metadata values and keys cannot contain the NULL ('\0') character. An exception will be thrown if either does.
- (void) setMetadataValue:(NSString*) v forKey:(NSString*) k;

// Removes the given key and its associated value from the metadata header of this packet.
- (void) removeMetadataValueForKey:(NSString*) key;

// Sets a payload for a specific key. Payloads are ordered in the order they're added.
// Adding a payload for a key that's already there will remove the current payload from its position and add the new payload to the end with the same key.
// body can be:
// - a NSData object. If so, length is ignored (pass kMvrPacketBuilderDefaultLength).
// - an UNOPENED NSInputStream. It will be scheduled on this thread's run loop on the common modes. If you pass a NSInputStream, you must also specify the stream's length. No more than length bytes will be read from it before closing.
// If the stream ends before length bytes, packetBuilder:didEndWithError: will be called with an appropriate error (kMvrPacketParserErrorDomain/kMvrPacketBuilderNotEnoughDataInStreamError)
- (void) addPayload:(id) payload length:(unsigned long long) length forKey:(NSString*) key;

// Convenience methods for addPayload:length:forKey:.
- (void) addPayloadWithData:(NSData*) d forKey:(NSString*) key;
- (BOOL) addPayloadByReferencingFile:(NSString*) s forKey:(NSString*) key error:(NSError**) e;

// Removing payloads from the packet.
- (void) removePayloadForKey:(NSString*) key;
- (void) removeAllPayloads;


// ----------------
// BUILDING METHODS
// ----------------

// Produces a packet!
- (void) start;

// YES if we're between willStart: and didEnd: as seen by the delegate.
@property(readonly, getter=isRunning) BOOL running;

// call this from willStart or didProduceData to end.
// will call didEndWithError: with a NSCocoaErrorDomain/NSUserCancelledError.
- (void) stop;

// While a packet builder is paused, calls that aren't ready to be delivered "without waiting" are put on hold until the builder is unpaused.
// This is a HINT. A paused packet builder can still send didProduceData: messages to its delegate while paused if those messages are ready to be processed; it can even finish providing the entire message without pausing (thus causing didEndWithError: to be called). This may at times cause this property to be ignored even if correctly set.
// Still, this property will be respected in any case where the builder would need to allocate more memory and/or access outside, slower-than-RAM resources such as reading from disk; if a paused builder is faced with either prospect, it will instead opt to wait until unpaused.
// This property is reset to NO whenever the builder starts producing a packet.
@property(getter=isPaused) BOOL paused;

// Reports the progress of a building operation.
// The value is only meaningful between a willStart and a didEndWithError.
// The value may also be unavailable, in which case it will be kMvrIndeterminateProgress.
@property(readonly, assign) float progress;

@end
