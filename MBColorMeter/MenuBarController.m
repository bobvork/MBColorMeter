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

// Menu Items:
enum {
	CMMenuTagHoldColor	= 123,
	CMMenuTagCopyColor,
	CMMenuTagShowColor,
	CMMenuTagModeMenu
};

#define USERDEF_COLORMODE	@"~~USERDEF_COLORMODE~~"
#define USERDEF_SHOWCOLOR	@"~~USERDEF_SHOWCOLOR~~"

#import "MenuBarController.h"
#import <Carbon/Carbon.h>

@interface MenuBarController () {
    BOOL holding, showColorCode;
	NSInteger lastX, lastY;
	unsigned char currentColor[4];
}

@property (nonatomic, retain) NSMutableArray *lastCopiedColors;
@property (nonatomic, retain) NSMenu *appMenu;

@end

@implementation MenuBarController

@synthesize mouseUpdateTimer, titleAttributes;

- (id)init {
    self = [super init];
    if (self) {
        holding = NO;

		//TODO: get this from userdefaults:
		
		NSInteger colorMode = [[NSUserDefaults standardUserDefaults] integerForKey:USERDEF_COLORMODE];
		if(colorMode != 0) {
			// Userdefaults have been saved before
			showColorCode		= [[NSUserDefaults standardUserDefaults] boolForKey:USERDEF_SHOWCOLOR];
			colorDisplayMode	= (int)colorMode;
		} else {
			showColorCode		= YES;
			colorDisplayMode	= ColorDisplayModeHex;
		}
		
		
		self.lastCopiedColors	= [NSMutableArray array];

        // Install status item into the menu bar
        statusBarItem			= [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
		statusBarItem.title		= @"";
		[statusBarItem retain];
		
		
		NSFont *font = [NSFont userFixedPitchFontOfSize:11];
		self.titleAttributes = [NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
		
		mouseUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.15 target:self selector:@selector(updateMouseInfo) userInfo:nil repeats:YES];
		

		lastX = lastY = -1;
		
		// Setup menu
		self.appMenu = [[[NSMenu alloc] initWithTitle:@"Menu Bar Color Meter"] autorelease];
		NSMenuItem *colorModeItem = [[[NSMenuItem alloc] initWithTitle:@"Color Code Format" action:NULL keyEquivalent:@""] autorelease];
		NSMenuItem *quitItem = [[[NSMenuItem alloc] initWithTitle:@"Quit MBColorMeter" action:@selector(quitApplication) keyEquivalent:@""] autorelease];
		quitItem.target = self;
		
		NSMenuItem *showCodeItem	= [[[NSMenuItem alloc] initWithTitle:@"Show Color Code" action:@selector(toggleColorCode:) keyEquivalent:@""] autorelease];
		showCodeItem.target			= self;
		showCodeItem.state			= showColorCode? NSOnState : NSOffState;
		
		NSMenuItem *copyItem		= [[[NSMenuItem alloc] initWithTitle:@"Copy Current Color" action:@selector(copyColor:) keyEquivalent:@"C"] autorelease];
		copyItem.keyEquivalentModifierMask = NSAlternateKeyMask | NSCommandKeyMask;
		copyItem.target				= self;
		copyItem.tag				= CMMenuTagCopyColor;
		
		NSMenuItem *holdItem		= [[[NSMenuItem alloc] initWithTitle:@"Hold Color" action:@selector(holdColor:) keyEquivalent:@"H"] autorelease];
		holdItem.target				= self;
		holdItem.state				= holding? NSOnState : NSOffState;
		holdItem.tag				= CMMenuTagHoldColor;
		
		NSMenu *modeMenu = [[[NSMenu alloc] initWithTitle:@"Color Mode"] autorelease];
		
		NSMenuItem *modeHex         = [[[NSMenuItem alloc] initWithTitle:@"Hexadecimal" action:@selector(changeColorMode:) keyEquivalent:@""] autorelease];
		NSMenuItem *modeRGBFloat    = [[[NSMenuItem alloc] initWithTitle:@"RGB (float)" action:@selector(changeColorMode:) keyEquivalent:@""] autorelease];
		NSMenuItem *modeRGB255      = [[[NSMenuItem alloc] initWithTitle:@"RGB (255)" action:@selector(changeColorMode:) keyEquivalent:@""] autorelease];
		
		modeHex.target		= self;
		modeHex.tag			= ColorModeTagHex;
		modeHex.state		= (colorMode == ColorDisplayModeHex)? NSOnState : NSOffState;
		
		modeRGBFloat.target = self;
		modeRGBFloat.tag	= ColorModeTagRGBFloat;
		modeRGBFloat.state	= (colorMode == ColorDisplayModeRGBFloat)? NSOnState : NSOffState;
		
		modeRGB255.target	= self;
		modeRGB255.tag		= ColorModeTagRGB255;
		modeRGB255.state	= (colorMode == ColorDisplayModeRGB255)? NSOnState : NSOffState;
		
		[modeMenu addItem:modeHex];
		[modeMenu addItem:modeRGBFloat];
		[modeMenu addItem:modeRGB255];
		
		colorModeItem.submenu = modeMenu;
		colorModeItem.tag = CMMenuTagModeMenu;
		
		[self.appMenu addItem:colorModeItem];
		[self.appMenu addItem:showCodeItem];
		[self.appMenu addItem:holdItem];
		[self.appMenu addItem:copyItem];
		[self.appMenu addItem:[NSMenuItem separatorItem]];
		[self.appMenu addItem:quitItem];
		
		[statusBarItem setMenu:self.appMenu];
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
				[controller copyColor:[controller.appMenu itemWithTag:CMMenuTagCopyColor]];
				break;
			case CMHotKeyHold:
				[controller holdColor:[controller.appMenu itemWithTag:CMMenuTagHoldColor]];
				break;
			default:
				break;
		}
	}
	return noErr;
}

