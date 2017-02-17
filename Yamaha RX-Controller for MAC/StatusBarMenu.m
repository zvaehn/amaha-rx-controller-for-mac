//
//  StatusBarMenu.m
//  Yamaha RX-Controller for MAC
//
//  Created by Sven Schiffer on 08/02/2017.
//  Copyright © 2017 Sven Schiffer. All rights reserved.
//

#import "StatusBarMenu.h"
#import "CommunicationController.h"
#import "AFHTTPSessionManager.h"
#import "PreferencesWindowController.h"

@implementation StatusBarMenu

- (void)awakeFromNib {
    self.comctrl = [[CommunicationController alloc] init];
    self.isConnected = NO;
    self.userDefaults = [NSUserDefaults standardUserDefaults];
}

- (void) updateMenuAppearance {
    
    [self.statusMenuItem setEnabled:NO];
    [self.volumeSlider setEnabled:NO];
    [self.toggleMuteMenuItem setHidden:YES];
    [self setMenuItemToBold:NO forMenuItem:self.deviceMenuItem];
    
    // Device Submenu items
    [self.devicePowerOnMenuItem setHidden: NO];
    [self.devicePowerOffMenuItem setHidden: YES];

    
    // Enable items and set mark them as visible
    if(self.isConnected) {
        // Device Submenu items
        if([self.powerStatus isEqualToString:@"Standby"]) {
            [self.volumeSlider setDoubleValue: [self.volumeSlider minValue]];
            [self.volumeStatusMenuItem setTitle:@"Volume: -"];
            [self.statusMenuItem setTitle:[NSString stringWithFormat:@"Standby: %@", self.modelNumber]];
            [self.devicePowerOnMenuItem setHidden: NO];
            [self.devicePowerOffMenuItem setHidden: YES];
        }
        else if([self.powerStatus isEqualToString:@"On"]) {
            [self.statusMenuItem setTitle:[NSString stringWithFormat:@"Connected: %@", self.modelNumber]];
            [self setMenuItemToBold:YES forMenuItem:self.deviceMenuItem];
            [self.volumeSlider setEnabled:YES];
            [self.toggleMuteMenuItem setHidden:NO];
            [self.devicePowerOnMenuItem setHidden: YES];
            [self.devicePowerOffMenuItem setHidden: NO];
            
            // Init Submenu for Input sources
            NSMenu *inputSubmenu = [[NSMenu alloc] init];
            
            // Set Menu Items for Source Menu:
            for (NSString* key in self.availableInputs) {
                NSString *inputName = key;
                NSString *inputDisplayName = [[self.availableInputs objectForKey:key] objectForKey:@"text"];
                NSString *itemTitle = [NSString stringWithFormat:@"%@", inputDisplayName];
                NSMenuItem *tmpMenuItem = [[NSMenuItem alloc]
                                           initWithTitle:itemTitle
                                           action:@selector(onInputChanged:)
                                           keyEquivalent:@""];
                
                // Due to yamaha's function tree response inputs are different from the requested inputs -.- WOW.
                NSString *expectedInputName = [inputName stringByReplacingOccurrencesOfString:@"_" withString:@""];
                [tmpMenuItem setRepresentedObject: expectedInputName]; // Append a representationobject to the menuitem
                [tmpMenuItem setTarget:self]; // _VERY_ important, otherwise menu items have no target and will stay disabled!!!
                
                if([expectedInputName isEqualToString:self.selectedInput]) {
                    [tmpMenuItem setState:NSOnState];
                }
                
                [inputSubmenu addItem:tmpMenuItem];
            }
            
            [self.sourceMenuItem setSubmenu:inputSubmenu];
        }
        else {
            // Off ?
            NSLog(@"else in powerstatus: %@", self.powerStatus);
        }
    }
    else {
        [self.volumeSlider setDoubleValue: [self.volumeSlider minValue]];
        [self.volumeStatusMenuItem setTitle:@"Volume: -"];
        [self.devicePowerOnMenuItem setEnabled:NO];
    }
}

- (void)menuDidClose:(NSMenu *)menu {
    
}

