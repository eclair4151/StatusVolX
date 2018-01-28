#import "StatusVolX.h"

bool sVolIsVisible = NO;

StatusVolX *svx;
NSString *oldFormatter;

// Send indicator command to the statusbar
%hook SBStatusBarStateAggregator
- (void)_resetTimeItemFormatter {
  %orig;

  NSDateFormatter *timeFormat = MSHookIvar<NSDateFormatter *>(self,"_timeItemDateFormatter");
  if (oldFormatter == nil) {
    oldFormatter = [timeFormat dateFormat]; // Allows us to reset the format
  }

  if ([svx showingVolume]) {
    [timeFormat setDateFormat:[svx volumeString]];
  } else {
    [timeFormat setDateFormat:oldFormatter];
  }
}
%end

// Hook volume change events
%hook VolumeControl
- (void)_changeVolumeBy:(float)arg1 {
  %orig;

  int theMode = MSHookIvar<int>(self,"_mode");
  if (theMode == 0) {
    [svx showVolume:[self getMediaVolume]*16];
  } else{
    [svx showVolume:[self volume]*16];
  }
}

// Force hide volume HUD
- (_Bool)_HUDIsDisplayableForCategory:(id)arg1 {
  return NO;
}

- (_Bool)_isCategoryAlwaysHidden:(id)arg1 {
  return YES;
}
%end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)arg1 {
  %orig;

  // Create StatusVolX inside SpringBoard
  svx = [[StatusVolX alloc] init];
}
%end

// StatusVol needs an auto-rotating UIWindow
@implementation svolWindow
// Un-hide after rotation
- (void)_finishedFullRotation:(id)arg1 finished:(id)arg2 context:(id)arg3 {
  [super _finishedFullRotation:arg1 finished:arg2 context:arg3];
  [self fixSvolWindow];
  if (sVolIsVisible) {
    [self setHidden:NO]; // Mitigate black box issue
  }
}

- (CGRect)getScreenBoundsForOrientation:(int)orientation {
  UIScreen *mainScreen = [UIScreen mainScreen];
  if ([mainScreen respondsToSelector:@selector(_boundsForInterfaceOrientation:)]) {
    return [mainScreen _boundsForInterfaceOrientation:orientation];
  }

  if (orientation != 3 && orientation != 4) return mainScreen.bounds;

  return CGRectMake(mainScreen.bounds.origin.x,
                    mainScreen.bounds.origin.y,
                    mainScreen.bounds.size.height,
                    mainScreen.bounds.size.width);
}

// Fix frame after orientation
- (void)fixSvolWindow {
  // Reset frame
  // Correctly set status bar rect
  // Y origin is set to -20 before animating it back to 0
  long orientation = (long)[(SpringBoard *)[UIApplication sharedApplication] _frontMostAppOrientation];
  CGRect mainScreenRect = [self getScreenBoundsForOrientation:orientation];
  CGRect windowRect = CGRectMake(0, 0, CGRectGetWidth(mainScreenRect), 20);

  // Change y position if the volume bar is supposed to be hidden
  if (!sVolIsVisible) {
    windowRect.origin.y = -20;
  }

  [self setFrame:windowRect];
}

// Force support auto-rotation. Hide on rotation events
- (BOOL)_shouldAutorotateToInterfaceOrientation:(int)arg1 {
  [self setHidden:YES]; // Mitigate black box issue
  return YES;
}
@end

@implementation StatusVolX
@synthesize showingVolume;

- (id)init {
  self = [super init];
  if (self) {
    volume = 0;
    self.showingVolume = NO;
    [self initializeWindow];
  }
  return self;
}

- (void)showVolume:(float)vol {
  volume =(int)vol;
  self.showingVolume = YES;

  SBStatusBarStateAggregator *sbsa = [%c(SBStatusBarStateAggregator) sharedInstance];
  [sbsa _resetTimeItemFormatter];
  [sbsa _updateTimeItems];

  if (hideTimer != nil) {
    [hideTimer invalidate];
  }
  hideTimer =[NSTimer scheduledTimerWithTimeInterval:2.0
                                              target:self
                                            selector:@selector(setNotShowingVolume)
                                            userInfo:nil
                                             repeats:NO];

  [self statusPeek];
}

- (bool)isCurrentAppStatusBarHidden {
  SpringBoard *springBoard = (SpringBoard *)[UIApplication sharedApplication];
  SBApplication *frontApp = (SBApplication *)[springBoard _accessibilityFrontMostApplication];

  if (frontApp == nil) return false;

  if ([frontApp respondsToSelector:@selector(statusBarHiddenForCurrentOrientation)]) {
    return [frontApp statusBarHiddenForCurrentOrientation];
  }

  // if (NSClassFromString(@"SBStatusBarManager")) {
  //   SBStatusBarManager *sbStatusBarManager = [%c(SBStatusBarManager) sharedInstance];
  //   if (sbStatusBarManager != nil && [sbStatusBarManager respondsToSelector:@selector(isFrontMostStatusBarHidden)]) {
  //     return [sbStatusBarManager isFrontMostStatusBarHidden];
  //   }
  // }

  return true;
}

