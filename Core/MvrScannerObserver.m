//
//  MvrScannerObserver.m
//  Network+Storage
//
//  Created by ∞ on 16/09/09.
//  Copyright 2009 Infinite Labs (Emanuele Vulcano). All rights reserved.
//

#import "MvrScannerObserver.h"

@interface MvrScannerObserver ()

- (void) beginObservingScanner;
- (void) endObservingScanner;

- (void) beginObservingChannel:(id <MvrChannel>) chan;
- (void) endObservingChannel:(id <MvrChannel>) chan;

- (void) beginObservingIncomingTransfer:(id <MvrIncoming>) incoming ofChannel:(id <MvrChannel>) chan;
- (void) endObservingIncomingTransfer:(id <MvrIncoming>) incoming;

- (void) beginObservingOutgoingTransfer:(id <MvrOutgoing>) outgoing ofChannel:(id <MvrChannel>) chan;
- (void) endObservingOutgoingTransfer:(id <MvrOutgoing>) outgoing;

@end


#import <MuiKit/MuiKit.h>

@implementation MvrScannerObserver

- (id) initWithScanner:(id <MvrScanner>) s delegate:(id <MvrScannerObserverDelegate>) d;
{
	if (self = [super init]) {
		kvo = [[L0KVODispatcher alloc] initWithTarget:self];

		delegate = d; // it owns us
		scanner = [s retain];
		
		observedObjects = [NSMutableSet new];
		
		[self beginObservingScanner];
	}
	
	return self;
}

- (void) dealloc;
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];

	[self endObservingScanner];
	[kvo release];
	
	[observedObjects release];
	
	[super dealloc];
}

- (NSString*) description;
{
	return [NSString stringWithFormat:@"%@ { delegate = %@; }", [super description], delegate];
}

#pragma mark -
#pragma mark Observing scanners.

- (void) scanner:(id <MvrScanner>) s didChangeJammedKey:(NSDictionary*) d;
{
	if ([delegate respondsToSelector:@selector(scanner:didChangeJammedKey:)]) {
		L0Log(@"Dispatching scanner:%@ didChangeJammedKey:%d", s, s.jammed);
		[delegate scanner:s didChangeJammedKey:s.jammed];
	}
}

- (void) scanner:(id <MvrScanner>) s didChangeEnabledKey:(NSDictionary*) d;
{
	if ([delegate respondsToSelector:@selector(scanner:didChangeEnabledKey:)]) {
		L0Log(@"Dispatching scanner:%@ didChangeEnabledKey:%d", s, s.enabled);
		[delegate scanner:s didChangeEnabledKey:s.enabled];
	}
}

- (void) scanner:(id <MvrScanner>)s didChangeChannelsKey:(NSDictionary *)d;
{
	[kvo forEachSetChange:d forObject:s invokeSelectorForInsertion:@selector(scanner:didAddChannel:) removal:@selector(scanner:didRemoveChannel:)];
}

- (void) scanner:(id <MvrScanner>)s didAddChannel:(id <MvrChannel>) chan;
{
	L0Log(@"%@.channels += %@", s, chan);
	[self beginObservingChannel:chan];
}

- (void) scanner:(id <MvrScanner>)s didRemoveChannel:(id <MvrChannel>) chan;
{
	L0Log(@"%@.channels -= %@", s, chan);
	[self performSelector:@selector(endObservingChannel:) withObject:chan afterDelay:0.1];
}

- (void) beginObservingScanner;
{
	L0Log(@"%@", scanner);
	
	if ([delegate respondsToSelector:@selector(scanner:didChangeJammedKey:)]) {
		L0Log(@"Dispatching initial scanner:%@ didChangeJammedKey:%d", scanner, scanner.jammed);
		[delegate scanner:scanner didChangeJammedKey:scanner.jammed];
	}
	
	if ([delegate respondsToSelector:@selector(scanner:didChangeEnabledKey:)]) {
		L0Log(@"Dispatching initial scanner:%@ didChangeEnabledKey:%d", scanner, scanner.enabled);
		[delegate scanner:scanner didChangeEnabledKey:scanner.enabled];
	}
	
	[kvo observe:@"enabled" ofObject:scanner usingSelector:@selector(scanner:didChangeEnabledKey:) options:0];
	[kvo observe:@"jammed" ofObject:scanner usingSelector:@selector(scanner:didChangeJammedKey:) options:0];
	
	for (id <MvrChannel> chan in scanner.channels)
		[self beginObservingChannel:chan];
	
	[kvo observe:@"channels" ofObject:scanner usingSelector:@selector(scanner:didChangeChannelsKey:) options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld];
}

