//
//  MainController.m
//  LectureHall
//
//  Created by alibaba on 2020/5/22.
//  Copyright © 2020 alibaba. All rights reserved.
//

#import "MainController.h"
#import "RTCRemoteUserManager.h"
#import "CommonUtils.h"
#import "RTCRemoterUserCell.h"
#import "RTCRemoteUserModel.h"
#import "AppDelegate.h"
#import "AlertMsgController.h"
#import "NetworkManager.h"
#import <AliyunPlayer/AliyunPlayer.h>
#import "AppConfig.h"
#import "RTCManager.h"

@interface MainController ()<AliRtcEngineDelegate,AVPDelegate>

/**
 @brief SDK管理
 */
@property (nonatomic, strong) RTCManager *rtcManager;

/**
 @brief 远端用户管理
 */
@property(nonatomic, strong) RTCRemoteUserManager *remoteUserManager;

/**
 @brief 主屏视图
 */
@property (weak, nonatomic) IBOutlet UIView *videoView;
/**
@brief 按钮容器视图
*/
@property (weak, nonatomic) IBOutlet UIView *btnsView;
/**
@brief 退出按钮
*/
@property (nonatomic,strong) UIButton *exitBtn;
/**
@brief 静音按钮
*/
@property (nonatomic,weak) UIButton *muteBtn;
/**
@brief 相机按钮
*/
@property (nonatomic,weak) UIButton *cameraBtn;
/**
@brief 连麦&下麦按钮
*/
@property (nonatomic,weak) UIButton *joinBtn;
/**
@brief 翻转相机按钮
*/
@property (nonatomic,weak) UIButton *flipBtn;
/**
@brief 是否正在连麦
*/
@property (nonatomic, assign) BOOL isJoinChannel;
/**
@brief 播放器地址
*/
@property (nonatomic,copy) NSString *playUrl;
/**
@brief 播放器
*/
@property (nonatomic,strong) AliPlayer *player;
/**
@brief 定时器
*/
@property (nonatomic,strong) NSTimer *timer;
/**
@brief 屏幕按钮显示时间倒计时
*/
@property (nonatomic, assign) NSInteger countDown;
/**
@brief 缓冲时间
*/
@property (nonatomic,assign) NSInteger loadingTime;
/**
@brief 是否需要缓冲计时
*/
@property (nonatomic,assign) BOOL shouldStartLoadingCount;
/**
@brief 网络状态显示label
*/
@property (nonatomic,assign) UILabel *networkLabel;

/**
 @brief 自己的网络状态
 */
@property (nonatomic,assign) AliRtcNetworkQuality  selfNetworkQuality;

/**
 @brief 其他人的网络状态
 */
@property (nonatomic,assign) AliRtcNetworkQuality  otherNetworkQuality;

/**
 @brief 小屏collectionView
 */

@property (weak, nonatomic) IBOutlet UICollectionView *remoteUserView;

/**
@brief 主屏显示的用户
*/
@property(nonatomic,strong) RTCRemoteUserModel *remoteUsermodel;

/**
@brief 小屏幕数据源
*/
@property(nonatomic, strong) NSMutableArray *dataArr;
/**
@brief 本地相机预览canvas
*/
@property(nonatomic,strong) AliVideoCanvas *localCanvas;

@end

@implementation MainController


#pragma mark - lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self initUI];
    self.countDown = 15;
    //请求播放地址 初始化播放器
    [self joinLiveByPlayer:_authInfo];

    [self startTimer];
    
    [self addNotification];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self onFullScreen:nil];
}

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    AppDelegate * app = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if (app.isLandscape) {
        app.isLandscape = NO;
        [self setInterfaceOrientation:UIInterfaceOrientationPortrait];
    }
}

- (void)viewDidLayoutSubviews {
    CGFloat x = self.btnsView.center.x;
    CGFloat y = self.btnsView.center.y - 60;
    self.networkLabel.center = CGPointMake(x, y);
}
- (void)dealloc {
    [self destoryPlayer];
    NSLog(@"mainController destroyed");
        
}

#pragma mark - UI funcions