- (void)statusPeek {
  if (![self isCurrentAppStatusBarHidden])
    return;

  // Show and set hide timer
  if (!sVolIsVisible || isAnimatingClose) {
    // Rotate status bar
    long orientation = (long)[(SpringBoard *)[UIApplication sharedApplication] _frontMostAppOrientation];
    [sVolWindow _rotateWindowToOrientation:orientation
                           updateStatusBar:NO
                                  duration:nil
                             skipCallbacks:YES];

    // Window adjustments
    if (!isAnimatingClose) {
      [sVolWindow fixSvolWindow];
      sVolIsVisible = YES;
      [sVolWindow setHidden:NO];
    } else {
      svolCloseInterrupt = YES;
    }

    // Animate entry
    [UIView animateWithDuration:0.3
                          delay:nil
                        options:(UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction)
                     animations:^{

        CGRect windowRect = sVolWindow.frame;
        windowRect.origin.y = 0;
        [sVolWindow setFrame:windowRect];
      } completion:^(BOOL finished) {
        // Reset the timer
        svolCloseInterrupt = NO;
        if (hideTimer != nil) {
          [hideTimer invalidate];
          hideTimer = nil;
        }

        hideTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                     target:self
                                                   selector:@selector(setNotShowingVolume)
                                                   userInfo:nil
                                                    repeats:NO];
      }];
  } else {
    // Reset the timer
    if (hideTimer != nil) {
      [hideTimer invalidate];
      hideTimer = nil;
    }
    hideTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                target:self
                                              selector:@selector(setNotShowingVolume)
                                              userInfo:nil
                                               repeats:NO];
  }
}

- (void)hideSvolWindow {
  // Unset hide timer
  hideTimer = nil;

  // Animate hide
  [UIView animateWithDuration:0.3
                        delay:0
                      options:(UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction)
                   animations:^{

      isAnimatingClose = YES;
      CGRect windowRect = sVolWindow.frame;
      // Animation dependent on orientation
      windowRect.origin.y = -20;
      [sVolWindow setFrame:windowRect];
    } completion:^(BOOL finished) {
      // Hide the window
      isAnimatingClose = NO;
      if (finished && !svolCloseInterrupt) {
        sVolIsVisible = NO;
        [sVolWindow setHidden:YES];
      }
    }];
}

- (void)initializeWindow {
  // Setup window
  /*CGRect mainFrame =[[UIScreen mainScreen] bounds];//[UIApplication sharedApplication].keyWindow.frame;
  mainFrame.origin.x =0;
  mainFrame.origin.y =-20;
  mainFrame.size.height =20;*/
  CGRect mainFrame = UIApplication.sharedApplication.statusBar.bounds;
  sVolWindow = [[svolWindow alloc] initWithFrame:mainFrame];
  if ([sVolWindow respondsToSelector:@selector(_setSecure:)]) {
    [sVolWindow _setSecure:YES];
  }
  sVolWindow.windowLevel = 1058;

  mainFrame.origin.y = 0;

  // Main view controller
  UIViewController *primaryVC = [[UIViewController alloc] init];
  [primaryVC.view setAutoresizingMask:UIViewAutoresizingFlexibleWidth];

  // Blur
  UIBlurEffect *blurEffect = [%c(UIBlurEffect) effectWithStyle:UIBlurEffectStyleDark];
  UIVisualEffectView *blurView = [[%c(UIVisualEffectView) alloc] initWithEffect:blurEffect];
  [blurView setFrame:mainFrame];
  [blurView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
  [primaryVC.view addSubview:blurView];

  int statusBarStyle = 0x12F; //Normal notification center style
  UIInterfaceOrientation orientation = [(SpringBoard *)[UIApplication sharedApplication] _frontMostAppOrientation];
  float statusBarHeight = [UIStatusBar.class heightForStyle:statusBarStyle orientation:orientation];
  float statusBarWidth = UIApplication.sharedApplication.statusBar.bounds.size.width;
  UIStatusBar *statusBar = [[UIStatusBar alloc] initWithFrame:CGRectMake(0, 0, statusBarWidth, statusBarHeight)];
  [statusBar requestStyle:statusBarStyle];
  statusBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  [primaryVC.view addSubview:statusBar];

  //After orientation changes
  //[statusBar setOrientation:UIApplication.sharedApplication.statusBarOrientation];

  // Make visible and hide window
  sVolWindow.rootViewController = primaryVC;
  [sVolWindow makeKeyAndVisible];
  [sVolWindow setHidden:YES];
}

- (void)setNotShowingVolume {
  hideTimer =nil;

  if (sVolIsVisible) {
    hideTimer =[NSTimer scheduledTimerWithTimeInterval:1.0
                                                target:self
                                              selector:@selector(hideSvolWindow)
                                              userInfo:nil
                                               repeats:NO];
  }

  self.showingVolume =NO;

  SBStatusBarStateAggregator *sbsa =[%c(SBStatusBarStateAggregator) sharedInstance];
  [sbsa _resetTimeItemFormatter];
  [sbsa _updateTimeItems];
}

- (NSString *)volumeString {
  return [NSString stringWithFormat:@"'#%d'",(int)volume];
}
@end