- (void) endObservingScanner;
{
	L0Log(@"%@", scanner);
	
	for (id <MvrChannel> chan in scanner.channels)
		[self endObservingChannel:chan];
	
	[kvo endObserving:@"channels" ofObject:scanner];
	[kvo endObserving:@"jammed" ofObject:scanner];
	[kvo endObserving:@"enabled" ofObject:scanner];
}

#pragma mark -
#pragma mark Observing channels.

- (void) channel:(id <MvrChannel>) chan didChangeIncomingTransfersKey:(NSDictionary*) change;
{
	[kvo forEachSetChange:change forObject:chan invokeSelectorForInsertion:@selector(channel:didAddIncomingTransfer:) removal:@selector(channel:didRemoveIncomingTransfer:)];
}

- (void) channel:(id <MvrChannel>) chan didAddIncomingTransfer:(id <MvrIncoming>) incoming;
{
	L0Log(@"%@.incomingTransfers += %@", chan, incoming);
	[self beginObservingIncomingTransfer:incoming ofChannel:chan];
}

- (void) channel:(id <MvrChannel>) chan didRemoveIncomingTransfer:(id <MvrIncoming>) incoming;
{
	L0Log(@"%@.incomingTransfers -= %@", chan, incoming);
}


- (void) channel:(id <MvrChannel>) chan didChangeOutgoingTransfersKey:(NSDictionary*) change;
{
	[kvo forEachSetChange:change forObject:chan invokeSelectorForInsertion:@selector(channel:didAddOutgoingTransfer:) removal:@selector(channel:didRemoveOutgoingTransfer:)];
}

- (void) channel:(id <MvrChannel>) chan didAddOutgoingTransfer:(id <MvrOutgoing>) outgoing;
{
	L0Log(@"%@.outgoingTransfers += %@", chan, outgoing);
	[self beginObservingOutgoingTransfer:outgoing ofChannel:chan];
}

- (void) channel:(id <MvrChannel>) chan didRemoveOutgoingTransfer:(id <MvrOutgoing>) outgoing;
{
	L0Log(@"%@.outgoingTransfers -= %@", chan, outgoing);
}

- (void) beginObservingChannel:(id <MvrChannel>) chan;
{
	L0Log(@"%@", chan);
	
	if ([delegate respondsToSelector:@selector(scanner:didAddChannel:)]) {
		L0Log(@"Dispatching scanner:%@ didAddChannel:%@", scanner, chan);
		[delegate scanner:scanner didAddChannel:chan];
	}
	
	for (id <MvrIncoming> incoming in chan.incomingTransfers)
		[self beginObservingIncomingTransfer:incoming ofChannel:chan];
	
	[kvo observe:@"incomingTransfers" ofObject:chan usingSelector:@selector(channel:didChangeIncomingTransfersKey:) options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld];
	
	for (id <MvrOutgoing> outgoing in chan.outgoingTransfers)
		[self beginObservingOutgoingTransfer:outgoing ofChannel:chan];
	
	[kvo observe:@"outgoingTransfers" ofObject:chan usingSelector:@selector(channel:didChangeOutgoingTransfersKey:) options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld];
	
	if ([delegate respondsToSelector:@selector(channel:didChangeSupportsStreamsKey:)]) {
		L0Log(@"Dispatching (initial) channel:%@ didChangeSupportsStreamsKey:%d", chan, [chan supportsStreams]);
		[delegate channel:chan didChangeSupportsStreamsKey:[chan supportsStreams]];
	}
	
	[kvo observe:@"supportsStreams" ofObject:chan usingSelector:@selector(channel:didChangeSupportsStreamsKey:) options:0];
}

