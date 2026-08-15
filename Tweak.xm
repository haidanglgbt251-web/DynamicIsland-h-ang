#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#ifdef __cplusplus
extern "C" {
#endif
    void MRMediaRemoteRegisterForNowPlayingNotifications(dispatch_queue_t queue);
    void MRMediaRemoteGetNowPlayingInfo(dispatch_queue_t queue, void (^completed)(CFDictionaryRef information));
    void MRMediaRemoteSendCommand(int command, id userInfo);
#ifdef __cplusplus
}
#endif

// ==========================================
// CỬA SỔ XUYÊN THẤU TƯƠNG TÁC
// ==========================================

@interface DIHPassThroughWindow : UIWindow
@end

@implementation DIHPassThroughWindow
- (BOOL)_pointInside:(CGPoint)point windowServerHitTestWindow:(id)arg2 {
    UIView *island = [self.subviews firstObject];
    if (island) {
        CGPoint pointInIsland = [island convertPoint:point fromView:self];
        if ([island pointInside:pointInIsland withEvent:nil]) {
            return YES; 
        }
    }
    return NO; 
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self) return nil;
    return hitView;
}
@end

// ==========================================
// DYNAMIC ISLAND VIEW
// ==========================================

@interface DIHIslandView : UIView <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIImageView *leadingImageView;   
@property (nonatomic, strong) UIImageView *trailingImageView;  
@property (nonatomic, strong) UILabel *titleLabel;             
@property (nonatomic, strong) UILabel *subtitleLabel;          

@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *prevButton;
@property (nonatomic, strong) UIButton *nextButton;

@property (nonatomic, strong) UIButton *acceptCallButton;      
@property (nonatomic, strong) UIButton *declineCallButton;     
@property (nonatomic, strong) UIButton *timerButton;           

@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, strong) NSString *currentMode;           
@property (nonatomic, strong) UIImage *cachedArtworkImage;     

+ (instancetype)sharedInstance;
- (void)expandIsland;
- (void)collapseIsland;
- (void)updateLayoutForCurrentDevice;
- (void)showFaceIDAnimation;
- (void)showIncomingCallWithName:(NSString *)name;
- (void)showSiriAnimation;
- (void)addTimerModeWithDuration:(NSString *)duration;

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
        self.layer.masksToBounds = NO;
        self.userInteractionEnabled = YES;
        self.layer.borderWidth = 0.5;
        self.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1.0].CGColor;
        self.currentMode = @"Music";

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
        tap.delaysTouchesBegan = NO;
        tap.delaysTouchesEnded = NO;
        [self addGestureRecognizer:tap];

        self.leadingImageView = [[UIImageView alloc] init];
        self.leadingImageView.clipsToBounds = YES;
        self.leadingImageView.contentMode = UIViewContentModeScaleAspectFill;
        [self addSubview:self.leadingImageView];

        self.trailingImageView = [[UIImageView alloc] init];
        self.trailingImageView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:self.trailingImageView];

        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        [self addSubview:self.titleLabel];

        self.subtitleLabel = [[UILabel alloc] init];
        self.subtitleLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
        self.subtitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        [self addSubview:self.subtitleLabel];

        self.timerButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.timerButton setTitleColor:[UIColor systemOrangeColor] forState:UIControlStateNormal];
        self.timerButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        [self.timerButton addTarget:self action:@selector(handleTimerTap) forControlEvents:UIControlEventTouchUpInside];
        self.timerButton.alpha = 0.0;
        [self addSubview:self.timerButton];

        self.playPauseButton = [self createButtonWithImage:@"pause.fill" action:@selector(togglePlayPause)];
        self.prevButton = [self createButtonWithImage:@"backward.fill" action:@selector(skipPrev)];
        self.nextButton = [self createButtonWithImage:@"forward.fill" action:@selector(skipNext)];

        self.acceptCallButton = [self createButtonWithImage:@"phone.fill" action:@selector(acceptCall)];
        self.acceptCallButton.backgroundColor = [UIColor systemGreenColor];
        
        self.declineCallButton = [self createButtonWithImage:@"phone.down.fill" action:@selector(declineCall)];
        self.declineCallButton.backgroundColor = [UIColor systemRedColor];

        [self updateLayoutForCurrentDevice];
        [self setupListeners];
    }
    return self;
}

- (UIButton *)createButtonWithImage:(NSString *)imageName action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
    [btn setTintColor:[UIColor whiteColor]];
    btn.userInteractionEnabled = YES;
    btn.exclusiveTouch = YES;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:btn];
    return btn;
}

