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
// CỬA SỔ XUYÊN THẤU & LUÔN NỔI TRÊN MỌI LỚP
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
    return NO; // Bấm ra ngoài -> Xuyên cảm ứng xuống màn hình khóa / ứng dụng bên dưới
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

@property (nonatomic, strong) UIImageView *statusIconView;
@property (nonatomic, strong) UILabel *timerLabel;

@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, assign) BOOL isFloatingMode;
@property (nonatomic, strong) NSString *currentMode; 

+ (instancetype)sharedInstance;
- (void)expandIsland;
- (void)collapseIsland;
- (void)updateLayoutForCurrentDevice;
- (void)updateNowPlayingInfo;

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
        self.currentMode = @"Idle";

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

        self.statusIconView = [[UIImageView alloc] init];
        self.statusIconView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:self.statusIconView];

        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        [self addSubview:self.titleLabel];

        self.subtitleLabel = [[UILabel alloc] init];
        self.subtitleLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
        self.subtitleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
        [self addSubview:self.subtitleLabel];

        self.timerLabel = [[UILabel alloc] init];
        self.timerLabel.textColor = [UIColor systemOrangeColor];
        self.timerLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        [self addSubview:self.timerLabel];

        self.playPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.playPauseButton setImage:[UIImage systemImageNamed:@"pause.fill"] forState:UIControlStateNormal];
        [self.playPauseButton setTintColor:[UIColor whiteColor]];
        [self.playPauseButton addTarget:self action:@selector(togglePlayPause) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.playPauseButton];

        self.prevButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.prevButton setImage:[UIImage systemImageNamed:@"backward.fill"] forState:UIControlStateNormal];
        [self.prevButton setTintColor:[UIColor whiteColor]];
        [self.prevButton addTarget:self action:@selector(skipPrev) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.prevButton];

        self.nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.nextButton setImage:[UIImage systemImageNamed:@"forward.fill"] forState:UIControlStateNormal];
        [self.nextButton setTintColor:[UIColor whiteColor]];
        [self.nextButton addTarget:self action:@selector(skipNext) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.nextButton];

        [self updateLayoutForCurrentDevice];
        [self setupMediaRemoteNotifications];
    }
    return self;
}

- (void)updateLayoutForCurrentDevice {
    CGRect screenRect = [UIScreen mainScreen].bounds;
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    CGFloat screenWidth = UIInterfaceOrientationIsLandscape(orientation) ? MAX(screenRect.size.width, screenRect.size.height) : MIN(screenRect.size.width, screenRect.size.height);

    CGFloat islandWidth = 125.0; 
    CGFloat islandHeight = 36.0;
    CGFloat topMargin = 8.0;

    self.frame = CGRectMake((screenWidth - islandWidth) / 2, topMargin, islandWidth, islandHeight);
    self.layer.cornerRadius = islandHeight / 2.0;

    self.leadingImageView.frame = CGRectMake(7, 6, 24, 24);
    self.leadingImageView.layer.cornerRadius = 6;
    self.leadingImageView.alpha = 0.0;
    
    self.trailingImageView.frame = CGRectMake(islandWidth - 31, 6, 24, 24);
    self.trailingImageView.alpha = 0.0;

    self.statusIconView.alpha = 0.0;
    self.titleLabel.alpha = 0.0;
    self.subtitleLabel.alpha = 0.0;
    self.timerLabel.alpha = 0.0;
    self.playPauseButton.alpha = 0.0;
    self.prevButton.alpha = 0.0;
    self.nextButton.alpha = 0.0;
    
    if (![self.currentMode isEqualToString:@"Music"]) {
        self.currentMode = @"Idle";
    }
}