- (void) channel:(id <MvrChannel>) channel didChangeSupportsStreamsKey:(NSDictionary*) change;
{
	if ([delegate respondsToSelector:@selector(channel:didChangeSupportsStreamsKey:)]) {
		L0Log(@"Dispatching channel:%@ didChangeSupportsStreamsKey:%d", channel, [channel supportsStreams]);
		[delegate channel:channel didChangeSupportsStreamsKey:[channel supportsStreams]];
	}
}

- (void) endObservingChannel:(id <MvrChannel>) chan;
{
	L0Log(@"%@", chan);
	
	for (id <MvrIncoming> incoming in chan.incomingTransfers)
		[self endObservingIncomingTransfer:incoming];
	for (id <MvrOutgoing> outgoing in chan.incomingTransfers)
		[self endObservingOutgoingTransfer:outgoing];

	[kvo endObserving:@"incomingTransfers" ofObject:chan];
	[kvo endObserving:@"outgoingTransfers" ofObject:chan];
	[kvo endObserving:@"supportsStreams" ofObject:chan];
	
	if ([delegate respondsToSelector:@selector(scanner:didRemoveChannel:)]) {
		L0Log(@"Dispatching scanner:%@ didRemoveChannel:%@", scanner, chan);
		[delegate scanner:scanner didRemoveChannel:chan];
	}
}

#pragma mark -
#pragma mark Observing incoming transfers.

- (void) incomingTransfer:(id <MvrIncoming>) incoming didChangeItemOrCancelledKey:(NSDictionary*) change;
{
	if (incoming.cancelled || incoming.item) {
		L0Log(@"%@.cancelled == %d, %@.item == %@", incoming, incoming.cancelled, incoming, incoming.item);

		if ([delegate respondsToSelector:@selector(incomingTransfer:didEndReceivingItem:)]) {
			MvrItem* item = (incoming.cancelled? nil : incoming.item);
			L0Log(@"Dispatching incomingTransfer:%@ didEndReceivingItem:%@", incoming, item);
			[delegate incomingTransfer:incoming didEndReceivingItem:item];
		}
		
		[self endObservingIncomingTransfer:incoming];
	}
}

- (void) incomingTransfer:(id <MvrIncoming>)incoming didChangeProgressKey:(NSDictionary *)change;
{
	if ([delegate respondsToSelector:@selector(incomingTransfer:didProgress:)]) {
		L0Log(@"Dispatching incomingTransfer:%@ didProgress:%f", incoming, [incoming progress]);
		[delegate incomingTransfer:incoming didProgress:[incoming progress]];
	}
}

- (void) endObservingIncomingTransfer:(id <MvrIncoming>) incoming;
{
	[kvo endObserving:@"progress" ofObject:incoming];
	[kvo endObserving:@"item" ofObject:incoming];
	[kvo endObserving:@"cancelled" ofObject:incoming];
	[observedObjects removeObject:incoming];
}

- (void) beginObservingIncomingTransfer:(id <MvrIncoming>) incoming ofChannel:(id <MvrChannel>) chan;
{
	L0Log(@"%@ (from %@.incomingTransfers)", incoming, chan);
	if ([delegate respondsToSelector:@selector(channel:didBeginReceivingWithIncomingTransfer:)]) {
		L0Log(@"Dispatching channel:%@ didBeginReceivingWithIncomingTransfer:%@", chan, incoming);
		[delegate channel:chan didBeginReceivingWithIncomingTransfer:incoming];
	}
	
	if (incoming.cancelled || incoming.item) {
		if ([delegate respondsToSelector:@selector(incomingTransfer:didEndReceivingItem:)]) {
			MvrItem* item = (incoming.cancelled? nil : incoming.item);
			L0Log(@"Dispatching (immediate) incomingTransfer:%@ didEndReceivingItem:%@", incoming, item);
			[delegate incomingTransfer:incoming didEndReceivingItem:item];
		}
	} else {
		[observedObjects addObject:incoming];
		
		if ([delegate respondsToSelector:@selector(incomingTransfer:didProgress:)]) {
			L0Log(@"Dispatching (immediate) incomingTransfer:%@ didProgress:%f", incoming, [incoming progress]);
			[delegate incomingTransfer:incoming didProgress:[incoming progress]];
		}
		
		[kvo observe:@"progress" ofObject:incoming usingSelector:@selector(incomingTransfer:didChangeProgressKey:) options:0];
		[kvo observe:@"item" ofObject:incoming usingSelector:@selector(incomingTransfer:didChangeItemOrCancelledKey:) options:0];
		[kvo observe:@"cancelled" ofObject:incoming usingSelector:@selector(incomingTransfer:didChangeItemOrCancelledKey:) options:0];
	}
}

