//
//  MenuBarController.m
//  MBColorMeter
//
//  Created by Bob Vork on 15-07-12.
//  Copyright (c) 2012 Cue. All rights reserved.
//

enum {
    ColorModeTagNone = 99,
	ColorModeTagHex = 101,
	ColorModeTagRGBFloat,
	ColorModeTagRGB255
};

enum {
	CMHotKeyHold = 1,
	CMHotKeyCopy
};

#import "MenuBarController.h"
#import <Carbon/Carbon.h>

@interface MenuBarController () {
    BOOL holding;
	NSInteger lastX, lastY;
}

@property (nonatomic, retain) NSMutableArray *lastCopiedColors;

@end

@implementation MenuBarController

@synthesize mouseUpdateTimer, titleAttributes;

- (id)init {
    self = [super init];
    if (self) {
        holding = NO;
		self.lastCopiedColors = [NSMutableArray array];
        // Install status item into the menu bar
        statusBarItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
		statusBarItem.title = @"";
		[statusBarItem retain];
		
		//[NSBundle loadNibNamed:@"StatusItemView" owner:self];
		
		NSFont *font = [NSFont userFixedPitchFontOfSize:12];
		self.titleAttributes = [NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
		
		mouseUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.15 target:self selector:@selector(updateMouseInfo) userInfo:nil repeats:YES];
		
		colorDisplayMode = ColorDisplayModeHex;
		lastX = lastY = -1;
		
		// Setup menu
		NSMenu *appMenu = [[[NSMenu alloc] initWithTitle:@"Menu Bar Color Meter"] autorelease];
		NSMenuItem *colorModeItem = [[[NSMenuItem alloc] initWithTitle:@"Color Code Format" action:NULL keyEquivalent:@""] autorelease];
		NSMenuItem *quitItem = [[[NSMenuItem alloc] initWithTitle:@"Quit MBColorMeter" action:@selector(quitApplication) keyEquivalent:@""] autorelease];
		quitItem.target = self;
		
		NSMenuItem *copyItem = [[[NSMenuItem alloc] initWithTitle:@"Copy Current Color" action:@selector(copyColor) keyEquivalent:@"C"] autorelease];
		copyItem.keyEquivalentModifierMask = NSAlternateKeyMask | NSCommandKeyMask;
		copyItem.target = self;
		
		NSMenuItem *holdItem = [[[NSMenuItem alloc] initWithTitle:@"Hold Color" action:@selector(holdColor) keyEquivalent:@"H"] autorelease];
		holdItem.target = self;
		
		NSMenu *modeMenu = [[[NSMenu alloc] initWithTitle:@"Color Mode"] autorelease];
		
		NSMenuItem *modeHex         = [[[NSMenuItem alloc] initWithTitle:@"Hexadecimal" action:@selector(changeColorMode:) keyEquivalent:@""] autorelease];
		NSMenuItem *modeRGBFloat    = [[[NSMenuItem alloc] initWithTitle:@"RGB (float)" action:@selector(changeColorMode:) keyEquivalent:@""] autorelease];
		NSMenuItem *modeRGB255      = [[[NSMenuItem alloc] initWithTitle:@"RGB (255)" action:@selector(changeColorMode:) keyEquivalent:@""] autorelease];
        NSMenuItem *modeNone        = [[[NSMenuItem alloc] initWithTitle:@"Don't Show Color Code" action:@selector(changeColorMode:) keyEquivalent:@""] autorelease];
		
		modeHex.target		= self;
		modeHex.tag			= ColorModeTagHex;
		
		modeRGBFloat.target = self;
		modeRGBFloat.tag	= ColorModeTagRGBFloat;
		
		modeRGB255.target	= self;
		modeRGB255.tag		= ColorModeTagRGB255;
        
        modeNone.target     = self;
        modeNone.tag        = ColorModeTagNone;
		
		[modeMenu addItem:modeHex];
		[modeMenu addItem:modeRGBFloat];
		[modeMenu addItem:modeRGB255];
		[modeMenu addItem:modeNone];
		
		colorModeItem.submenu = modeMenu;
		
		[appMenu addItem:colorModeItem];
		[appMenu addItem:holdItem];
		[appMenu addItem:copyItem];
		[appMenu addItem:[NSMenuItem separatorItem]];
		[appMenu addItem:quitItem];
		
		[statusBarItem setMenu:appMenu];
		statusBarItem.highlightMode = YES;
		

		// Use Carbon to register global hotkeys
		// We use this for holding the color, and
		// for copying it to the clipboard
			
		EventHotKeyRef	hotKeyRef;
		EventHotKeyID	hotKeyHoldId, hotKeyCopyId;
		EventTypeSpec	eventType;
		
		eventType.eventClass	= kEventClassKeyboard;
		eventType.eventKind		= kEventHotKeyPressed;
		
		InstallApplicationEventHandler(&mbHotKeyHandler, 1, &eventType, self, NULL);
		
		hotKeyHoldId.signature = 'hkhl';
		hotKeyHoldId.id = CMHotKeyHold;
		
		hotKeyCopyId.signature = 'hkcp';
		hotKeyCopyId.id = CMHotKeyCopy;
		
		RegisterEventHotKey(kVK_ANSI_C, cmdKey + shiftKey, hotKeyCopyId, GetApplicationEventTarget(), 0, &hotKeyRef);
		RegisterEventHotKey(kVK_ANSI_H, cmdKey + shiftKey, hotKeyHoldId, GetApplicationEventTarget(), 0, &hotKeyRef);
		
    }
    return self;
}