- (void)expandIsland {
    if (self.isExpanded) return;
    
    CGRect screenRect = [UIScreen mainScreen].bounds;
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    CGFloat screenWidth = UIInterfaceOrientationIsLandscape(orientation) ? MAX(screenRect.size.width, screenRect.size.height) : MIN(screenRect.size.width, screenRect.size.height);
    
    CGFloat expandedWidth = screenWidth - 32;
    CGFloat expandedHeight = 130.0;
    
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.72 initialSpringVelocity:0.7 options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut animations:^{
        self.frame = CGRectMake(16, 8, expandedWidth, expandedHeight);
        self.layer.cornerRadius = 32;
        
        if ([self.currentMode isEqualToString:@"Music"]) {
            self.leadingImageView.frame = CGRectMake(16, 16, 52, 52);
            self.leadingImageView.layer.cornerRadius = 10;
            self.leadingImageView.alpha = 1.0;
            
            self.titleLabel.frame = CGRectMake(80, 16, expandedWidth - 96, 20);
            self.titleLabel.alpha = 1.0;
            self.subtitleLabel.frame = CGRectMake(80, 38, expandedWidth - 96, 18);
            self.subtitleLabel.alpha = 1.0;
            
            CGFloat btnY = 80;
            CGFloat centerX = expandedWidth / 2;
            self.prevButton.frame = CGRectMake(centerX - 60, btnY, 30, 30);
            self.prevButton.alpha = 1.0;
            self.playPauseButton.frame = CGRectMake(centerX - 15, btnY, 30, 30);
            self.playPauseButton.alpha = 1.0;
            self.nextButton.frame = CGRectMake(centerX + 30, btnY, 30, 30);
            self.nextButton.alpha = 1.0;
        }
    } completion:^(BOOL finished) {
        self.isExpanded = YES;
    }];
}

- (void)collapseIsland {
    if (!self.isExpanded) return;
    
    [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.78 initialSpringVelocity:0.6 options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut animations:^{
        [self updateLayoutForCurrentDevice];
    } completion:^(BOOL finished) {
        self.isExpanded = NO;
    }];
}

- (void)handleTap {
    if (self.isFloatingMode) return;
    if (self.isExpanded) {
        [self collapseIsland];
    } else if ([self.currentMode isEqualToString:@"Music"]) {
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
    [UIView animateWithDuration:0.45 animations:^{
        if (self.isFloatingMode) {
            self.frame = CGRectMake(20, 80, 140, 65);
            self.layer.cornerRadius = 20;
        } else {
            [self updateLayoutForCurrentDevice];
        }
    }];
}

- (void)setupMediaRemoteNotifications {
    MRMediaRemoteRegisterForNowPlayingNotifications(dispatch_get_main_queue());
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNowPlayingInfo) name:@"kMRMediaRemoteNowPlayingInfoDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNowPlayingInfo) name:@"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification" object:nil];
    
    // Tự động quét trạng thái phát nhạc liên tục mỗi 1.5 giây
    [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(updateNowPlayingInfo) userInfo:nil repeats:YES];
}

- (void)updateNowPlayingInfo {
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
                    self.leadingImageView.image = artImage;
                }
                
                self.currentMode = @"Music";
                
                if (!self.isExpanded) {
                    self.trailingImageView.image = [UIImage systemImageNamed:@"waveform"];
                    self.trailingImageView.tintColor = [UIColor systemGreenColor];
                    [UIView animateWithDuration:0.3 animations:^{
                        self.trailingImageView.frame = CGRectMake(125 - 28, 6, 20, 24);
                        self.trailingImageView.alpha = 1.0;
                    }];
                }
            }
        }
    });
}

- (void)togglePlayPause { MRMediaRemoteSendCommand(0, nil); }
- (void)skipPrev { MRMediaRemoteSendCommand(4, nil); }
- (void)skipNext { MRMediaRemoteSendCommand(3, nil); }

@end

// ==========================================
// HOOKS HIỂN THỊ MÀN HÌNH KHÓA (iOS 14 - 15)
// ==========================================

static DIHPassThroughWindow *islandWindow = nil;

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!islandWindow) {
            CGRect screenRect = [UIScreen mainScreen].bounds;
            islandWindow = [[DIHPassThroughWindow alloc] initWithFrame:screenRect];
            
            // Ép mức cửa sổ vượt qua lớp bảo mật màn hình khóa
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