#pragma mark -
#pragma mark Observing outgoing transfers.

- (void) outgoingTransfer:(id <MvrOutgoing>) outgoing didChangeFinishedKey:(NSDictionary*) d;
{
	L0Log(@"%@.finished == %d", outgoing, outgoing.finished);
	if (outgoing.finished) {
		if ([delegate respondsToSelector:@selector(outgoingTransferDidEndSending:)]) {
			L0Log(@"Dispatching outgoingTransferDidEndSending:%@", outgoing);
			[delegate outgoingTransferDidEndSending:outgoing];
		}
		
		[self endObservingOutgoingTransfer:outgoing];
	}
}

- (void) outgoingTransfer:(id <MvrOutgoing>) outgoing didChangeProgressKey:(NSDictionary*) d;
{
	L0Log(@"%@.progress == %f (-1 == indeterminate)", outgoing, [outgoing progress]);
	if ([delegate respondsToSelector:@selector(outgoingTransfer:didProgress:)]) {
		L0Log(@"Dispatching outgoingTransfer:%@ didProgress:%f", outgoing, [outgoing progress]);
		[delegate outgoingTransfer:outgoing didProgress:[outgoing progress]];
	}
}

- (void) endObservingOutgoingTransfer:(id <MvrOutgoing>) outgoing;
{
	L0Log(@"%@", outgoing);
	[kvo endObserving:@"finished" ofObject:outgoing];
	[kvo endObserving:@"progress" ofObject:outgoing];
	[observedObjects removeObject:outgoing];
}

- (void) beginObservingOutgoingTransfer:(id <MvrOutgoing>) outgoing ofChannel:(id <MvrChannel>) chan;
{
	L0Log(@"%@ (from %@.outgoingTransfers)", outgoing, chan);
	if ([delegate respondsToSelector:@selector(channel:didBeginSendingWithOutgoingTransfer:)]) {
		L0Log(@"Dispatching channel:%@ didBeginSendingWithOutgoingTransfer:%@", chan, outgoing);
		[delegate channel:chan didBeginSendingWithOutgoingTransfer:outgoing];
	}
	
	if (outgoing.finished) {
		if ([delegate respondsToSelector:@selector(outgoingTransferDidEndSending:)]) {
			L0Log(@"Dispatching (immediate) outgoingTransferDidEndSending:%@", outgoing);
			[delegate outgoingTransferDidEndSending:outgoing];
		}
	} else {
		[observedObjects addObject:outgoing];
		[kvo observe:@"finished" ofObject:outgoing usingSelector:@selector(outgoingTransfer:didChangeFinishedKey:) options:0];
		
		if ([outgoing respondsToSelector:@selector(progress)]) {
			if ([delegate respondsToSelector:@selector(outgoingTransfer:didProgress:)]) {
				L0Log(@"Dispatching (initial) outgoingTransfer:%@ didProgress:%f", outgoing, [outgoing progress]);
				[delegate outgoingTransfer:outgoing didProgress:[outgoing progress]];
			}
			
			[kvo observe:@"progress" ofObject:outgoing usingSelector:@selector(outgoingTransfer:didChangeProgressKey:) options:0];
		}
	}
}

@end