- (void)dealloc {
	[_appMenu release];
	[mouseUpdateTimer invalidate];
	[mouseUpdateTimer release];
	[titleAttributes release];	
    [statusBarItem release];
    [super dealloc];
}

- (void)updateMouseInfo {
	
	if(!holding) {
		[self readColorFromScreen];
	}
	
	[self updateColor];
		
	[self updateLabel];
}

-(void)readColorFromScreen {
	NSPoint mPoint		= [NSEvent mouseLocation];
	
	NSRect screenFrame	= [[NSScreen mainScreen] frame];
	NSInteger x			= floor(mPoint.x);
	NSInteger y			= floor(screenFrame.size.height - mPoint.y);
	
	if(lastX == x && lastY == y)	return;
	
	lastX = x;	lastY = y;
	
	CGImageRef pixelImageRef	= CGDisplayCreateImageForRect(CGMainDisplayID(), CGRectMake(x,y, 1, 1));
	CGColorSpaceRef colorSpace	= CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	CGContextRef readContext	= CGBitmapContextCreate(currentColor, 1, 1, 8, 4,
														colorSpace,
														kCGImageAlphaPremultipliedLast);
	
	CGContextDrawImage(readContext, CGRectMake(0, 0, 1, 1),pixelImageRef);
	CGContextRelease(readContext);
	CGColorSpaceRelease(colorSpace);
	CGImageRelease(pixelImageRef);
}

