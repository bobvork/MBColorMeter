//
//  MenuBarController.m
//  MBColorMeter
//
//  Created by Bob Vork on 15-07-12.
//  Copyright (c) 2012 Cue. All rights reserved.
//

enum {
	ColorModeTagHex = 101,
	ColorModeTagRGBFloat,
	ColorModeTagRGB255
};

#import "MenuBarController.h"

@implementation MenuBarController
@synthesize cView;
@synthesize colorWell;
@synthesize label;

@synthesize statusText, mouseUpdateTimer, titleAttributes;

- (id)init {
    self = [super init];
    if (self) {
        // Install status item into the menu bar
        statusBarItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
		statusBarItem.title = @"lala";
//		statusBarItem.target = self;
//		statusBarItem.action = @selector(statusBarItemClicked:);
		
		[NSBundle loadNibNamed:@"StatusItemView" owner:self];
		
		//statusBarItem.view = self.cView;
//		statusBarItem.view.acceptsFirstResponder = NO;
		
//		NSFont *font = [NSFont fontWithName:@"Inconsolata" size:16.0];
		NSFont *font = [NSFont userFixedPitchFontOfSize:12];
		self.titleAttributes = [NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
		
		mouseUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateMouseInfo) userInfo:nil repeats:YES];
		
		colorDisplayMode = ColorDisplayModeHex;
		lastX = lastY = -1;
		
		// Setup menu
		NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Menu Bar Color Meter"];
		NSMenuItem *colorModeItem = [[NSMenuItem alloc] initWithTitle:@"Color mode" action:NULL keyEquivalent:@""];
		NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit MBColorMeter" action:@selector(quitApplication) keyEquivalent:@""];
		quitItem.target = self;
		
		NSMenuItem *copyItem = [[NSMenuItem alloc] initWithTitle:@"Copy Current Color" action:@selector(copyColor) keyEquivalent:@"C"];
		copyItem.keyEquivalentModifierMask = NSAlternateKeyMask | NSCommandKeyMask;
		copyItem.target = self;
		
		NSMenuItem *holdItem = [[NSMenuItem alloc] initWithTitle:@"Hold Color" action:@selector(holdColor) keyEquivalent:@"H"];
		holdItem.target = self;
		
		NSMenu *modeMenu = [[NSMenu alloc] initWithTitle:@"Color Mode"];
		
		NSMenuItem *modeHex			= [[NSMenuItem alloc] initWithTitle:@"Hexadecimal" action:@selector(changeColorMode:) keyEquivalent:@""];
		NSMenuItem *modeRGBFloat	= [[NSMenuItem alloc] initWithTitle:@"RGB (float)" action:@selector(changeColorMode:) keyEquivalent:@""];
		NSMenuItem *modeRGB255		= [[NSMenuItem alloc] initWithTitle:@"RGB (255)" action:@selector(changeColorMode:) keyEquivalent:@""];
		
		modeHex.target		= self;
		modeHex.tag			= ColorModeTagHex;
		
		modeRGBFloat.target = self;
		modeRGBFloat.tag	= ColorModeTagRGBFloat;
		
		modeRGB255.target	= self;
		modeRGB255.tag		= ColorModeTagRGB255;
		
		[modeMenu addItem:modeHex];
		[modeMenu addItem:modeRGBFloat];
		[modeMenu addItem:modeRGB255];

		colorModeItem.submenu = modeMenu;
		
		[appMenu addItem:colorModeItem];
		[appMenu addItem:holdItem];
		[appMenu addItem:copyItem];
		[appMenu addItem:[NSMenuItem separatorItem]];
		[appMenu addItem:quitItem];
		
		[statusBarItem setMenu:appMenu];
		statusBarItem.highlightMode = YES;
		
		[NSEvent addGlobalMonitorForEventsMatchingMask:NSKeyDownMask handler:^(NSEvent *)event {
			NSLog(@"woop event");
		}];
    }
    return self;
}


- (void)statusBarItemClicked:(id)sender {
	// Toggle Color display mode:
	colorDisplayMode = ((colorDisplayMode+1) % ColorDisplayModeNumber);
}


- (void)updateMouseInfo {
	NSPoint mPoint = [NSEvent mouseLocation];
	
	NSRect screenFrame = [[NSScreen mainScreen] frame];
	NSInteger x = floor(mPoint.x);
	NSInteger y = floor(screenFrame.size.height - mPoint.y);
	
	if(lastX == x && lastY == y) {
		return;
	}
	
	lastX = x;	lastY = y;
	
	CGImageRef pixelImageRef = CGDisplayCreateImageForRect(CGMainDisplayID(), CGRectMake(x,y, 1, 1));
	
	unsigned char pixel[4] = {0};
	CGContextRef context = CGBitmapContextCreate(pixel, 1, 1, 8, 4, 
												 CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB),
												 kCGImageAlphaPremultipliedLast);

	CGContextDrawImage(context, CGRectMake(0, 0, 1, 1),pixelImageRef); 
	
	CGContextRelease(context);
	
	NSImage *colorImage = [[NSImage alloc] initWithCGImage:pixelImageRef size:NSMakeSize(12, 12)];
	statusBarItem.image = colorImage;
	
	CGFloat red		= pixel[0]/255.0;
	CGFloat green	= pixel[1]/255.0;
	CGFloat blue	= pixel[2]/255.0;
	
	NSString *titleString = nil;
	
	if(colorDisplayMode == ColorDisplayModeHex) {
		titleString = [NSString stringWithFormat:@"#%02X%02X%02X", pixel[0], pixel[1], pixel[2]];
	} else if(colorDisplayMode == ColorDisplayModeRGB255) {
		titleString = [NSString stringWithFormat:@"RGB(%d,%d,%d)", pixel[0], pixel[1], pixel[2]];
	} else if(colorDisplayMode == ColorDisplayModeRGBFloat) {
		titleString = [NSString stringWithFormat:@"RGB(%0.2f,%0.2f,%0.2f)", pixel[0]/255.0, pixel[1]/255.0, pixel[2]/255.0];
	}
	
	[self.label setStringValue:titleString];
	statusBarItem.attributedTitle = [[NSAttributedString alloc] initWithString:titleString attributes:self.titleAttributes];
	
	NSColor *color = [NSColor colorWithDeviceRed:red green:green blue:blue alpha:1.0];
	
	self.colorWell.color = color;
}

#pragma mark - Menu Item methods

-(void)changeColorMode:(NSMenuItem*)senderItem {
	if(senderItem.tag == ColorModeTagHex) {
		colorDisplayMode = ColorDisplayModeHex;
	} else if (senderItem.tag == ColorModeTagRGBFloat) {
		colorDisplayMode = ColorDisplayModeRGBFloat;
	} else if (senderItem.tag == ColorModeTagRGB255) {
		colorDisplayMode = ColorDisplayModeRGB255;
	}
	
	NSLog(@"Sender: %@",senderItem);
}

-(void)quitApplication {
	[[NSApplication sharedApplication] terminate:self];
}

-(void)holdColor {
	NSLog(@"HOLDUP1");
}

-(void)copyColor {
	NSLog(@"CopycopyColor!!");
}

@end
