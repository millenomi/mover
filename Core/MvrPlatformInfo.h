
#import <Foundation/Foundation.h>
#import <MuiKit/MuiKit.h>

enum {
	// This isn't the Mover application. Useful if, say, we're embedding the Mover engine stuff in another application, eg for testing (see mvr-wifi.m).
	kMvrAppVariantNotMover = 0,
	
	kMvrAppVariantMoverExperimental,

	// Open-source means that anyone can grab it and compile it. Paid means that most of it is open but I can still add Labs-exclusive features to the app that aren't distributed as FOSS. Lite is like Paid, but it's meant to be free of charge and have advertisements or less features and such.
	// These correspond to Mover Open (Cydia), Mover+ and Mover Lite respectively.
	kMvrAppVariantMoverOpen,
	kMvrAppVariantMoverPaid,
	kMvrAppVariantMoverPlus = kMvrAppVariantMoverPaid,
	kMvrAppVariantMoverLite,
};
typedef NSUInteger MvrAppVariant;

// Platform constants may be useful, but most one-platform-only should use appropriate conditionals, noted below for convenience.

// Apple iPhone OS
// use #if TARGET_OS_IPHONE.
// If something specifies a version and the version does not include a platform, assume this for obvious reasons.
extern NSString* const kMvrAppleiPhoneOSPlatform;

// Apple Mac OS X
// use #if TARGET_OS_MAC && !TARGET_OS_IPHONE.
extern NSString* const kMvrAppleMacOSXPlatform;

// WISHFUL THINKING AHEAD, MIND YOUR STEP
// Windows
// use #if __WIN32__
extern NSString* const kMvrMicrosoftWindowsPlatform;

// Maemo
// use #if kMvrPlatformCompilingForMaemo.
extern NSString* const kMvrNokiaMaemoPlatform;

#define kMvrUnknownVersion ((double)-1.0)

@protocol MvrPlatformInfo <NSObject>

// It's the name we identify ourselves with on the network.
- (NSString*) displayNameForSelf;

// A UUID. It's used so that other peers can distinguish us even if something happens to alter our display name (eg Bonjour renaming).
- (L0UUID*) identifierForSelf;

// The display name and identifier for Mover app variants.
- (MvrAppVariant) variant;
- (NSString*) variantDisplayName;

// The version for this application, used by "new version!" alerts and such.
// The version is actually a platform/version pair, plus a user-visible version string to display.
- (id) platform;
- (double) version;
- (NSString*) userVisibleVersion;

@end