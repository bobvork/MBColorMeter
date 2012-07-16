//
//  AppDelegate.h
//  MBColorMeter
//
//  Created by Bob Vork on 15-07-12.
//  Copyright (c) 2012 Cue. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MenuBarController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (strong) MenuBarController *mbController;

@end