OSStatus mbHotKeyHandler(EventHandlerCallRef nextHandler, EventRef event, void *userData) {
	if( userData && [(id)userData isKindOfClass:MenuBarController.class]) {
		
		MenuBarController *controller = (MenuBarController*)userData;
		
		EventHotKeyID eventHotKeyId;
		GetEventParameter(event, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(eventHotKeyId), NULL, &eventHotKeyId);
		int hotKey = eventHotKeyId.id;
				
		switch (hotKey) {
			case CMHotKeyCopy:
				[controller copyColor];
				break;
			case CMHotKeyHold:
				[controller holdColor];
				break;
			default:
				break;
		}
	}
	return noErr;
}

- (void)dealloc {
	[mouseUpdateTimer invalidate];
	[mouseUpdateTimer release];
	[titleAttributes release];	
    [statusBarItem release];
    [super dealloc];
}

- (void)updateMouseInfo {
    // Do not update if the user wants to hold the current colour:
    if( holding ) {
        return;
    }
	NSPoint mPoint = [NSEvent mouseLocation];
	
	NSRect screenFrame = [[NSScreen mainScreen] frame];
	NSInteger x = floor(mPoint.x);
	NSInteger y = floor(screenFrame.size.height - mPoint.y);
	
	if(lastX == x && lastY == y) {
		return;
	}
	
	lastX = x;	lastY = y;
	
	CGImageRef pixelImageRef = CGDisplayCreateImageForRect(CGMainDisplayID(), CGRectMake(x,y, 1, 1));
	CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	unsigned char pixel[4] = {0};
	CGContextRef readContext = CGBitmapContextCreate(pixel, 1, 1, 8, 4,
												 colorSpace,
												 kCGImageAlphaPremultipliedLast);

	CGContextDrawImage(readContext, CGRectMake(0, 0, 1, 1),pixelImageRef);
	CGContextRelease(readContext);
	

	
	
	// Create image to show in the Menu bar:
	CGContextRef drawContext = CGBitmapContextCreate(NULL, 12, 12, 8, 48, colorSpace, kCGImageAlphaPremultipliedLast);
	
	
	CGContextDrawImage(drawContext, CGRectMake(0, 0, 12, 12), pixelImageRef);
	// Draw border
	[[NSColor darkGrayColor] setStroke];

	CGContextBeginPath(drawContext);
//	CGMutablePathRef borderPath = CGPathCreateMutable();
	//CGPathAddRect(borderPath, NULL, CGRectMake(1, 1, 10, 10));
	
	CGContextMoveToPoint(drawContext, 1, 1);
	CGContextAddRect(drawContext, CGRectMake(.5, .5, 11, 11));
	
	CGContextStrokePath(drawContext);

	CGContextDrawPath(drawContext, kCGPathFill);

	CGImageRef statusImg = CGBitmapContextCreateImage(drawContext);

	NSImage *colorImage = [[[NSImage alloc] initWithCGImage:statusImg size:NSMakeSize(12, 12)] autorelease];
	
	CGColorSpaceRelease(colorSpace);
	CGContextRelease(drawContext);
		
	statusBarItem.image = colorImage;

	CGImageRelease(pixelImageRef);
	
	NSString *titleString = nil;
	
	if(ColorDisplayModeHex == colorDisplayMode) {
		titleString = [NSString stringWithFormat:@"#%02X%02X%02X", pixel[0], pixel[1], pixel[2]];
	} else if(ColorDisplayModeRGB255 == colorDisplayMode) {
		titleString = [NSString stringWithFormat:@"RGB(%d,%d,%d)", pixel[0], pixel[1], pixel[2]];
	} else if(ColorDisplayModeRGBFloat == colorDisplayMode) {
		titleString = [NSString stringWithFormat:@"RGB(%0.2f,%0.2f,%0.2f)", pixel[0]/255.0, pixel[1]/255.0, pixel[2]/255.0];
	} else if(ColorDisplayModeNone == colorDisplayMode) {
		titleString = @"";
	}
	
	statusBarItem.attributedTitle = [[[NSAttributedString alloc] initWithString:titleString attributes:self.titleAttributes] autorelease];	
}

#pragma mark - Menu Item methods

-(void)changeColorMode:(NSMenuItem*)senderItem {
	if(senderItem.tag == ColorModeTagHex) {
		colorDisplayMode = ColorDisplayModeHex;
	} else if (senderItem.tag == ColorModeTagRGBFloat) {
		colorDisplayMode = ColorDisplayModeRGBFloat;
	} else if (senderItem.tag == ColorModeTagRGB255) {
		colorDisplayMode = ColorDisplayModeRGB255;
	} else if (senderItem.tag == ColorModeTagNone) {
		colorDisplayMode = ColorDisplayModeNone;
	}
}

-(void)quitApplication {
	[[NSApplication sharedApplication] terminate:self];
}

-(void)holdColor {
	NSLog(@"HOLDUP1");
	
	
    holding = !holding;
}

-(void)copyColor {
	NSLog(@"CopycopyColor!!");
}

@end