- (void)menuWillOpen:(NSMenu *)menu {
    // Assign custom view to menu item
    [self.volumeSliderItem setView:self.volumeSliderView];

    //    [self.playControlMenuItem setView:self.playControlView];
    
    self.recieverIp = [self.userDefaults stringForKey:@"reciever-ip"];
    [self.statusMenuItem setTitle:@"Connecting..."];
    
    [self updateMenuAppearance];
    [self getVolumeInformation];
}

-(void)getSystemConfig {
    NSString *xml = @"<YAMAHA_AV cmd=\"GET\"><System><Config>GetParam</Config></System></YAMAHA_AV>";
    NSString *urlString = [NSString stringWithFormat:@"http://%@/YamahaRemoteControl/ctrl", self.recieverIp];
    
    // Start the request
    NSMutableURLRequest *urlrequest = [[AFHTTPRequestSerializer serializer] requestWithMethod:@"POST" URLString:urlString parameters:nil error:nil];
    [urlrequest setTimeoutInterval:5];
    [urlrequest setHTTPBody:[NSKeyedArchiver archivedDataWithRootObject:xml]];
    
    AFHTTPSessionManager *smanager = [[AFHTTPSessionManager alloc] init];
    smanager.responseSerializer = [AFHTTPResponseSerializer serializer];
    smanager.responseSerializer.acceptableContentTypes =  [smanager.responseSerializer.acceptableContentTypes setByAddingObject:@"text/xml"];
    
    NSURLSessionDataTask *task = [smanager dataTaskWithRequest:urlrequest completionHandler:^(NSURLResponse* _Nonnull response, id  _Nullable responseObject, NSError* _Nullable error) {
        
        if(!error) {
            NSError *parseerror = nil;
            NSString *fetchedXML = [[NSString alloc] initWithData:(NSData *)responseObject encoding:NSUTF8StringEncoding];
            
            NSData *data = [fetchedXML dataUsingEncoding:NSUTF8StringEncoding];
            
            // Parse XML-Response
            NSDictionary *dict = [XMLReader dictionaryForXMLData:data
                                                         options:XMLReaderOptionsProcessNamespaces
                                                           error:&parseerror];
            
            // Get System config dictionary
            NSDictionary *config = [dict valueForKeyPath:@"YAMAHA_AV.System.Config"];
            
            self.modelNumber = [config valueForKeyPath: @"Model_Name.text"];
            self.versionNumber = [config valueForKeyPath: @"Version.text"];
            
            NSDictionary *unsortedInputs = [config valueForKeyPath:@"Name.Input"];
            NSDictionary *unsortedFeatures = [config valueForKeyPath:@"Feature_Existence"];
            
            /*
            NSArray *sortedKeys = [[unsortedInputs allKeys] sortedArrayUsingSelector: @selector(compare:)];
            NSMutableArray *sortedValues = [NSMutableArray array];
            
            for (NSString *key in sortedKeys) {
                [sortedValues addObject: [unsortedInputs objectForKey: key]];
            }*/
            
            self.availableInputs = unsortedInputs;
            self.availableFeatures = unsortedFeatures;
            self.isConnected = YES;
            
            [self.statusMenuItem setTitle:@"Status: Connected"];
            [self.statusMenuItem setTitle:[NSString stringWithFormat:@"Connected: %@", self.modelNumber]];
            [self.deviceInfoMenuItem setTitle:[NSString stringWithFormat:@"Firmware Version: %@", self.versionNumber]];
        }
        else {
            [self.statusMenuItem setTitle:@"Unable to connect."];
            self.isConnected = NO;
            
            NSLog(@"Error: %@", error);
        }
        
        [self updateMenuAppearance];
    }];
    
    [task resume];
}

