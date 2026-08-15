#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#ifdef __cplusplus
extern "C" {
#endif
    void MRMediaRemoteRegisterForNowPlayingNotifications(dispatch_queue_t queue);
    void MRMediaRemoteGetNowPlayingInfo(dispatch_queue_t queue, void (^completed)(CFDictionaryRef information));
#ifdef __cplusplus
}
#endif

// ==========================================
// DYNAMIC ISLAND VIEW - ULTRA SMOOTH ANIMATION
// ==========================================

@interface DIHIslandView : UIView <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIImageView *leadingImageView;   
@property (nonatomic, strong) UIImageView *trailingImageView;  
@property (nonatomic, strong) UILabel *titleLabel;             
@property (nonatomic, strong) UILabel *subtitleLabel;          
@property (nonatomic, strong) UIView *recordingDotView;        
@property (nonatomic, strong) UIImageView *faceIDIconView;      
@property (nonatomic, strong) UIView *siriGlowView;            

@property (nonatomic, strong) UIButton *acceptCallButton;
@property (nonatomic, strong) UIButton *declineCallButton;

@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, assign) BOOL isFloatingMode;
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, strong) NSString *currentMode; 

+ (instancetype)sharedInstance;
- (void)expandIsland;
- (void)collapseIsland;
- (void)toggleFloatingMode;
- (void)updateNowPlayingInfo;
- (void)updateBatteryState;
- (void)showIncomingCallWithName:(NSString *)callerName number:(NSString *)number;
- (void)setRecordingState:(BOOL)recording;
- (void)triggerFaceIDAnimation;
- (void)setSiriActive:(BOOL)active;

@end

@implementation DIHIslandView

+ (instancetype)sharedInstance {
    static DIHIslandView *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[DIHIslandView alloc] initWithFrame:CGRectZero];
    });
    return shared;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        self.layer.masksToBounds = YES;
        self.userInteractionEnabled = YES;
        self.layer.borderWidth = 0.5;
        self.layer.borderColor = [UIColor colorWithWhite:0.18 alpha:0.8].CGColor;

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        
        [self addGestureRecognizer:tap];
        [self addGestureRecognizer:longPress];
        [self addGestureRecognizer:pan];

        self.leadingImageView = [[UIImageView alloc] init];
        self.leadingImageView.clipsToBounds = YES;
        self.leadingImageView.contentMode = UIViewContentModeScaleAspectFill;
        [self addSubview:self.leadingImageView];

        self.trailingImageView = [[UIImageView alloc] init];
        self.trailingImageView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:self.trailingImageView];

        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        self.titleLabel.alpha = 0.0;
        [self addSubview:self.titleLabel];

        self.subtitleLabel = [[UILabel alloc] init];
        self.subtitleLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
        self.subtitleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
        self.subtitleLabel.alpha = 0.0;
        [self addSubview:self.subtitleLabel];

        self.recordingDotView = [[UIView alloc] init];
        self.recordingDotView.backgroundColor = [UIColor systemRedColor];
        self.recordingDotView.layer.cornerRadius = 4;
        self.recordingDotView.alpha = 0.0;
        [self addSubview:self.recordingDotView];

        self.faceIDIconView = [[UIImageView alloc] init];
        self.faceIDIconView.image = [UIImage systemImageNamed:@"faceid"];
        self.faceIDIconView.tintColor = [UIColor systemGreenColor];
        self.faceIDIconView.contentMode = UIViewContentModeScaleAspectFit;
        self.faceIDIconView.alpha = 0.0;
        [self addSubview:self.faceIDIconView];

        self.siriGlowView = [[UIView alloc] init];
        self.siriGlowView.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.4];
        self.siriGlowView.layer.cornerRadius = 20;
        self.siriGlowView.alpha = 0.0;
        [self insertSubview:self.siriGlowView atIndex:0];

        self.acceptCallButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.acceptCallButton.backgroundColor = [UIColor systemGreenColor];
        self.acceptCallButton.layer.cornerRadius = 18;
        [self.acceptCallButton setTitle:@"✓" forState:UIControlStateNormal];
        self.acceptCallButton.alpha = 0.0;
        [self addSubview:self.acceptCallButton];

        self.declineCallButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.declineCallButton.backgroundColor = [UIColor systemRedColor];
        self.declineCallButton.layer.cornerRadius = 18;
        [self.declineCallButton setTitle:@"✕" forState:UIControlStateNormal];
        self.declineCallButton.alpha = 0.0;
        [self addSubview:self.declineCallButton];

        [self updateLayoutForCurrentDevice];
        [self setupMediaRemoteNotifications];
    }
    return self;
}