-(void)initUI{
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [backBtn setImage:[UIImage imageNamed:@"back"] forState:UIControlStateNormal];
    [backBtn setTitle:[@"教室编号:" stringByAppendingString:_authInfo.channel] forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
    [backBtn sizeToFit];
    
    UIBarButtonItem *leftItem = [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    self.navigationItem.leftBarButtonItem = leftItem;
    
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"share"] style:UIBarButtonItemStylePlain target:self action:@selector(share)];
    
    [self.remoteUserView registerClass:[RTCRemoterUserCell class] forCellWithReuseIdentifier:@"cell"];
    
    _remoteUserManager = [RTCRemoteUserManager shareManager];
    
    UILabel *label  = [[UILabel alloc] initWithFrame:CGRectMake(200, 100, 150, 40)];
    [self.view addSubview:label];
    self.networkLabel = label;
    self.networkLabel.font = [UIFont systemFontOfSize:18];
    self.networkLabel.textColor = [UIColor whiteColor];
    self.networkLabel.text = @"";
    self.networkLabel.textAlignment = NSTextAlignmentCenter;
    
}

-(void)buildBtns{
    //先清空一下
    while (self.btnsView.subviews.count) {
        [self.btnsView.subviews.lastObject removeFromSuperview];
    }
    
    NSArray *arr = @[
        @{@"img":@"unmute",@"selectedImg":@"mute_grey",@"title":@"静音",@"selectedtitle":@"取消静音"},
        @{@"img":@"camera",@"selectedImg":@"cameraclosed",@"title":@"摄像头",@"selectedtitle":@"开启摄像头"},
        @{@"img":@"voice",@"selectedImg":@"voice",@"title":@"连麦",@"selectedtitle":@"下麦"},
        @{@"img":@"rotate",@"selectedImg":@"rotate",@"title":@"翻转",@"selectedtitle":@"翻转"},
        @{@"img":@"exit",@"selectedImg":@"exit",@"title":@"退出课程",@"selectedtitle":@"退出课程"},
    ];
    
    AppDelegate * app = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    int size = app.isLandscape?5:4;
    int paddingLeft = (CGRectGetWidth(self.btnsView.frame) - (60*size+(28*size-1)))/2;
    for (int i=0; i<size; i++) {
        [self buildBtnItem:arr[i] AtIdx:i padding:paddingLeft];
    }
}

-(void)buildBtnItem:(NSDictionary*)item AtIdx:(int)idx padding:(int)padding{
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(idx*(60+28)+padding, 0, 60, 68)];
    btn.tag = idx;
    if (idx == 0) {
        self.muteBtn = btn;
        self.muteBtn.alpha = 0.5;
    }
    if (idx == 1) {
        self.cameraBtn = btn;
        self.cameraBtn.alpha = 0.5;
    }
    if (idx == 2) {
        self.joinBtn = btn;
    }
    if (idx == 3) {
        self.flipBtn = btn;
        self.flipBtn.alpha = 0.5;
    }
    
    
    [btn setImage:[UIImage imageNamed:item[@"img"]] forState:UIControlStateNormal];
    [btn setImage:[UIImage imageNamed:item[@"selectedImg"]] forState:UIControlStateSelected];
    [btn setTitle:item[@"title"] forState:UIControlStateNormal];
    [btn setTitle:item[@"selectedtitle"] forState:UIControlStateSelected];
    btn.titleLabel.font = [UIFont fontWithName:@"PingFangSC-Regular" size:12];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    
    [btn setTitleEdgeInsets:UIEdgeInsetsMake(0, -50, -60, 0)];
    
    [btn setImageEdgeInsets:UIEdgeInsetsMake(-20, 6, 0, 0)];

   
    [self.btnsView addSubview:btn];
    
}

-(void)canvasSettings{
    AliRenderView *curView = nil;
    if(_remoteUsermodel){
        [_remoteUsermodel.view setFrame:self.videoView.bounds];
        [_remoteUsermodel.view.subviews.firstObject setFrame:self.videoView.bounds];
        [self.videoView addSubview:_remoteUsermodel.view];
        curView = _remoteUsermodel.view;
        curView.tag = 100;
    }

    int delTag = 100;
    if(self.videoView.subviews.count>1){
        for (UIView *view in self.videoView.subviews) {
            if(view!=curView && view.tag ==delTag){
                [view removeFromSuperview];
            }
        }
    }
}
#pragma mark - notification
- (void)addNotification {
    // app启动或者app从后台进入前台都会调用这个方法
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    // app从后台进入前台都会调用这个方法
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationBecomeActive) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    // 添加检测app进入后台的观察者
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationEnterBackground)
                                                 name: UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)applicationBecomeActive {
    
    if (self.player) {
        [self.player prepare];
    }
}

