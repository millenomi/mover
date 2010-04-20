#import <Foundation/Foundation.h>
#import <OCMock/OCMock.h>

static NSData* MvrPacketTestValidPacket() {
	NSMutableData* data = [NSMutableData data];
	const char* header = "MOVR2";
	[data appendBytes:header length:5];
	
	const uint8_t nullCharacter = 0;
	[data appendData:[@"Payload-Keys" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendBytes:&nullCharacter length:1];
	[data appendData:[@"okay wow" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendBytes:&nullCharacter length:1];	

	[data appendData:[@"Payload-Stops" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendBytes:&nullCharacter length:1];
	[data appendData:[@"2 5" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendBytes:&nullCharacter length:1];	
	
	[data appendData:[@"Title" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendBytes:&nullCharacter length:1];
	[data appendData:[@"A short test packet" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendBytes:&nullCharacter length:1];
	
	[data appendData:[@"Type" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendBytes:&nullCharacter length:1];
	[data appendData:[@"net.infinite-labs.Mover.test-packet" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendBytes:&nullCharacter length:1];
	
	[data appendBytes:&nullCharacter length:1];
	
	[data appendData:[@"OK" dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendData:[@"WOW" dataUsingEncoding:NSUTF8StringEncoding]];
	
	return data;
}