// Recieves Volume information and applies visual changes depending on the recieved information
-(void)getVolumeInformation {
    NSString *xml = @"<YAMAHA_AV cmd=\"GET\"><Main_Zone><Basic_Status>GetParam</Basic_Status></Main_Zone></YAMAHA_AV>";
    
    NSString *urlString = [NSString stringWithFormat:@"http://%@/YamahaRemoteControl/ctrl", self.recieverIp];
    
    // Start the request
    NSMutableURLRequest *urlrequest = [[AFHTTPRequestSerializer serializer] requestWithMethod:@"POST" URLString:urlString parameters:nil error:nil];
    [urlrequest setTimeoutInterval:5];
    [urlrequest setHTTPBody:[NSKeyedArchiver archivedDataWithRootObject:xml]];
    
    AFHTTPSessionManager *smanager = [[AFHTTPSessionManager alloc] init];
    smanager.responseSerializer = [AFHTTPResponseSerializer serializer];
    smanager.responseSerializer.acceptableContentTypes =  [smanager.responseSerializer.acceptableContentTypes setByAddingObject:@"text/xml"];
    
    NSURLSessionDataTask *task = [smanager dataTaskWithRequest:urlrequest completionHandler:^(NSURLResponse* _Nonnull response, id  _Nullable responseObject, NSError* _Nullable error) {
        
        if(!error) {
            NSError *parseerror = nil;
            NSString *fetchedXML = [[NSString alloc] initWithData:(NSData *)responseObject encoding:NSUTF8StringEncoding];
            
            NSData *data = [fetchedXML dataUsingEncoding:NSUTF8StringEncoding];
            
            NSDictionary *dict = [XMLReader dictionaryForXMLData:data
                                                         options:XMLReaderOptionsProcessNamespaces
                                                           error:&parseerror];
            
            
            NSDictionary *basicStatus = [dict valueForKeyPath:@"YAMAHA_AV.Main_Zone.Basic_Status"];
            NSDictionary *volume = [basicStatus valueForKeyPath:@"Volume"];
            
            self.powerStatus = [basicStatus valueForKeyPath:@"Power_Control.Power.text"];
            self.isConnected = YES;
            
            // Get Current Input
            self.selectedInput = [basicStatus valueForKeyPath:@"Input.Input_Sel.text"];
            
            // Get Volume
            NSString *rawVolLevel = [volume valueForKeyPath:@"Lvl.Val.text"];
            NSNumber *volLevel = [NSNumber numberWithInt: [rawVolLevel intValue]];
            
            // Set slider Volume
            [self.volumeSlider setDoubleValue:[volLevel doubleValue]];
            [self.volumeStatusMenuItem setTitle:[NSString stringWithFormat:@"Volume: %.1f dB", ([volLevel doubleValue]/10)]];
            
            // Set Mute status
            NSString *mute = [volume valueForKeyPath:@"Mute.text"];
            
            if([mute isEqualToString:@"On"]) {
                [self.toggleMuteMenuItem setState:1];
            }
            else {
                [self.toggleMuteMenuItem setState:0];
            }
            
            [self getSystemConfig];
        }
        else {
            [self.statusMenuItem setTitle:@"Unable to connect."];
            self.isConnected = NO;
            
            NSLog(@"Error: %@", error);
        }
        
        [self updateMenuAppearance];
    }];
    
    [task resume];
}

- (IBAction)onInputChanged:(id)sender {
    NSString *inputKey = [sender representedObject];
    
    [self.comctrl sendCommand: [NSString stringWithFormat: @"<YAMAHA_AV cmd=\"PUT\"><Main_Zone><Input><Input_Sel>%@</Input_Sel></Input></Main_Zone></YAMAHA_AV>", inputKey]];
}