- (void)updateLayoutForCurrentDevice {
    CGRect screenRect = [UIScreen mainScreen].bounds;
    CGFloat screenWidth = MIN(screenRect.size.width, screenRect.size.height);

    CGFloat islandWidth = 125.0; 
    CGFloat islandHeight = 36.0;
    CGFloat topMargin = 8.0;

    self.frame = CGRectMake((screenWidth - islandWidth) / 2, topMargin, islandWidth, islandHeight);
    self.layer.cornerRadius = islandHeight / 2.0;

    self.leadingImageView.alpha = 1.0;
    self.leadingImageView.frame = CGRectMake(12, 10, 16, 16);
    if (self.cachedArtworkImage) {
        self.leadingImageView.image = self.cachedArtworkImage;
        self.leadingImageView.layer.cornerRadius = 8.0;
    } else {
        self.leadingImageView.image = [UIImage systemImageNamed:@"circle.fill"];
        self.leadingImageView.tintColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    }

    self.trailingImageView.alpha = 1.0;
    self.trailingImageView.frame = CGRectMake(125 - 28, 10, 16, 16);
    self.trailingImageView.image = [UIImage systemImageNamed:@"circle.fill"];
    self.trailingImageView.tintColor = [UIColor colorWithWhite:0.15 alpha:1.0];

    self.titleLabel.alpha = 0.0;
    self.subtitleLabel.alpha = 0.0;
    self.playPauseButton.alpha = 0.0;
    self.prevButton.alpha = 0.0;
    self.nextButton.alpha = 0.0;
    self.acceptCallButton.alpha = 0.0;
    self.declineCallButton.alpha = 0.0;
    self.timerButton.alpha = 0.0;
}