- (void)applicationEnterBackground {
    if (self.player) {
        [self.player stop];
    }
}

#pragma mark - timer function

- (void)startTimer {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(count:) userInfo:nil repeats:YES];
    [self.timer fire];
}
- (void)count:(NSTimer *) timer {
    self.countDown--;
    if (self.shouldStartLoadingCount) {
        self.loadingTime++;
        if (self.loadingTime == 30) {
            [self LiveTimeout];
        }
    }
}
- (void)destoryTimer {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.countDown = self.countDown <= 0 ? 15:0;
}

#pragma mark - button actions

- (void)share{
    NSString *shareurl =[NSString stringWithFormat:@"%@index.html#/studentOnly?channel=%@&role=1",shareBaseUrl,_authInfo.channel];
    
    //复制到剪切板
    UIPasteboard *board = [UIPasteboard generalPasteboard];
    board.string = shareurl;
    
    [CommonUtils showHud:@"链接已复制" inView:self.view];
}

-(void)back{
    
    [self exitChanel:nil];
}

-(void)exitChanel:(id)sender{
    AlertMsgController *alert =  [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"AlertMsgController"];
    alert.modalPresentationStyle = UIModalPresentationOverFullScreen;
    alert.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    __weak typeof(self) weakSelf = self;
    alert.submitblock = ^{
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [weakSelf removeRTCSDK];
            [weakSelf destoryTimer];
        });
        
     
        [weakSelf.navigationController popViewControllerAnimated:YES];
    };
    [self presentViewController:alert animated:YES completion:nil];
}


- (void)onBtnClick:(UIButton*)btn {
    switch (btn.tag) {
        //静音
        case 0:
            if (self.isJoinChannel) {
                [btn setSelected:!btn.isSelected];
                [self.rtcManager muteLocalMic:btn.isSelected];
                [CommonUtils showHud:[NSString stringWithFormat:@"已%@静音",btn.isSelected?@"开启":@"关闭"] inView:self.view];
            }else{
                [CommonUtils showHud:@"请在连麦后使用" inView:self.view];
            }
            break;
        //摄像头
        case 1:
            if (self.isJoinChannel) {
                [btn setSelected:!btn.isSelected];
                int tag = 300;
                if (btn.isSelected) {
                    UIView *view = [[UIView alloc] initWithFrame:self.localCanvas.view.bounds];
                    view.backgroundColor = [UIColor blackColor];
                    view.tag = tag;
                    [self.localCanvas.view addSubview:view];
                } else {
                    for (UIView *view in self.localCanvas.view.subviews) {
                        if (view.tag == tag) {
                            [view removeFromSuperview];
                        }
                    }
                }
                [self.rtcManager muteLocalCamera:btn.isSelected forTrack:AliRtcVideoTrackCamera];
                [CommonUtils showHud:[NSString stringWithFormat:@"已%@摄像头",btn.isSelected?@"关闭":@"开启"] inView:self.view];
            }else{
                [CommonUtils showHud:@"请在连麦后使用" inView:self.view];
            }
            break;
        //连麦
        case 2:
            if (!btn.isSelected) {
                [self joinRTC:_authInfo];
                
            }else{
                [self joinLiveByPlayer:_authInfo];
                self.remoteUserView.hidden = YES;
                self.isJoinChannel = NO;
                [self canvasSettings];
                [self.remoteUserView reloadData];
                [CommonUtils showHud:@"听众模式" inView:self.view];
            }
            break;
        //翻转
        case 3:
            if (self.isJoinChannel) {
                [btn setSelected:!btn.isSelected];
                [self.rtcManager switchCamera];
                [CommonUtils showHud:@"已切换摄像头" inView:self.view];
            }else{
                [CommonUtils showHud:@"请在连麦后使用" inView:self.view];
            }
            break;
        //退出课程
        case 4:
            [self exitChanel:nil];
            break;
            
        default:
            break;
    }
}