-(void)updateColor {
	
	// Create image to show in the Menu bar:
	CGColorSpaceRef colorSpace	= CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	CGContextRef drawContext = CGBitmapContextCreate(NULL, 12, 12, 8, 48, colorSpace, kCGImageAlphaPremultipliedLast);
	// Draw color:	
	CGColorRef drawColor = CGColorCreateGenericRGB(currentColor[0]/255.0, currentColor[1]/255.0, currentColor[2]/255.0, currentColor[3]/255.0);
	CGContextSetFillColorWithColor(drawContext, drawColor);
	CGColorRelease(drawColor);
	CGContextFillRect(drawContext, CGRectMake(0, 0, 12, 12));
	// Draw border
	[[NSColor darkGrayColor] setStroke];
	CGContextBeginPath(drawContext);
	
	CGContextMoveToPoint(drawContext, 1, 1);
	CGContextAddRect(drawContext, CGRectMake(.5, .5, 11, 11));
	CGContextStrokePath(drawContext);
	
	CGImageRef statusImg = CGBitmapContextCreateImage(drawContext);
	
	// Get image from the context we drew on:
	NSImage *colorImage = [[[NSImage alloc] initWithCGImage:statusImg size:NSMakeSize(12, 12)] autorelease];
	
	CGColorSpaceRelease(colorSpace);
	CGContextRelease(drawContext);
	CGImageRelease(statusImg);
	
	statusBarItem.image = colorImage;
	

}

-(void)updateLabel {
	// Set title of the menuitem:
	NSString *titleString = @"";
	
	if(showColorCode) {		
		titleString = [self stringForCurrentColor];
	}
	
	statusBarItem.attributedTitle = [[[NSAttributedString alloc] initWithString:titleString attributes:self.titleAttributes] autorelease];
}

-(NSString*)stringForCurrentColor {
	if(ColorDisplayModeHex == colorDisplayMode) {
		return [NSString stringWithFormat:@"#%02X%02X%02X", currentColor[0], currentColor[1], currentColor[2]];
	} else if(ColorDisplayModeRGB255 == colorDisplayMode) {
		return [NSString stringWithFormat:@"rgb(%d,%d,%d)", currentColor[0], currentColor[1], currentColor[2]];
	} else if(ColorDisplayModeRGBFloat == colorDisplayMode) {
		return [NSString stringWithFormat:@"rgb(%0.2f,%0.2f,%0.2f)", currentColor[0]/255.0, currentColor[1]/255.0, currentColor[2]/255.0];
	}
	
	return nil;
}

#pragma mark - Menu Item methods

-(void)changeColorMode:(NSMenuItem*)senderItem {
	for (NSMenuItem *item in senderItem.parentItem.submenu.itemArray) {
		item.state = NSOffState;
	}
	senderItem.state = NSOnState;
	
	if(senderItem.tag == ColorModeTagHex) {
		colorDisplayMode = ColorDisplayModeHex;
	} else if (senderItem.tag == ColorModeTagRGBFloat) {
		colorDisplayMode = ColorDisplayModeRGBFloat;
	} else if (senderItem.tag == ColorModeTagRGB255) {
		colorDisplayMode = ColorDisplayModeRGB255;
	} else if (senderItem.tag == ColorModeTagNone) {
		colorDisplayMode = ColorDisplayModeNone;
	}
	[[NSUserDefaults standardUserDefaults] setInteger:colorDisplayMode forKey:USERDEF_COLORMODE];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

-(void)quitApplication {
	[[NSApplication sharedApplication] terminate:self];
}

-(void)toggleColorCode:(NSMenuItem*)senderItem {
	showColorCode = !showColorCode;
	senderItem.state = showColorCode? NSOnState : NSOffState;
	[[NSUserDefaults standardUserDefaults] setBool:showColorCode forKey:USERDEF_SHOWCOLOR];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

-(void)holdColor:(NSMenuItem*)senderItem {
    holding = !holding;
	senderItem.state = holding? NSOnState : NSOffState;
}

-(void)copyColor:(NSMenuItem*)senderItem {
	NSString *colorString = [self stringForCurrentColor];	
	NSPasteboard *pBoard = [NSPasteboard generalPasteboard];
	[pBoard clearContents];
	[pBoard writeObjects:@[colorString]];
}

@end