- (void)expandIsland {
    if (self.isExpanded) return;
    
    CGRect screenRect = [UIScreen mainScreen].bounds;
    CGFloat screenWidth = MIN(screenRect.size.width, screenRect.size.height);
    CGFloat expandedWidth = screenWidth - 28;
    CGFloat expandedHeight = 115.0;
    
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.9 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut animations:^{
        self.frame = CGRectMake(14, 6, expandedWidth, expandedHeight);
        self.layer.cornerRadius = 30;
        
        if ([self.currentMode isEqualToString:@"Music"]) {
            self.leadingImageView.frame = CGRectMake(14, 14, 55, 55);
            self.leadingImageView.layer.cornerRadius = 12;
            self.leadingImageView.alpha = 1.0;
            if (self.cachedArtworkImage) {
                self.leadingImageView.image = self.cachedArtworkImage;
            }
            
            self.trailingImageView.image = [UIImage systemImageNamed:@"waveform"];
            self.trailingImageView.tintColor = [UIColor systemGreenColor];
            self.trailingImageView.frame = CGRectMake(expandedWidth - 36, 26, 22, 22);
            self.trailingImageView.alpha = 1.0;
            
            self.titleLabel.frame = CGRectMake(82, 16, expandedWidth - 130, 20);
            self.titleLabel.alpha = 1.0;
            
            self.subtitleLabel.frame = CGRectMake(82, 38, expandedWidth - 130, 18);
            self.subtitleLabel.alpha = 1.0;
            
            CGFloat btnY = 70;
            CGFloat centerX = expandedWidth / 2;
            
            self.prevButton.frame = CGRectMake(centerX - 65, btnY, 40, 40);
            self.prevButton.alpha = 1.0;
            
            self.playPauseButton.frame = CGRectMake(centerX - 20, btnY, 40, 40);
            self.playPauseButton.alpha = 1.0;
            
            self.nextButton.frame = CGRectMake(centerX + 25, btnY, 40, 40);
            self.nextButton.alpha = 1.0;
        } else if ([self.currentMode isEqualToString:@"Call"]) {
            self.leadingImageView.image = [UIImage systemImageNamed:@"phone.fill"];
            self.leadingImageView.tintColor = [UIColor systemGreenColor];
            self.leadingImageView.frame = CGRectMake(18, 18, 40, 40);
            self.leadingImageView.layer.cornerRadius = 20;
            self.leadingImageView.alpha = 1.0;
            
            self.trailingImageView.alpha = 0.0;
            
            self.titleLabel.frame = CGRectMake(72, 18, expandedWidth - 140, 20);
            self.titleLabel.alpha = 1.0;
            
            self.subtitleLabel.frame = CGRectMake(72, 40, expandedWidth - 140, 18);
            self.subtitleLabel.alpha = 1.0;
            
            self.declineCallButton.frame = CGRectMake(expandedWidth - 100, 22, 36, 36);
            self.declineCallButton.layer.cornerRadius = 18;
            self.declineCallButton.alpha = 1.0;
            
            self.acceptCallButton.frame = CGRectMake(expandedWidth - 52, 22, 36, 36);
            self.acceptCallButton.layer.cornerRadius = 18;
            self.acceptCallButton.alpha = 1.0;
        } else if ([self.currentMode isEqualToString:@"FaceID"]) {
            self.leadingImageView.image = [UIImage systemImageNamed:@"faceid"];
            self.leadingImageView.tintColor = [UIColor systemGreenColor];
            self.leadingImageView.frame = CGRectMake(18, 20, 32, 32);
            self.leadingImageView.alpha = 1.0;
            
            self.trailingImageView.alpha = 0.0;

            self.titleLabel.text = @"Face ID";
            self.titleLabel.frame = CGRectMake(62, 26, 120, 20);
            self.titleLabel.alpha = 1.0;
            self.subtitleLabel.alpha = 0.0;
        } else if ([self.currentMode isEqualToString:@"Timer"]) {
            self.leadingImageView.image = [UIImage systemImageNamed:@"timer"];
            self.leadingImageView.tintColor = [UIColor systemOrangeColor];
            self.leadingImageView.frame = CGRectMake(18, 20, 32, 32);
            self.leadingImageView.alpha = 1.0;
            
            self.trailingImageView.alpha = 0.0;

            self.titleLabel.text = @"Hẹn giờ";
            self.titleLabel.frame = CGRectMake(62, 14, 120, 20);
            self.titleLabel.alpha = 1.0;
            
            [self.timerButton setTitle:self.subtitleLabel.text forState:UIControlStateNormal];
            self.timerButton.frame = CGRectMake(62, 36, 120, 24);
            self.timerButton.alpha = 1.0;
        } else if ([self.currentMode isEqualToString:@"Charging"]) {
            self.leadingImageView.image = [UIImage systemImageNamed:@"bolt.fill"];
            self.leadingImageView.tintColor = [UIColor systemYellowColor];
            self.leadingImageView.frame = CGRectMake(18, 20, 32, 32);
            self.leadingImageView.alpha = 1.0;
            
            self.trailingImageView.alpha = 0.0;
            
            self.titleLabel.text = @"Đang sạc pin";
            self.titleLabel.frame = CGRectMake(62, 16, 150, 20);
            self.titleLabel.alpha = 1.0;
            
            self.subtitleLabel.frame = CGRectMake(62, 38, 150, 18);
            self.subtitleLabel.alpha = 1.0;
        } else if ([self.currentMode isEqualToString:@"Siri"]) {
            self.leadingImageView.image = [UIImage systemImageNamed:@"sparkles"];
            self.leadingImageView.tintColor = [UIColor systemPurpleColor];
            self.leadingImageView.frame = CGRectMake(18, 20, 32, 32);
            self.leadingImageView.alpha = 1.0;
            
            self.trailingImageView.alpha = 0.0;
            
            self.titleLabel.text = @"Siri đang lắng nghe...";
            self.titleLabel.frame = CGRectMake(62, 26, expandedWidth - 80, 20);
            self.titleLabel.alpha = 1.0;
            self.subtitleLabel.alpha = 0.0;
        }
    } completion:^(BOOL finished) {
        self.isExpanded = YES;
    }];
}

- (void)collapseIsland {
    if (!self.isExpanded) return;
    
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.9 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut animations:^{
        [self updateLayoutForCurrentDevice];
    } completion:^(BOOL finished) {
        self.isExpanded = NO;
    }];
}

- (void)handleTap {
    if (self.isExpanded) {
        [self collapseIsland];
    } else {
        [self expandIsland];
    }
}

- (void)handleTimerTap {
    [self collapseIsland];
}

- (void)showFaceIDAnimation {
    self.currentMode = @"FaceID";
    [self expandIsland];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([self.currentMode isEqualToString:@"FaceID"]) {
            [self collapseIsland];
        }
    });
}

- (void)showIncomingCallWithName:(NSString *)name {
    self.currentMode = @"Call";
    self.titleLabel.text = name ? name : @"Cuộc gọi đến";
    self.subtitleLabel.text = @"Điện thoại Di động";
    [self expandIsland];
}