- (IBAction)onVolumeHasChanged:(id)sender {
    NSEvent *event = [[NSApplication sharedApplication] currentEvent];
    BOOL startingDrag = event.type == NSEventTypeLeftMouseDown;
    BOOL endingDrag = event.type == NSEventTypeLeftMouseUp;
    BOOL dragging = event.type == NSEventTypeLeftMouseDragged;
    
    double rawSiderValue = [sender doubleValue];
    double sliderValue = rawSiderValue/10;
    double roundedSliderValue = round(sliderValue * 2.0) / 2.0; // round to 0, 0.5, 1 ...
    int dbValue = (roundedSliderValue * 10);
    
    NSAssert(startingDrag || endingDrag || dragging, @"unexpected event type caused slider change: %@", event);
    
    // Slider startet dragging
    if (startingDrag) {
        
    }
    
    // Slide value has been selected after mouse release
    if (endingDrag) {
        [self.comctrl sendCommand: [NSString stringWithFormat: @"<YAMAHA_AV cmd=\"PUT\"><Main_Zone><Volume><Lvl><Val>%d</Val><Exp>1</Exp><Unit>dB</Unit></Lvl></Volume></Main_Zone></YAMAHA_AV>", dbValue]];
        
        // Force the menu to close itself. This is necessary due to sendCommand limitations :/
        [self cancelTracking];
    }
    
    [self.volumeStatusMenuItem setTitle:[NSString stringWithFormat:@"Volume: %.1f dB ", roundedSliderValue]];
}

- (IBAction)onToggleMuteClicked:(id)sender {
    if([self.toggleMuteMenuItem state] > 0) {
        [self.toggleMuteMenuItem setState:0];
    }
    else {
        [self.toggleMuteMenuItem setState:1];
    }
    
    [self.comctrl sendCommand:@"<YAMAHA_AV cmd=\"PUT\"><Main_Zone><Volume><Mute>On/Off</Mute></Volume></Main_Zone></YAMAHA_AV>"];
}

- (IBAction)onPreferencesClicked:(id)sender {
    self.prefWinCon = [[PreferencesWindowController alloc] init];
}

- (IBAction)onQuitPressed:(id)sender {
     [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
}

- (IBAction)onDevicePowerOnClicked:(id)sender {
    [self.comctrl sendCommand:@"<YAMAHA_AV cmd=\"PUT\"><Main_Zone><Power_Control><Power>On</Power></Power_Control></Main_Zone></YAMAHA_AV>"];
}

- (IBAction)onDevicePowerOffClicked:(id)sender {
    [self.comctrl sendCommand:@"<YAMAHA_AV cmd=\"PUT\"><Main_Zone><Power_Control><Power>Standby</Power></Power_Control></Main_Zone></YAMAHA_AV>"];
}

- (IBAction)onPrevButtonClicked:(id)sender {
    [self.comctrl sendCommand:@"<YAMAHA_AV cmd=\"PUT\"><Main_Zone><Play_Control><Playback>Skip Rev</Playback></Play_Control></Main_Zone></YAMAHA_AV>"];
    [self cancelTracking];
}

- (IBAction)onPauseButtonClicked:(id)sender {
    [self.comctrl sendCommand:@"<YAMAHA_AV cmd=\"PUT\"><Main_Zone><Play_Control><Playback>Pause</Playback></Play_Control></Main_Zone></YAMAHA_AV>"];
    [self cancelTracking];
}

- (IBAction)onPlayButtonClicked:(id)sender {
     [self.comctrl sendCommand:@"<YAMAHA_AV cmd=\"PUT\"><Main_Zone><Play_Control><Playback>Play</Playback></Play_Control></Main_Zone></YAMAHA_AV>"];
    [self cancelTracking];
}

- (IBAction)onNextButtonClicked:(id)sender {
    [self.comctrl sendCommand:@"<YAMAHA_AV cmd=\"PUT\"><Main_Zone><Play_Control><Playback>Skip Fwd<</Playback></Play_Control></Main_Zone></YAMAHA_AV>"];
    [self cancelTracking];
}



- (void)setMenuItemToBold:(bool)bold forMenuItem:(NSMenuItem *)menuItem {
    NSFont *pFont;
    
    if(bold) {
        pFont = [NSFont boldSystemFontOfSize:14];
    }
    else {
        pFont = [NSFont menuFontOfSize:14];
    }
    
    NSDictionary* fontAttribute = [NSDictionary dictionaryWithObjectsAndKeys: pFont, NSFontAttributeName, nil] ;
    NSMutableAttributedString* newTitle = [[NSMutableAttributedString alloc] initWithString:[menuItem title] attributes:fontAttribute];
    [menuItem setAttributedTitle:newTitle];
}

@end