- (void)updateLayoutForCurrentDevice {
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat islandWidth = 125.0; 
    CGFloat islandHeight = 36.0;
    CGFloat topMargin = (screenWidth > 390) ? 12.0 : 8.0;

    self.frame = CGRectMake((screenWidth - islandWidth) / 2, topMargin, islandWidth, islandHeight);
    self.layer.cornerRadius = islandHeight / 2.0;

    self.leadingImageView.frame = CGRectMake(7, 6, 24, 24);
    self.leadingImageView.layer.cornerRadius = 12;
    self.trailingImageView.frame = CGRectMake(islandWidth - 31, 6, 24, 24);
    self.recordingDotView.frame = CGRectMake(islandWidth - 20, 14, 8, 8);

    self.titleLabel.alpha = 0.0;
    self.subtitleLabel.alpha = 0.0;
    self.acceptCallButton.alpha = 0.0;
    self.declineCallButton.alpha = 0.0;
    self.faceIDIconView.alpha = 0.0;
    self.siriGlowView.alpha = 0.0;
}

- (void)triggerFaceIDAnimation {
    self.currentMode = @"FaceID";
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.62 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.frame = CGRectMake((screenWidth - 95) / 2, 10, 95, 95);
        self.layer.cornerRadius = 30;
        
        self.faceIDIconView.frame = CGRectMake(27, 27, 41, 41);
        self.faceIDIconView.alpha = 1.0;
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.3 animations:^{
                self.faceIDIconView.alpha = 0.0;
            }];
            [self collapseIsland];
        });
    }];
}

- (void)setSiriActive:(BOOL)active {
    if (active) {
        self.currentMode = @"Siri";
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        
        [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.6 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.frame = CGRectMake((screenWidth - 170) / 2, 10, 170, 44);
            self.layer.cornerRadius = 22;
            
            self.siriGlowView.frame = self.bounds;
            self.siriGlowView.alpha = 0.85;
            self.titleLabel.text = @"Siri đang nghe...";
            self.titleLabel.frame = CGRectMake(22, 13, 130, 18);
            self.titleLabel.alpha = 1.0;
        } completion:nil];
    } else {
        [UIView animateWithDuration:0.35 animations:^{
            self.siriGlowView.alpha = 0.0;
        }];
        [self collapseIsland];
    }
}

- (void)setRecordingState:(BOOL)recording {
    self.isRecording = recording;
    if (recording) {
        self.currentMode = @"Recording";
        [UIView animateWithDuration:0.3 animations:^{
            self.recordingDotView.alpha = 1.0;
        }];
    } else {
        [UIView animateWithDuration:0.3 animations:^{
            self.recordingDotView.alpha = 0.0;
        }];
        self.currentMode = @"Idle";
    }
}

- (void)expandIsland {
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat expandedWidth = screenWidth - 32;
    CGFloat expandedHeight = 165.0;
    
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.72 initialSpringVelocity:0.7 options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut animations:^{
        self.frame = CGRectMake(16, 10, expandedWidth, expandedHeight);
        self.layer.cornerRadius = 38;
        
        self.leadingImageView.frame = CGRectMake(18, 18, 52, 52);
        self.leadingImageView.layer.cornerRadius = 14;
        
        self.titleLabel.frame = CGRectMake(82, 22, expandedWidth - 100, 22);
        self.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
        self.titleLabel.alpha = 1.0;
        
        self.subtitleLabel.frame = CGRectMake(82, 46, expandedWidth - 100, 18);
        self.subtitleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        self.subtitleLabel.alpha = 1.0;
    } completion:^(BOOL finished) {
        self.isExpanded = YES;
    }];
}

- (void)collapseIsland {
    [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.78 initialSpringVelocity:0.6 options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut animations:^{
        [self updateLayoutForCurrentDevice];
    } completion:^(BOOL finished) {
        self.isExpanded = NO;
    }];
}

- (void)showIncomingCallWithName:(NSString *)callerName number:(NSString *)number {
    self.currentMode = @"Call";
    self.titleLabel.text = callerName ? callerName : @"Cuộc gọi đến";
    self.subtitleLabel.text = number ? number : @"Đang đổ chuông...";
    
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat expandedWidth = screenWidth - 32;
    
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.6 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.frame = CGRectMake(16, 10, expandedWidth, 90.0);
        self.layer.cornerRadius = 32;
        
        self.titleLabel.frame = CGRectMake(20, 18, expandedWidth - 120, 20);
        self.titleLabel.alpha = 1.0;
        self.subtitleLabel.frame = CGRectMake(20, 40, expandedWidth - 120, 18);
        self.subtitleLabel.alpha = 1.0;

        self.declineCallButton.frame = CGRectMake(expandedWidth - 95, 27, 36, 36);
        self.declineCallButton.alpha = 1.0;
        self.acceptCallButton.frame = CGRectMake(expandedWidth - 50, 27, 36, 36);
        self.acceptCallButton.alpha = 1.0;
    } completion:nil];
}