- (IBAction)onFullScreen:(id)sender {
    [self swithOrientation:UIInterfaceOrientationLandscapeRight];
}

#pragma mark - initializeSDK
/**
 @brief 初始化SDK
 */
- (void)initializeSDK{
    [self removeRTCSDK];
    self.rtcManager = [[RTCManager sharedManager] initializeSDKWithDelegate:self];
}

-(void)removeRTCSDK{
    _localCanvas = nil;
    _remoteUsermodel = nil;
    [self.remoteUserManager removeAllUser];
    [_dataArr removeAllObjects];
    self.isJoinChannel = NO;
    [self.rtcManager  destroyEngine];
}

- (void)joinRTC:(AliRtcAuthInfo*)authInfo{
    [self destoryPlayer];
    self.remoteUserView.hidden = NO;
    [self initializeSDK];
    self.isJoinChannel = NO;
    
    __weak typeof(self) weakSelf = self;
    [NetworkManager GET:@"describeChannelUsers" parameters:@{@"channelId":_authInfo.channel} completionHandler:^(NSString * _Nullable errString, NSDictionary * _Nullable resultDic) {
        NSInteger num = [resultDic[@"commTotalNum"] integerValue];
        if (num > 0) {
            [self.rtcManager joinChannel:authInfo name:weakSelf.userName success:^{
                weakSelf.isJoinChannel = YES;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [CommonUtils showHud:@"连麦模式" inView:self.view];
                    
                });
            } error:^(NSInteger errCode) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    weakSelf.isJoinChannel = NO;
                    [CommonUtils showHud:@"连麦失败" inView:self.view];
                });
            }];
        }else{
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.isJoinChannel = NO;
                [CommonUtils showHud:@"连麦失败,老师已离开" inView:self.view];
            });
        }
    }];
    
    [self canvasSettings];
    
    //防止屏幕锁定
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}



/// 旁路直播模式观看
/// @param authInfo  授权信息
- (void)joinLiveByPlayer:(AliRtcAuthInfo*)authInfo {
    self.remoteUserView.hidden = YES;
    self.networkLabel.text =@"";
    [self removeRTCSDK];
    [NetworkManager GET:@"getPlayUrl" parameters:@{@"channelId":authInfo.channel,@"userId":authInfo.user_id} completionHandler:^(NSString * _Nullable errString, NSDictionary * _Nullable resultDic) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.playUrl = resultDic[@"playUrl"][@"flv"];
            AVPUrlSource *playSource = [[AVPUrlSource alloc] urlWithString: self.playUrl];
            AliPlayer *player = [[AliPlayer alloc] init];
            self.player = player;
            [player setUrlSource:playSource];
            player.autoPlay = YES;
            player.loop = YES;
            player.delegate = self;
            player.playerView = self.videoView;
            player.scalingMode = AVP_SCALINGMODE_SCALEASPECTFIT;
            [player prepare];
        });
    }];
    
}

- (void)destoryPlayer {
    if (self.player) {
           [self.player stop];
           [self.player destroy];
           self.player = nil;
       }
}

#pragma mark - orientaiton
- (void)swithOrientation:(UIInterfaceOrientation)orientation{
    AppDelegate * app = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if (orientation==UIInterfaceOrientationLandscapeRight) {
        app.isLandscape = YES;
    }else{
        app.isLandscape = NO;
    }
    [self setInterfaceOrientation:orientation];
    //进来直接横屏，需处理一下
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self buildBtns];
        [self canvasSettings];
    });
}

//强制转屏
- (void)setInterfaceOrientation:(UIInterfaceOrientation)orientation{

    if ([[UIDevice currentDevice] respondsToSelector:@selector(setOrientation:)]) {
        SEL selector  = NSSelectorFromString(@"setOrientation:");
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[UIDevice instanceMethodSignatureForSelector:selector]];
        [invocation setSelector:selector];
        [invocation setTarget:[UIDevice currentDevice]];
        // 从2开始是因为前两个参数已经被selector和target占用
        [invocation setArgument:&orientation atIndex:2];
        [invocation invoke];
    }
}

