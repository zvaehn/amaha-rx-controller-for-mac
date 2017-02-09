//
//  StatusBarMenu.h
//  Yamaha RX-Controller for MAC
//
//  Created by Sven Schiffer on 08/02/2017.
//  Copyright © 2017 Sven Schiffer. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CommunicationController.h"

@interface StatusBarMenu : NSMenu <NSMenuDelegate>

@property CommunicationController *cmdcstrl;
@property (weak) IBOutlet NSView *volumeSliderView;
@property (weak) IBOutlet NSSlider *volumeSlider;

- (IBAction)onToggleMuteClicked:(id)sender;
- (IBAction)onPreferencesClicked:(id)sender;
- (IBAction)onQuitPressed:(id)sender;
- (IBAction)onVolumeHasChanged:(id)sender;


@end
