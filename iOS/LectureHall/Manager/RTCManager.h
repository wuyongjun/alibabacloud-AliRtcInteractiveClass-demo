//
//  RTCManager.h
//  LectureHall
//
//  Created by alibaba on 2020/6/15.
//  Copyright © 2020 alibaba. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AliRTCSdk/AliRTCSdk.h>
NS_ASSUME_NONNULL_BEGIN

@interface RTCManager : NSObject


/**
* @brief 获取单例
* @return RTCManager 单例对象
*/
+ (RTCManager *) sharedManager;

/// 初始化RTC SDK
/// @param delegate 代理
- (RTCManager *)initializeSDKWithDelegate:(id<AliRtcEngineDelegate>)delegate;

/// 销毁RTCSDK
-(void)destroyEngine;


/**
* @brief 加入频道
* @param authInfo    认证信息，从App Server获取。
* @param name    任意用于显示的用户名称。不是User ID
* @param success    成功回调
* @param error 失败回调
*/
- (void)joinChannel:authInfo name:(NSString *)name success:(void(^)(void))success  error:(void(^)(NSInteger errCode))error;

/**
* @brief mute/unmute本地音频采集
* @param mute  YES表示本地音频采集空帧；NO表示恢复正常
* @note mute是指采集和发送静音帧。采集和编码模块仍然在工作
* @return 0表示成功放入队列，-1表示被拒绝
*/

- (int)muteLocalMic:(BOOL)mute;

/**
* @brief 是否将停止本地视频采集
* @param mute     YES表示停止视频采集；NO表示恢复正常
* @param track    需要停止采集的track
* @return 0表示Success 非0表示Failure
* @note 发送黑色的视频帧。本地预览也呈现黑色。采集，编码，发送模块仍然工作，
*       只是视频内容是黑色帧
*/

- (int)muteLocalCamera:(BOOL)mute forTrack:(AliRtcVideoTrack)track;

/**
* @brief 切换前后摄像头
* @return 0表示Success 非0表示Failure
* @note 只有iOS和android提供这个接口
*/
- (int)switchCamera;

/**
* @brief 为远端的视频设置窗口以及绘制参数
* @param canvas canvas包含了窗口以及渲染方式
* @param uid    User ID。从App server分配的唯一标示符
* @param track  需要设置的track
* @return 0表示Success 非0表示Failure
* @note 支持joinChannel之前和之后切换窗口。如果canvas为nil或者view为nil，则停止渲染相应的流
*       如果在播放过程中需要重新设置render mode，请保持canvas中其他成员变量不变，仅修改
*       renderMode
*       如果在播放过程中需要重新设置mirror mode，请保持canvas中其他成员变量不变，仅修改
*       mirrorMode
*/

- (int)setRemoteViewConfig:(AliVideoCanvas *)canvas uid:(NSString *)uid forTrack:(AliRtcVideoTrack)track;

/**
* @brief 为本地预览设置窗口以及绘制参数
* @param viewConfig 包含了窗口以及渲染方式
* @param track      must be AliVideoTrackCamera
* @return 0表示Success 非0表示Failure
* @note 支持joinChannel之前和之后切换窗口。如果viewConfig或者viewConfig中的view为nil，则停止渲染
*       如果在播放过程中需要重新设置render mode，请保持canvas中其他成员变量不变，仅修改
*       renderMode
*       如果在播放过程中需要重新设置mirror mode，请保持canvas中其他成员变量不变，仅修改
*       mirrorMode
*/

- (int)setLocalViewConfig:(AliVideoCanvas *)viewConfig forTrack:(AliRtcVideoTrack)track;

/**
* @brief 停止本地预览
* @return 0表示Success 非0表示Failure
* @note leaveChannel会自动停止本地预览
*       会自动关闭摄像头 (如果正在publish camera流，则不会关闭摄像头)
*/

- (int)stopPreview;

/**
* @brief 开始本地预览
* @return 0表示Success 非0表示Failure
* @note 如果没有设置view，则无法预览。可以在joinChannel之前就开启预览
*       会自动打开摄像头
*/

- (int)startPreview;


/**
 * @brief 设置是否拉取camera screen audio流
 * @param uid userId 从App server分配的唯一标示符。
 * @param master  是否优先拉取大流
 * @param enable  YES: 拉取; NO: 不拉取
 * @note 可以在joinChannel之前或者之后设置。如果已经订阅该用户的流，需要调用subscribe:(NSString *)uid onResult:才生效
 */

- (void)configRemoteTrack:(NSString *)uid preferMaster:(BOOL)master enable:(BOOL)enable;

/**
* @brief 手动拉视频和音频流
* @param uid        User ID。不允许为nil
* @param onResult   当subscribe执行结束后调用这个回调
* @note 如果需要手动选择拉取的流，调用configRemoteAudio, configRemoteCameraTrack,
*       configRemoteScreenTrack来设置。缺省是拉取audio和camera track
*       如果需要unsub所有的流，先通过configRemoteAudio, configRemoteCameraTrack,
*       configRemoteScreenTrack来清除设置，然后调用subscribe
*/

- (void)subscribe:(NSString *)uid onResult:(void (^)(NSString *uid, AliRtcVideoTrack vt, AliRtcAudioTrack at))onResult;

@end

NS_ASSUME_NONNULL_END