- (BOOL)shouldAutorotate{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations{
    return UIInterfaceOrientationMaskLandscapeRight;
}


#pragma mark - alert function

- (void) connectionTimeout {
     __weak typeof(self) weakSelf = self;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"体验时间已到"
                                                                             message:@"您的本次体验时长已满\n如需再次体验，请重新创建通话"
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *confirm = [UIAlertAction actionWithTitle:@"我知道了" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
                 [weakSelf removeRTCSDK];
                 [weakSelf destoryTimer];
             });
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.navigationController popViewControllerAnimated:YES];
        });
        
     
    }];
    [alertController addAction:confirm];
    [self.navigationController presentViewController:alertController animated:YES completion:nil];
    
}

- (void) LiveTimeout {
     __weak typeof(self) weakSelf = self;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示"
                                                                             message:@"老师已离开房间"
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *confirm = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
                 [weakSelf removeRTCSDK];
                 [weakSelf destoryTimer];
             });
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.navigationController popViewControllerAnimated:YES];
        });
    }];
    [alertController addAction:confirm];
    [self.navigationController presentViewController:alertController animated:YES completion:nil];
    
}

- (void)sdkError:(NSString *)errorMsg {
    __weak typeof(self) weakSelf = self;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"错误提示"
                                                                             message:errorMsg
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *confirm = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
                 [weakSelf removeRTCSDK];
                 [weakSelf destoryTimer];
             });
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.navigationController popViewControllerAnimated:YES];
            
        });
    }];
    [alertController addAction:confirm];
    [self.navigationController presentViewController:alertController animated:YES completion:nil];
}




#pragma mark - aliplayer delegate


- (void)onPlayerEvent:(AliPlayer *)player eventType:(AVPEventType)eventType {
    if (eventType == AVPEventLoadingStart) {
        //开始缓冲计时
        self.shouldStartLoadingCount = YES;
    }else if(eventType == AVPEventLoadingEnd) {
        //结束计时
        self.shouldStartLoadingCount = NO;
        self.loadingTime = 0;
    }
}

- (void)onError:(AliPlayer *)player errorModel:(AVPErrorModel *)errorModel {
    NSLog(@"%@",errorModel);
}


#pragma mark - alirtcengine delegate


- (void)onSubscribeChangedNotify:(NSString *)uid audioTrack:(AliRtcAudioTrack)audioTrack videoTrack:(AliRtcVideoTrack)videoTrack {
    
    //收到远端订阅回调
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.remoteUserManager updateRemoteUser:uid forTrack:videoTrack];
        
        if (videoTrack == AliRtcVideoTrackCamera) {
            AliVideoCanvas *canvas = [[AliVideoCanvas alloc] init];
            canvas.renderMode = AliRtcRenderModeFill;
            canvas.view = [self.remoteUserManager cameraView:uid];
            [self.rtcManager setRemoteViewConfig:canvas uid:uid forTrack:AliRtcVideoTrackCamera];
        }else if (videoTrack == AliRtcVideoTrackScreen) {
            AliVideoCanvas *canvas2 = [[AliVideoCanvas alloc] init];
            canvas2.renderMode = AliRtcRenderModeFill;
            canvas2.view = [self.remoteUserManager screenView:uid];
            [self.rtcManager setRemoteViewConfig:canvas2 uid:uid forTrack:AliRtcVideoTrackScreen];
        }else if (videoTrack == AliRtcVideoTrackBoth) {
            AliVideoCanvas *canvas2 = [[AliVideoCanvas alloc] init];
            canvas2.renderMode = AliRtcRenderModeFill;
            canvas2.view = [self.remoteUserManager screenView:uid];
            [self.rtcManager setRemoteViewConfig:canvas2 uid:uid forTrack:AliRtcVideoTrackScreen];
        }
        
        if([self.remoteUserManager allOnlineUsers].count>0){
            //如果remoteUserMode 不存在 或者 不在数组列表中 默认复制第一个用户 放在主屏显示
            if (!self.remoteUsermodel ||![[self.remoteUserManager allOnlineUsers] containsObject:self.remoteUsermodel]) {
                  self.remoteUsermodel =  [[self.remoteUserManager allOnlineUsers] firstObject];
            }
            
            //如果是屏幕共享 则主屏显示屏幕共享画面 遍历查找是否有AliRtcVideoTrackScreen
            for (RTCRemoteUserModel *model in [self.remoteUserManager allOnlineUsers]) {
                if (model.track == AliRtcVideoTrackScreen) {
                    self.remoteUsermodel = model;
                    break;
                }
            }
             [self canvasSettings];
        }
       
        [self loadData];
    });
}

