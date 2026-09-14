#import <Foundation/Foundation.h>

extern void HaloTeleprompterInstall(void);

__attribute__((constructor))
static void HaloInstallTeleprompterBootstrap(void) {
    [[NSNotificationCenter defaultCenter]
        addObserverForName:NSApplicationDidFinishLaunchingNotification
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(__unused NSNotification *note) {
            HaloTeleprompterInstall();
        }];
}
