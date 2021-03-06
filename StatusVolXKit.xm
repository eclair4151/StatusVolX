#import "StatusVolXKit.h"
#import <notify.h>

// %hook UIStatusBarTimeItemView
// - (id)imageWithText:(NSString *)arg1 {
//   // Manipulate
//   if ([arg1 length] > 0 && [arg1 characterAtIndex:0] == '#'){
//     int val = [[arg1 substringFromIndex:1] intValue];

//     // Get color from foregroundStyle
//     UIStatusBarForegroundStyleAttributes *fgStyle = self.foregroundStyle;
//     int legibilityStyle = [fgStyle legibilityStyle];
//     UIColor *fgColor = [fgStyle textColorForStyle:legibilityStyle];
//     UIImage *whiteImage = [self makeVolumeImageForState:val withColor:fgColor];

//     // We need to play around with the shadow image more...
//     // UIImage *shadowImage = [self.foregroundStyle shadowImageForImage:whiteImagewithIdentifier:[NSString stringWithFormat:@"SV_%d",val] forStyle:[self.foregroundStyle legibilityStyle] withStrength:0.0];

//     _UILegibilityImageSet *leg = [%c(_UILegibilityImageSet) imageFromImage:whiteImage withShadowImage:nil];

//     return leg;
//   } else {
//     return %orig;
//   }
// }

// %new(@:d@)
// - (UIImage *)makeVolumeImageForState:(int)state withColor:(UIColor *)color {
//   UIImage *theImage;

//   // Setup context
//   UIGraphicsBeginImageContextWithOptions(CGSizeMake(0.5+(7*16), 5.5), NO, 0.0f);
//   CGContextRef ctx = UIGraphicsGetCurrentContext();
//   CGContextSaveGState(ctx);

//   // Set line width
//   CGContextSetLineWidth(ctx, 0.3);

//   // Draw each circle
//   for (int i = 0; i < 16; i++) {
//     CGRect rect = CGRectMake((7*i)+0.25, 0.25, 5, 5);
//     CGContextSetFillColorWithColor(ctx, color.CGColor);
//     CGContextSetStrokeColorWithColor(ctx, color.CGColor);
//     CGContextStrokeEllipseInRect(ctx, rect);

//     // Fill appropriate ones
//     if (i < state){
//       CGContextFillEllipseInRect(ctx, rect);
//     }
//   }

//   // Save and flush state
//   CGContextRestoreGState(ctx);
//   theImage = UIGraphicsGetImageFromCurrentImageContext();
//   UIGraphicsEndImageContext();

//   // Return UIImage
//   return theImage;
// }
// %end

static void SendAppStatusBarVisibility(bool hidden) {
  if (hidden) {
    notify_post("com.fidele007.statusvolxkit/SetStatusBarHidden");
  } else {
    notify_post("com.fidele007.statusvolxkit/SetStatusBarVisible");
  }
}

%hook UIApplication
- (bool)_isStatusBarHiddenForOrientation:(long long)arg1 {
  SendAppStatusBarVisibility(%orig);
  return %orig;
}
- (void)_setStatusBarHidden:(bool)arg1 animationParameters:(id)arg2 changeApplicationFlag:(bool)arg3 {
  %orig;
  SendAppStatusBarVisibility(arg1);
}
- (void)setStatusBarHidden:(bool)arg1 {
  %orig;
  SendAppStatusBarVisibility(arg1);
}
- (void)setStatusBarHidden:(bool)arg1 animated:(bool)arg2 {
  %orig;
  SendAppStatusBarVisibility(arg1);
}
- (void)setStatusBarHidden:(bool)arg1 animationParameters:(id)arg2 {
  %orig;
  SendAppStatusBarVisibility(arg1);
}
- (void)setStatusBarHidden:(bool)arg1 animationParameters:(id)arg2 changeApplicationFlag:(bool)arg3 {
  %orig;
  SendAppStatusBarVisibility(arg1);
}
- (void)setStatusBarHidden:(bool)arg1 duration:(double)arg2 {
  %orig;
  SendAppStatusBarVisibility(arg1);
}
- (void)setStatusBarHidden:(bool)arg1 duration:(double)arg2 changeApplicationFlag:(bool)arg3 {
  %orig;
  SendAppStatusBarVisibility(arg1);
}
- (void)setStatusBarHidden:(bool)arg1 withAnimation:(long long)arg2 {
  %orig;
  SendAppStatusBarVisibility(arg1);
}
- (void)applicationDidBecomeActive:(UIApplication *)arg1 {
  %orig;
  SendAppStatusBarVisibility([self _isStatusBarHiddenForOrientation:[self _frontMostAppOrientation]]);
}
%end