- (void)onRemoteTrackAvailableNotify:(NSString *)uid audioTrack:(AliRtcAudioTrack)audioTrack videoTrack:(AliRtcVideoTrack)videoTrack {
    //在这里订阅流 数组里有对象 订阅小流 第一个对象订阅大流
    if (audioTrack !=AliRtcAudioTrackNo && videoTrack != AliRtcVideoTrackNo) {
        [self.rtcManager configRemoteTrack:uid preferMaster:self.dataArr.count enable:YES];
        [self.rtcManager subscribe:uid onResult:^(NSString * _Nonnull uid, AliRtcVideoTrack vt, AliRtcAudioTrack at) {
            
        }];
    }
}

- (void)onRemoteUserOffLineNotify:(NSString *)uid;{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.remoteUserManager remoteUserOffLine:uid];
        [self loadData];
        if([self->_remoteUsermodel.uid isEqualToString:uid]) {
              //点击自己头像
              [self collectionView:self.remoteUserView didSelectItemAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        }
    });
}

- (void)onBye:(int)code {
    NSLog(@"服务器提出频道");
    dispatch_async(dispatch_get_main_queue(), ^{
      [self connectionTimeout];
    });
}



- (void)onOccurError:(int)error {
    NSString *errMsg = @"";
     if (error == AliRtcErrSdkInvalidState) {
         errMsg = @"sdk 状态错误";
    }else if (error == AliRtcErrIceConnectionHeartbeatTimeout) {
         errMsg = @"信令心跳超时";
    }else if (error == AliRtcErrSessionRemoved) {
         errMsg = @"Session 已经被移除，Session 不存在";
    }
    
    if (errMsg.length) {
        [self sdkError:errMsg];
    }
}

- (void)onPublishResult:(int)result isPublished:(BOOL)isPublished {
    if (result > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [CommonUtils showHud:@"推流失败" inView:self.view];
        });
      
    }
}

- (void)onNetworkQualityChanged:(NSString *)uid
  upNetworkQuality:(AliRtcNetworkQuality)upQuality
             downNetworkQuality:(AliRtcNetworkQuality)downQuality {
    
        if([uid isEqualToString:@""] || [uid isEqualToString:_authInfo.user_id]||[uid isEqualToString:@"0"]) {
            //自己的网络状态
            self.selfNetworkQuality = upQuality;
        } else {
             self.otherNetworkQuality = upQuality;
        }
}
#pragma mark - uicollectionview delegate & datasource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _dataArr.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    RTCRemoterUserCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    RTCRemoteUserModel *model =  _dataArr[indexPath.row];
    AliRenderView *view = model.view;
    [cell updateUserRenderview:view];
    
    if ([model.uid isEqualToString:@"me"]) {
            [self.rtcManager startPreview];
    }
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    RTCRemoteUserModel *model =  _dataArr[indexPath.row];
    
  
    
    
    //remoteUserModel 订阅小流
    //不能是自己
    NSString *uid = self.remoteUsermodel.uid;
    if (uid.length > 0 && ![uid isEqualToString:@"me"]) {
        [self.rtcManager configRemoteTrack:self.remoteUsermodel.uid preferMaster:NO enable:YES];
        [self.rtcManager subscribe:self.remoteUsermodel.uid onResult:^(NSString * _Nonnull uid, AliRtcVideoTrack vt, AliRtcAudioTrack at) {
            
        }];
    }
    //点击的对象订阅大流
    self.remoteUsermodel = model;
    
    [self.rtcManager configRemoteTrack:model.uid preferMaster:YES enable:YES];
    [self.rtcManager subscribe:model.uid onResult:^(NSString * _Nonnull uid, AliRtcVideoTrack vt, AliRtcAudioTrack at) {
    }];
         
    [self canvasSettings];
    [self loadData];
 
}