- (void)showSiriAnimation {
    self.currentMode = @"Siri";
    [self expandIsland];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([self.currentMode isEqualToString:@"Siri"]) {
            [self collapseIsland];
        }
    });
}

- (void)setupListeners {
    MRMediaRemoteRegisterForNowPlayingNotifications(dispatch_get_main_queue());
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNowPlayingInfo) name:@"kMRMediaRemoteNowPlayingInfoDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNowPlayingInfo) name:@"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification" object:nil];
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateNowPlayingInfo) userInfo:nil repeats:YES];

    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryStateDidChange) name:UIDeviceBatteryStateDidChangeNotification object:nil];
}

- (void)updateNowPlayingInfo {
    if ([self.currentMode isEqualToString:@"Call"] || [self.currentMode isEqualToString:@"Timer"] || [self.currentMode isEqualToString:@"FaceID"] || [self.currentMode isEqualToString:@"Charging"] || [self.currentMode isEqualToString:@"Siri"]) return;
    
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(CFDictionaryRef information) {
        NSDictionary *info = (__bridge NSDictionary *)information;
        if (info) {
            NSString *title = info[@"kMRMediaRemoteNowPlayingInfoTitle"];
            NSString *artist = info[@"kMRMediaRemoteNowPlayingInfoArtist"];
            NSData *artworkData = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
            
            if (title && title.length > 0) {
                self.titleLabel.text = title;
                self.subtitleLabel.text = artist ? artist : @"Đang phát";
                
                if (artworkData) {
                    UIImage *artImage = [UIImage imageWithData:artworkData];
                    if (artImage) {
                        self.cachedArtworkImage = artImage;
                        self.leadingImageView.image = artImage;
                        self.leadingImageView.tintColor = nil;
                    }
                }
                
                self.currentMode = @"Music";
                
                if (!self.isExpanded) {
                    if (self.cachedArtworkImage) {
                        self.leadingImageView.image = self.cachedArtworkImage;
                    }
                    self.trailingImageView.image = [UIImage systemImageNamed:@"waveform"];
                    self.trailingImageView.tintColor = [UIColor systemGreenColor];
                    self.trailingImageView.frame = CGRectMake(125 - 28, 10, 16, 16);
                    self.trailingImageView.alpha = 1.0;
                }
            }
        }
    });
}

- (void)batteryStateDidChange {
    UIDeviceBatteryState state = [[UIDevice currentDevice] batteryState];
    int batteryLevel = (int)([[UIDevice currentDevice] batteryLevel] * 100);
    
    if (state == UIDeviceBatteryStateCharging || state == UIDeviceBatteryStateFull) {
        self.currentMode = @"Charging";
        self.subtitleLabel.text = [NSString stringWithFormat:@"%d%% (Đang sạc)", batteryLevel];
        [self expandIsland];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([self.currentMode isEqualToString:@"Charging"]) {
                [self collapseIsland];
            }
        });
    }
}

- (void)addTimerModeWithDuration:(NSString *)duration {
    self.currentMode = @"Timer";
    self.subtitleLabel.text = duration;
    [self expandIsland];
}

- (void)togglePlayPause { 
    MRMediaRemoteSendCommand(0, nil); 
}

- (void)skipPrev { 
    MRMediaRemoteSendCommand(4, nil); 
}

- (void)skipNext { 
    MRMediaRemoteSendCommand(3, nil); 
}

- (void)acceptCall { 
    [self collapseIsland]; 
}

- (void)declineCall { 
    [self collapseIsland]; 
}

@end

// ==========================================
// HOOKS GIAO DIỆN HỆ THỐNG
// ==========================================

static DIHPassThroughWindow *islandWindow = nil;

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!islandWindow) {
            CGRect screenRect = [UIScreen mainScreen].bounds;
            islandWindow = [[DIHPassThroughWindow alloc] initWithFrame:screenRect];
            
            islandWindow.windowLevel = 100000.0; 
            islandWindow.backgroundColor = [UIColor clearColor];
            islandWindow.userInteractionEnabled = YES;
            islandWindow.hidden = NO;
            
            DIHIslandView *island = [DIHIslandView sharedInstance];
            [islandWindow addSubview:island];
            [islandWindow makeKeyAndVisible];
        }
    });
}
%end

%hook SBDashBoardViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (islandWindow) {
        [islandWindow setHidden:NO];
        [[islandWindow rootViewController].view bringSubviewToFront:[DIHIslandView sharedInstance]];
    }
}
%end