- (void)handleTap {
    if (self.isFloatingMode) return;
    if (self.isExpanded) {
        [self collapseIsland];
    } else {
        [self expandIsland];
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self toggleFloatingMode];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (!self.isFloatingMode && !self.isExpanded) return;

    CGPoint translation = [pan translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:self.superview];
}

- (void)toggleFloatingMode {
    self.isFloatingMode = !self.isFloatingMode;
    
    [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        if (self.isFloatingMode) {
            self.frame = CGRectMake(20, 80, 150, 75);
            self.layer.cornerRadius = 24;
            self.titleLabel.alpha = 1.0;
            self.titleLabel.frame = CGRectMake(48, 16, 90, 18);
            self.subtitleLabel.alpha = 1.0;
            self.subtitleLabel.frame = CGRectMake(48, 36, 90, 16);
        } else {
            [self updateLayoutForCurrentDevice];
        }
    } completion:nil];
}

- (void)setupMediaRemoteNotifications {
    MRMediaRemoteRegisterForNowPlayingNotifications(dispatch_get_main_queue());
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNowPlayingInfo) name:@"kMRMediaRemoteNowPlayingInfoDidChangeNotification" object:nil];
}

- (void)updateNowPlayingInfo {
    if ([self.currentMode isEqualToString:@"Call"] || [self.currentMode isEqualToString:@"FaceID"] || self.isRecording) return;
    
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(CFDictionaryRef information) {
        NSDictionary *info = (__bridge NSDictionary *)information;
        if (info) {
            NSString *title = info[@"kMRMediaRemoteNowPlayingInfoTitle"];
            NSString *artist = info[@"kMRMediaRemoteNowPlayingInfoArtist"];
            NSData *artworkData = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
            
            if (title) {
                self.titleLabel.text = title;
                self.subtitleLabel.text = artist ? artist : @"Unknown Artist";
                if (artworkData) {
                    self.leadingImageView.image = [UIImage imageWithData:artworkData];
                }
                self.currentMode = @"Music";
            }
        }
    });
}

- (void)updateBatteryState {
    if ([self.currentMode isEqualToString:@"Call"] || [self.currentMode isEqualToString:@"FaceID"]) return;
    
    UIDevice *device = [UIDevice currentDevice];
    [device setBatteryMonitoringEnabled:YES];
    
    float level = [device batteryLevel] * 100;
    BOOL isCharging = ([device batteryState] == UIDeviceBatteryStateCharging || [device batteryState] == UIDeviceBatteryStateFull);
    
    self.titleLabel.text = [NSString stringWithFormat:@"%.0f%%", level];
    self.subtitleLabel.text = isCharging ? @"Đang sạc..." : @"Pin";
    self.currentMode = @"Battery";
    
    [self expandIsland];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self collapseIsland];
    });
}

@end

%hook SBLockScreenManager
- (void)_handleBiometricEvent:(unsigned long long)event {
    %orig;
    [[DIHIslandView sharedInstance] triggerFaceIDAnimation];
}
%end

%hook SiriUICommandHandler
- (void)handleSiriDidActivate {
    %orig;
    [[DIHIslandView sharedInstance] setSiriActive:YES];
}
- (void)handleSiriDidDeactivate {
    %orig;
    [[DIHIslandView sharedInstance] setSiriActive:NO];
}
%end

%hook SBUIController
- (void)updateBatteryState {
    %orig;
    [[DIHIslandView sharedInstance] updateBatteryState];
}
%end

%hook RPScreenRecorder
- (void)setRecording:(BOOL)recording {
    %orig;
    [[DIHIslandView sharedInstance] setRecordingState:recording];
}
%end

%hook SBNCAlertingController
- (void)alertOnCallIncomingWithCallerName:(NSString *)name number:(NSString *)number {
    %orig;
    [[DIHIslandView sharedInstance] showIncomingCallWithName:name number:number];
}
%end

static UIWindow *islandWindow = nil;

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        islandWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        islandWindow.windowLevel = UIWindowLevelStatusBar + 1;
        islandWindow.backgroundColor = [UIColor clearColor];
        islandWindow.userInteractionEnabled = YES;
        islandWindow.hidden = NO;
        
        DIHIslandView *island = [DIHIslandView sharedInstance];
        [islandWindow addSubview:island];
    });
}
%end