- (void)loadData{
    _dataArr = @[].mutableCopy;
    
    RTCRemoteUserModel *model = [[RTCRemoteUserModel alloc] init];
    model.uid   = @"me";
    model.track = AliRtcVideoTrackCamera;
    model.view  = self.localCanvas.view;
    [_dataArr addObject:model];
    
    [_dataArr addObjectsFromArray:[self.remoteUserManager allOnlineUsers]];
    
    for (int i=0;i<_dataArr.count;i++) {
        RTCRemoteUserModel *item = [_dataArr objectAtIndex:i];
        if ([item.uid isEqualToString:self.remoteUsermodel.uid]) {
            [_dataArr removeObjectAtIndex:i];
            i--;
        }
    }
    
    [self.remoteUserView reloadData];
}

#pragma mark - setter & getters
- (UIButton *)exitBtn{
    if (!_exitBtn) {
        _exitBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 58, 27)];
       [_exitBtn setTitle:@" 退出课程 " forState:UIControlStateNormal];
       [_exitBtn addTarget:self action:@selector(exitChanel:) forControlEvents:UIControlEventTouchUpInside];
       [_exitBtn setBackgroundImage:[CommonUtils imageWithColor:[CommonUtils colorWithHex:0xFC4448]] forState:UIControlStateNormal];
       _exitBtn.titleLabel.font = [UIFont fontWithName:@"PingFangSC-Regular" size:13];
       _exitBtn.layer.cornerRadius = 2;
       _exitBtn.layer.masksToBounds = YES;
    }
    return _exitBtn;;
}

- (AliVideoCanvas *)localCanvas{
    if (!_localCanvas) {
        _localCanvas = [[AliVideoCanvas alloc] init];
        _localCanvas.renderMode = AliRtcRenderModeFill;
        _localCanvas.view = [[AliRenderView alloc] init];
        [self.rtcManager setLocalViewConfig:_localCanvas forTrack:AliRtcVideoTrackCamera];
    }
    return _localCanvas;
}


- (void)setCountDown:(NSInteger)countDown {
    _countDown = countDown;
     self.btnsView.hidden = countDown <= 0;
     self.navigationController.navigationBar.hidden =  countDown <= 0;
  
}

- (void)setSelfNetworkQuality:(AliRtcNetworkQuality)selfNetworkQuality {
    if (_selfNetworkQuality != selfNetworkQuality) {
        _selfNetworkQuality = selfNetworkQuality;
        
        //更新Label
        dispatch_async(dispatch_get_main_queue(), ^{
            if (selfNetworkQuality >= AlivcRtcNetworkQualityBad) {
                self.networkLabel.text = @"当前网络不佳";
            }else{
                self.networkLabel.text = @"";
            }
        });
    }
    
}

- (void)setOtherNetworkQuality:(AliRtcNetworkQuality)otherNetworkQuality {
    if (_otherNetworkQuality != otherNetworkQuality) {
        _otherNetworkQuality = otherNetworkQuality;
        //更新Label
        dispatch_async(dispatch_get_main_queue(), ^{
            if (otherNetworkQuality >= AlivcRtcNetworkQualityBad) {
                 self.networkLabel.text = @"对方网络不佳";
            }else{
                 self.networkLabel.text = @"";
            }
        });
    }
}

- (void)setIsJoinChannel:(BOOL)isJoinChannel {
    _isJoinChannel = isJoinChannel;
     __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (weakSelf.isJoinChannel) {
            weakSelf.muteBtn.alpha = 1;
            weakSelf.cameraBtn.alpha = 1;
            weakSelf.flipBtn.alpha = 1;
            weakSelf.joinBtn.selected = YES;
        }else{
            weakSelf.joinBtn.selected = NO;
            weakSelf.muteBtn.selected = NO;
            weakSelf.cameraBtn.selected = NO;
            weakSelf.flipBtn.selected = NO;
            weakSelf.cameraBtn.alpha = 0.5;
            weakSelf.muteBtn.alpha = 0.5;
            weakSelf.flipBtn.alpha = 0.5;
        }
    });
}
@end
