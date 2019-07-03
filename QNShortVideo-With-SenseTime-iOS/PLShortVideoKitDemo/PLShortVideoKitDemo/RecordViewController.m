//
//  RecordViewController.m
//  PLShortVideoKitDemo
//
//  Created by suntongmian on 17/3/1.
//  Copyright © 2017年 Pili Engineering, Qiniu Inc. All rights reserved.
//

#import "RecordViewController.h"
#import "PLShortVideoKit/PLShortVideoKit.h"
#import "PLSProgressBar.h"
#import "PLSDeleteButton.h"
#import "EditViewController.h"
#import <Photos/Photos.h>
#import "PhotoAlbumViewController.h"
#import "PLSEditVideoCell.h"
#import "PLSFilterGroup.h"
#import "PLSViewRecorderManager.h"
#import "PLSRateButtonView.h"
#import "PLScreenRecorderManager.h"
#import <Masonry.h>

/***************************** senseTime 相关导入 start ******************************/

// senseTime 需导入的头文件
#import "st_mobile_sticker.h"           //贴纸
#import "st_mobile_beautify.h"          //美化
#import "st_mobile_license.h"           //鉴权操作
#import "st_mobile_face_attribute.h"    //人脸属性检测
#import "st_mobile_filter.h"            //滤镜
#import "st_mobile_object.h"            //通⽤用物体跟踪
#import "st_mobile_animal.h"
#import "st_mobile_avatar.h"

#import "SenseArSourceService.h"        // AR

// senseTime 系统文件导入
#import <CommonCrypto/CommonDigest.h>   //授权 getSHA1StringWithData 使用到
#import <OpenGLES/ES2/glext.h>
#import <CoreMotion/CoreMotion.h>

// senseTime UI 界面类导入
#import "EffectsCollectionView.h"
#import "EffectsCollectionViewCell.h"
#import "STBeautySlider.h"
#import "STCollectionView.h"
#import "STCommonObjectContainerView.h"
#import "STCustomMemoryCache.h"
#import "STEffectsAudioPlayer.h"
#import "STFilterView.h"
#import "STParamUtil.h"
#import "STScrollTitleView.h"
#import "STTriggerView.h"
#import "STViewButton.h"

#define TIMELOG(key) double key = CFAbsoluteTimeGetCurrent();
#define TIMEPRINT(key , dsc) printf("%s\t%.1f ms\n" , dsc , (CFAbsoluteTimeGetCurrent() - key) * 1000);

#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height
#define STEFFECT_HEIGHT 210

#define POINT_KEY @"POINT_KEY"
#define POINTS_KEY @"POINTS_KEY"
#define RECT_KEY @"RECT_KEY"

typedef NS_ENUM(NSInteger, STViewTag) {
    STViewTagSpecialEffectsBtn = 10000,
    STViewTagBeautyBtn,
};

@protocol STEffectsMessageDelegate <NSObject>
- (void)loadSound:(NSData *)soundData name:(NSString *)strName;
- (void)playSound:(NSString *)strName loop:(int)iLoop;
- (void)pauseSound:(NSString *)strName;
- (void)resumeSound:(NSString *)strName;
- (void)stopSound:(NSString *)strName;
- (void)unloadSound:(NSString *)strName;
@end

@interface STEffectsMessageManager : NSObject
@property (nonatomic, readwrite, weak) id<STEffectsMessageDelegate> delegate;
@end

@implementation STEffectsMessageManager
@end

STEffectsMessageManager *messageManager = nil;
/***************************** senseTime 相关导入 end ******************************/

#define AlertViewShow(msg) [[[UIAlertView alloc] initWithTitle:@"warning" message:[NSString stringWithFormat:@"%@", msg] delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil] show]

#define PLS_CLOSE_CONTROLLER_ALERTVIEW_TAG 10001
#define PLS_SCREEN_WIDTH CGRectGetWidth([UIScreen mainScreen].bounds)
#define PLS_SCREEN_HEIGHT CGRectGetHeight([UIScreen mainScreen].bounds)
#define PLS_RGBCOLOR(r,g,b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]
#define PLS_RGBACOLOR(r,g,b,a) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:(a)]

#define PLS_BaseToolboxView_HEIGHT 64
#define PLS_SCREEN_WIDTH CGRectGetWidth([UIScreen mainScreen].bounds)
#define PLS_SCREEN_HEIGHT CGRectGetHeight([UIScreen mainScreen].bounds)

@interface RecordViewController ()
<
PLShortVideoRecorderDelegate,
UICollectionViewDelegate,
UICollectionViewDataSource,
UICollectionViewDelegateFlowLayout,
PLSViewRecorderManagerDelegate,
PLSRateButtonViewDelegate,
PLScreenRecorderManagerDelegate,

// senseTime 相关代理
STCommonObjectContainerViewDelegate,
STViewButtonDelegate,
STBeautySliderDelegate,
STEffectsMessageDelegate,
STEffectsAudioPlayerDelegate
>

// senseTime 相关属性
{
    st_handle_t _hSticker;  // sticker句柄
    st_handle_t _hDetector; // detector句柄
    st_handle_t _hBeautify; // beautify句柄
    st_handle_t _hAttribute;// attribute句柄
    st_handle_t _hFilter;   // filter句柄
    st_handle_t _hTracker;  // 通用物体跟踪句柄
    st_handle_t _animalHandle; //猫脸
#if TEST_AVATAR_EXPRESSION
    st_handle_t _avatarHandle; //avatar expression
#endif
    
    st_mobile_animal_face_t *_detectResult1;
    
    st_rect_t _rect;  // 通用物体位置
    float _result_score; //通用物体置信度

    CVOpenGLESTextureCacheRef _cvTextureCache;
    
    CVOpenGLESTextureRef _cvTextureOrigin;
    CVOpenGLESTextureRef _cvTextureBeautify;
    CVOpenGLESTextureRef _cvTextureSticker;
    CVOpenGLESTextureRef _cvTextureFilter;
    
    CVPixelBufferRef _cvBeautifyBuffer;
    CVPixelBufferRef _cvStickerBuffer;
    CVPixelBufferRef _cvFilterBuffer;
    
    GLuint _textureOriginInput;
    GLuint _textureBeautifyOutput;
    GLuint _textureStickerOutput;
    GLuint _textureFilterOutput;
    
    st_mobile_human_action_t _detectResult;
}

@property (strong, nonatomic) PLSVideoConfiguration *videoConfiguration;
@property (strong, nonatomic) PLSAudioConfiguration *audioConfiguration;
@property (strong, nonatomic) PLShortVideoRecorder *shortVideoRecorder;
@property (strong, nonatomic) PLSViewRecorderManager *viewRecorderManager;
@property (strong, nonatomic) PLScreenRecorderManager *screenRecorderManager;
@property (strong, nonatomic) PLSProgressBar *progressBar;
@property (strong, nonatomic) UIButton *recordButton;
@property (strong, nonatomic) UIButton *viewRecordButton;
@property (strong, nonatomic) PLSDeleteButton *deleteButton;
@property (strong, nonatomic) UIButton *endButton;
@property (strong, nonatomic) PLSRateButtonView *rateButtonView;
@property (strong, nonatomic) NSArray *titleArray;
@property (assign, nonatomic) NSInteger titleIndex;

@property (strong, nonatomic) UIView *baseToolboxView;
@property (strong, nonatomic) UIView *recordToolboxView;
@property (strong, nonatomic) UIImageView *indicator;
@property (strong, nonatomic) UIButton *squareRecordButton;
@property (strong, nonatomic) UILabel *durationLabel;
@property (strong, nonatomic) UIAlertView *alertView;

@property (strong, nonatomic) UIView *importMovieView;
@property (strong, nonatomic) UIButton *importMovieButton;

@property (strong, nonatomic) UIScrollView *rightScrollView;

// 录制的视频文件的存储路径设置
@property (strong, nonatomic) UIButton *filePathButton;
@property (assign, nonatomic) BOOL useSDKInternalPath;

// 录制时是否使用滤镜
@property (assign, nonatomic) BOOL isUseFilterWhenRecording;

// 所有滤镜
@property (strong, nonatomic) PLSFilterGroup *filterGroup;
// 展示所有滤镜的集合视图
@property (strong, nonatomic) UICollectionView *editVideoCollectionView;
@property (strong, nonatomic) NSMutableArray<NSDictionary *> *filtersArray;
// 切换滤镜的时候，为了更好的用户体验，添加以下属性来做切换动画
@property (nonatomic, assign) BOOL isPanning;
@property (nonatomic, assign) BOOL isLeftToRight;
@property (nonatomic, assign) BOOL isNeedChangeFilter;
@property (nonatomic, weak) PLSFilter *leftFilter;
@property (nonatomic, weak) PLSFilter *rightFilter;
@property (nonatomic, assign) float leftPercent;

@property (strong, nonatomic) UIButton *draftButton;
@property (strong, nonatomic) NSURL *URL;

@property (strong, nonatomic) UIButton *musicButton;
@property (strong, nonatomic) UIActivityIndicatorView *activityIndicatorView;

@property (strong, nonatomic) UIButton *monitorButton;
// 实时截图按钮
@property (strong, nonatomic) UIButton *snapshotButton;
// 帧率切换按钮
@property (strong, nonatomic) UIButton *frameRateButton;

// 录制前是否开启自动检测设备方向调整视频拍摄的角度（竖屏、横屏）
@property (assign, nonatomic) BOOL isUseAutoCheckDeviceOrientationBeforeRecording;

// 辅助隐藏音乐选取和滤镜选取 view 的 buttom
@property (nonatomic, strong) UIButton *dismissButton;

/***************************** senseTime 相关属性 start ******************************/
@property (nonatomic, readwrite, strong) STViewButton *specialEffectsBtn; // 特效按钮
@property (nonatomic, readwrite, strong) STViewButton *beautyBtn;         // 美颜按钮
@property (nonatomic, readwrite, assign) BOOL specialEffectsContainerViewIsShow;
@property (nonatomic, readwrite, assign) BOOL beautyContainerViewIsShow;

@property (nonatomic, readwrite, strong) UIView *specialEffectsContainerView;
@property (nonatomic, readwrite, strong) UIView *beautyContainerView;
@property (nonatomic, readwrite, strong) UIView *filterCategoryView;
@property (nonatomic, readwrite, strong) UIView *filterStrengthView;
@property (nonatomic, readwrite, strong) UIImageView *noneStickerImageView;

@property (nonatomic, readwrite, strong) STCommonObjectContainerView *commonObjectContainerView;
@property (nonatomic, readwrite, strong) STScrollTitleView *scrollTitleView;
@property (nonatomic, readwrite, strong) STCollectionView *objectTrackCollectionView;
@property (nonatomic, readwrite, strong) STFilterCollectionView *filterCollectionView;
@property (nonatomic, readwrite, strong) STFilterView *filterView;

@property (nonatomic, strong) STScrollTitleView *beautyScrollTitleViewNew;
@property (nonatomic, strong) STTriggerView *triggerView;
@property (nonatomic, strong) STNewBeautyCollectionView *beautyCollectionView;
@property (nonatomic, strong) EffectsCollectionView *effectsList;

@property (nonatomic, strong) UILabel *lblFilterStrength;
@property (nonatomic, strong) UIButton *resetBtn;

@property (nonatomic, strong) NSArray *arrCurrentModels;
@property (nonatomic, strong) EffectsCollectionViewCellModel *prepareModel;
@property (nonatomic, readwrite, strong) NSArray *arrObjectTrackers;

@property (nonatomic, assign) STEffectsType curEffectStickerType;
@property (nonatomic, assign) STEffectsType curEffectBeautyType;
@property (nonatomic, assign) STBeautyType curBeautyBeautyType;
@property (nonatomic, strong) STBeautySlider *beautySlider;

@property (nonatomic, strong) STCustomMemoryCache *thumbnailCache;
@property (nonatomic, strong) STCustomMemoryCache *effectsDataSource;
@property (nonatomic, strong) NSFileManager *fManager;

@property (nonatomic, strong) NSArray<STNewBeautyCollectionViewModel *> *microSurgeryModels;
@property (nonatomic, strong) NSArray<STNewBeautyCollectionViewModel *> *baseBeautyModels;
@property (nonatomic, strong) NSArray<STNewBeautyCollectionViewModel *> *beautyShapeModels;
@property (nonatomic, strong) NSArray<STNewBeautyCollectionViewModel *> *adjustModels;

@property (nonatomic, readwrite, strong) UIView *beautyShapeView;
@property (nonatomic, readwrite, strong) UIView *beautyBaseView;
@property (nonatomic, strong) UIView *beautyBodyView;

// beauty value
@property (nonatomic, assign) float fWhitenStrength;
@property (nonatomic, assign) float fReddenStrength;
@property (nonatomic, assign) float fSmoothStrength;
@property (nonatomic, assign) float fDehighlightStrength;

@property (nonatomic, assign) float fShrinkFaceStrength;
@property (nonatomic, assign) float fEnlargeEyeStrength;
@property (nonatomic, assign) float fShrinkJawStrength;
@property (nonatomic, assign) float fNarrowFaceStrength;

@property (nonatomic, assign) float fThinFaceShapeStrength;
@property (nonatomic, assign) float fChinStrength;
@property (nonatomic, assign) float fHairLineStrength;
@property (nonatomic, assign) float fNarrowNoseStrength;
@property (nonatomic, assign) float fLongNoseStrength;
@property (nonatomic, assign) float fMouthStrength;
@property (nonatomic, assign) float fPhiltrumStrength;
@property (nonatomic, assign) float fAppleMusleStrength;
@property (nonatomic, assign) float fProfileRhinoplastyStrength;
@property (nonatomic, assign) float fEyeDistanceStrength;
@property (nonatomic, assign) float fEyeAngleStrength;
@property (nonatomic, assign) float fOpenCanthusStrength;
@property (nonatomic, assign) float fBrightEyeStrength;
@property (nonatomic, assign) float fRemoveDarkCirclesStrength;
@property (nonatomic, assign) float fRemoveNasolabialFoldsStrength;
@property (nonatomic, assign) float fWhiteTeethStrength;

@property (nonatomic, assign) float fContrastStrength;
@property (nonatomic, assign) float fSaturationStrength;

//filter value
@property (nonatomic, assign) float fFilterStrength;

@property (nonatomic, strong) EAGLContext *glContext;
@property (nonatomic, strong) CIContext *ciContext;

@property (nonatomic, assign) BOOL needDetectAnimal;
@property (nonatomic, readwrite, assign) unsigned long long iCurrentAction;

@property (nonatomic, assign) CGFloat scale;  //视频充满全屏的缩放比例
@property (nonatomic, assign) int margin;
@property (nonatomic, assign, getter=isCommonObjectViewAdded) BOOL commonObjectViewAdded;
@property (nonatomic, assign, getter=isCommonObjectViewSetted) BOOL commonObjectViewSetted;

@property (nonatomic, readwrite, strong) NSMutableArray *arrBeautyViews;
@property (nonatomic, readwrite, strong) NSMutableArray<STViewButton *> *arrFilterCategoryViews;
@property (nonatomic, strong) NSMutableArray *faceArray;
@property (nonatomic, assign) double lastTimeAttrDetected;

@property (nonatomic) dispatch_queue_t thumbDownlaodQueue;
@property (nonatomic, strong) NSOperationQueue *imageLoadQueue;

@property (nonatomic, readwrite, assign) CGFloat imageWidth;
@property (nonatomic, readwrite, assign) CGFloat imageHeight;

@property (nonatomic, readwrite, assign) BOOL bBeauty;
@property (nonatomic, readwrite, assign) BOOL bSticker;
@property (nonatomic, readwrite, assign) BOOL bFilter;
@property (nonatomic, readwrite, assign) BOOL bTracker;
@property (nonatomic, readwrite, assign) BOOL isNullSticker;

@property (nonatomic, readwrite, strong) UISlider *filterStrengthSlider;
@property (nonatomic, readwrite, strong) STCollectionViewDisplayModel *currentSelectedFilterModel;

@property (nonatomic, strong) CMMotionManager *motionManager;

@property (nonatomic, copy) NSString *preFilterModelPath;
@property (nonatomic, copy) NSString *curFilterModelPath;
@property (nonatomic, copy) NSString *strThumbnailPath;

@property (nonatomic, strong) NSData *licenseData;

@property (nonatomic, readwrite, strong) STEffectsAudioPlayer *audioPlayer;
/***************************** senseTime 相关属性 end ******************************/

@end

@implementation RecordViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        // 录制时默认关闭滤镜
        self.isUseFilterWhenRecording = YES;
        
        // 录制前默认打开自动检测设备方向调整视频拍摄的角度（竖屏、横屏）
        self.isUseAutoCheckDeviceOrientationBeforeRecording = YES;
        
        if (self.isUseFilterWhenRecording) {
            // 滤镜
            self.filterGroup = [[PLSFilterGroup alloc] init];
        }
    }
    return self;
}

- (void)loadView{
    [super loadView];
    self.view.backgroundColor = PLS_RGBCOLOR(25, 24, 36);
    
    // --------------------------
    // 短视频录制核心类设置
    [self setupShortVideoRecorder];
    
    // --------------------------
    [self setupBaseToolboxView];
    [self setupRecordToolboxView];
    [self setupRightButtonView];
    
    // senseTime UI
    [self setDefaultValue];
    [self addSenseTimeUIViews];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // --------------------------
    // 通过手势切换滤镜
    [self setupGestureRecognizer];
    
    // --------------------------
    
    // 初始化 SenseTime
    [self setupSenseTime];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.shortVideoRecorder startCaptureSession];
    
    [self getFirstMovieFromPhotoAlbum];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.shortVideoRecorder stopCaptureSession];
}

// 短视频录制核心类设置
- (void)setupShortVideoRecorder {

    // SDK 的版本信息
    NSLog(@"PLShortVideoRecorder versionInfo: %@", [PLShortVideoRecorder versionInfo]);
    
    // SDK 授权信息查询
    [PLShortVideoRecorder checkAuthentication:^(PLSAuthenticationResult result) {
        NSString *authResult[] = {@"NotDetermined", @"Denied", @"Authorized"};
        NSLog(@"PLShortVideoRecorder auth status: %@", authResult[result]);
    }];
    
    self.videoConfiguration = [PLSVideoConfiguration defaultConfiguration];
    self.videoConfiguration.position = AVCaptureDevicePositionFront;
    self.videoConfiguration.videoFrameRate = 30;
    self.videoConfiguration.videoSize = CGSizeMake(720, 1280);
    self.videoConfiguration.averageVideoBitRate = [self suitableVideoBitrateWithSize:self.videoConfiguration.videoSize];
    self.videoConfiguration.videoOrientation = AVCaptureVideoOrientationPortrait;
    self.videoConfiguration.sessionPreset = AVCaptureSessionPreset1280x720;

    self.audioConfiguration = [PLSAudioConfiguration defaultConfiguration];
    
    self.shortVideoRecorder = [[PLShortVideoRecorder alloc] initWithVideoConfiguration:self.videoConfiguration audioConfiguration:self.audioConfiguration];
    self.shortVideoRecorder.delegate = self;
    self.shortVideoRecorder.maxDuration = 10.0f; // 设置最长录制时长
    [self.shortVideoRecorder setBeautifyModeOn:YES]; // 默认打开美颜
    self.shortVideoRecorder.outputFileType = PLSFileTypeMPEG4;
    self.shortVideoRecorder.innerFocusViewShowEnable = YES; // 显示 SDK 内部自带的对焦动画
    self.shortVideoRecorder.previewView.frame = CGRectMake(0, 0, PLS_SCREEN_WIDTH, PLS_SCREEN_HEIGHT);
    [self.view addSubview:self.shortVideoRecorder.previewView];
    self.shortVideoRecorder.backgroundMonitorEnable = NO;

    // 录制前是否开启自动检测设备方向调整视频拍摄的角度（竖屏、横屏）
    if (self.isUseAutoCheckDeviceOrientationBeforeRecording) {
        UIView *deviceOrientationView = [[UIView alloc] init];
        deviceOrientationView.frame = CGRectMake(0, 0, PLS_SCREEN_WIDTH/2, 44);
        deviceOrientationView.center = CGPointMake(PLS_SCREEN_WIDTH/2, 44/2);
        deviceOrientationView.backgroundColor = [UIColor grayColor];
        deviceOrientationView.alpha = 0.7;
        [self.view addSubview:deviceOrientationView];
        self.shortVideoRecorder.adaptationRecording = YES; // 根据设备方向自动确定横屏 or 竖屏拍摄效果
        [self.shortVideoRecorder setDeviceOrientationBlock:^(PLSPreviewOrientation deviceOrientation){
            switch (deviceOrientation) {
                case PLSPreviewOrientationPortrait:
                    NSLog(@"deviceOrientation : PLSPreviewOrientationPortrait");
                    break;
                case PLSPreviewOrientationPortraitUpsideDown:
                    NSLog(@"deviceOrientation : PLSPreviewOrientationPortraitUpsideDown");
                    break;
                case PLSPreviewOrientationLandscapeRight:
                    NSLog(@"deviceOrientation : PLSPreviewOrientationLandscapeRight");
                    break;
                case PLSPreviewOrientationLandscapeLeft:
                    NSLog(@"deviceOrientation : PLSPreviewOrientationLandscapeLeft");
                    break;
                default:
                    break;
            }
            
            if (deviceOrientation == PLSPreviewOrientationPortrait) {
                deviceOrientationView.frame = CGRectMake(0, 0, PLS_SCREEN_WIDTH/2, 44);
                deviceOrientationView.center = CGPointMake(PLS_SCREEN_WIDTH/2, 44/2);
                
            } else if (deviceOrientation == PLSPreviewOrientationPortraitUpsideDown) {
                deviceOrientationView.frame = CGRectMake(0, 0, PLS_SCREEN_WIDTH/2, 44);
                deviceOrientationView.center = CGPointMake(PLS_SCREEN_WIDTH/2, PLS_SCREEN_HEIGHT - 44/2);
                
            } else if (deviceOrientation == PLSPreviewOrientationLandscapeRight) {
                deviceOrientationView.frame = CGRectMake(0, 0, 44, PLS_SCREEN_HEIGHT/2);
                deviceOrientationView.center = CGPointMake(PLS_SCREEN_WIDTH - 44/2, PLS_SCREEN_HEIGHT/2);
                
            } else if (deviceOrientation == PLSPreviewOrientationLandscapeLeft) {
                deviceOrientationView.frame = CGRectMake(0, 0, 44, PLS_SCREEN_HEIGHT/2);
                deviceOrientationView.center = CGPointMake(44/2, PLS_SCREEN_HEIGHT/2);
            }
        }];
    }
    
    // 默认关闭内部滤镜
    if (self.isUseFilterWhenRecording) {
        // 滤镜资源
        self.filtersArray = [[NSMutableArray alloc] init];
        for (NSDictionary *filterInfoDic in self.filterGroup.filtersInfo) {
            NSString *name = [filterInfoDic objectForKey:@"name"];
            NSString *coverImagePath = [filterInfoDic objectForKey:@"coverImagePath"];
            
            NSDictionary *dic = @{
                                  @"name"            : name,
                                  @"coverImagePath"  : coverImagePath
                                  };
            
            [self.filtersArray addObject:dic];
        }
        
        // 展示多种滤镜的 UICollectionView
        CGRect frame = self.editVideoCollectionView.frame;
        CGFloat x = PLS_BaseToolboxView_HEIGHT;
        CGFloat y = PLS_BaseToolboxView_HEIGHT;
        CGFloat width = frame.size.width - 2*x;
        CGFloat height = frame.size.height;
        self.editVideoCollectionView.frame = CGRectMake(x, y, width, height);
        [self.view addSubview:self.editVideoCollectionView];
        [self.editVideoCollectionView reloadData];
        self.editVideoCollectionView.hidden = YES;
    }
    
    // 本地视频
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"video_draft_test" ofType:@"mp4"];
    self.URL = [NSURL fileURLWithPath:filePath];
}

- (void)setupBaseToolboxView {
    self.baseToolboxView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, PLS_BaseToolboxView_HEIGHT, PLS_BaseToolboxView_HEIGHT + PLS_SCREEN_WIDTH)];
    self.baseToolboxView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.baseToolboxView];
    
    // 返回
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    backButton.frame = CGRectMake(10, 10, 35, 35);
    [backButton setBackgroundImage:[UIImage imageNamed:@"btn_camera_cancel_a"] forState:UIControlStateNormal];
    [backButton setBackgroundImage:[UIImage imageNamed:@"btn_camera_cancel_b"] forState:UIControlStateHighlighted];
    [backButton addTarget:self action:@selector(backButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.baseToolboxView addSubview:backButton];
    
    // 七牛滤镜
    UIButton *filterButton = [UIButton buttonWithType:UIButtonTypeCustom];
    filterButton.frame = CGRectMake(10, 55, 35, 35);
    [filterButton setTitle:@"滤镜" forState:UIControlStateNormal];
    [filterButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    filterButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [filterButton addTarget:self action:@selector(filterButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.baseToolboxView addSubview:filterButton];
    
    // 录屏按钮
    self.viewRecordButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.viewRecordButton.frame = CGRectMake(10, 100, 35, 35);
    [self.viewRecordButton setTitle:@"录屏" forState:UIControlStateNormal];
    [self.viewRecordButton setTitle:@"完成" forState:UIControlStateSelected];
    self.viewRecordButton.selected = NO;
    [self.viewRecordButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.viewRecordButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.viewRecordButton addTarget:self action:@selector(viewRecorderButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.baseToolboxView addSubview:self.viewRecordButton];
    
    // 全屏／正方形录制模式
    self.squareRecordButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.squareRecordButton.frame = CGRectMake(10, 145, 35, 35);
    [self.squareRecordButton setTitle:@"1:1" forState:UIControlStateNormal];
    [self.squareRecordButton setTitle:@"全屏" forState:UIControlStateSelected];
    self.squareRecordButton.selected = NO;
    [self.squareRecordButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.squareRecordButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.squareRecordButton addTarget:self action:@selector(squareRecordButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.baseToolboxView addSubview:self.squareRecordButton];
    
    // 闪光灯
    UIButton *flashButton = [UIButton buttonWithType:UIButtonTypeCustom];
    flashButton.frame = CGRectMake(10, 190, 35, 35);
    [flashButton setBackgroundImage:[UIImage imageNamed:@"flash_close"] forState:UIControlStateNormal];
    [flashButton setBackgroundImage:[UIImage imageNamed:@"flash_open"] forState:UIControlStateSelected];
    [flashButton addTarget:self action:@selector(flashButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.baseToolboxView addSubview:flashButton];
    
    // 美颜
    UIButton *beautyFaceButton = [UIButton buttonWithType:UIButtonTypeCustom];
    beautyFaceButton.frame = CGRectMake(10, 235, 30, 30);
    [beautyFaceButton setTitle:@"美颜" forState:UIControlStateNormal];
    [beautyFaceButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    beautyFaceButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [beautyFaceButton addTarget:self action:@selector(beautyFaceButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.baseToolboxView addSubview:beautyFaceButton];
    beautyFaceButton.selected = YES;
    
    // 切换摄像头
    UIButton *toggleCameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
    toggleCameraButton.frame = CGRectMake(10, 280, 35, 35);
    [toggleCameraButton setBackgroundImage:[UIImage imageNamed:@"toggle_camera"] forState:UIControlStateNormal];
    [toggleCameraButton addTarget:self action:@selector(toggleCameraButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.baseToolboxView addSubview:toggleCameraButton];
    
    // 录制的视频文件的存储路径设置
    self.filePathButton = [[UIButton alloc] init];
    self.filePathButton.frame = CGRectMake(10, 325, 35, 35);
    [self.filePathButton setImage:[UIImage imageNamed:@"file_path"] forState:UIControlStateNormal];
    [self.filePathButton addTarget:self action:@selector(filePathButtonClickedEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.baseToolboxView addSubview:self.filePathButton];
    
    self.filePathButton.selected = NO;
    self.useSDKInternalPath = YES;
    
    // 展示拼接视频的动画
    self.activityIndicatorView = [[UIActivityIndicatorView alloc] initWithFrame:self.view.bounds];
    self.activityIndicatorView.center = self.view.center;
    [self.activityIndicatorView setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.activityIndicatorView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
}

- (void)setupRightButtonView {
    
    self.rightScrollView = [[UIScrollView alloc] init];
    self.rightScrollView.bounces = YES;
    CGRect rc = self.rateButtonView.bounds;
    self.rateButtonView.hidden = YES;
    rc = [self.rateButtonView convertRect:rc toView:self.view];
    self.rightScrollView.frame = CGRectMake(self.view.bounds.size.width - 60, 0, 60, rc.origin.y);
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf.rightScrollView flashScrollIndicators];
    });
    
    UIColor *backgroundColor = [UIColor colorWithWhite:0.0 alpha:.55];
    
    int index = 0;
    // 拍照
    self.snapshotButton = [[UIButton alloc] initWithFrame:CGRectMake(0, index * 60 + 10, 46, 46)];
    self.snapshotButton.layer.cornerRadius = 23;
    self.snapshotButton.backgroundColor = backgroundColor;
    [self.snapshotButton setImage:[UIImage imageNamed:@"icon_trim"] forState:UIControlStateNormal];
    self.snapshotButton.imageEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
    [self.snapshotButton addTarget:self action:@selector(snapshotButtonOnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.rightScrollView addSubview:_snapshotButton];
    
    index ++;
    // 加载草稿视频
    self.draftButton = [[UIButton alloc] initWithFrame:CGRectMake(0, index * 60 + 10, 46, 46)];
    self.draftButton.layer.cornerRadius = 23;
    self.draftButton.backgroundColor = backgroundColor;
    [self.draftButton setImage:[UIImage imageNamed:@"draft_video"] forState:UIControlStateNormal];
    self.draftButton.imageEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
    [self.draftButton addTarget:self action:@selector(draftVideoButtonOnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.rightScrollView addSubview:self.draftButton];
    
    index ++;
    // 是否使用背景音乐
    self.musicButton = [[UIButton alloc] initWithFrame:CGRectMake(0, index * 60 + 10, 46, 46)];
    self.musicButton.layer.cornerRadius = 23;
    self.musicButton.backgroundColor = backgroundColor;
    [self.musicButton setImage:[UIImage imageNamed:@"music_no_selected"] forState:UIControlStateNormal];
    [self.musicButton setImage:[UIImage imageNamed:@"music_selected"] forState:UIControlStateSelected];
    self.musicButton.imageEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
    [self.musicButton addTarget:self action:@selector(musicButtonOnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.rightScrollView addSubview:self.musicButton];
    
    index ++;
    // 30FPS/60FPS
    self.frameRateButton = [[UIButton alloc] initWithFrame:CGRectMake(0, index * 60 + 10, 46, 46)];
    self.frameRateButton.layer.cornerRadius = 23;
    self.frameRateButton.backgroundColor = backgroundColor;
    [self.frameRateButton setTitle:@"30帧" forState:(UIControlStateNormal)];
    self.frameRateButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.frameRateButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.frameRateButton addTarget:self action:@selector(frameRateButtonOnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.rightScrollView addSubview:self.frameRateButton];
    
    index ++;
    //是否开启 SDK 退到后台监听
    self.monitorButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.monitorButton.layer.cornerRadius = 23;
    self.monitorButton.backgroundColor = backgroundColor;
    [self.monitorButton setTitle:@"监听关" forState:UIControlStateNormal];
    [self.monitorButton setTitle:@"监听开" forState:UIControlStateSelected];
    self.monitorButton.selected = NO;
    [self.monitorButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.monitorButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.monitorButton sizeToFit];
    self.monitorButton.frame = CGRectMake(0, index * 60 + 10, 46, 46);
    [self.monitorButton addTarget:self action:@selector(monitorButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.rightScrollView addSubview:self.monitorButton];
    
    index ++;
    [self.view addSubview:self.rightScrollView];
    self.rightScrollView.contentSize = CGSizeMake(60, index * 60 + 10);
}

- (void)setupRecordToolboxView {
    CGFloat y = PLS_BaseToolboxView_HEIGHT + PLS_SCREEN_WIDTH;
    self.recordToolboxView = [[UIView alloc] initWithFrame:CGRectMake(0, y, PLS_SCREEN_WIDTH, PLS_SCREEN_HEIGHT- y)];
    self.recordToolboxView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.recordToolboxView];

    
    // 倍速拍摄
    self.titleArray = @[@"极慢", @"慢", @"正常", @"快", @"极快"];
    CGFloat rateTopSapce;
    if (PLS_SCREEN_HEIGHT > 568) {
        rateTopSapce = 35;
    } else{
        rateTopSapce = 30;
    }
    self.rateButtonView = [[PLSRateButtonView alloc] initWithFrame:CGRectMake(PLS_SCREEN_WIDTH/2 - 130, rateTopSapce, 260, 34) defaultIndex:2];
    self.rateButtonView.hidden = NO;
    self.titleIndex = 2;
    CGFloat countSpace = 200 /self.titleArray.count / 6;
    self.rateButtonView.space = countSpace;
    self.rateButtonView.staticTitleArray = self.titleArray;
    self.rateButtonView.rateDelegate = self;
    [self.recordToolboxView addSubview:_rateButtonView];

    
    // 录制视频的操作按钮
    CGFloat buttonWidth = 80.0f;
    self.recordButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.recordButton.frame = CGRectMake(0, 0, buttonWidth, buttonWidth);
    self.recordButton.center = CGPointMake(PLS_SCREEN_WIDTH / 2, self.recordToolboxView.frame.size.height - 80);
    [self.recordButton setImage:[UIImage imageNamed:@"btn_record_a"] forState:UIControlStateNormal];
    [self.recordButton addTarget:self action:@selector(recordButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.recordToolboxView addSubview:self.recordButton];
    
    // 删除视频片段的按钮
    CGPoint center = self.recordButton.center;
    center.x = center.x + 80;
    self.deleteButton = [PLSDeleteButton getInstance];
    self.deleteButton.style = PLSDeleteButtonStyleNormal;
    self.deleteButton.frame = CGRectMake(15, PLS_SCREEN_HEIGHT - 80, 50, 50);
    self.deleteButton.center = center;
    [self.deleteButton setImage:[UIImage imageNamed:@"btn_del_a"] forState:UIControlStateNormal];
    [self.deleteButton addTarget:self action:@selector(deleteButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.recordToolboxView addSubview:self.deleteButton];
    self.deleteButton.hidden = YES;
    
    // 结束录制的按钮
    center.x = center.x + 70;
    self.endButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.endButton.frame = CGRectMake(PLS_SCREEN_WIDTH - 40, PLS_SCREEN_HEIGHT - 80, 50, 50);
    self.endButton.center = center;
    [self.endButton setBackgroundImage:[UIImage imageNamed:@"end_normal"] forState:UIControlStateNormal];
    [self.endButton setBackgroundImage:[UIImage imageNamed:@"end_disable"] forState:UIControlStateDisabled];
    [self.endButton addTarget:self action:@selector(endButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    self.endButton.enabled = NO;
    [self.recordToolboxView addSubview:self.endButton];
    self.endButton.hidden = YES;
    
    // 视频录制进度条
    self.progressBar = [[PLSProgressBar alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.recordToolboxView.frame) - 10, PLS_SCREEN_WIDTH, 10)];
    [self.recordToolboxView addSubview:self.progressBar];
    
    self.durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(PLS_SCREEN_WIDTH - 150, CGRectGetHeight(self.recordToolboxView.frame) - 45, 130, 40)];
    self.durationLabel.textColor = [UIColor whiteColor];
    self.durationLabel.text = [NSString stringWithFormat:@"%.2fs", self.shortVideoRecorder.getTotalDuration];
    self.durationLabel.textAlignment = NSTextAlignmentRight;
    [self.recordToolboxView addSubview:self.durationLabel];
    
    // 导入视频的操作按钮
    center = self.recordButton.center;
    center.x = CGRectGetWidth([UIScreen mainScreen].bounds) - 60;
    self.importMovieView = [[UIView alloc] init];
    self.importMovieView.backgroundColor = [UIColor clearColor];
    self.importMovieView.frame = CGRectMake(PLS_SCREEN_WIDTH - 60, PLS_SCREEN_HEIGHT - 80, 80, 80);
    self.importMovieView.center = center;
    [self.recordToolboxView addSubview:self.importMovieView];
    self.importMovieButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.importMovieButton.frame = CGRectMake(15, 10, 50, 50);
    [self.importMovieButton setBackgroundImage:[UIImage imageNamed:@"movie"] forState:UIControlStateNormal];
    [self.importMovieButton addTarget:self action:@selector(importMovieButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.importMovieView addSubview:self.importMovieButton];
    UILabel *importMovieLabel = [[UILabel alloc] init];
    importMovieLabel.frame = CGRectMake(0, 60, 80, 20);
    importMovieLabel.text = @"导入视频";
    importMovieLabel.textColor = [UIColor whiteColor];
    importMovieLabel.textAlignment = NSTextAlignmentCenter;
    importMovieLabel.font = [UIFont systemFontOfSize:14.0];
    [self.importMovieView addSubview:importMovieLabel];
}

#pragma mark -- Button event
// 获取相册中最新的一个视频的封面
- (void)getFirstMovieFromPhotoAlbum {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
        fetchOptions.includeHiddenAssets = NO;
        fetchOptions.includeAllBurstAssets = NO;
        fetchOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"modificationDate" ascending:NO],
                                         [NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
        PHFetchResult *fetchResult = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeVideo options:fetchOptions];
        
        NSMutableArray *assets = [[NSMutableArray alloc] init];
        [fetchResult enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [assets addObject:obj];
        }];
        
        if (assets.count > 0) {
            PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
            CGSize size = CGSizeMake(50, 50);
            [[PHImageManager defaultManager] requestImageForAsset:assets[0] targetSize:size contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage *result, NSDictionary *info) {
                
                // 设置的 options 可能会导致该回调调用两次，第一次返回你指定尺寸的图片，第二次将会返回原尺寸图片
                if ([[info valueForKey:@"PHImageResultIsDegradedKey"] integerValue] == 0){
                    // Do something with the FULL SIZED image
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.importMovieButton setBackgroundImage:result forState:UIControlStateNormal];
                    });
                } else {
                    // Do something with the regraded image
                }
            }];
        }
    });
}

// 返回上一层
- (void)backButtonEvent:(id)sender {
    if (self.viewRecordButton.isSelected) {
        [self.viewRecorderManager cancelRecording];
        [self.screenRecorderManager cancelRecording];
    }
    if ([self.shortVideoRecorder getFilesCount] > 0) {
        self.alertView = [[UIAlertView alloc] initWithTitle:@"提醒" message:[NSString stringWithFormat:@"放弃这个视频(共%ld个视频段)?", (long)[self.shortVideoRecorder getFilesCount]] delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
        self.alertView.tag = PLS_CLOSE_CONTROLLER_ALERTVIEW_TAG;
        [self.alertView show];
    } else {
        [self discardRecord];
    }
}

// 全屏录制／正方形录制
- (void)squareRecordButtonEvent:(id)sender {
    UIButton *button = (UIButton *)sender;
    button.selected = !button.selected;
    if (button.selected) {
        self.videoConfiguration.videoSize = CGSizeMake(720, 720);
        [self.shortVideoRecorder reloadvideoConfiguration:self.videoConfiguration];
        
        self.shortVideoRecorder.maxDuration = 10.0f;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.shortVideoRecorder.previewView.frame = CGRectMake(0, PLS_BaseToolboxView_HEIGHT, PLS_SCREEN_WIDTH, PLS_SCREEN_WIDTH);
            self.progressBar.frame = CGRectMake(0, 0, PLS_SCREEN_WIDTH, 10);
            
        });
        
    } else {
        self.videoConfiguration.videoSize = CGSizeMake(720, 1280);
        [self.shortVideoRecorder reloadvideoConfiguration:self.videoConfiguration];
        
        self.shortVideoRecorder.maxDuration = 10.0f;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.shortVideoRecorder.previewView.frame = CGRectMake(0, 0, PLS_SCREEN_WIDTH, PLS_SCREEN_HEIGHT);
            self.progressBar.frame = CGRectMake(0, CGRectGetHeight(self.recordToolboxView.frame) - 10, PLS_SCREEN_WIDTH, 10);
        });
    }
}

//录制 self.view
- (void)viewRecorderButtonClick:(id)sender {
    if (@available(iOS 11.0, *)) {
        if (!self.screenRecorderManager) {
            self.screenRecorderManager = [[PLScreenRecorderManager alloc] init];
            self.screenRecorderManager.delegate = self;
        }
        if (self.viewRecordButton.isSelected) {
            self.viewRecordButton.selected = NO;
            [self.screenRecorderManager stopRecording];
        } else {
            self.viewRecordButton.selected = YES;
            [self.screenRecorderManager startRecording];
        }
    } else {
        if (!self.viewRecorderManager) {
            self.viewRecorderManager = [[PLSViewRecorderManager alloc] initWithRecordedView:self.shortVideoRecorder.previewView];
            self.viewRecorderManager.delegate = self;
        }
        
        if (self.viewRecordButton.isSelected) {
            self.viewRecordButton.selected = NO;
            [self.viewRecorderManager stopRecording];
            
            [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
        }
        else {
            self.viewRecordButton.selected = YES;
            [self.viewRecorderManager startRecording];
            
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(applicationWillResignActive:)
                                                         name:UIApplicationWillResignActiveNotification
                                                       object:nil];
        }}
}

// 打开／关闭闪光灯
- (void)flashButtonEvent:(id)sender {
    if (self.shortVideoRecorder.torchOn) {
        self.shortVideoRecorder.torchOn = NO;
    } else {
        self.shortVideoRecorder.torchOn = YES;
    }
}

// 打开／关闭美颜
- (void)beautyFaceButtonEvent:(id)sender {
    UIButton *button = (UIButton *)sender;
    
    [self.shortVideoRecorder setBeautifyModeOn:!button.selected];
    
    button.selected = !button.selected;
}

// 切换前后置摄像头
- (void)toggleCameraButtonEvent:(UIButton *)sender {
    // 采集帧率不大于 30 帧的时候，使用 [self.shortVideoRecorder toggleCamera] 和 [self.shortVideoRecorder toggleCamera:block] 都可以。当采集大于 30 帧的时候，为确保切换成功，需要先停止采集，再切换相机，切换完成再启动采集。如果不先停止采集，部分机型上采集 60 帧的时候，切换摄像头可能会耗时几秒钟
    if (self.videoConfiguration.videoFrameRate > 30) {
        sender.enabled = NO;
        __weak typeof(self) weakself = self;
        [self.shortVideoRecorder stopCaptureSession];
        [self.shortVideoRecorder toggleCamera:^(BOOL isFinish) {
            [weakself checkActiveFormat];// 默认的 active 可能最大只支持采集 30 帧，这里手动设置一下
            [weakself.shortVideoRecorder startCaptureSession];
            dispatch_async(dispatch_get_main_queue(), ^{
                sender.enabled = YES;
            });
        }];
    } else {
        [self.shortVideoRecorder toggleCamera];
    }
}

// 七牛滤镜
- (void)filterButtonEvent:(UIButton *)button {
    button.selected = !button.selected;
    self.editVideoCollectionView.hidden = !button.selected;
}

// 加载草稿视频
- (void)draftVideoButtonOnClick:(id)sender{
    AVAsset *asset = [AVAsset assetWithURL:_URL];
    CGFloat duration = CMTimeGetSeconds(asset.duration);
    if ((self.shortVideoRecorder.getTotalDuration + duration) <= self.shortVideoRecorder.maxDuration) {
        [self.shortVideoRecorder insertVideo:_URL];
        if (self.shortVideoRecorder.getTotalDuration != 0) {
            _deleteButton.style = PLSDeleteButtonStyleNormal;
            _deleteButton.hidden = NO;
            
            [_progressBar addProgressView];
            [_progressBar startShining];
            [_progressBar setLastProgressToWidth:duration / self.shortVideoRecorder.maxDuration * _progressBar.frame.size.width];
            [_progressBar stopShining];
        }
        self.durationLabel.text = [NSString stringWithFormat:@"%.2fs", self.shortVideoRecorder.getTotalDuration];
        if (self.shortVideoRecorder.getTotalDuration >= self.shortVideoRecorder.maxDuration) {
            self.importMovieButton.hidden = YES;
            [self endButtonEvent:nil];
        }
    }
}

// 是否使用背景音乐
- (void)musicButtonOnClick:(id)sender {
    self.musicButton.selected = !self.musicButton.selected;
    if (self.musicButton.selected) {
        // 背景音乐
        NSURL *audioURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"counter-6s" ofType:@"m4a"]];
        [self.shortVideoRecorder mixAudio:audioURL];
    } else{
        [self.shortVideoRecorder mixAudio:nil];
    }
}

- (void)frameRateButtonOnClick:(UIButton *)button {
    if (60 == self.videoConfiguration.videoFrameRate) {
        self.videoConfiguration.videoFrameRate = 30;
        self.videoConfiguration.sessionPreset = AVCaptureSessionPreset1280x720;
        [button setTitle:@"30帧" forState:(UIControlStateNormal)];
        [self.shortVideoRecorder reloadvideoConfiguration:self.videoConfiguration];
    } else {
        self.videoConfiguration.videoFrameRate = 60;
        self.videoConfiguration.sessionPreset = AVCaptureSessionPresetInputPriority;
        [button setTitle:@"60帧" forState:(UIControlStateNormal)];
        [self.shortVideoRecorder reloadvideoConfiguration:self.videoConfiguration];
        [self checkActiveFormat];
    }
}

// 拍照
-(void)snapshotButtonOnClick:(UIButton *)sender {
    sender.enabled = NO;

    [self.shortVideoRecorder getScreenShotWithCompletionHandler:^(UIImage * _Nullable image) {
        sender.enabled = YES;
        if (image) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
            });
        }
    }];
}

- (void)monitorButtonEvent:(UIButton *)button {
    button.selected = !button.isSelected;
    self.shortVideoRecorder.backgroundMonitorEnable = button.selected;
    if (button.selected) {
        [self removeObserverEvent];
    } else {
        [self addObserverEvent];
    }
}

//
- (void)filePathButtonClickedEvent:(id)sender {
    self.filePathButton.selected = !self.filePathButton.selected;
    if (self.filePathButton.selected) {
        self.useSDKInternalPath = NO;
    } else {
        self.useSDKInternalPath = YES;
    }
}

// 删除上一段视频
- (void)deleteButtonEvent:(id)sender {
    if (_deleteButton.style == PLSDeleteButtonStyleNormal) {
        
        [_progressBar setLastProgressToStyle:PLSProgressBarProgressStyleDelete];
        _deleteButton.style = PLSDeleteButtonStyleDelete;
        
    } else if (_deleteButton.style == PLSDeleteButtonStyleDelete) {
        
        [self.shortVideoRecorder deleteLastFile];
        
        [_progressBar deleteLastProgress];
        
        _deleteButton.style = PLSDeleteButtonStyleNormal;
    }
}

// 录制视频
- (void)recordButtonEvent:(id)sender {
    if (self.shortVideoRecorder.isRecording) {
        [self.shortVideoRecorder stopRecording];
    } else {
        if (self.useSDKInternalPath) {
            // 方式1
            // 录制的视频的存放地址由 SDK 内部自动生成
             [self.shortVideoRecorder startRecording];
        } else {
            // 方式2
            // fileURL 录制的视频的存放地址，该参数可以在外部设置，录制的视频会保存到该位置
            [self.shortVideoRecorder startRecording:[self getFileURL]];
        }
    }
}

- (NSURL *)getFileURL {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    
    path = [path stringByAppendingPathComponent:@"TestPath"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if(![fileManager fileExistsAtPath:path]) {
        // 如果不存在,则说明是第一次运行这个程序，那么建立这个文件夹
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    
    NSString *fileName = [[path stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@".mp4"];
    
    NSURL *fileURL = [NSURL fileURLWithPath:fileName];
    
    return fileURL;
}

// 结束录制
- (void)endButtonEvent:(id)sender {
    AVAsset *asset = self.shortVideoRecorder.assetRepresentingAllFiles;
    [self playEvent:asset];
    [self.viewRecorderManager cancelRecording];
    [self.screenRecorderManager cancelRecording];
    self.viewRecordButton.selected = NO;
}

// 取消录制
- (void)discardRecord {
    [self.shortVideoRecorder cancelRecording];
    [self dismissViewControllerAnimated:YES completion:nil];
}

// 导入视频
- (void)importMovieButtonEvent:(id)sender {
    PhotoAlbumViewController *photoAlbumViewController = [[PhotoAlbumViewController alloc] init];
    [self presentViewController:photoAlbumViewController animated:YES completion:nil];
}

#pragma mark - Notification
- (void)applicationWillResignActive:(NSNotification *)notification {
    if (self.viewRecordButton.selected) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
        self.viewRecordButton.selected = NO;        
        [self.viewRecorderManager cancelRecording];
    }
}

#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (alertView.tag) {
        case PLS_CLOSE_CONTROLLER_ALERTVIEW_TAG:
        {
            switch (buttonIndex) {
                case 0:
                    
                    break;
                case 1:
                {
                    [self discardRecord];
                }
                default:
                    break;
            }
        }
            break;
            
        default:
            break;
    }
}

#pragma mark -- PLSRateButtonViewDelegate
- (void)rateButtonView:(PLSRateButtonView *)rateButtonView didSelectedTitleIndex:(NSInteger)titleIndex{
    self.titleIndex = titleIndex;
    switch (titleIndex) {
        case 0:
            self.shortVideoRecorder.recoderRate = PLSVideoRecoderRateTopSlow;
            break;
        case 1:
            self.shortVideoRecorder.recoderRate = PLSVideoRecoderRateSlow;
            break;
        case 2:
            self.shortVideoRecorder.recoderRate = PLSVideoRecoderRateNormal;
            break;
        case 3:
            self.shortVideoRecorder.recoderRate = PLSVideoRecoderRateFast;
            break;
        case 4:
            self.shortVideoRecorder.recoderRate = PLSVideoRecoderRateTopFast;
            break;
        default:
            break;
    }
}

#pragma mark - PLSViewRecorderManagerDelegate
- (void)viewRecorderManager:(PLSViewRecorderManager *)manager didFinishRecordingToAsset:(AVAsset *)asset totalDuration:(CGFloat)totalDuration {
    self.viewRecordButton.selected = NO;
    // 设置音视频、水印等编辑信息
    NSMutableDictionary *outputSettings = [[NSMutableDictionary alloc] init];
    // 待编辑的原始视频素材
    NSMutableDictionary *plsMovieSettings = [[NSMutableDictionary alloc] init];
    plsMovieSettings[PLSAssetKey] = asset;
    plsMovieSettings[PLSStartTimeKey] = [NSNumber numberWithFloat:0.f];
    plsMovieSettings[PLSDurationKey] = [NSNumber numberWithFloat:totalDuration];
    plsMovieSettings[PLSVolumeKey] = [NSNumber numberWithFloat:1.0f];
    outputSettings[PLSMovieSettingsKey] = plsMovieSettings;
    
    EditViewController *videoEditViewController = [[EditViewController alloc] init];
    videoEditViewController.settings = outputSettings;
    [self presentViewController:videoEditViewController animated:YES completion:nil];
}

#pragma mark - PLScreenRecorderManagerDelegate
- (void)screenRecorderManager:(PLScreenRecorderManager *)manager didFinishRecordingToAsset:(AVAsset *)asset totalDuration:(CGFloat)totalDuration {
    self.viewRecordButton.selected = NO;
    // 设置音视频、水印等编辑信息
    NSMutableDictionary *outputSettings = [[NSMutableDictionary alloc] init];
    // 待编辑的原始视频素材
    NSMutableDictionary *plsMovieSettings = [[NSMutableDictionary alloc] init];
    plsMovieSettings[PLSAssetKey] = asset;
    plsMovieSettings[PLSStartTimeKey] = [NSNumber numberWithFloat:0.f];
    plsMovieSettings[PLSDurationKey] = [NSNumber numberWithFloat:totalDuration];
    plsMovieSettings[PLSVolumeKey] = [NSNumber numberWithFloat:1.0f];
    outputSettings[PLSMovieSettingsKey] = plsMovieSettings;
    
    EditViewController *videoEditViewController = [[EditViewController alloc] init];
    videoEditViewController.settings = outputSettings;
    [self presentViewController:videoEditViewController animated:YES completion:nil];
}

- (void)screenRecorderManager:(PLScreenRecorderManager *)manager errorOccur:(NSError *)error {
    NSString *message = [NSString stringWithFormat:@"%@", error];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误" message:message delegate:nil cancelButtonTitle:@"确定" otherButtonTitles: nil];
    [alert show];
    self.viewRecordButton.selected = NO;
}

#pragma mark -- PLShortVideoRecorderDelegate 摄像头／麦克风鉴权的回调
- (void)shortVideoRecorder:(PLShortVideoRecorder *__nonnull)recorder didGetCameraAuthorizationStatus:(PLSAuthorizationStatus)status {
    if (status == PLSAuthorizationStatusAuthorized) {
        [recorder startCaptureSession];
    }
    else if (status == PLSAuthorizationStatusDenied) {
        NSLog(@"Error: user denies access to camera");
    }
}

- (void)shortVideoRecorder:(PLShortVideoRecorder *__nonnull)recorder didGetMicrophoneAuthorizationStatus:(PLSAuthorizationStatus)status {
    if (status == PLSAuthorizationStatusAuthorized) {
        [recorder startCaptureSession];
    }
    else if (status == PLSAuthorizationStatusDenied) {
        NSLog(@"Error: user denies access to microphone");
    }
}

#pragma mark - PLShortVideoRecorderDelegate 摄像头对焦位置的回调
- (void)shortVideoRecorder:(PLShortVideoRecorder *)recorder didFocusAtPoint:(CGPoint)point {
    NSLog(@"shortVideoRecorder: didFocusAtPoint: %@", NSStringFromCGPoint(point));
}

#pragma mark - PLShortVideoRecorderDelegate 摄像头采集的视频数据的回调
/// @abstract 获取到摄像头原数据时的回调, 便于开发者做滤镜等处理，需要注意的是这个回调在 camera 数据的输出线程，请不要做过于耗时的操作，否则可能会导致帧率下降
- (CVPixelBufferRef)shortVideoRecorder:(PLShortVideoRecorder *)recorder cameraSourceDidGetPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    //此处可以做美颜/滤镜等处理
    
    // 这里注释掉 七牛短视频 SDK 自带滤镜处理
    // 是否在录制时使用滤镜，默认是关闭的，NO
//    if (self.isUseFilterWhenRecording) {
//        // 进行滤镜处理
//        if (self.isPanning) {
//            // 正在滤镜切换过程中，使用 processPixelBuffer:leftPercent:leftFilter:rightFilter 做滤镜切换动画
//            pixelBuffer = [self.filterGroup processPixelBuffer:pixelBuffer leftPercent:self.leftPercent leftFilter:self.leftFilter rightFilter:self.rightFilter];
//        } else {
//            // 正常滤镜处理
//            pixelBuffer = [self.filterGroup.currentFilter process:pixelBuffer];
//        }
//    }
    
    // SenseTime 进行贴纸处理

    //获取每一帧图像信息
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    unsigned char* pBGRAImageIn = (unsigned char*)CVPixelBufferGetBaseAddress(pixelBuffer);

    int iBytesPerRow = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
    int iWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
    int iHeight = (int)CVPixelBufferGetHeight(pixelBuffer);

    size_t iTop , iBottom , iLeft , iRight;
    CVPixelBufferGetExtendedPixels(pixelBuffer, &iLeft, &iRight, &iTop, &iBottom);

    iWidth = iWidth + (int)iLeft + (int)iRight;
    iHeight = iHeight + (int)iTop + (int)iBottom;
    iBytesPerRow = iBytesPerRow + (int)iLeft + (int)iRight;

    _scale = MAX(SCREEN_HEIGHT / iHeight, SCREEN_WIDTH / iWidth);
    _margin = (iWidth * _scale - SCREEN_WIDTH) / 2;

    st_rotate_type stMobileRotate = [self getRotateType];

    st_mobile_human_action_t detectResult;
    memset(&detectResult, 0, sizeof(st_mobile_human_action_t));
    st_result_t iRet = ST_OK;

    _faceArray = [NSMutableArray array];

    // 如果需要做属性,每隔一秒做一次属性
    double dTimeNow = CFAbsoluteTimeGetCurrent();
    BOOL isAttributeTime = (dTimeNow - self.lastTimeAttrDetected) >= 1.0;

    if (isAttributeTime) {
        self.lastTimeAttrDetected = dTimeNow;
    }

    ///ST_MOBILE 以下为通用物体跟踪部分
    if (_bTracker && _hTracker) {
        if (self.isCommonObjectViewAdded) {
            if (!self.isCommonObjectViewSetted) {
                iRet = st_mobile_object_tracker_set_target(_hTracker, pBGRAImageIn, ST_PIX_FMT_BGRA8888, iWidth, iHeight, iBytesPerRow, &_rect);

                if (iRet != ST_OK) {
                    NSLog(@"st mobile object tracker set target failed: %d", iRet);
                    _rect.left = 0;
                    _rect.top = 0;
                    _rect.right = 0;
                    _rect.bottom = 0;
                } else {
                    self.commonObjectViewSetted = YES;
                }
            }

            if (self.isCommonObjectViewSetted) {
                TIMELOG(keyTracker);
                iRet = st_mobile_object_tracker_track(_hTracker, pBGRAImageIn, ST_PIX_FMT_BGRA8888, iWidth, iHeight, iBytesPerRow, &_rect, &_result_score);
                NSLog(@"tracking, result_score: %f,rect.left: %d, rect.top: %d, rect.right: %d, rect.bottom: %d", _result_score, _rect.left, _rect.top, _rect.right, _rect.bottom);
                TIMEPRINT(keyTracker, "st_mobile_object_tracker_track time:");

                if (iRet != ST_OK) {
                    NSLog(@"st mobile object tracker track failed: %d", iRet);
                    _rect.left = 0;
                    _rect.top = 0;
                    _rect.right = 0;
                    _rect.bottom = 0;
                }

                CGRect rectDisplay = CGRectMake(_rect.left * _scale - _margin,
                                                _rect.top * _scale,
                                                _rect.right * _scale - _rect.left * _scale,
                                                _rect.bottom * _scale - _rect.top * _scale);
                CGPoint center = CGPointMake(rectDisplay.origin.x + rectDisplay.size.width / 2,
                                             rectDisplay.origin.y + rectDisplay.size.height / 2);

                dispatch_async(dispatch_get_main_queue(), ^{

                    if (self.commonObjectContainerView.currentCommonObjectView.isOnFirst) {
                        //用作同步,防止再次改变currentCommonObjectView的位置
                    } else if (_rect.left == 0 && _rect.top == 0 && _rect.right == 0 && _rect.bottom == 0) {
                        self.commonObjectContainerView.currentCommonObjectView.hidden = YES;
                    } else {
                        self.commonObjectContainerView.currentCommonObjectView.hidden = NO;
                        self.commonObjectContainerView.currentCommonObjectView.center = center;
                    }
                });
            }
        }
    }

    int catFaceCount = -1;
    ///cat face
    if (_needDetectAnimal && _animalHandle) {
        st_result_t iRet = st_mobile_tracker_animal_face_track(_animalHandle, pBGRAImageIn, ST_PIX_FMT_BGRA8888, iWidth, iHeight, iBytesPerRow, stMobileRotate, &_detectResult1, &catFaceCount);
        if (iRet != ST_OK) {
            NSLog(@"st mobile animal face tracker failed: %d", iRet);
        } else {
            NSLog(@"cat face count: %d", catFaceCount);
        }
    }

    ///ST_MOBILE 人脸信息检测部分
    if (_hDetector) {
        BOOL needFaceDetection = ((self.fEnlargeEyeStrength != 0 || self.fShrinkFaceStrength != 0 || self.fShrinkJawStrength != 0 || self.fThinFaceShapeStrength != 0 || self.fNarrowFaceStrength != 0 || self.fChinStrength != 0 || self.fHairLineStrength != 0 || self.fNarrowNoseStrength != 0 || self.fLongNoseStrength != 0 || self.fMouthStrength != 0 || self.fPhiltrumStrength != 0 || self.fDehighlightStrength != 0 || self.fEyeDistanceStrength != 0 || self.fEyeAngleStrength != 0 || self.fOpenCanthusStrength != 0 || self.fProfileRhinoplastyStrength != 0 || self.fBrightEyeStrength != 0 || self.fRemoveDarkCirclesStrength != 0 || self.fRemoveNasolabialFoldsStrength != 0 || self.fWhiteTeethStrength != 0 || self.fAppleMusleStrength != 0) && _hBeautify) || (isAttributeTime && _hAttribute);

        if (needFaceDetection) {
#if TEST_AVATAR_EXPRESSION
            self.iCurrentAction |= ST_MOBILE_FACE_DETECT | self.avatarConfig;
#else
            self.iCurrentAction |= ST_MOBILE_FACE_DETECT;
#endif
        }

        if (self.iCurrentAction > 0) {
            TIMELOG(keyDetect);

            st_result_t iRet = st_mobile_human_action_detect(_hDetector, pBGRAImageIn, ST_PIX_FMT_BGRA8888, iWidth, iHeight, iBytesPerRow, stMobileRotate, self.iCurrentAction, &detectResult);

            TIMEPRINT(keyDetect, "st_mobile_human_action_detect time:");

            if(iRet == ST_OK) {
#if TEST_AVATAR_EXPRESSION
                //获取avatar表情参数，该接口只会处理一张人脸信息，结果信息会以数组形式返回，数组下标对应的表情在ST_AVATAR_EXPRESSION_INDEX枚举中
                if (detectResult.face_count > 0) {
                    float expression[ST_AVATAR_EXPRESSION_NUM] = {0.0};
                    iRet = st_mobile_avatar_get_expression(_avatarHandle, iWidth, iHeight, stMobileRotate, detectResult.p_faces, expression);
                    if (expression[0] == 1) {
                        NSLog(@"右眼闭");
                    }
                }
#endif
            }else{
                NSLog(@"st_mobile_human_action_detect failed %d" , iRet);
            }
        }
    }
    CFRetain(pixelBuffer);

    __block st_mobile_human_action_t newDetectResult;
    memset(&newDetectResult, 0, sizeof(st_mobile_human_action_t));
    copyHumanAction(&detectResult, &newDetectResult);

    int faceCount = catFaceCount;
    st_mobile_animal_face_t *newDetectResult1 = NULL;
    if (faceCount > 0) {
        newDetectResult1 = malloc(sizeof(st_mobile_animal_face_t) * faceCount);
        memset(newDetectResult1, 0, sizeof(st_mobile_animal_face_t) * faceCount);
        copyCatFace(_detectResult1, faceCount, newDetectResult1);
    }
    
    // 设置 OpenGL 环境 , 需要与初始化 SDK 时一致
    if ([EAGLContext currentContext] != self.glContext) {
        [EAGLContext setCurrentContext:self.glContext];
    }
    
    // 当图像尺寸发生改变时需要对应改变纹理大小
    if (iWidth != self.imageWidth || iHeight != self.imageHeight) {
        [self releaseResultTexture];
        self.imageWidth = iWidth;
        self.imageHeight = iHeight;
        [self initResultTexture];
    }
    
    // 获取原图纹理
    BOOL isTextureOriginReady = [self setupOriginTextureWithPixelBuffer:pixelBuffer];
    GLuint textureResult = _textureOriginInput;
    CVPixelBufferRef resultPixelBufffer = pixelBuffer;
    if (isTextureOriginReady) {
        
        ///ST_MOBILE 以下为美颜部分
        if (_bBeauty && _hBeautify) {
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_SHRINK_FACE_RATIO, self.fShrinkFaceStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_ENLARGE_EYE_RATIO, self.fEnlargeEyeStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_SHRINK_JAW_RATIO, self.fShrinkJawStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_SMOOTH_STRENGTH, self.fSmoothStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_REDDEN_STRENGTH, self.fReddenStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_WHITEN_STRENGTH, self.fWhitenStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_CONTRAST_STRENGTH, self.fContrastStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_SATURATION_STRENGTH, self.fSaturationStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_DEHIGHLIGHT_STRENGTH, self.fDehighlightStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_NARROW_FACE_STRENGTH, self.fNarrowFaceStrength);
            
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_THIN_FACE_SHAPE_RATIO, self.fThinFaceShapeStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_CHIN_LENGTH_RATIO, self.fChinStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_HAIRLINE_HEIGHT_RATIO, self.fHairLineStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_NARROW_NOSE_RATIO, self.fNarrowNoseStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_NOSE_LENGTH_RATIO, self.fLongNoseStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_MOUTH_SIZE_RATIO, self.fMouthStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_PHILTRUM_LENGTH_RATIO, self.fPhiltrumStrength);
            
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_APPLE_MUSLE_RATIO, self.fAppleMusleStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_PROFILE_RHINOPLASTY_RATIO, self.fProfileRhinoplastyStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_EYE_DISTANCE_RATIO, self.fEyeDistanceStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_EYE_ANGLE_RATIO, self.fEyeAngleStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_OPEN_CANTHUS_RATIO, self.fOpenCanthusStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_BRIGHT_EYE_RATIO, self.fBrightEyeStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_REMOVE_DARK_CIRCLES_RATIO, self.fRemoveDarkCirclesStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_REMOVE_NASOLABIAL_FOLDS_RATIO, self.fRemoveNasolabialFoldsStrength);
            setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_WHITE_TEETH_RATIO, self.fWhiteTeethStrength);
            
            TIMELOG(keyBeautify);
            
            iRet = st_mobile_beautify_process_texture(_hBeautify, _textureOriginInput, iWidth, iHeight, stMobileRotate, &newDetectResult, _textureBeautifyOutput, &newDetectResult);
            
            TIMEPRINT(keyBeautify, "st_mobile_beautify_process_texture time:");
            
            if (ST_OK != iRet) {
                NSLog(@"st_mobile_beautify_process_texture failed %d" , iRet);
            } else {
                textureResult = _textureBeautifyOutput;
                resultPixelBufffer = _cvBeautifyBuffer;
            }
        }
    }
    
#if DRAW_FACE_KEY_POINTS
    [self drawKeyPoints:newDetectResult];
#endif
    
    ///ST_MOBILE 以下为贴纸部分
    if (_bSticker && _hSticker) {
        TIMELOG(stickerProcessKey);
        
        st_mobile_input_params_t inputEvent;
        memset(&inputEvent, 0, sizeof(st_mobile_input_params_t));
        
        int type = ST_INPUT_PARAM_NONE;
        iRet = st_mobile_sticker_get_needed_input_params(_hSticker, &type);
        
        if (CHECK_FLAG(type, ST_INPUT_PARAM_CAMERA_QUATERNION)) {
            CMDeviceMotion *motion = self.motionManager.deviceMotion;
            inputEvent.camera_quaternion[0] = motion.attitude.quaternion.x;
            inputEvent.camera_quaternion[1] = motion.attitude.quaternion.y;
            inputEvent.camera_quaternion[2] = motion.attitude.quaternion.z;
            inputEvent.camera_quaternion[3] = motion.attitude.quaternion.w;
            
            if (self.shortVideoRecorder.captureDevicePosition == AVCaptureDevicePositionBack) {
                inputEvent.is_front_camera = false;
            } else {
                inputEvent.is_front_camera = true;
            }
        } else {
            inputEvent.camera_quaternion[0] = 0;
            inputEvent.camera_quaternion[1] = 0;
            inputEvent.camera_quaternion[2] = 0;
            inputEvent.camera_quaternion[3] = 1;
        }
        
        iRet = st_mobile_sticker_process_texture_both(_hSticker, textureResult, iWidth, iHeight, stMobileRotate, ST_CLOCKWISE_ROTATE_0, false, &newDetectResult, &inputEvent, newDetectResult1, catFaceCount, _textureStickerOutput);
        
        TIMEPRINT(stickerProcessKey, "st_mobile_sticker_process_texture time:");
        
        if (ST_OK != iRet) {
            NSLog(@"st_mobile_sticker_process_texture %d" , iRet);
        }
        
        textureResult = _textureStickerOutput;
        resultPixelBufffer = _cvStickerBuffer;
    }
    
    if (self.isNullSticker && _hSticker) {
        iRet = st_mobile_sticker_change_package(_hSticker, NULL, NULL);
        
        if (ST_OK != iRet) {
            NSLog(@"st_mobile_sticker_change_package error %d", iRet);
        }
    }
    
    ///ST_MOBILE 以下为滤镜部分
    if (_bFilter && _hFilter) {
        
        if (self.curFilterModelPath != self.preFilterModelPath) {
            iRet = st_mobile_gl_filter_set_style(_hFilter, self.curFilterModelPath.UTF8String);
            if (iRet != ST_OK) {
                NSLog(@"st mobile filter set style failed: %d", iRet);
            }
            self.preFilterModelPath = self.curFilterModelPath;
        }
        
        TIMELOG(keyFilter);
        
        iRet = st_mobile_gl_filter_process_texture(_hFilter, textureResult, iWidth, iHeight, _textureFilterOutput);
        
        TIMEPRINT(keyFilter, "st_mobile_gl_filter_process_texture time:");
        
        if (ST_OK != iRet) {
            NSLog(@"st_mobile_gl_filter_process_texture %d" , iRet);
        }
        
        textureResult = _textureFilterOutput;
        resultPixelBufffer = _cvFilterBuffer;
    }
    freeHumanAction(&newDetectResult);
    if (faceCount > 0) {
        freeCatFace(newDetectResult1, faceCount);
    }
    
    if (_cvTextureOrigin) {
        CFRelease(_cvTextureOrigin);
        _cvTextureOrigin = NULL;
    }
    
    CVOpenGLESTextureCacheFlush(_cvTextureCache, 0);
    CFRelease(pixelBuffer);
    return resultPixelBufffer;
}

#pragma mark -- PLShortVideoRecorderDelegate 视频录制回调

// 开始录制一段视频时
- (void)shortVideoRecorder:(PLShortVideoRecorder *)recorder didStartRecordingToOutputFileAtURL:(NSURL *)fileURL {
    NSLog(@"start recording fileURL: %@", fileURL);

    [self.progressBar addProgressView];
    [_progressBar startShining];
}

// 正在录制的过程中
- (void)shortVideoRecorder:(PLShortVideoRecorder *)recorder didRecordingToOutputFileAtURL:(NSURL *)fileURL fileDuration:(CGFloat)fileDuration totalDuration:(CGFloat)totalDuration {
    [_progressBar setLastProgressToWidth:fileDuration / self.shortVideoRecorder.maxDuration * _progressBar.frame.size.width];
    
    self.endButton.enabled = (totalDuration >= self.shortVideoRecorder.minDuration);
    
    self.squareRecordButton.hidden = YES; // 录制过程中不允许切换分辨率（1:1 <--> 全屏）
    self.deleteButton.hidden = YES;
    self.endButton.hidden = YES;
    self.importMovieView.hidden = YES;
    self.musicButton.hidden = YES;
    self.filePathButton.hidden = YES;
    self.frameRateButton.hidden = YES;
    
    self.durationLabel.text = [NSString stringWithFormat:@"%.2fs", totalDuration];
}

// 删除了某一段视频
- (void)shortVideoRecorder:(PLShortVideoRecorder *)recorder didDeleteFileAtURL:(NSURL *)fileURL fileDuration:(CGFloat)fileDuration totalDuration:(CGFloat)totalDuration {
    NSLog(@"delete fileURL: %@, fileDuration: %f, totalDuration: %f", fileURL, fileDuration, totalDuration);

    self.endButton.enabled = totalDuration >= self.shortVideoRecorder.minDuration;

    if (totalDuration <= 0.0000001f) {
        self.squareRecordButton.hidden = NO;
        self.deleteButton.hidden = YES;
        self.endButton.hidden = YES;
        self.importMovieView.hidden = NO;
        self.musicButton.hidden = NO;
        self.filePathButton.hidden = NO;
        self.frameRateButton.hidden = NO;
    }
    
    AVAsset *asset = [AVAsset assetWithURL:_URL];
    CGFloat duration = CMTimeGetSeconds(asset.duration);
    self.draftButton.hidden = (totalDuration +  duration) >= self.shortVideoRecorder.maxDuration;

    self.durationLabel.text = [NSString stringWithFormat:@"%.2fs", totalDuration];
}

// 完成一段视频的录制时
- (void)shortVideoRecorder:(PLShortVideoRecorder *)recorder didFinishRecordingToOutputFileAtURL:(NSURL *)fileURL fileDuration:(CGFloat)fileDuration totalDuration:(CGFloat)totalDuration {
    NSLog(@"finish recording fileURL: %@, fileDuration: %f, totalDuration: %f", fileURL, fileDuration, totalDuration);
    
    [_progressBar stopShining];

    self.deleteButton.hidden = NO;
    self.endButton.hidden = NO;

    AVAsset *asset = [AVAsset assetWithURL:_URL];
    CGFloat duration = CMTimeGetSeconds(asset.duration);
    self.draftButton.hidden = (totalDuration +  duration) >= self.shortVideoRecorder.maxDuration;
    
    if (totalDuration >= self.shortVideoRecorder.maxDuration) {
        [self endButtonEvent:nil];
    }
}

// 在达到指定的视频录制时间 maxDuration 后，如果再调用 [PLShortVideoRecorder startRecording]，直接执行该回调
- (void)shortVideoRecorder:(PLShortVideoRecorder *)recorder didFinishRecordingMaxDuration:(CGFloat)maxDuration {
    NSLog(@"finish recording maxDuration: %f", maxDuration);

    AVAsset *asset = self.shortVideoRecorder.assetRepresentingAllFiles;
    [self playEvent:asset];
    [self.viewRecorderManager cancelRecording];
    self.viewRecordButton.selected = NO;
}

#pragma mark -- 下一步
- (void)playEvent:(AVAsset *)asset {
    // 获取当前会话的所有的视频段文件
    NSArray *filesURLArray = [self.shortVideoRecorder getAllFilesURL];
    NSLog(@"filesURLArray:%@", filesURLArray);

    __block AVAsset *movieAsset = asset;
    if (self.musicButton.selected) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [self loadActivityIndicatorView];
        // MusicVolume：1.0，videoVolume:0.0 即完全丢弃掉拍摄时的所有声音，只保留背景音乐的声音
        [self.shortVideoRecorder mixWithMusicVolume:1.0 videoVolume:0.0 completionHandler:^(AVMutableComposition * _Nullable composition, AVAudioMix * _Nullable audioMix, NSError * _Nullable error) {
            AVAssetExportSession *exporter = [[AVAssetExportSession alloc]initWithAsset:composition presetName:AVAssetExportPresetHighestQuality];
            NSURL *outputPath = [self exportAudioMixPath];
            exporter.outputURL = outputPath;
            exporter.outputFileType = AVFileTypeMPEG4;
            exporter.shouldOptimizeForNetworkUse= YES;
            exporter.audioMix = audioMix;
            [exporter exportAsynchronouslyWithCompletionHandler:^{
                switch ([exporter status]) {
                    case AVAssetExportSessionStatusFailed: {
                        NSLog(@"audio mix failed：%@", [[exporter error] description]);
                        AlertViewShow([[exporter error] description]);
                    } break;
                    case AVAssetExportSessionStatusCancelled: {
                        NSLog(@"audio mix canceled");
                    } break;
                    case AVAssetExportSessionStatusCompleted: {
                        NSLog(@"audio mix success");
                        movieAsset = [AVAsset assetWithURL:outputPath];
                    } break;
                    default: {
                        
                    } break;
                }
                dispatch_semaphore_signal(semaphore);
            }];
        }];
        [self removeActivityIndicatorView];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
    // 设置音视频、水印等编辑信息
    NSMutableDictionary *outputSettings = [[NSMutableDictionary alloc] init];
    // 待编辑的原始视频素材
    NSMutableDictionary *plsMovieSettings = [[NSMutableDictionary alloc] init];
    plsMovieSettings[PLSAssetKey] = movieAsset;
    plsMovieSettings[PLSStartTimeKey] = [NSNumber numberWithFloat:0.f];
    plsMovieSettings[PLSDurationKey] = [NSNumber numberWithFloat:[self.shortVideoRecorder getTotalDuration]];
    plsMovieSettings[PLSVolumeKey] = [NSNumber numberWithFloat:1.0f];
    outputSettings[PLSMovieSettingsKey] = plsMovieSettings;
    
    EditViewController *videoEditViewController = [[EditViewController alloc] init];
    videoEditViewController.settings = outputSettings;
    videoEditViewController.filesURLArray = filesURLArray;
    [self presentViewController:videoEditViewController animated:YES completion:nil];
}
#pragma mark - 输出路径
- (NSURL *)exportAudioMixPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if(![fileManager fileExistsAtPath:path]) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    NSString *fileName = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_mix.mp4",nowTimeStr]];
    return [NSURL fileURLWithPath:fileName];
}

// 加载拼接视频的动画
- (void)loadActivityIndicatorView {
    if ([self.activityIndicatorView isAnimating]) {
        [self.activityIndicatorView stopAnimating];
        [self.activityIndicatorView removeFromSuperview];
    }
    
    [self.view addSubview:self.activityIndicatorView];
    [self.activityIndicatorView startAnimating];
}

// 移除拼接视频的动画
- (void)removeActivityIndicatorView {
    [self.activityIndicatorView removeFromSuperview];
    [self.activityIndicatorView stopAnimating];
}

#pragma mark -- 隐藏状态栏
- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -- dealloc
- (void)dealloc {
    // 移除前后台监听的通知
    [self removeObserverEvent];

    self.shortVideoRecorder.delegate = nil;
    self.shortVideoRecorder = nil;
    
    self.alertView = nil;
    
    self.filtersArray = nil;
    
    if ([self.activityIndicatorView isAnimating]) {
        [self.activityIndicatorView stopAnimating];
        self.activityIndicatorView = nil;
    }
    
    NSLog(@"dealloc: %@", [[self class] description]);
}

#pragma mark -- UICollectionView delegate  用来展示和处理 SDK 内部自带的滤镜效果
// 加载 collectionView 视图
- (UICollectionView *)editVideoCollectionView {
    if (!_editVideoCollectionView) {
        
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc]init];
        layout.itemSize = CGSizeMake(50, 65);
        [layout setScrollDirection:UICollectionViewScrollDirectionHorizontal];
        layout.minimumLineSpacing = 10;
        layout.minimumInteritemSpacing = 10;
        
        _editVideoCollectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, PLS_SCREEN_WIDTH, layout.itemSize.height) collectionViewLayout:layout];
        _editVideoCollectionView.backgroundColor = [UIColor clearColor];
        
        _editVideoCollectionView.showsHorizontalScrollIndicator = NO;
        _editVideoCollectionView.showsVerticalScrollIndicator = NO;
        [_editVideoCollectionView setExclusiveTouch:YES];
        
        [_editVideoCollectionView registerClass:[PLSEditVideoCell class] forCellWithReuseIdentifier:NSStringFromClass([PLSEditVideoCell class])];
        
        _editVideoCollectionView.delegate = self;
        _editVideoCollectionView.dataSource = self;
    }
    return _editVideoCollectionView;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return self.filtersArray.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PLSEditVideoCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass([PLSEditVideoCell class]) forIndexPath:indexPath];
    
    // 滤镜
    NSDictionary *filterInfoDic = self.filtersArray[indexPath.row];
    
    NSString *name = [filterInfoDic objectForKey:@"name"];
    NSString *coverImagePath = [filterInfoDic objectForKey:@"coverImagePath"];
    
    cell.iconPromptLabel.text = name;
    cell.iconImageView.image = [UIImage imageWithContentsOfFile:coverImagePath];
    
    return  cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {

    // 滤镜
    self.filterGroup.filterIndex = indexPath.row;
}

#pragma mark - 通过手势切换滤镜
- (void)setupGestureRecognizer {
    UIPanGestureRecognizer * panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleFilterPan:)];
    [self.view addGestureRecognizer:panGesture];
}

// 添加手势的响应事件
- (void)handleFilterPan:(UIPanGestureRecognizer *)gestureRecognizer {
    
    CGPoint transPoint = [gestureRecognizer translationInView:gestureRecognizer.view];
    CGPoint speed = [gestureRecognizer velocityInView:gestureRecognizer.view];
    
    switch (gestureRecognizer.state) {
            
            /*!
             手势开始的时候，根据手势的滑动方向，确定切换到下一个滤镜的索引值
             */
        case UIGestureRecognizerStateBegan: {
            NSInteger index = 0;
            if (speed.x > 0) {
                self.isLeftToRight = YES;
                index = self.filterGroup.filterIndex - 1;
            } else {
                index = self.filterGroup.filterIndex + 1;
                self.isLeftToRight = NO;
            }
            
            if (index < 0) {
                index = self.filterGroup.filtersInfo.count - 1;
            } else if (index >= self.filterGroup.filtersInfo.count) {
                index = index - self.filterGroup.filtersInfo.count;
            }
            self.filterGroup.nextFilterIndex = index;
            
            if (self.isLeftToRight) {
                self.leftFilter = self.filterGroup.nextFilter;
                self.rightFilter = self.filterGroup.currentFilter;
                self.leftPercent = 0.0;
            } else {
                self.leftFilter = self.filterGroup.currentFilter;
                self.rightFilter = self.filterGroup.nextFilter;
                self.leftPercent = 1.0;
            }
            self.isPanning = YES;
            
            break;
        }
            
            /*!
             手势变化的过程中，根据滑动的距离来确定两个滤镜所占的百分比
             */
        case UIGestureRecognizerStateChanged: {
            if (self.isLeftToRight) {
                if (transPoint.x <= 0) {
                    transPoint.x = 0;
                }
                self.leftPercent = transPoint.x / gestureRecognizer.view.bounds.size.width;
                self.isNeedChangeFilter = (self.leftPercent >= 0.5) || (speed.x > 500 );
            } else {
                if (transPoint.x >= 0) {
                    transPoint.x = 0;
                }
                self.leftPercent = 1 - fabs(transPoint.x) / gestureRecognizer.view.bounds.size.width;
                self.isNeedChangeFilter = (self.leftPercent <= 0.5) || (speed.x < -500);
            }
            break;
        }
            
            /*!
             手势结束的时候，根据滑动距离，判断是否切换到下一个滤镜，并且做一下切换的动画
             */
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed: {
            gestureRecognizer.enabled = NO;
            
            // 做一个滤镜过渡动画，优化用户体验
            dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
            dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC, 0.005 * NSEC_PER_SEC);
            dispatch_source_set_event_handler(timer, ^{
                if (!self.isPanning) return;
                
                float delta = 0.03;
                if (self.isNeedChangeFilter) {
                    // apply filter change
                    if (self.isLeftToRight) {
                        self.leftPercent = MIN(1, self.leftPercent + delta);
                    } else {
                        self.leftPercent = MAX(0, self.leftPercent - delta);
                    }
                } else {
                    // cancel filter change
                    if (self.isLeftToRight) {
                        self.leftPercent = MAX(0, self.leftPercent - delta);
                    } else {
                        self.leftPercent = MIN(1, self.leftPercent + delta);
                    }
                }
                
                if (self.leftPercent < FLT_EPSILON || fabs(1.0 - self.leftPercent) < FLT_EPSILON) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        dispatch_source_cancel(timer);
                        if (self.isNeedChangeFilter) {
                            self.filterGroup.filterIndex = self.filterGroup.nextFilterIndex;
                        }
                        self.isPanning = NO;
                        self.isNeedChangeFilter = NO;
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            gestureRecognizer.enabled = YES;
                        });
                    });
                }
            });
            dispatch_resume(timer);
            break;
        }
            
        case UIGestureRecognizerStatePossible: {
            NSLog(@"UIGestureRecognizerStatePossible");
        } break;
            
        default:
            break;
    }
}

#pragma mark - 较高质量下，不同分辨率对应的码率值取值
- (NSInteger)suitableVideoBitrateWithSize:(CGSize)videoSize {
    
    // 下面的码率设置均偏大，为了拍摄出来的视频更清晰，选择了偏大的码率，不过均比系统相机拍摄出来的视频码率小很多
    if (videoSize.width + videoSize.height > 720 + 1280) {
        return 8 * 1000 * 1000;
    } else if (videoSize.width + videoSize.height > 544 + 960) {
        return 4 * 1000 * 1000;
    } else if (videoSize.width + videoSize.height > 360 + 640) {
        return 2 * 1000 * 1000;
    } else {
        return 1 * 1000 * 1000;
    }
}

#pragma mark - addObserverEvent
- (void)addObserverEvent {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

#pragma mark - removeObserverEvent
- (void)removeObserverEvent {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applicationDidEnterBackground:(id)sender {
    NSLog(@"%s, %d, applicationDidEnterBackground:", __func__, __LINE__);
    [self.shortVideoRecorder stopRecording];
}

- (void)applicationDidBecomeActive:(id)sender {
    NSLog(@"%s, %d, applicationDidBecomeActive:", __func__, __LINE__);
}

- (void)checkActiveFormat {
    
    CGSize needCaptureSize = self.videoConfiguration.videoSize;
    
    if (AVCaptureVideoOrientationPortrait == self.videoConfiguration.videoOrientation ||
        AVCaptureVideoOrientationPortraitUpsideDown == self.videoConfiguration.videoOrientation) {
        needCaptureSize = CGSizeMake(self.videoConfiguration.videoSize.height, self.videoConfiguration.videoSize.width);
    }
    
    AVCaptureDeviceFormat *activeFormat = self.shortVideoRecorder.videoActiveFormat;
    AVFrameRateRange *frameRateRange = [activeFormat.videoSupportedFrameRateRanges firstObject];
    
    CMVideoDimensions captureSize = CMVideoFormatDescriptionGetDimensions(activeFormat.formatDescription);
    if (frameRateRange.maxFrameRate < self.videoConfiguration.videoFrameRate ||
        frameRateRange.minFrameRate > self.videoConfiguration.videoFrameRate ||
        needCaptureSize.width > captureSize.width ||
        needCaptureSize.height > captureSize.height) {
        
        NSArray *videoFormats = self.shortVideoRecorder.videoFormats;
        for (AVCaptureDeviceFormat *format in videoFormats) {
            frameRateRange = [format.videoSupportedFrameRateRanges firstObject];
            captureSize = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
            
            if (frameRateRange.maxFrameRate >= self.videoConfiguration.videoFrameRate &&
                frameRateRange.minFrameRate <= self.videoConfiguration.videoFrameRate &&
                captureSize.width >= needCaptureSize.width &&
                captureSize.height >= needCaptureSize.height) {
                NSLog(@"size = {%d x %d}, fps = %f ~ %f", captureSize.width, captureSize.height, frameRateRange.minFrameRate, frameRateRange.maxFrameRate);
                self.shortVideoRecorder.videoActiveFormat = format;
                break;
            }
        }
    }
}

- (UIButton *)dismissButton {
    if (!_dismissButton) {
        _dismissButton = [UIButton buttonWithType:(UIButtonTypeSystem)];
        [_dismissButton addTarget:self action:@selector(clickDismissPickerViewButton:) forControlEvents:(UIControlEventTouchUpInside)];
    }
    return _dismissButton;
}


- (void)clickDismissPickerViewButton:(UIButton *)button {
    [button removeFromSuperview];
}

// ================================================= senseTime 相关使用 start =================================================

#pragma mark - senseTime

- (void)addSenseTimeUIViews {
    CGFloat space = ((SCREEN_WIDTH - self.recordButton.frame.size.width)/2 - self.specialEffectsBtn.frame.size.width - self.beautyBtn.frame.size.width) /3;
    
    [self.view addSubview:_specialEffectsBtn];
    [_specialEffectsBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.recordButton);
        make.right.equalTo(self.recordButton.mas_left).offset(-space);
    }];
    
    [self.view addSubview:_beautyBtn];
    [_beautyBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.recordButton);
        make.right.equalTo(self.specialEffectsBtn.mas_left).offset(-space);
    }];
    
    [self.view addSubview:self.specialEffectsContainerView];
    [self.view addSubview:self.beautyContainerView];
    
    [self.view addSubview:self.triggerView];
    [self.view addSubview:self.filterStrengthView];
    [self.view addSubview:self.beautySlider];
    
    [self.view addSubview:self.specialEffectsBtn]; // 特效
    [self.view addSubview:self.beautyBtn];         // 美颜
    [self.view addSubview:self.resetBtn];          // 重置
}

- (void)setupSenseTime {
    self.audioPlayer = [[STEffectsAudioPlayer alloc] init];
    self.audioPlayer.delegate = self;
    
    messageManager = [[STEffectsMessageManager alloc] init];
    messageManager.delegate = self;
    
    self.motionManager = [[CMMotionManager alloc] init];
    self.motionManager.accelerometerUpdateInterval = 0.5;
    self.motionManager.deviceMotionUpdateInterval = 1 / 25.0;
    
    [self setupThumbnailCache];
    [self setupSenseArService];
}

- (void)setupThumbnailCache {
    self.thumbDownlaodQueue = dispatch_queue_create("com.sensetime.thumbDownloadQueue", NULL);
    self.imageLoadQueue = [[NSOperationQueue alloc] init];
    self.imageLoadQueue.maxConcurrentOperationCount = 20;
    
    self.thumbnailCache = [[STCustomMemoryCache alloc] init];
    self.fManager = [[NSFileManager alloc] init];
    
    // 可以根据实际情况实现素材列表缩略图的缓存策略 , 这里仅做演示 .
    self.strThumbnailPath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"senseme_thumbnail"];
    
    NSError *error = nil;
    BOOL bCreateSucceed = [self.fManager createDirectoryAtPath:self.strThumbnailPath
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&error];
    if (!bCreateSucceed || error) {
        NSLog(@"create thumbnail cache directory failed !");
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"创建列表图片缓存文件夹失败" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil, nil];
        [alert show];
    }
}

#pragma - mark Setup Service

- (void)setupSenseArService {
    STWeakSelf;
    [[SenseArMaterialService sharedInstance]
     authorizeWithAppID:@"6dc0af51b69247d0af4b0a676e11b5ee"
     appKey:@"e4156e4d61b040d2bcbf896c798d06e3"
     onSuccess:^{
         weakSelf.licenseData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SENSEME" ofType:@"lic"]];
         dispatch_async(dispatch_get_main_queue(), ^{
             [weakSelf initResourceAndStartPreview];
         });
         [[SenseArMaterialService sharedInstance] setMaxCacheSize:120000000];
         [weakSelf fetchLists];
     }
     onFailure:^(SenseArAuthorizeError iErrorCode) {
         dispatch_async(dispatch_get_main_queue(), ^{
             UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误提示" message:@"" delegate:nil cancelButtonTitle:@"好" otherButtonTitles:nil, nil];
             switch (iErrorCode) {
                 case AUTHORIZE_ERROR_KEY_NOT_MATCHED:
                 {
                     [alert setMessage:@"无效 AppID/SDKKey"];
                 }
                     break;
                 case AUTHORIZE_ERROR_NETWORK_NOT_AVAILABLE:
                 {
                     [alert setMessage:@"网络不可用"];
                 }
                     break;
                 case AUTHORIZE_ERROR_DECRYPT_FAILED:
                 {
                     [alert setMessage:@"解密失败"];
                 }
                     break;
                 case AUTHORIZE_ERROR_DATA_PARSE_FAILED:
                 {
                     [alert setMessage:@"解析失败"];
                 }
                     break;
                 case AUTHORIZE_ERROR_UNKNOWN:
                 {
                     [alert setMessage:@"未知错误"];
                 }
                     break;
                 default:
                     break;
             }
             [alert show];
         });
     }];
}

- (void)fetchLists {
    self.effectsDataSource = [[STCustomMemoryCache alloc] init];
    NSString *strLocalBundlePath = [[NSBundle mainBundle] pathForResource:@"my_sticker" ofType:@"bundle"];
    if (strLocalBundlePath) {
        NSMutableArray *arrLocalModels = [NSMutableArray array];
        NSFileManager *fManager = [[NSFileManager alloc] init];
        NSArray *arrFiles = [fManager contentsOfDirectoryAtPath:strLocalBundlePath error:nil];
        int indexOfItem = 0;
        for (NSString *strFileName in arrFiles) {
            if ([strFileName hasSuffix:@".zip"]) {
                NSString *strMaterialPath = [strLocalBundlePath stringByAppendingPathComponent:strFileName];
                NSString *strThumbPath = [[strMaterialPath stringByDeletingPathExtension] stringByAppendingString:@".png"];
                UIImage *imageThumb = [UIImage imageWithContentsOfFile:strThumbPath];
                if (!imageThumb) {
                    imageThumb = [UIImage imageNamed:@"none"];
                }
                
                EffectsCollectionViewCellModel *model = [[EffectsCollectionViewCellModel alloc] init];
                model.iEffetsType = STEffectsTypeStickerMy;
                model.state = Downloaded;
                model.indexOfItem = indexOfItem;
                model.imageThumb = imageThumb;
                model.strMaterialPath = strMaterialPath;
                [arrLocalModels addObject:model];
                indexOfItem ++;
            }
        }
        
        NSString *strDocumentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        NSString *localStickerPath = [strDocumentsPath stringByAppendingPathComponent:@"local_sticker"];
        if (![fManager fileExistsAtPath:localStickerPath]) {
            [fManager createDirectoryAtPath:localStickerPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        NSArray *arrFileNames = [fManager contentsOfDirectoryAtPath:localStickerPath error:nil];
        for (NSString *strFileName in arrFileNames) {
            if ([strFileName hasSuffix:@"zip"]) {
                NSString *strMaterialPath = [localStickerPath stringByAppendingPathComponent:strFileName];
                NSString *strThumbPath = [[strMaterialPath stringByDeletingPathExtension] stringByAppendingString:@".png"];
                UIImage *imageThumb = [UIImage imageWithContentsOfFile:strThumbPath];
                
                if (!imageThumb) {
                    imageThumb = [UIImage imageNamed:@"none"];
                }
                
                EffectsCollectionViewCellModel *model = [[EffectsCollectionViewCellModel alloc] init];
                model.iEffetsType = STEffectsTypeStickerMy;
                model.state = Downloaded;
                model.indexOfItem = indexOfItem;
                model.imageThumb = imageThumb;
                model.strMaterialPath = strMaterialPath;
                [arrLocalModels addObject:model];
                indexOfItem ++;
            }
        }
        [self.effectsDataSource setObject:arrLocalModels
                                   forKey:@(STEffectsTypeStickerMy)];
        self.arrCurrentModels = arrLocalModels;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.effectsList reloadData];
        });
    }
    [self fetchMaterialsAndReloadDataWithGroupID:@"ff81fc70f6c111e899f602f2be7c2171"
                                            type:STEffectsTypeStickerNew];
    [self fetchMaterialsAndReloadDataWithGroupID:@"3cd2dae0f6c211e8877702f2beb67403"
                                            type:STEffectsTypeSticker2D];
    [self fetchMaterialsAndReloadDataWithGroupID:@"46028a20f6c211e888ea020d88863a42"
                                            type:STEffectsTypeStickerAvatar];
    [self fetchMaterialsAndReloadDataWithGroupID:@"4e869010f6c211e888ea020d88863a42"
                                            type:STEffectsTypeSticker3D];
    [self fetchMaterialsAndReloadDataWithGroupID:@"5aea6840f6c211e899f602f2be7c2171"
                                            type:STEffectsTypeStickerGesture];
    [self fetchMaterialsAndReloadDataWithGroupID:@"65365cf0f6c211e8877702f2beb67403"
                                            type:STEffectsTypeStickerSegment];
    [self fetchMaterialsAndReloadDataWithGroupID:@"6d036ef0f6c211e899f602f2be7c2171"
                                            type:STEffectsTypeStickerFaceDeformation];
    [self fetchMaterialsAndReloadDataWithGroupID:@"73bffb50f6c211e899f602f2be7c2171"
                                            type:STEffectsTypeStickerFaceChange];
    [self fetchMaterialsAndReloadDataWithGroupID:@"7c6089f0f6c211e8877702f2beb67403"
                                            type:STEffectsTypeStickerParticle];
}

- (void)fetchMaterialsAndReloadDataWithGroupID:(NSString *)strGroupID
                                          type:(STEffectsType)iType {
    __weak typeof(self) weakSelf = self;
    [[SenseArMaterialService sharedInstance]
     fetchMaterialsWithUserID:@"testUserID"
     GroupID:strGroupID
     onSuccess:^(NSArray<SenseArMaterial *> *arrMaterials) {
         NSMutableArray *arrModels = [NSMutableArray array];
         for (int i = 0; i < arrMaterials.count; i ++) {
             SenseArMaterial *material = [arrMaterials objectAtIndex:i];
             EffectsCollectionViewCellModel *model = [[EffectsCollectionViewCellModel alloc] init];
             model.material = material;
             model.indexOfItem = i;
             model.state = [[SenseArMaterialService sharedInstance] isMaterialDownloaded:material] ? Downloaded : NotDownloaded;
             model.iEffetsType = iType;
             if (material.strMaterialPath) {
                 model.strMaterialPath = material.strMaterialPath;
             }
             [arrModels addObject:model];
         }
         [weakSelf.effectsDataSource setObject:arrModels forKey:@(iType)];
         
         if (iType == weakSelf.curEffectStickerType) {
             dispatch_async(dispatch_get_main_queue(), ^{
                 [weakSelf.effectsList reloadData];
             });
         }
         
         for (EffectsCollectionViewCellModel *model in arrModels) {
             dispatch_async(weakSelf.thumbDownlaodQueue, ^{
                 [weakSelf cacheThumbnailOfModel:model];
             });
         }
     }
     onFailure:^(int iErrorCode, NSString *strMessage)
     {
         dispatch_async(dispatch_get_main_queue(), ^{
             UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil];
             [alert setMessage:@"获取贴纸列表失败"];
             [alert show];
         });
     }];
}

- (void)cacheThumbnailOfModel:(EffectsCollectionViewCellModel *)model {
    NSString *strFileID = model.material.strMaterialFileID;
    id cacheObj = [self.thumbnailCache objectForKey:strFileID];
    if (!cacheObj || ![cacheObj isKindOfClass:[UIImage class]]) {
        NSString *strThumbnailImagePath = [self.strThumbnailPath stringByAppendingPathComponent:strFileID];
        if (![self.fManager fileExistsAtPath:strThumbnailImagePath]) {
            [self.thumbnailCache setObject:strFileID forKey:strFileID];
            
            __weak typeof(self) weakSelf = self;
            [weakSelf.imageLoadQueue addOperationWithBlock:^{
                UIImage *imageDownloaded = nil;
                if ([model.material.strThumbnailURL isKindOfClass:[NSString class]]) {
                    NSError *error = nil;
                    NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:model.material.strThumbnailURL] options:NSDataReadingMappedIfSafe error:&error];
                    imageDownloaded = [UIImage imageWithData:imageData];
                    
                    if (imageDownloaded) {
                        if ([weakSelf.fManager createFileAtPath:strThumbnailImagePath contents:imageData attributes:nil]) {
                            [weakSelf.thumbnailCache setObject:imageDownloaded forKey:strFileID];
                        }else{
                            [weakSelf.thumbnailCache removeObjectForKey:strFileID];
                        }
                    }else{
                        [weakSelf.thumbnailCache removeObjectForKey:strFileID];
                    }
                }else{
                    [weakSelf.thumbnailCache removeObjectForKey:strFileID];
                }
                
                model.imageThumb = imageDownloaded;
                if (weakSelf.curEffectStickerType == model.iEffetsType) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf.effectsList reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:model.indexOfItem inSection:0]]];
                    });
                }
            }];
        }else{
            UIImage *image = [UIImage imageWithContentsOfFile:strThumbnailImagePath];
            if (image) {
                [self.thumbnailCache setObject:image forKey:strFileID];
            }else{
                [self.fManager removeItemAtPath:strThumbnailImagePath error:nil];
            }
        }
    }
}

#pragma mark - setup handle

- (void)setupHandle {
    st_result_t iRet = ST_OK;
    //初始化检测模块句柄
    NSString *strModelPath = [[NSBundle mainBundle] pathForResource:@"M_SenseME_Face_Video_5.3.3" ofType:@"model"];
    uint32_t config = ST_MOBILE_HUMAN_ACTION_DEFAULT_CONFIG_VIDEO;
    
    TIMELOG(key);
    
    iRet = st_mobile_human_action_create(strModelPath.UTF8String, config, &_hDetector);
    
    TIMEPRINT(key,"human action create time:");
    
    if (ST_OK != iRet || !_hDetector) {
        NSLog(@"st mobile human action create failed: %d", iRet);
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误提示" message:@"算法SDK初始化失败，可能是模型路径错误，SDK权限过期，与绑定包名不符" delegate:nil cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
        [alert show];
    } else {
        addSubModel(_hDetector, @"M_SenseME_Face_Extra_5.6.0");
        addSubModel(_hDetector, @"M_SenseME_Iris_1.11.1");
        addSubModel(_hDetector, @"M_SenseME_Hand_5.4.0");
        addSubModel(_hDetector, @"M_SenseME_Segment_1.5.0");
    }
    
    //猫脸检测
    NSString *catFaceModel = [[NSBundle mainBundle] pathForResource:@"M_SenseME_CatFace_1.0.0" ofType:@"model"];
    TIMELOG(keyCat);
    
    iRet = st_mobile_tracker_animal_face_create(catFaceModel.UTF8String, ST_MOBILE_TRACKING_MULTI_THREAD, &_animalHandle);
    TIMEPRINT(keyCat, "cat handle create time:")
    
    if (iRet != ST_OK || !_animalHandle) {
        NSLog(@"st mobile tracker animal face create failed: %d", iRet);
    }
#if TEST_AVATAR_EXPRESSION
    //avatar expression
    //如要获取avatar表情信息，需创建avatar句柄
    NSString *strAvatarModelPath = [[NSBundle mainBundle] pathForResource:@"M_SenseME_Avatar_Core_2.0.0" ofType:@"model"];
    iRet = st_mobile_avatar_create(&_avatarHandle, strAvatarModelPath.UTF8String);
    if (iRet != ST_OK) {
        NSLog(@"st mobile avatar create failed: %d", iRet);
    } else {
        //然后获取此功能需要human action检测的参数(即st_mobile_human_action_detect接口需要传入的config参数，例如avatar需要获取眼球关键点信息，st_mobile_avatar_get_detect_config就会返回眼球检测的config，通常会返回多个检测的`|`)
        self.avatarConfig = st_mobile_avatar_get_detect_config(_avatarHandle);
    }
#endif
    
    //初始化贴纸模块句柄 , 默认开始时无贴纸 , 所以第一个路径参数传空
    TIMELOG(keySticker);
    
    iRet = st_mobile_sticker_create(&_hSticker);
    TIMEPRINT(keySticker, "sticker create time:");
    
    if (ST_OK != iRet || !_hSticker) {
        NSLog(@"st mobile sticker create failed: %d", iRet);
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误提示" message:@"贴纸SDK初始化失败 , SDK权限过期，或者与绑定包名不符" delegate:nil cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
        [alert show];
    } else {
        iRet = st_mobile_sticker_set_param_ptr(_hSticker, -1, ST_STICKER_PARAM_SOUND_LOAD_FUNC_PTR, load_sound);
        if (iRet != ST_OK) {
            NSLog(@"st mobile set load sound func failed: %d", iRet);
        }
        
        iRet = st_mobile_sticker_set_param_ptr(_hSticker, -1, ST_STICKER_PARAM_SOUND_PLAY_FUNC_PTR, play_sound);
        if (iRet != ST_OK) {
            NSLog(@"st mobile set play sound func failed: %d", iRet);
        }
        
        iRet = st_mobile_sticker_set_param_ptr(_hSticker, -1, ST_STICKER_PARAM_SOUND_PAUSE_FUNC_PTR, pause_sound);
        if (iRet != ST_OK) {
            NSLog(@"st mobile set pause sound func failed: %d", iRet);
        }
        
        iRet = st_mobile_sticker_set_param_ptr(_hSticker, -1, ST_STICKER_PARAM_SOUND_RESUME_FUNC_PTR, resume_sound);
        if (iRet != ST_OK) {
            NSLog(@"st mobile set resume sound func failed: %d", iRet);
        }
        
        iRet = st_mobile_sticker_set_param_ptr(_hSticker, -1, ST_STICKER_PARAM_SOUND_STOP_FUNC_PTR, stop_sound);
        if (iRet != ST_OK) {
            NSLog(@"st mobile set stop sound func failed: %d", iRet);
        }
        
        iRet = st_mobile_sticker_set_param_ptr(_hSticker, -1, ST_STICKER_PARAM_SOUND_UNLOAD_FUNC_PTR, unload_sound);
        if (iRet != ST_OK) {
            NSLog(@"st mobile set unload sound func failed: %d", iRet);
        }
        
        NSString *strAvatarModelPath = [[NSBundle mainBundle] pathForResource:@"M_SenseME_Avatar_Core_2.0.0" ofType:@"model"];
        iRet = st_mobile_sticker_load_avatar_model(_hSticker, strAvatarModelPath.UTF8String);
        if (iRet != ST_OK) {
            NSLog(@"load avatar model failed: %d", iRet);
        }
    }
    //初始化美颜模块句柄
    iRet = st_mobile_beautify_create(&_hBeautify);
    if (ST_OK != iRet || !_hBeautify) {
        NSLog(@"st mobile beautify create failed: %d", iRet);
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误提示" message:@"美颜SDK初始化失败，可能是模型路径错误，SDK权限过期，与绑定包名不符" delegate:nil cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
        [alert show];
    } else{
        // 设置默认红润参数
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_REDDEN_STRENGTH, self.fReddenStrength);
        // 设置默认磨皮参数
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_SMOOTH_STRENGTH, self.fSmoothStrength);
        // 设置默认大眼参数
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_ENLARGE_EYE_RATIO, self.fEnlargeEyeStrength);
        // 设置默认瘦脸参数
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_SHRINK_FACE_RATIO, self.fShrinkFaceStrength);
        // 设置小脸参数
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_SHRINK_JAW_RATIO, self.fShrinkJawStrength);
        // 设置美白参数
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_WHITEN_STRENGTH, self.fWhitenStrength);
        //设置对比度参数
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_CONTRAST_STRENGTH, self.fContrastStrength);
        //设置饱和度参数
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_SATURATION_STRENGTH, self.fSaturationStrength);
        //去高光参数
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_DEHIGHLIGHT_STRENGTH, self.fDehighlightStrength);
        //瘦脸型
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_THIN_FACE_SHAPE_RATIO, self.fThinFaceShapeStrength);
        //窄脸
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_NARROW_FACE_STRENGTH, self.fNarrowFaceStrength);
        //下巴
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_CHIN_LENGTH_RATIO, self.fChinStrength);
        //额头
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_HAIRLINE_HEIGHT_RATIO, self.fHairLineStrength);
        //瘦鼻翼
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_NARROW_NOSE_RATIO, self.fNarrowNoseStrength);
        //长鼻
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_NOSE_LENGTH_RATIO, self.fLongNoseStrength);
        //嘴形
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_MOUTH_SIZE_RATIO, self.fMouthStrength);
        //缩人中
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_PHILTRUM_LENGTH_RATIO, self.fPhiltrumStrength);
        
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_APPLE_MUSLE_RATIO, self.fAppleMusleStrength);
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_PROFILE_RHINOPLASTY_RATIO, self.fProfileRhinoplastyStrength);
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_EYE_DISTANCE_RATIO, self.fEyeDistanceStrength);
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_EYE_ANGLE_RATIO, self.fEyeAngleStrength);
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_OPEN_CANTHUS_RATIO, self.fOpenCanthusStrength);
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_BRIGHT_EYE_RATIO, self.fBrightEyeStrength);
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_REMOVE_DARK_CIRCLES_RATIO, self.fRemoveDarkCirclesStrength);
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_REMOVE_NASOLABIAL_FOLDS_RATIO, self.fRemoveNasolabialFoldsStrength);
        setBeautifyParam(_hBeautify, ST_BEAUTIFY_3D_WHITE_TEETH_RATIO, self.fWhiteTeethStrength);
    }
    
    // 初始化滤镜句柄
    iRet = st_mobile_gl_filter_create(&_hFilter);
    
    if (ST_OK != iRet || !_hFilter) {
        NSLog(@"st mobile gl filter create failed: %d", iRet);
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误提示" message:@"滤镜SDK初始化失败，可能是SDK权限过期或与绑定包名不符" delegate:nil cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
        [alert show];
    }
    
    // 初始化通用物体追踪句柄
    iRet = st_mobile_object_tracker_create(&_hTracker);
    
    if (ST_OK != iRet || !_hTracker) {
        NSLog(@"st mobile object tracker create failed: %d", iRet);
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误提示" message:@"通用物体跟踪SDK初始化失败，可能是SDK权限过期或与绑定包名不符" delegate:nil cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
        [alert show];
    }
}

- (BOOL)checkActiveCodeWithData:(NSData *)dataLicense {
    NSString *strKeyActiveCode = @"ACTIVE_CODE_ONLINE";
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *strActiveCode = [userDefaults objectForKey:strKeyActiveCode];
    st_result_t iRet = ST_E_FAIL;
    
    iRet = st_mobile_check_activecode_from_buffer(
                                                  [dataLicense bytes],
                                                  (int)[dataLicense length],
                                                  strActiveCode.UTF8String,
                                                  (int)[strActiveCode length]
                                                  );
    
    if (ST_OK == iRet) {
        return YES;
    }
    
    char active_code[1024];
    int active_code_len = 1024;
    
    iRet = st_mobile_generate_activecode_from_buffer(
                                                     [dataLicense bytes],
                                                     (int)[dataLicense length],
                                                     active_code,
                                                     &active_code_len
                                                     );
    strActiveCode = [[NSString alloc] initWithUTF8String:active_code];
    
    if (iRet == ST_OK && strActiveCode.length) {
        [userDefaults setObject:strActiveCode forKey:strKeyActiveCode];
        [userDefaults synchronize];
        return YES;
    }
    return NO;
}

#pragma mark - sound
void load_sound(void* handle, void* sound, const char* sound_name, int length) {
    if ([messageManager.delegate respondsToSelector:@selector(loadSound:name:)]) {
        NSData *soundData = [NSData dataWithBytes:sound length:length];
        NSString *strName = [NSString stringWithUTF8String:sound_name];
        [messageManager.delegate loadSound:soundData name:strName];
    }
}

void play_sound(void* handle, const char* sound_name, int loop) {
    if ([messageManager.delegate respondsToSelector:@selector(playSound:loop:)]) {
        NSString *strName = [NSString stringWithUTF8String:sound_name];
        [messageManager.delegate playSound:strName loop:loop];
    }
}

void pause_sound(void *handle, const char *sound_name) {
    if ([messageManager.delegate respondsToSelector:@selector(pauseSound:)]) {
        NSString *strName = [NSString stringWithUTF8String:sound_name];
        [messageManager.delegate pauseSound:strName];
    }
}

void resume_sound(void *handle, const char *sound_name) {
    if ([messageManager.delegate respondsToSelector:@selector(resumeSound:)]) {
        NSString *strName = [NSString stringWithUTF8String:sound_name];
        [messageManager.delegate resumeSound:strName];
    }
}

void stop_sound(void* handle, const char* sound_name) {
    if ([messageManager.delegate respondsToSelector:@selector(stopSound:)]) {
        NSString *strName = [NSString stringWithUTF8String:sound_name];
        [messageManager.delegate stopSound:strName];
    }
}

void unload_sound(void *handle, const char *sound_name) {
    if ([messageManager.delegate respondsToSelector:@selector(unloadSound:)]) {
        NSString *strName = [NSString stringWithUTF8String:sound_name];
        [messageManager.delegate unloadSound:strName];
    }
}

#pragma mark - STEffectsMessageManagerDelegate

- (void)loadSound:(NSData *)soundData name:(NSString *)strName {
    if ([self.audioPlayer loadSound:soundData name:strName]) {
        NSLog(@"STEffectsAudioPlayer load %@ successfully", strName);
    }
}

- (void)playSound:(NSString *)strName loop:(int)iLoop {
    if ([self.audioPlayer playSound:strName loop:iLoop]) {
        NSLog(@"STEffectsAudioPlayer play %@ successfully", strName);
    }
}

- (void)pauseSound:(NSString *)strName {
    [self.audioPlayer pauseSound:strName];
}

- (void)resumeSound:(NSString *)strName {
    [self.audioPlayer resumeSound:strName];
}

- (void)stopSound:(NSString *)strName {
    [self.audioPlayer stopSound:strName];
}

- (void)unloadSound:(NSString *)strName {
    [self.audioPlayer unloadSound:strName];
}

#pragma mark - handle texture

- (void)initResultTexture {
    // 创建结果纹理
    [self setupTextureWithPixelBuffer:&_cvBeautifyBuffer
                                    w:self.imageWidth
                                    h:self.imageHeight
                            glTexture:&_textureBeautifyOutput
                            cvTexture:&_cvTextureBeautify];
    
    [self setupTextureWithPixelBuffer:&_cvStickerBuffer
                                    w:self.imageWidth
                                    h:self.imageHeight
                            glTexture:&_textureStickerOutput
                            cvTexture:&_cvTextureSticker];
    
    
    [self setupTextureWithPixelBuffer:&_cvFilterBuffer
                                    w:self.imageWidth
                                    h:self.imageHeight
                            glTexture:&_textureFilterOutput
                            cvTexture:&_cvTextureFilter];
}

- (BOOL)setupTextureWithPixelBuffer:(CVPixelBufferRef *)pixelBufferOut
                                  w:(int)iWidth
                                  h:(int)iHeight
                          glTexture:(GLuint *)glTexture
                          cvTexture:(CVOpenGLESTextureRef *)cvTexture {
    CFDictionaryRef empty = CFDictionaryCreate(kCFAllocatorDefault,
                                               NULL,
                                               NULL,
                                               0,
                                               &kCFTypeDictionaryKeyCallBacks,
                                               &kCFTypeDictionaryValueCallBacks);
    
    CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                             1,
                                                             &kCFTypeDictionaryKeyCallBacks,
                                                             &kCFTypeDictionaryValueCallBacks);
    
    CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, empty);
    
    CVReturn cvRet = CVPixelBufferCreate(kCFAllocatorDefault,
                                         iWidth,
                                         iHeight,
                                         kCVPixelFormatType_32BGRA,
                                         attrs,
                                         pixelBufferOut);
    
    if (kCVReturnSuccess != cvRet) {
        NSLog(@"CVPixelBufferCreate %d" , cvRet);
    }
    
    cvRet = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                         _cvTextureCache,
                                                         *pixelBufferOut,
                                                         NULL,
                                                         GL_TEXTURE_2D,
                                                         GL_RGBA,
                                                         self.imageWidth,
                                                         self.imageHeight,
                                                         GL_BGRA,
                                                         GL_UNSIGNED_BYTE,
                                                         0,
                                                         cvTexture);
    
    CFRelease(attrs);
    CFRelease(empty);
    
    if (kCVReturnSuccess != cvRet) {
        NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage %d" , cvRet);
        return NO;
    }
    
    *glTexture = CVOpenGLESTextureGetName(*cvTexture);
    glBindTexture(CVOpenGLESTextureGetTarget(*cvTexture), *glTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    return YES;
}

- (BOOL)setupOriginTextureWithPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    CVReturn cvRet = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                  _cvTextureCache,
                                                                  pixelBuffer,
                                                                  NULL,
                                                                  GL_TEXTURE_2D,
                                                                  GL_RGBA,
                                                                  self.imageWidth,
                                                                  self.imageHeight,
                                                                  GL_BGRA,
                                                                  GL_UNSIGNED_BYTE,
                                                                  0,
                                                                  &_cvTextureOrigin);
    
    if (!_cvTextureOrigin || kCVReturnSuccess != cvRet) {
        NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage %d" , cvRet);
        return NO;
    }
    
    _textureOriginInput = CVOpenGLESTextureGetName(_cvTextureOrigin);
    glBindTexture(GL_TEXTURE_2D , _textureOriginInput);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    return YES;
}

- (void)releaseResultTexture {
    _textureBeautifyOutput = 0;
    _textureStickerOutput = 0;
    _textureFilterOutput = 0;
    
    if (_cvTextureOrigin) {
        CFRelease(_cvTextureOrigin);
        _cvTextureOrigin = NULL;
    }
    
    CFRelease(_cvTextureBeautify);
    CFRelease(_cvTextureSticker);
    CFRelease(_cvTextureFilter);
    
    CVPixelBufferRelease(_cvBeautifyBuffer);
    CVPixelBufferRelease(_cvStickerBuffer);
    CVPixelBufferRelease(_cvFilterBuffer);
}

- (void)setDefaultValue {
    self.bBeauty = YES;
    self.bFilter = NO;
    self.bSticker = NO;
    self.bTracker = NO;
    self.needDetectAnimal = NO;
    self.isNullSticker = NO;
    
    self.fFilterStrength = 0.65;
    self.iCurrentAction = 0;

    self.imageWidth = 720;
    self.imageHeight = 1280;
    
    self.preFilterModelPath = nil;
    self.curFilterModelPath = nil;
    
    self.curEffectBeautyType = STEffectsTypeBeautyBase;
    
    self.microSurgeryModels = @[
                                getModel([UIImage imageNamed:@"zhailian"], [UIImage imageNamed:@"zhailian_selected"], @"瘦脸型", 0, NO, 0, STEffectsTypeBeautyMicroSurgery, STBeautyTypeThinFaceShape),
                                getModel([UIImage imageNamed:@"xiaba"], [UIImage imageNamed:@"xiaba_selected"], @"下巴", 0, NO, 1, STEffectsTypeBeautyMicroSurgery, STBeautyTypeChin),
                                getModel([UIImage imageNamed:@"etou"], [UIImage imageNamed:@"etou_selected"], @"额头", 0, NO, 2, STEffectsTypeBeautyMicroSurgery, STBeautyTypeHairLine),
                                getModel([UIImage imageNamed:@"pingguoji"], [UIImage imageNamed:@"pingguoji_selected"], @"苹果肌", 0, NO, 3, STEffectsTypeBeautyMicroSurgery, STBeautyTypeAppleMusle),
                                getModel([UIImage imageNamed:@"shoubiyi"], [UIImage imageNamed:@"shoubiyi_selected"], @"瘦鼻翼", 0, NO, 4, STEffectsTypeBeautyMicroSurgery, STBeautyTypeNarrowNose),
                                getModel([UIImage imageNamed:@"changbi"], [UIImage imageNamed:@"changbi_selected"], @"长鼻", 0, NO, 5, STEffectsTypeBeautyMicroSurgery, STBeautyTypeLengthNose),
                                getModel([UIImage imageNamed:@"cebi"], [UIImage imageNamed:@"cebi_selected"], @"侧脸隆鼻", 0, NO, 6, STEffectsTypeBeautyMicroSurgery, STBeautyTypeProfileRhinoplasty),
                                getModel([UIImage imageNamed:@"zuixing"], [UIImage imageNamed:@"zuixing_selected"], @"嘴形", 0, NO, 7, STEffectsTypeBeautyMicroSurgery, STBeautyTypeMouthSize),
                                getModel([UIImage imageNamed:@"suorenzhong"], [UIImage imageNamed:@"suorenzhong_selected"], @"缩人中", 0, NO, 8, STEffectsTypeBeautyMicroSurgery, STBeautyTypeLengthPhiltrum),
                                getModel([UIImage imageNamed:@"yanju"], [UIImage imageNamed:@"yanju_selected"], @"眼距", 0, NO, 9, STEffectsTypeBeautyMicroSurgery, STBeautyTypeEyeDistance),
                                getModel([UIImage imageNamed:@"weiyan"], [UIImage imageNamed:@"weiyan_selected"], @"眼睛角度", 0, NO, 10, STEffectsTypeBeautyMicroSurgery, STBeautyTypeEyeAngle),
                                getModel([UIImage imageNamed:@"yanjiao"], [UIImage imageNamed:@"yanjiao_selected"], @"开眼角", 0, NO, 11, STEffectsTypeBeautyMicroSurgery, STBeautyTypeOpenCanthus),
                                getModel([UIImage imageNamed:@"liangyan"], [UIImage imageNamed:@"liangyan_selected"], @"亮眼", 0, NO, 12, STEffectsTypeBeautyMicroSurgery, STBeautyTypeBrightEye),
                                getModel([UIImage imageNamed:@"heiyanquan"], [UIImage imageNamed:@"heiyanquan_selected"], @"祛黑眼圈", 0, NO, 13, STEffectsTypeBeautyMicroSurgery, STBeautyTypeRemoveDarkCircles),
                                getModel([UIImage imageNamed:@"falingwen"], [UIImage imageNamed:@"falingwen_selected"], @"祛法令纹", 0, NO, 14, STEffectsTypeBeautyMicroSurgery, STBeautyTypeRemoveNasolabialFolds),
                                getModel([UIImage imageNamed:@"yachi"], [UIImage imageNamed:@"yachi_selected"], @"白牙", 0, NO, 15, STEffectsTypeBeautyMicroSurgery, STBeautyTypeWhiteTeeth),
                                ];
    
    self.baseBeautyModels = @[
                              getModel([UIImage imageNamed:@"meibai"], [UIImage imageNamed:@"meibai_selected"], @"美白", 2, NO, 0, STEffectsTypeBeautyBase, STBeautyTypeWhiten),
                              getModel([UIImage imageNamed:@"hongrun"], [UIImage imageNamed:@"hongrun_selected"], @"红润", 36, NO, 1, STEffectsTypeBeautyBase, STBeautyTypeRuddy),
                              getModel([UIImage imageNamed:@"mopi"], [UIImage imageNamed:@"mopi_selected"], @"磨皮", 74, NO, 2, STEffectsTypeBeautyBase, STBeautyTypeDermabrasion),
                              getModel([UIImage imageNamed:@"qugaoguang"], [UIImage imageNamed:@"qugaoguang_selected"], @"去高光", 0, NO, 3, STEffectsTypeBeautyBase, STBeautyTypeDehighlight),
                              ];
    self.beautyShapeModels = @[
                               getModel([UIImage imageNamed:@"shoulian"], [UIImage imageNamed:@"shoulian_selected"], @"瘦脸", 11, NO, 0, STEffectsTypeBeautyShape, STBeautyTypeShrinkFace),
                               getModel([UIImage imageNamed:@"dayan"], [UIImage imageNamed:@"dayan_selected"], @"大眼", 13, NO, 1, STEffectsTypeBeautyShape, STBeautyTypeEnlargeEyes),
                               getModel([UIImage imageNamed:@"xiaolian"], [UIImage imageNamed:@"xiaolian_selected"], @"小脸", 10, NO, 2, STEffectsTypeBeautyShape, STBeautyTypeShrinkJaw),
                               getModel([UIImage imageNamed:@"zhailian2"], [UIImage imageNamed:@"zhailian2_selected"], @"窄脸", 0, NO, 3, STEffectsTypeBeautyShape, STBeautyTypeNarrowFace)
                               ];
    self.adjustModels = @[
                          getModel([UIImage imageNamed:@"contrast"], [UIImage imageNamed:@"contrast_selected"], @"对比度", 0, NO, 0, STEffectsTypeBeautyAdjust, STBeautyTypeContrast),
                          getModel([UIImage imageNamed:@"saturation"], [UIImage imageNamed:@"saturation_selected"], @"饱和度", 0, NO, 1, STEffectsTypeBeautyAdjust, STBeautyTypeSaturation),
                          ];
}

#pragma mark - draw points

- (void)drawKeyPoints:(st_mobile_human_action_t)detectResult {
    for (int i = 0; i < detectResult.face_count; ++i) {
        for (int j = 0; j < 106; ++j) {
            [_faceArray addObject:@{
                                    POINT_KEY: [NSValue valueWithCGPoint:[self coordinateTransformation:detectResult.p_faces[i].face106.points_array[j]]]
                                    }];
        }
        
        if (detectResult.p_faces[i].p_extra_face_points && detectResult.p_faces[i].extra_face_points_count > 0) {
            for (int j = 0; j < detectResult.p_faces[i].extra_face_points_count; ++j) {
                [_faceArray addObject:@{
                                        POINT_KEY: [NSValue valueWithCGPoint:[self coordinateTransformation:detectResult.p_faces[i].p_extra_face_points[j]]]
                                        }];
            }
        }
        
        if (detectResult.p_faces[i].p_eyeball_contour && detectResult.p_faces[i].eyeball_contour_points_count > 0) {
            for (int j = 0; j < detectResult.p_faces[i].eyeball_contour_points_count; ++j) {
                [_faceArray addObject:@{
                                        POINT_KEY: [NSValue valueWithCGPoint:[self coordinateTransformation:detectResult.p_faces[i].p_eyeball_contour[j]]]
                                        }];
            }
        }
    }
    
    if (detectResult.p_bodys && detectResult.body_count > 0) {
        for (int j = 0; j < detectResult.p_bodys[0].key_points_count; ++j) {
            if (detectResult.p_bodys[0].p_key_points_score[j] > 0.15) {
                [_faceArray addObject:@{
                                        POINT_KEY: [NSValue valueWithCGPoint:[self coordinateTransformation:detectResult.p_bodys[0].p_key_points[j]]]
                                        }];
            }
        }
    }
    self.commonObjectContainerView.faceArray = [_faceArray copy];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.commonObjectContainerView setNeedsDisplay];
    });
}

- (CGPoint)coordinateTransformation:(st_pointf_t)point {
    return CGPointMake(_scale * point.x - _margin, _scale * point.y);
}

#pragma mark - lazy load views

- (STViewButton *)specialEffectsBtn {
    if (!_specialEffectsBtn) {
        _specialEffectsBtn = [[[NSBundle mainBundle] loadNibNamed:@"STViewButton" owner:nil options:nil] firstObject];
        [_specialEffectsBtn setExclusiveTouch:YES];
        
        UIImage *image = [UIImage imageNamed:@"btn_special_effects.png"];
        _specialEffectsBtn.frame = CGRectMake(0, 0, image.size.width, image.size.height);
        _specialEffectsBtn.backgroundColor = [UIColor clearColor];
        _specialEffectsBtn.imageView.image = [UIImage imageNamed:@"btn_special_effects.png"];
        _specialEffectsBtn.imageView.highlightedImage = [UIImage imageNamed:@"btn_special_effects_selected.png"];
        _specialEffectsBtn.titleLabel.textColor = [UIColor whiteColor];
        _specialEffectsBtn.titleLabel.highlightedTextColor = UIColorFromRGB(0xc086e5);
        _specialEffectsBtn.titleLabel.text = @"特效";
        _specialEffectsBtn.tag = STViewTagSpecialEffectsBtn;
        
        STWeakSelf;
        _specialEffectsBtn.tapBlock = ^{
            [weakSelf clickBottomViewButton:weakSelf.specialEffectsBtn];
        };
    }
    return _specialEffectsBtn;
}

- (STViewButton *)beautyBtn {
    if (!_beautyBtn) {
        _beautyBtn = [[[NSBundle mainBundle] loadNibNamed:@"STViewButton" owner:nil options:nil] firstObject];
        [_beautyBtn setExclusiveTouch:YES];
        
        UIImage *image = [UIImage imageNamed:@"btn_beauty.png"];
        _beautyBtn.frame = CGRectMake(0, 0, image.size.width, image.size.height);
        _beautyBtn.backgroundColor = [UIColor clearColor];
        _beautyBtn.imageView.image = [UIImage imageNamed:@"btn_beauty.png"];
        _beautyBtn.imageView.highlightedImage = [UIImage imageNamed:@"btn_beauty_selected.png"];
        _beautyBtn.titleLabel.textColor = [UIColor whiteColor];
        _beautyBtn.titleLabel.highlightedTextColor = UIColorFromRGB(0xc086e5);
        _beautyBtn.titleLabel.text = @"美颜";
        _beautyBtn.tag = STViewTagBeautyBtn;
        
        STWeakSelf;
        _beautyBtn.tapBlock = ^{
            [weakSelf clickBottomViewButton:weakSelf.beautyBtn];
        };
    }
    return _beautyBtn;
}

- (UIView *)specialEffectsContainerView {
    if (!_specialEffectsContainerView) {
        _specialEffectsContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, SCREEN_HEIGHT, SCREEN_WIDTH, STEFFECT_HEIGHT)];
        _specialEffectsContainerView.backgroundColor = [UIColor clearColor];
        
        UIView *noneStickerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 57, 40)];
        noneStickerView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        noneStickerView.layer.shadowColor = UIColorFromRGB(0x141618).CGColor;
        noneStickerView.layer.shadowOpacity = 0.5;
        noneStickerView.layer.shadowOffset = CGSizeMake(3, 3);
        
        UIImage *image = [UIImage imageNamed:@"none_sticker.png"];
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake((57 - image.size.width) / 2, (40 - image.size.height) / 2, image.size.width, image.size.height)];
        imageView.contentMode = UIViewContentModeCenter;
        imageView.image = image;
        imageView.highlightedImage = [UIImage imageNamed:@"none_sticker_selected.png"];
        _noneStickerImageView = imageView;
        
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapNoneSticker:)];
        [noneStickerView addGestureRecognizer:tapGesture];
        [noneStickerView addSubview:imageView];
        
        UIView *whiteLineView = [[UIView alloc] initWithFrame:CGRectMake(56, 3, 1, 34)];
        whiteLineView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3];
        [noneStickerView addSubview:whiteLineView];
        
        UIView *lineView = [[UIView alloc] initWithFrame:CGRectMake(0, 40, SCREEN_WIDTH, 1)];
        lineView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3];
        [_specialEffectsContainerView addSubview:lineView];
        
        [_specialEffectsContainerView addSubview:noneStickerView];
        [_specialEffectsContainerView addSubview:self.scrollTitleView];
        [_specialEffectsContainerView addSubview:self.effectsList];
        [_specialEffectsContainerView addSubview:self.objectTrackCollectionView];
        
        UIView *blankView = [[UIView alloc] initWithFrame:CGRectMake(0, 181, SCREEN_WIDTH, 50)];
        blankView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        [_specialEffectsContainerView addSubview:blankView];
    }
    return _specialEffectsContainerView;
}

- (UIView *)beautyContainerView {
    if (!_beautyContainerView) {
        _beautyContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, SCREEN_HEIGHT, SCREEN_WIDTH, STEFFECT_HEIGHT)];
        _beautyContainerView.backgroundColor = [UIColor clearColor];
        [_beautyContainerView addSubview:self.beautyScrollTitleViewNew];
        
        UIView *whiteLineView = [[UIView alloc] initWithFrame:CGRectMake(0, 40, SCREEN_WIDTH, 1)];
        whiteLineView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3];
        [_beautyContainerView addSubview:whiteLineView];
        
        [_beautyContainerView addSubview:self.filterCategoryView];
        [_beautyContainerView addSubview:self.filterView];
        [_beautyContainerView addSubview:self.beautyCollectionView];
        
        [self.arrBeautyViews addObject:self.filterCategoryView];
        [self.arrBeautyViews addObject:self.filterView];
        [self.arrBeautyViews addObject:self.beautyCollectionView];
    }
    return _beautyContainerView;
}

- (STTriggerView *)triggerView {
    if (!_triggerView) {
        _triggerView = [[STTriggerView alloc] init];
    }
    return _triggerView;
}

- (STFilterView *)filterView {
    if (!_filterView) {
        _filterView = [[STFilterView alloc] initWithFrame:CGRectMake(SCREEN_WIDTH, 41, SCREEN_WIDTH, 300)];
        _filterView.leftView.imageView.image = [UIImage imageNamed:@"still_life_highlighted"];
        _filterView.leftView.titleLabel.text = @"静物";
        _filterView.leftView.titleLabel.textColor = [UIColor whiteColor];
        
        _filterView.filterCollectionView.arrSceneryFilterModels = [self getFilterModelsByType:STEffectsTypeFilterScenery];
        _filterView.filterCollectionView.arrPortraitFilterModels = [self getFilterModelsByType:STEffectsTypeFilterPortrait];
        _filterView.filterCollectionView.arrStillLifeFilterModels = [self getFilterModelsByType:STEffectsTypeFilterStillLife];
        _filterView.filterCollectionView.arrDeliciousFoodFilterModels = [self getFilterModelsByType:STEffectsTypeFilterDeliciousFood];
        
        STWeakSelf;
        _filterView.filterCollectionView.delegateBlock = ^(STCollectionViewDisplayModel *model) {
            [weakSelf handleFilterChanged:model];
        };
        _filterView.block = ^{
            [UIView animateWithDuration:0.5 animations:^{
                weakSelf.filterCategoryView.frame = CGRectMake(0, weakSelf.filterCategoryView.frame.origin.y, SCREEN_WIDTH, 300);
                weakSelf.filterView.frame = CGRectMake(SCREEN_WIDTH, weakSelf.filterView.frame.origin.y, SCREEN_WIDTH, 300);
            }];
            weakSelf.filterStrengthView.hidden = YES;
        };
    }
    return _filterView;
}

- (UIView *)filterCategoryView {
    if (!_filterCategoryView) {
        _filterCategoryView = [[UIView alloc] initWithFrame:CGRectMake(0, 41, SCREEN_WIDTH, 300)];
        _filterCategoryView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        
        STViewButton *portraitViewBtn = [[[NSBundle mainBundle] loadNibNamed:@"STViewButton" owner:nil options:nil] firstObject];
        portraitViewBtn.tag = STEffectsTypeFilterPortrait;
        portraitViewBtn.backgroundColor = [UIColor clearColor];
        portraitViewBtn.frame =  CGRectMake(SCREEN_WIDTH / 2 - 143, 58, 33, 60);
        portraitViewBtn.imageView.image = [UIImage imageNamed:@"portrait"];
        portraitViewBtn.imageView.highlightedImage = [UIImage imageNamed:@"portrait_highlighted"];
        portraitViewBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        portraitViewBtn.titleLabel.textColor = [UIColor whiteColor];
        portraitViewBtn.titleLabel.highlightedTextColor = [UIColor whiteColor];
        portraitViewBtn.titleLabel.text = @"人物";
        
        for (UIGestureRecognizer *recognizer in portraitViewBtn.gestureRecognizers) {
            [portraitViewBtn removeGestureRecognizer:recognizer];
        }
        UITapGestureRecognizer *portraitRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(switchFilterType:)];
        [portraitViewBtn addGestureRecognizer:portraitRecognizer];
        [self.arrFilterCategoryViews addObject:portraitViewBtn];
        [_filterCategoryView addSubview:portraitViewBtn];
        
        STViewButton *sceneryViewBtn = [[[NSBundle mainBundle] loadNibNamed:@"STViewButton" owner:nil options:nil] firstObject];
        sceneryViewBtn.tag = STEffectsTypeFilterScenery;
        sceneryViewBtn.backgroundColor = [UIColor clearColor];
        sceneryViewBtn.frame =  CGRectMake(SCREEN_WIDTH / 2 - 60, 58, 33, 60);
        sceneryViewBtn.imageView.image = [UIImage imageNamed:@"scenery"];
        sceneryViewBtn.imageView.highlightedImage = [UIImage imageNamed:@"scenery_highlighted"];
        sceneryViewBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        sceneryViewBtn.titleLabel.textColor = [UIColor whiteColor];
        sceneryViewBtn.titleLabel.highlightedTextColor = [UIColor whiteColor];
        sceneryViewBtn.titleLabel.text = @"风景";
        
        for (UIGestureRecognizer *recognizer in sceneryViewBtn.gestureRecognizers) {
            [sceneryViewBtn removeGestureRecognizer:recognizer];
        }
        UITapGestureRecognizer *sceneryRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(switchFilterType:)];
        [sceneryViewBtn addGestureRecognizer:sceneryRecognizer];
        [self.arrFilterCategoryViews addObject:sceneryViewBtn];
        [_filterCategoryView addSubview:sceneryViewBtn];
        
        STViewButton *stillLifeViewBtn = [[[NSBundle mainBundle] loadNibNamed:@"STViewButton" owner:nil options:nil] firstObject];
        stillLifeViewBtn.tag = STEffectsTypeFilterStillLife;
        stillLifeViewBtn.backgroundColor = [UIColor clearColor];
        stillLifeViewBtn.frame =  CGRectMake(SCREEN_WIDTH / 2 + 27, 58, 33, 60);
        stillLifeViewBtn.imageView.image = [UIImage imageNamed:@"still_life"];
        stillLifeViewBtn.imageView.highlightedImage = [UIImage imageNamed:@"still_life_highlighted"];
        stillLifeViewBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        stillLifeViewBtn.titleLabel.textColor = [UIColor whiteColor];
        stillLifeViewBtn.titleLabel.highlightedTextColor = [UIColor whiteColor];
        stillLifeViewBtn.titleLabel.text = @"静物";
        
        for (UIGestureRecognizer *recognizer in stillLifeViewBtn.gestureRecognizers) {
            [stillLifeViewBtn removeGestureRecognizer:recognizer];
        }
        UITapGestureRecognizer *stillLifeRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(switchFilterType:)];
        [stillLifeViewBtn addGestureRecognizer:stillLifeRecognizer];
        [self.arrFilterCategoryViews addObject:stillLifeViewBtn];
        [_filterCategoryView addSubview:stillLifeViewBtn];
        
        STViewButton *deliciousFoodViewBtn = [[[NSBundle mainBundle] loadNibNamed:@"STViewButton" owner:nil options:nil] firstObject];
        deliciousFoodViewBtn.tag = STEffectsTypeFilterDeliciousFood;
        deliciousFoodViewBtn.backgroundColor = [UIColor clearColor];
        deliciousFoodViewBtn.frame =  CGRectMake(SCREEN_WIDTH / 2 + 110, 58, 33, 60);
        deliciousFoodViewBtn.imageView.image = [UIImage imageNamed:@"delicious_food"];
        deliciousFoodViewBtn.imageView.highlightedImage = [UIImage imageNamed:@"delicious_food_highlighted"];
        deliciousFoodViewBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        deliciousFoodViewBtn.titleLabel.textColor = [UIColor whiteColor];
        deliciousFoodViewBtn.titleLabel.highlightedTextColor = [UIColor whiteColor];
        deliciousFoodViewBtn.titleLabel.text = @"美食";
        
        for (UIGestureRecognizer *recognizer in deliciousFoodViewBtn.gestureRecognizers) {
            [deliciousFoodViewBtn removeGestureRecognizer:recognizer];
        }
        UITapGestureRecognizer *deliciousFoodRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(switchFilterType:)];
        [deliciousFoodViewBtn addGestureRecognizer:deliciousFoodRecognizer];
        [self.arrFilterCategoryViews addObject:deliciousFoodViewBtn];
        [_filterCategoryView addSubview:deliciousFoodViewBtn];
    }
    return _filterCategoryView;
}

- (UIView *)filterStrengthView {
    if (!_filterStrengthView) {
        _filterStrengthView = [[UIView alloc] initWithFrame:CGRectMake(0, SCREEN_HEIGHT - STEFFECT_HEIGHT - 35.5, SCREEN_WIDTH, 35.5)];
        _filterStrengthView.backgroundColor = [UIColor clearColor];
        _filterStrengthView.hidden = YES;
        
        UILabel *leftLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, 10, 35.5)];
        leftLabel.textColor = [UIColor whiteColor];
        leftLabel.font = [UIFont systemFontOfSize:11];
        leftLabel.text = @"0";
        [_filterStrengthView addSubview:leftLabel];
        
        UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(40, 0, SCREEN_WIDTH - 90, 35.5)];
        slider.thumbTintColor = UIColorFromRGB(0x9e4fcb);
        slider.minimumTrackTintColor = UIColorFromRGB(0x9e4fcb);
        slider.maximumTrackTintColor = [UIColor whiteColor];
        slider.value = 1;
        [slider addTarget:self action:@selector(filterSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
        _filterStrengthSlider = slider;
        [_filterStrengthView addSubview:slider];
        
        UILabel *rightLabel = [[UILabel alloc] initWithFrame:CGRectMake(SCREEN_WIDTH - 40, 0, 20, 35.5)];
        rightLabel.textColor = [UIColor whiteColor];
        rightLabel.font = [UIFont systemFontOfSize:11];
        rightLabel.text = [NSString stringWithFormat:@"%d", (int)(self.fFilterStrength * 100)];
        _lblFilterStrength = rightLabel;
        [_filterStrengthView addSubview:rightLabel];
    }
    return _filterStrengthView;
}

- (UISlider *)beautySlider {
    if (!_beautySlider) {
        _beautySlider = [[STBeautySlider alloc] initWithFrame:CGRectMake(40, SCREEN_HEIGHT - STEFFECT_HEIGHT - 40, SCREEN_WIDTH - 90, 40)];
        _beautySlider.thumbTintColor = UIColorFromRGB(0x9e4fcb);
        _beautySlider.minimumTrackTintColor = UIColorFromRGB(0x9e4fcb);
        _beautySlider.maximumTrackTintColor = [UIColor whiteColor];
        _beautySlider.minimumValue = -1;
        _beautySlider.maximumValue = 1;
        _beautySlider.value = 0;
        _beautySlider.hidden = YES;
        _beautySlider.delegate = self;
        [_beautySlider addTarget:self action:@selector(beautySliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    }
    return _beautySlider;
}

- (void)beautySliderValueChanged:(UISlider *)sender {
    
    
    //[-1,1] -> [0,1]
    float value1 = (sender.value + 1) / 2;
    
    //[-1,1]
    float value2 = sender.value;
    
    STNewBeautyCollectionViewModel *model = self.beautyCollectionView.selectedModel;
    
//    model.beautyValue = value * 100;
    
//    [self.beautyCollectionView reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForRow:model.modelIndex inSection:0]]];
    
    switch (model.beautyType) {
            
        case STBeautyTypeNone:
            break;
        case STBeautyTypeWhiten:
            self.fWhitenStrength = value1;
            model.beautyValue = value1 * 100;
            break;
        case STBeautyTypeRuddy:
            self.fReddenStrength = value1;
            model.beautyValue = value1 * 100;
            break;
        case STBeautyTypeDermabrasion:
            self.fSmoothStrength = value1;
            model.beautyValue = value1 * 100;
            break;
        case STBeautyTypeDehighlight:
            self.fDehighlightStrength = value1;
            model.beautyValue = value1 * 100;
            break;
        case STBeautyTypeShrinkFace:
            self.fShrinkFaceStrength = value1;
            model.beautyValue = value1 * 100;
            break;
        case STBeautyTypeNarrowFace:
            self.fNarrowFaceStrength = value1;
            model.beautyValue = value1 * 100;
            break;
        case STBeautyTypeEnlargeEyes:
            self.fEnlargeEyeStrength = value1;
            model.beautyValue = value1 * 100;
            break;
        case STBeautyTypeShrinkJaw:
            self.fShrinkJawStrength = value1;
            model.beautyValue = value1 * 100;
            break;
        case STBeautyTypeThinFaceShape:
            self.fThinFaceShapeStrength = value1;
            model.beautyValue = value1 * 100;
            break;
        case STBeautyTypeChin:
            self.fChinStrength = value2;
            model.beautyValue = value2 * 100;
            break;
        case STBeautyTypeHairLine:
            self.fHairLineStrength = value2;
            model.beautyValue = value2 * 100;
            break;
        case STBeautyTypeNarrowNose:
            self.fNarrowNoseStrength = value1;
            model.beautyValue = value1 * 100;
            break;
        case STBeautyTypeLengthNose:
            self.fLongNoseStrength = value2;
            model.beautyValue = value2 * 100;
            break;
        case STBeautyTypeMouthSize:
            self.fMouthStrength = value2;
            model.beautyValue = value2 * 100;
            break;
        case STBeautyTypeLengthPhiltrum:
            self.fPhiltrumStrength = value2;
            model.beautyValue = value2 * 100;
            break;
        case STBeautyTypeContrast:
            self.fContrastStrength = value1;
            model.beautyValue = value1 * 100;
            break;
        case STBeautyTypeSaturation:
            self.fSaturationStrength = value1;
            model.beautyValue = value1 * 100;
            break;
        case STBeautyTypeAppleMusle:
            self.fAppleMusleStrength = value1;
            model.beautyValue = value1 * 100;
            break;
        case STBeautyTypeProfileRhinoplasty:
            self.fProfileRhinoplastyStrength = value1;
            model.beautyValue = value1 * 100;
            break;
        case STBeautyTypeBrightEye:
            self.fBrightEyeStrength = value1;
            model.beautyValue = value1 * 100;
            break;
        case STBeautyTypeRemoveDarkCircles:
            self.fRemoveDarkCirclesStrength = value1;
            model.beautyValue = value1 * 100;
            break;
        case STBeautyTypeWhiteTeeth:
            self.fWhiteTeethStrength = value1;
            model.beautyValue = value1 * 100;
            break;
        case STBeautyTypeEyeDistance:
            self.fEyeDistanceStrength = value2;
            model.beautyValue = value2 * 100;
            break;
        case STBeautyTypeEyeAngle:
            self.fEyeAngleStrength = value2;
            model.beautyValue = value2 * 100;
            break;
        case STBeautyTypeOpenCanthus:
            self.fOpenCanthusStrength = value1;
            model.beautyValue = value1 * 100;
            break;
        case STBeautyTypeRemoveNasolabialFolds:
            self.fRemoveNasolabialFoldsStrength = value1;
            model.beautyValue = value1 * 100;
            break;
    }
    [self.beautyCollectionView reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForRow:model.modelIndex inSection:0]]];
}

- (void)switchFilterType:(UITapGestureRecognizer *)recognizer {
    [UIView animateWithDuration:0.5 animations:^{
        self.filterCategoryView.frame = CGRectMake(-SCREEN_WIDTH, self.filterCategoryView.frame.origin.y, SCREEN_WIDTH, 300);
        self.filterView.frame = CGRectMake(0, self.filterView.frame.origin.y, SCREEN_WIDTH, 300);
    }];
    
    if (self.currentSelectedFilterModel.modelType == recognizer.view.tag && self.currentSelectedFilterModel.isSelected) {
        self.filterStrengthView.hidden = NO;
    } else {
        self.filterStrengthView.hidden = YES;
    }
    
//    self.filterStrengthView.hidden = !(self.currentSelectedFilterModel.modelType == recognizer.view.tag);
    
    switch (recognizer.view.tag) {
        case STEffectsTypeFilterPortrait:
            _filterView.leftView.imageView.image = [UIImage imageNamed:@"portrait_highlighted"];
            _filterView.leftView.titleLabel.text = @"人物";
            _filterView.filterCollectionView.arrModels = _filterView.filterCollectionView.arrPortraitFilterModels;
            
            break;
        case STEffectsTypeFilterScenery:
            _filterView.leftView.imageView.image = [UIImage imageNamed:@"scenery_highlighted"];
            _filterView.leftView.titleLabel.text = @"风景";
            _filterView.filterCollectionView.arrModels = _filterView.filterCollectionView.arrSceneryFilterModels;
            
            break;
        case STEffectsTypeFilterStillLife:
            _filterView.leftView.imageView.image = [UIImage imageNamed:@"still_life_highlighted"];
            _filterView.leftView.titleLabel.text = @"静物";
            _filterView.filterCollectionView.arrModels = _filterView.filterCollectionView.arrStillLifeFilterModels;
            
            break;
        case STEffectsTypeFilterDeliciousFood:
            _filterView.leftView.imageView.image = [UIImage imageNamed:@"delicious_food_highlighted"];
            _filterView.leftView.titleLabel.text = @"美食";
            _filterView.filterCollectionView.arrModels = _filterView.filterCollectionView.arrDeliciousFoodFilterModels;
            
            break;
            
        default:
            break;
    }
    [_filterView.filterCollectionView reloadData];
}

- (void)refreshFilterCategoryState:(STEffectsType)type {
    for (int i = 0; i < self.arrFilterCategoryViews.count; ++i) {
        if (self.arrFilterCategoryViews[i].highlighted) {
            self.arrFilterCategoryViews[i].highlighted = NO;
        }
    }
    switch (type) {
        case STEffectsTypeFilterPortrait:
            self.arrFilterCategoryViews[0].highlighted = YES;
            break;
            
        case STEffectsTypeFilterScenery:
            self.arrFilterCategoryViews[1].highlighted = YES;
            break;
            
        case STEffectsTypeFilterStillLife:
            self.arrFilterCategoryViews[2].highlighted = YES;
            break;
            
        case STEffectsTypeFilterDeliciousFood:
            self.arrFilterCategoryViews[3].highlighted = YES;
            break;
            
        default:
            break;
    }
}

- (STScrollTitleView *)beautyScrollTitleViewNew {
    if (!_beautyScrollTitleViewNew) {
        NSArray *beautyCategory = @[@"基础美颜", @"美形", @"微整形", @"滤镜", @"调整"];
        NSArray *beautyType = @[@(STEffectsTypeBeautyBase),
                                @(STEffectsTypeBeautyShape),
                                @(STEffectsTypeBeautyMicroSurgery),
                                @(STEffectsTypeBeautyFilter),
                                @(STEffectsTypeBeautyAdjust)];
        STWeakSelf;
        _beautyScrollTitleViewNew = [[STScrollTitleView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, 40) titles:beautyCategory effectsType:beautyType titleOnClick:^(STTitleViewItem *titleView, NSInteger index, STEffectsType type) {
            [weakSelf handleEffectsType:type];
        }];
        _beautyScrollTitleViewNew.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    }
    return _beautyScrollTitleViewNew;
}

- (STScrollTitleView *)scrollTitleView {
    if (!_scrollTitleView) {
        STWeakSelf;
        NSArray *stickerTypeArray = @[
                                      @(STEffectsTypeStickerMy),
                                      @(STEffectsTypeStickerNew),
                                      @(STEffectsTypeSticker2D),
                                      @(STEffectsTypeStickerAvatar),
                                      @(STEffectsTypeSticker3D),
                                      @(STEffectsTypeStickerGesture),
                                      @(STEffectsTypeStickerSegment),
                                      @(STEffectsTypeStickerFaceDeformation),
                                      @(STEffectsTypeStickerFaceChange),
                                      @(STEffectsTypeStickerParticle),
                                      @(STEffectsTypeObjectTrack)];
        
        NSArray *normalImages = @[
                                  [UIImage imageNamed:@"native.png"],
                                  [UIImage imageNamed:@"new_sticker.png"],
                                  [UIImage imageNamed:@"2d.png"],
                                  [UIImage imageNamed:@"avatar.png"],
                                  [UIImage imageNamed:@"3d.png"],
                                  [UIImage imageNamed:@"sticker_gesture.png"],
                                  [UIImage imageNamed:@"sticker_segment.png"],
                                  [UIImage imageNamed:@"sticker_face_deformation.png"],
                                  [UIImage imageNamed:@"face_painting.png"],
                                  [UIImage imageNamed:@"particle_effect.png"],
                                  [UIImage imageNamed:@"common_object_track.png"]
                                  ];
        NSArray *selectedImages = @[
                                    [UIImage imageNamed:@"native_selected.png"],
                                    [UIImage imageNamed:@"new_sticker_selected.png"],
                                    [UIImage imageNamed:@"2d_selected.png"],
                                    [UIImage imageNamed:@"avatar_selected.png"],
                                    [UIImage imageNamed:@"3d_selected.png"],
                                    [UIImage imageNamed:@"sticker_gesture_selected.png"],
                                    [UIImage imageNamed:@"sticker_segment_selected.png"],
                                    [UIImage imageNamed:@"sticker_face_deformation_selected.png"],
                                    [UIImage imageNamed:@"face_painting_selected.png"],
                                    [UIImage imageNamed:@"particle_effect_selected.png"],
                                    [UIImage imageNamed:@"common_object_track_selected.png"]
                                    ];
        
        
        _scrollTitleView = [[STScrollTitleView alloc] initWithFrame:CGRectMake(57, 0, SCREEN_WIDTH - 57, 40) normalImages:normalImages selectedImages:selectedImages effectsType:stickerTypeArray titleOnClick:^(STTitleViewItem *titleView, NSInteger index, STEffectsType type) {
            [weakSelf handleEffectsType:type];
        }];
        _scrollTitleView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    }
    return _scrollTitleView;
}

- (EffectsCollectionView *)effectsList {
    if (!_effectsList) {
        STWeakSelf
        _effectsList = [[EffectsCollectionView alloc] initWithFrame:CGRectMake(0, 41, SCREEN_WIDTH, 140)];
        [_effectsList registerNib:[UINib nibWithNibName:@"EffectsCollectionViewCell"
                                                 bundle:[NSBundle mainBundle]] forCellWithReuseIdentifier:@"EffectsCollectionViewCell"];
        _effectsList.numberOfSectionsInView = ^NSInteger(STCustomCollectionView *collectionView) {
            return 1;
        };
        _effectsList.numberOfItemsInSection = ^NSInteger(STCustomCollectionView *collectionView, NSInteger section) {
            return weakSelf.arrCurrentModels.count;
        };
        _effectsList.cellForItemAtIndexPath = ^UICollectionViewCell *(STCustomCollectionView *collectionView, NSIndexPath *indexPath) {
            static NSString *strIdentifier = @"EffectsCollectionViewCell";
            EffectsCollectionViewCell *cell = (EffectsCollectionViewCell *)[collectionView dequeueReusableCellWithReuseIdentifier:strIdentifier forIndexPath:indexPath];
            NSArray *arrModels = weakSelf.arrCurrentModels;
            if (arrModels.count) {
                EffectsCollectionViewCellModel *model = arrModels[indexPath.item];
                
                if (model.iEffetsType != STEffectsTypeStickerMy) {
                    id cacheObj = [weakSelf.thumbnailCache objectForKey:model.material.strMaterialFileID];
                    if (cacheObj && [cacheObj isKindOfClass:[UIImage class]]) {
                        model.imageThumb = cacheObj;
                    }else{
                        model.imageThumb = [UIImage imageNamed:@"none"];
                    }
                }
                cell.model = model;
                return cell;
            }else{
                cell.model = nil;
                return cell;
            }
        };
        _effectsList.didSelectItematIndexPath = ^(STCustomCollectionView *collectionView, NSIndexPath *indexPath) {
            NSArray *arrModels = weakSelf.arrCurrentModels;
            [weakSelf handleStickerChanged:arrModels[indexPath.item]];
        };
    }
    return _effectsList;
}

- (STCollectionView *)objectTrackCollectionView {
    if (!_objectTrackCollectionView) {
        STWeakSelf
        _objectTrackCollectionView = [[STCollectionView alloc] initWithFrame:CGRectMake(0, 41, SCREEN_WIDTH, 140) withModels:nil andDelegateBlock:^(STCollectionViewDisplayModel *model) {
            [weakSelf handleObjectTrackChanged:model];
        }];
        _objectTrackCollectionView.arrModels = self.arrObjectTrackers;
        _objectTrackCollectionView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    }
    return _objectTrackCollectionView;
}

- (STNewBeautyCollectionView *)beautyCollectionView {
    if (!_beautyCollectionView) {
        STWeakSelf;
        _beautyCollectionView = [[STNewBeautyCollectionView alloc] initWithFrame:CGRectMake(0, 41, SCREEN_WIDTH, 220) models:self.baseBeautyModels delegateBlock:^(STNewBeautyCollectionViewModel *model) {
            [weakSelf handleBeautyTypeChanged:model];
        }];
        _beautyCollectionView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        [_beautyCollectionView reloadData];
    }
    return _beautyCollectionView;
}

#pragma mark - lazy load array

- (NSArray *)arrObjectTrackers {
    if (!_arrObjectTrackers) {
        _arrObjectTrackers = [self getObjectTrackModels];
    }
    return _arrObjectTrackers;
}

- (NSMutableArray *)arrBeautyViews {
    if (!_arrBeautyViews) {
        _arrBeautyViews = [NSMutableArray array];
    }
    return _arrBeautyViews;
}

- (NSMutableArray *)arrFilterCategoryViews {
    if (!_arrFilterCategoryViews) {
        _arrFilterCategoryViews = [NSMutableArray array];
    }
    return _arrFilterCategoryViews;
}

- (void)handleEffectsType:(STEffectsType)type {
    switch (type) {
        case STEffectsTypeStickerMy:
        case STEffectsTypeSticker2D:
        case STEffectsTypeStickerAvatar:
        case STEffectsTypeSticker3D:
        case STEffectsTypeStickerGesture:
        case STEffectsTypeStickerSegment:
        case STEffectsTypeStickerFaceChange:
        case STEffectsTypeStickerFaceDeformation:
        case STEffectsTypeStickerParticle:
        case STEffectsTypeStickerNew:
        case STEffectsTypeObjectTrack:
            self.curEffectStickerType = type;
            break;
        case STEffectsTypeBeautyFilter:
        case STEffectsTypeBeautyBase:
        case STEffectsTypeBeautyShape:
        case STEffectsTypeBeautyMicroSurgery:
        case STEffectsTypeBeautyAdjust:
            self.curEffectBeautyType = type;
            break;
            
        default:
            break;
    }
    
    if (type != STEffectsTypeBeautyFilter) {
        self.filterStrengthView.hidden = YES;
    }
    
    if (type == self.beautyCollectionView.selectedModel.modelType) {
        self.beautySlider.hidden = NO;
    } else {
        self.beautySlider.hidden = YES;
    }
    
    switch (type) {
        case STEffectsTypeStickerMy:
        case STEffectsTypeStickerNew:
        case STEffectsTypeSticker2D:
        case STEffectsTypeStickerAvatar:
        case STEffectsTypeStickerFaceDeformation:
        case STEffectsTypeStickerSegment:
        case STEffectsTypeSticker3D:
        case STEffectsTypeStickerGesture:
        case STEffectsTypeStickerFaceChange:
        case STEffectsTypeStickerParticle:
            
            self.objectTrackCollectionView.hidden = YES;
            self.arrCurrentModels = [self.effectsDataSource objectForKey:@(type)];
            [self.effectsList reloadData];
            self.effectsList.hidden = NO;
            break;
            
        case STEffectsTypeObjectTrack:
            self.objectTrackCollectionView.arrModels = self.arrObjectTrackers;
            self.objectTrackCollectionView.hidden = NO;
            self.effectsList.hidden = YES;
            [self.objectTrackCollectionView reloadData];
            break;
            
        case STEffectsTypeBeautyFilter:
            self.filterCategoryView.hidden = NO;
            self.filterView.hidden = NO;
            self.beautyCollectionView.hidden = YES;
            self.filterCategoryView.center = CGPointMake(SCREEN_WIDTH / 2, self.filterCategoryView.center.y);
            self.filterView.center = CGPointMake(SCREEN_WIDTH * 3 / 2, self.filterView.center.y);
            break;
            
        case STEffectsTypeNone:
            break;
            
        case STEffectsTypeBeautyShape:
            [self hideBeautyViewExcept:self.beautyShapeView];
            self.filterStrengthView.hidden = YES;
            self.beautyCollectionView.hidden = NO;
            self.filterCategoryView.hidden = YES;
            self.beautyCollectionView.models = self.beautyShapeModels;
            [self.beautyCollectionView reloadSections:[NSIndexSet indexSetWithIndex:0]];
            break;
            
        case STEffectsTypeBeautyBase:
            self.filterStrengthView.hidden = YES;
            [self hideBeautyViewExcept:self.beautyCollectionView];
            
            self.beautyCollectionView.hidden = NO;
            self.filterCategoryView.hidden = YES;
            self.beautyCollectionView.models = self.baseBeautyModels;
            [self.beautyCollectionView reloadSections:[NSIndexSet indexSetWithIndex:0]];
            break;
            
        case STEffectsTypeBeautyMicroSurgery:
            [self hideBeautyViewExcept:self.beautyCollectionView];
            self.beautyCollectionView.hidden = NO;
            self.filterCategoryView.hidden = YES;
            self.beautyCollectionView.models = self.microSurgeryModels;
            [self.beautyCollectionView reloadSections:[NSIndexSet indexSetWithIndex:0]];
            break;
            
        case STEffectsTypeBeautyAdjust:
            [self hideBeautyViewExcept:self.beautyCollectionView];
            self.beautyCollectionView.hidden = NO;
            self.filterCategoryView.hidden = YES;
            self.beautyCollectionView.models = self.adjustModels;
            [self.beautyCollectionView reloadSections:[NSIndexSet indexSetWithIndex:0]];
            break;
            
        case STEffectsTypeBeautyBody:
            self.filterStrengthView.hidden = YES;
            [self hideBeautyViewExcept:self.beautyBodyView];
            break;
            
        default:
            break;
    }
}

- (void)handleBeautyTypeChanged:(STNewBeautyCollectionViewModel *)model {
    self.curBeautyBeautyType = model.beautyType;
    self.beautySlider.hidden = NO;
    switch (model.beautyType) {
        case STBeautyTypeNone:
        case STBeautyTypeWhiten:
        case STBeautyTypeRuddy:
        case STBeautyTypeDermabrasion:
        case STBeautyTypeDehighlight:
        case STBeautyTypeShrinkFace:
        case STBeautyTypeEnlargeEyes:
        case STBeautyTypeShrinkJaw:
        case STBeautyTypeThinFaceShape:
        case STBeautyTypeNarrowNose:
        case STBeautyTypeContrast:
        case STBeautyTypeSaturation:
        case STBeautyTypeNarrowFace:
        case STBeautyTypeAppleMusle:
        case STBeautyTypeProfileRhinoplasty:
        case STBeautyTypeBrightEye:
        case STBeautyTypeRemoveDarkCircles:
        case STBeautyTypeWhiteTeeth:
        case STBeautyTypeOpenCanthus:
        case STBeautyTypeRemoveNasolabialFolds:
            
            self.beautySlider.value = model.beautyValue / 50.0 - 1;
            break;
            
        case STBeautyTypeChin:
        case STBeautyTypeHairLine:
        case STBeautyTypeLengthNose:
        case STBeautyTypeMouthSize:
        case STBeautyTypeLengthPhiltrum:
        case STBeautyTypeEyeAngle:
        case STBeautyTypeEyeDistance:
            
            self.beautySlider.value = model.beautyValue / 100.0;
            break;
    }
}

#pragma mark - get models

- (NSArray *)getStickerModelsByType:(STEffectsType)type {
    NSArray *stickerZipPaths = [STParamUtil getStickerPathsByType:type];
    NSMutableArray *arrModels = [NSMutableArray array];
    
    for (int i = 0; i < stickerZipPaths.count; i ++) {
        STCollectionViewDisplayModel *model = [[STCollectionViewDisplayModel alloc] init];
        model.strPath = stickerZipPaths[i];
        
        UIImage *thumbImage = [UIImage imageWithContentsOfFile:[[model.strPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"]];
        model.image = thumbImage ? thumbImage : [UIImage imageNamed:@"none.png"];
        model.strName = @"";
        model.index = i;
        model.isSelected = NO;
        model.modelType = type;
        [arrModels addObject:model];
    }
    return [arrModels copy];
}

- (NSArray *)getFilterModelsByType:(STEffectsType)type {
    NSArray *filterModelPath = [STParamUtil getFilterModelPathsByType:type];
    NSMutableArray *arrModels = [NSMutableArray array];
    
    NSString *natureImageName = @"";
    switch (type) {
        case STEffectsTypeFilterDeliciousFood:
            natureImageName = @"nature_food";
            break;
        case STEffectsTypeFilterStillLife:
            natureImageName = @"nature_stilllife";
            break;
        case STEffectsTypeFilterScenery:
            natureImageName = @"nature_scenery";
            break;
        case STEffectsTypeFilterPortrait:
            natureImageName = @"nature_portrait";
            break;
        default:
            break;
    }
    
    STCollectionViewDisplayModel *model1 = [[STCollectionViewDisplayModel alloc] init];
    model1.strPath = NULL;
    model1.strName = @"original";
    model1.image = [UIImage imageNamed:natureImageName];
    model1.index = 0;
    model1.isSelected = NO;
    model1.modelType = STEffectsTypeNone;
    [arrModels addObject:model1];
    
    for (int i = 1; i < filterModelPath.count + 1; ++i) {
        STCollectionViewDisplayModel *model = [[STCollectionViewDisplayModel alloc] init];
        model.strPath = filterModelPath[i - 1];
        model.strName = [[model.strPath.lastPathComponent stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:@"filter_style_" withString:@""];
        
        UIImage *thumbImage = [UIImage imageWithContentsOfFile:[[model.strPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"]];
        model.image = thumbImage ?: [UIImage imageNamed:@"none"];
        model.index = i;
        model.isSelected = NO;
        model.modelType = type;
        [arrModels addObject:model];
    }
    return [arrModels copy];
}

- (NSArray *)getObjectTrackModels {
    NSMutableArray *arrModels = [NSMutableArray array];
    NSArray *arrImageNames = @[@"object_track_happy", @"object_track_hi", @"object_track_love", @"object_track_star", @"object_track_sticker", @"object_track_sun"];
    for (int i = 0; i < arrImageNames.count; ++i) {
        STCollectionViewDisplayModel *model = [[STCollectionViewDisplayModel alloc] init];
        model.strPath = NULL;
        model.strName = @"";
        model.index = i;
        model.isSelected = NO;
        model.image = [UIImage imageNamed:arrImageNames[i]];
        model.modelType = STEffectsTypeObjectTrack;
        [arrModels addObject:model];
    }
    return [arrModels copy];
}

#pragma mark - collectionview click events

- (void)handleFilterChanged:(STCollectionViewDisplayModel *)model {
    if ([EAGLContext currentContext] != self.glContext) {
        [EAGLContext setCurrentContext:self.glContext];
    }
    self.currentSelectedFilterModel = model;
    self.bFilter = model.index > 0;
    
    if (self.bFilter) {
        self.filterStrengthView.hidden = NO;
    } else {
        self.filterStrengthView.hidden = YES;
    }
    // 切换滤镜
    if (_hFilter) {
        self.filterStrengthSlider.value = self.fFilterStrength;
        self.curFilterModelPath = model.strPath;
        [self refreshFilterCategoryState:model.modelType];
        st_result_t iRet = ST_OK;
        iRet = st_mobile_gl_filter_set_param(_hFilter, ST_GL_FILTER_STRENGTH, self.fFilterStrength);
        if (iRet != ST_OK) {
            NSLog(@"st_mobile_gl_filter_set_param %d" , iRet);
        }
    }
}

- (void)handleObjectTrackChanged:(STCollectionViewDisplayModel *)model {
    if (self.commonObjectContainerView.currentCommonObjectView) {
        [self.commonObjectContainerView.currentCommonObjectView removeFromSuperview];
    }
    _commonObjectViewSetted = NO;
    _commonObjectViewAdded = NO;
    if (model.isSelected) {
        UIImage *image = model.image;
        [self.commonObjectContainerView addCommonObjectViewWithImage:image];
        self.commonObjectContainerView.currentCommonObjectView.onFirst = YES;
        self.bTracker = YES;
    }
}

- (void)handleStickerChanged:(EffectsCollectionViewCellModel *)model {
    self.prepareModel = model;
    
    if (STEffectsTypeStickerMy == model.iEffetsType) {
        [self setMaterialModel:model];
        return;
    }
    STWeakSelf;
    
    BOOL isMaterialExist = [[SenseArMaterialService sharedInstance] isMaterialDownloaded:model.material];
    BOOL isDirectory = YES;
    BOOL isFileAvalible = [[NSFileManager defaultManager] fileExistsAtPath:model.material.strMaterialPath
                                                               isDirectory:&isDirectory];
    ///TODO: 双页面共享 service  会造成 model & material 状态更新错误
    if (isMaterialExist && (isDirectory || !isFileAvalible)) {
        model.state = NotDownloaded;
        model.strMaterialPath = nil;
        isMaterialExist = NO;
    }
    
    if (model && model.material && !isMaterialExist) {
        model.state = IsDownloading;
        [self.effectsList reloadData];
        [[SenseArMaterialService sharedInstance]
         downloadMaterial:model.material
         onSuccess:^(SenseArMaterial *material){
             model.state = Downloaded;
             model.strMaterialPath = material.strMaterialPath;
             
             if (model == weakSelf.prepareModel) {
                 [weakSelf setMaterialModel:model];
             }else{
                 dispatch_async(dispatch_get_main_queue(), ^{
                     [weakSelf.effectsList reloadData];
                 });
             }
         }
         onFailure:^(SenseArMaterial *material, int iErrorCode, NSString *strMessage) {
             model.state = NotDownloaded;
             dispatch_async(dispatch_get_main_queue(), ^{
                 [weakSelf.effectsList reloadData];
             });
         }
         onProgress:nil];
    }else{
        [self setMaterialModel:model];
    }
}

- (void)setMaterialModel:(EffectsCollectionViewCellModel *)targetModel {
    self.bSticker = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.triggerView.hidden = YES;
    });
    
    const char *stickerPath = [targetModel.strMaterialPath UTF8String];
    if (!targetModel || IsSelected == targetModel.state) {
        stickerPath = NULL;
    }
    
    for (NSArray *arrModels in [self.effectsDataSource allValues]) {
        for (EffectsCollectionViewCellModel *model in arrModels) {
            if (model == targetModel) {
                if (IsSelected == model.state) {
                    model.state = Downloaded;
                }else{
                    model.state = IsSelected;
                }
            }else{
                if (IsSelected == model.state) {
                    model.state = Downloaded;
                }
            }
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.effectsList reloadData];
    });
    
    if (self.isNullSticker) {
        self.isNullSticker = NO;
    }
    // 获取触发动作类型
    unsigned long long iAction = 0;
    
    st_result_t iRet = ST_OK;
    iRet = st_mobile_sticker_change_package(_hSticker, stickerPath, NULL);
    
    if (iRet != ST_OK && iRet != ST_E_PACKAGE_EXIST_IN_MEMORY) {
        NSLog(@"st_mobile_sticker_change_package error %d" , iRet);
    } else {
        // 需要在 st_mobile_sticker_change_package 之后调用才可以获取新素材包的 trigger action .
        iRet = st_mobile_sticker_get_trigger_action(_hSticker, &iAction);
        
        if (ST_OK != iRet) {
            NSLog(@"st_mobile_sticker_get_trigger_action error %d" , iRet);
            return;
        }
        
        NSString *triggerContent = @"";
        UIImage *image = nil;
        
        if (0 != iAction) {//有 trigger信息
            if (CHECK_FLAG(iAction, ST_MOBILE_BROW_JUMP)) {
                triggerContent = [NSString stringWithFormat:@"%@请挑挑眉~", triggerContent];
                image = [UIImage imageNamed:@"head_brow_jump"];
            }
            if (CHECK_FLAG(iAction, ST_MOBILE_EYE_BLINK)) {
                triggerContent = [NSString stringWithFormat:@"%@请眨眨眼~", triggerContent];
                image = [UIImage imageNamed:@"eye_blink"];
            }
            if (CHECK_FLAG(iAction, ST_MOBILE_HEAD_YAW)) {
                triggerContent = [NSString stringWithFormat:@"%@请摇摇头~", triggerContent];
                image = [UIImage imageNamed:@"head_yaw"];
            }
            if (CHECK_FLAG(iAction, ST_MOBILE_HEAD_PITCH)) {
                triggerContent = [NSString stringWithFormat:@"%@请点点头~", triggerContent];
                image = [UIImage imageNamed:@"head_pitch"];
            }
            if (CHECK_FLAG(iAction, ST_MOBILE_MOUTH_AH)) {
                triggerContent = [NSString stringWithFormat:@"%@请张张嘴~", triggerContent];
                image = [UIImage imageNamed:@"mouth_ah"];
            }
            if (CHECK_FLAG(iAction, ST_MOBILE_HAND_GOOD)) {
                triggerContent = [NSString stringWithFormat:@"%@请比个赞~", triggerContent];
                image = [UIImage imageNamed:@"hand_good"];
            }
            if (CHECK_FLAG(iAction, ST_MOBILE_HAND_PALM)) {
                triggerContent = [NSString stringWithFormat:@"%@请伸手掌~", triggerContent];
                image = [UIImage imageNamed:@"hand_palm"];
            }
            if (CHECK_FLAG(iAction, ST_MOBILE_HAND_LOVE)) {
                triggerContent = [NSString stringWithFormat:@"%@请双手比心~", triggerContent];
                image = [UIImage imageNamed:@"hand_love"];
            }
            if (CHECK_FLAG(iAction, ST_MOBILE_HAND_HOLDUP)) {
                triggerContent = [NSString stringWithFormat:@"%@请托个手~", triggerContent];
                image = [UIImage imageNamed:@"hand_holdup"];
            }
            if (CHECK_FLAG(iAction, ST_MOBILE_HAND_CONGRATULATE)) {
                triggerContent = [NSString stringWithFormat:@"%@请抱个拳~", triggerContent];
                image = [UIImage imageNamed:@"hand_congratulate"];
            }
            if (CHECK_FLAG(iAction, ST_MOBILE_HAND_FINGER_HEART)) {
                triggerContent = [NSString stringWithFormat:@"%@请单手比心~", triggerContent];
                image = [UIImage imageNamed:@"hand_finger_heart"];
            }
            if (CHECK_FLAG(iAction, ST_MOBILE_HAND_FINGER_INDEX)) {
                triggerContent = [NSString stringWithFormat:@"%@请伸出食指~", triggerContent];
                image = [UIImage imageNamed:@"hand_finger"];
            }
            if (CHECK_FLAG(iAction, ST_MOBILE_HAND_OK)) {
                triggerContent = [NSString stringWithFormat:@"%@请亮出OK手势~", triggerContent];
                image = [UIImage imageNamed:@"hand_ok"];
            }
            if (CHECK_FLAG(iAction, ST_MOBILE_HAND_SCISSOR)) {
                triggerContent = [NSString stringWithFormat:@"%@请比个剪刀手~", triggerContent];
                image = [UIImage imageNamed:@"hand_victory"];
            }
            if (CHECK_FLAG(iAction, ST_MOBILE_HAND_PISTOL)) {
                triggerContent = [NSString stringWithFormat:@"%@请比个手枪~", triggerContent];
                image = [UIImage imageNamed:@"hand_gun"];
            }
            
            if (CHECK_FLAG(iAction, ST_MOBILE_HAND_666)) {
                triggerContent = [NSString stringWithFormat:@"%@请亮出666手势~", triggerContent];
                image = [UIImage imageNamed:@"666_selected"];
            }
            if (CHECK_FLAG(iAction, ST_MOBILE_HAND_BLESS)) {
                triggerContent = [NSString stringWithFormat:@"%@请双手合十~", triggerContent];
                image = [UIImage imageNamed:@"bless_selected"];
            }
            if (CHECK_FLAG(iAction, ST_MOBILE_HAND_ILOVEYOU)) {
                triggerContent = [NSString stringWithFormat:@"%@请亮出我爱你手势~", triggerContent];
                image = [UIImage imageNamed:@"love_selected"];
            }
            if (CHECK_FLAG(iAction, ST_MOBILE_HAND_FIST)) {
                triggerContent = [NSString stringWithFormat:@"%@请举起拳头~", triggerContent];
                image = [UIImage imageNamed:@"fist_selected"];
            }
            [self.triggerView showTriggerViewWithContent:triggerContent image:image];
        }
        //猫脸config
        unsigned long long animalConfig = 0;
        iRet = st_mobile_sticker_get_animal_detect_config(_hSticker, &animalConfig);
        if (iRet == ST_OK && animalConfig == ST_MOBILE_CAT_DETECT) {
            _needDetectAnimal = YES;
        } else {
            _needDetectAnimal = NO;
        }
    }
    self.iCurrentAction = iAction;
}

void copyCatFace(st_mobile_animal_face_t *src, int faceCount, st_mobile_animal_face_t *dst) {
    memcpy(dst, src, sizeof(st_mobile_animal_face_t) * faceCount);
    for (int i = 0; i < faceCount; ++i) {
        size_t key_points_size = sizeof(st_pointf_t) * src[i].key_points_count;
        st_pointf_t *p_key_points = malloc(key_points_size);
        memset(p_key_points, 0, key_points_size);
        memcpy(p_key_points, src[i].p_key_points, key_points_size);
        dst[i].p_key_points = p_key_points;
    }
}

void freeCatFace(st_mobile_animal_face_t *src, int faceCount) {
    if (faceCount > 0) {
        for (int i = 0; i < faceCount; ++i) {
            if (src[i].p_key_points != NULL) {
                free(src[i].p_key_points);
                src[i].p_key_points = NULL;
            }
        }
        free(src);
        src = NULL;
    }
}

void copyHumanAction(st_mobile_human_action_t *src , st_mobile_human_action_t *dst) {
    memcpy(dst, src, sizeof(st_mobile_human_action_t));
    // copy faces
    if ((*src).face_count > 0) {
        size_t faces_size = sizeof(st_mobile_face_t) * (*src).face_count;
        st_mobile_face_t *p_faces = malloc(faces_size);
        memset(p_faces, 0, faces_size);
        memcpy(p_faces, (*src).p_faces, faces_size);
        (*dst).p_faces = p_faces;
        
        for (int i = 0; i < (*src).face_count; i ++) {
            st_mobile_face_t face = (*src).p_faces[i];
            // p_extra_face_points
            if (face.extra_face_points_count > 0 && face.p_extra_face_points != NULL) {
                size_t extra_face_points_size = sizeof(st_pointf_t) * face.extra_face_points_count;
                st_pointf_t *p_extra_face_points = malloc(extra_face_points_size);
                memset(p_extra_face_points, 0, extra_face_points_size);
                memcpy(p_extra_face_points, face.p_extra_face_points, extra_face_points_size);
                (*dst).p_faces[i].p_extra_face_points = p_extra_face_points;
            }
            // p_tongue_points & p_tongue_points_score
            if (   face.tongue_points_count > 0
                && face.p_tongue_points != NULL
                && face.p_tongue_points_score != NULL) {
                size_t tongue_points_size = sizeof(st_pointf_t) * face.tongue_points_count;
                st_pointf_t *p_tongue_points = malloc(tongue_points_size);
                memset(p_tongue_points, 0, tongue_points_size);
                memcpy(p_tongue_points, face.p_tongue_points, tongue_points_size);
                (*dst).p_faces[i].p_tongue_points = p_tongue_points;
                
                size_t tongue_points_score_size = sizeof(float) * face.tongue_points_count;
                float *p_tongue_points_score = malloc(tongue_points_score_size);
                memset(p_tongue_points_score, 0, tongue_points_score_size);
                memcpy(p_tongue_points_score, face.p_tongue_points_score, tongue_points_score_size);
                (*dst).p_faces[i].p_tongue_points_score = p_tongue_points_score;
            }
            // p_eyeball_center
            if (face.eyeball_center_points_count > 0 && face.p_eyeball_center != NULL) {
                size_t eyeball_center_points_size = sizeof(st_pointf_t) * face.eyeball_center_points_count;
                st_pointf_t *p_eyeball_center = malloc(eyeball_center_points_size);
                memset(p_eyeball_center, 0, eyeball_center_points_size);
                memcpy(p_eyeball_center, face.p_eyeball_center, eyeball_center_points_size);
                (*dst).p_faces[i].p_eyeball_center = p_eyeball_center;
            }
            // p_eyeball_contour
            if (face.eyeball_contour_points_count > 0 && face.p_eyeball_contour != NULL) {
                size_t eyeball_contour_points_size = sizeof(st_pointf_t) * face.eyeball_contour_points_count;
                st_pointf_t *p_eyeball_contour = malloc(eyeball_contour_points_size);
                memset(p_eyeball_contour, 0, eyeball_contour_points_size);
                memcpy(p_eyeball_contour, face.p_eyeball_contour, eyeball_contour_points_size);
                (*dst).p_faces[i].p_eyeball_contour = p_eyeball_contour;
            }
        }
    }
    // copy hands
    if ((*src).hand_count > 0) {
        size_t hands_size = sizeof(st_mobile_hand_t) * (*src).hand_count;
        st_mobile_hand_t *p_hands = malloc(hands_size);
        memset(p_hands, 0, hands_size);
        memcpy(p_hands, (*src).p_hands, hands_size);
        (*dst).p_hands = p_hands;
        
        for (int i = 0; i < (*src).hand_count; i ++) {
            st_mobile_hand_t hand = (*src).p_hands[i];
            // p_key_points
            if (hand.key_points_count > 0 && hand.p_key_points != NULL) {
                size_t key_points_size = sizeof(st_pointf_t) * hand.key_points_count;
                st_pointf_t *p_key_points = malloc(key_points_size);
                memset(p_key_points, 0, key_points_size);
                memcpy(p_key_points, hand.p_key_points, key_points_size);
                (*dst).p_hands[i].p_key_points = p_key_points;
            }
            // p_skeleton_keypoints
            if (hand.skeleton_keypoints_count > 0 && hand.p_skeleton_keypoints != NULL) {
                size_t skeleton_keypoints_size = sizeof(st_pointf_t) * hand.skeleton_keypoints_count;
                st_pointf_t *p_skeleton_keypoints = malloc(skeleton_keypoints_size);
                memset(p_skeleton_keypoints, 0, skeleton_keypoints_size);
                memcpy(p_skeleton_keypoints, hand.p_skeleton_keypoints, skeleton_keypoints_size);
                (*dst).p_hands[i].p_skeleton_keypoints = p_skeleton_keypoints;
            }
            // p_skeleton_3d_keypoints
            if (hand.skeleton_3d_keypoints_count > 0 && hand.p_skeleton_3d_keypoints != NULL) {
                size_t skeleton_3d_keypoints_size = sizeof(st_point3f_t) * hand.skeleton_3d_keypoints_count;
                st_point3f_t *p_skeleton_3d_keypoints = malloc(skeleton_3d_keypoints_size);
                memset(p_skeleton_3d_keypoints, 0, skeleton_3d_keypoints_size);
                memcpy(p_skeleton_3d_keypoints, hand.p_skeleton_3d_keypoints, skeleton_3d_keypoints_size);
                (*dst).p_hands[i].p_skeleton_3d_keypoints = p_skeleton_3d_keypoints;
            }
        }
    }
    // copy body
    if ((*src).body_count > 0) {
        size_t bodys_size = sizeof(st_mobile_body_t) * (*src).body_count;
        st_mobile_body_t *p_bodys = malloc(bodys_size);
        memset(p_bodys, 0, bodys_size);
        memcpy(p_bodys, (*src).p_bodys, bodys_size);
        (*dst).p_bodys = p_bodys;
        
        for (int i = 0; i < (*src).body_count; i ++) {
            st_mobile_body_t body = (*src).p_bodys[i];
            // p_key_points & p_key_points_score
            if (   body.key_points_count > 0
                && body.p_key_points != NULL
                && body.p_key_points_score != NULL) {
                
                size_t key_points_size = sizeof(st_pointf_t) * body.key_points_count;
                st_pointf_t *p_key_points = malloc(key_points_size);
                memset(p_key_points, 0, key_points_size);
                memcpy(p_key_points, body.p_key_points, key_points_size);
                (*dst).p_bodys[i].p_key_points = p_key_points;
                
                size_t key_points_score_size = sizeof(float) * body.key_points_count;
                float *p_key_points_score = malloc(key_points_score_size);
                memset(p_key_points_score, 0, key_points_score_size);
                memcpy(p_key_points_score, body.p_key_points_score, key_points_score_size);
                (*dst).p_bodys[i].p_key_points_score = p_key_points_score;
            }
            
            // p_contour_points & p_contour_points_score
            if (   body.contour_points_count > 0
                && body.p_contour_points != NULL
                && body.p_contour_points_score != NULL) {
                size_t contour_points_size = sizeof(st_pointf_t) * body.contour_points_count;
                st_pointf_t *p_contour_points = malloc(contour_points_size);
                memset(p_contour_points, 0, contour_points_size);
                memcpy(p_contour_points, body.p_contour_points, contour_points_size);
                (*dst).p_bodys[i].p_contour_points = p_contour_points;
                
                size_t contour_points_score_size = sizeof(float) * body.contour_points_count;
                float *p_contour_points_score = malloc(contour_points_score_size);
                memset(p_contour_points_score, 0, contour_points_score_size);
                memcpy(p_contour_points_score, body.p_contour_points_score, contour_points_score_size);
                (*dst).p_bodys[i].p_contour_points_score = p_contour_points_score;
            }
        }
    }
    // p_background
    if ((*src).p_background != NULL) {
        st_image_t *p_background = malloc(sizeof(st_image_t));
        memcpy(p_background, (*src).p_background, sizeof(st_image_t));
        
        size_t image_data_size = sizeof(unsigned char) * (*src).p_background[0].width * (*src).p_background[0].height;
        unsigned char *data = malloc(image_data_size);
        memset(data, 0, image_data_size);
        memcpy(data, (*src).p_background[0].data, image_data_size);
        p_background[0].data = data;
        
        (*dst).p_background = p_background;
    }
    // p_hair
    if ((*src).p_hair != NULL) {
        st_image_t *p_hair = malloc(sizeof(st_image_t));
        memcpy(p_hair, (*src).p_hair, sizeof(st_image_t));
        
        size_t image_data_size = sizeof(unsigned char) * (*src).p_hair[0].width * (*src).p_hair[0].height;
        unsigned char *data = malloc(image_data_size);
        memset(data, 0, image_data_size);
        memcpy(data, (*src).p_hair[0].data, image_data_size);
        p_hair[0].data = data;
        
        (*dst).p_hair = p_hair;
    }
}

void freeHumanAction(st_mobile_human_action_t *src) {
    // free faces
    if ((*src).face_count > 0) {
        for (int i = 0; i < (*src).face_count; i ++) {
            st_mobile_face_t face = (*src).p_faces[i];
            // p_extra_face_points
            if (face.extra_face_points_count > 0 && face.p_extra_face_points != NULL) {
                free(face.p_extra_face_points);
                face.p_extra_face_points = NULL;
            }
            // p_tongue_points & p_tongue_points_score
            if (   face.tongue_points_count > 0
                && face.p_tongue_points != NULL
                && face.p_tongue_points_score != NULL) {
                
                free(face.p_tongue_points);
                face.p_tongue_points = NULL;
                
                free(face.p_tongue_points_score);
                face.p_tongue_points_score = NULL;
            }
            // p_eyeball_center
            if (face.eyeball_center_points_count > 0 && face.p_eyeball_center != NULL) {
                free(face.p_eyeball_center);
                face.p_eyeball_center = NULL;
            }
            // p_eyeball_contour
            if (face.eyeball_contour_points_count > 0 && face.p_eyeball_contour != NULL) {
                free(face.p_eyeball_contour);
                face.p_eyeball_contour = NULL;
            }
        }
        free((*src).p_faces);
        (*src).p_faces = NULL;
    }
    // free hands
    if ((*src).hand_count > 0) {
        for (int i = 0; i < (*src).hand_count; i ++) {
            st_mobile_hand_t hand = (*src).p_hands[i];
            // p_key_points
            if (hand.key_points_count > 0 && hand.p_key_points != NULL) {
                free(hand.p_key_points);
                hand.p_key_points = NULL;
            }
            // p_skeleton_keypoints
            if (hand.skeleton_keypoints_count > 0 && hand.p_skeleton_keypoints != NULL) {
                free(hand.p_skeleton_keypoints);
                hand.p_skeleton_keypoints = NULL;
            }
            // p_skeleton_3d_keypoints
            if (hand.skeleton_3d_keypoints_count > 0 && hand.p_skeleton_3d_keypoints != NULL) {
                free(hand.p_skeleton_3d_keypoints);
                hand.p_skeleton_3d_keypoints = NULL;
            }
        }
        free((*src).p_hands);
        (*src).p_hands = NULL;
    }
    // free body
    if ((*src).body_count > 0) {
        for (int i = 0; i < (*src).body_count; i ++) {
            st_mobile_body_t body = (*src).p_bodys[i];
            // p_key_points & p_key_points_score
            if (   body.key_points_count > 0
                && body.p_key_points != NULL
                && body.p_key_points_score != NULL) {
                
                free(body.p_key_points);
                body.p_key_points = NULL;
                
                free(body.p_key_points_score);
                body.p_key_points_score = NULL;
            }
            // p_contour_points & p_contour_points_score
            if (   body.contour_points_count > 0
                && body.p_contour_points != NULL
                && body.p_contour_points_score != NULL) {
                
                free(body.p_contour_points);
                body.p_contour_points = NULL;
                
                free(body.p_contour_points_score);
                body.p_contour_points_score = NULL;
            }
        }
        free((*src).p_bodys);
        (*src).p_bodys = NULL;
    }
    // p_background
    if ((*src).p_background != NULL) {
        if ((*src).p_background[0].data != NULL) {
            free((*src).p_background[0].data);
            (*src).p_background[0].data = NULL;
        }
        
        free((*src).p_background);
        (*src).p_background = NULL;
    }
    // p_hair
    if ((*src).p_hair != NULL) {
        if ((*src).p_hair[0].data != NULL) {
            free((*src).p_hair[0].data);
            (*src).p_hair[0].data = NULL;
        }
        
        free((*src).p_hair);
        (*src).p_hair = NULL;
    }
    memset(src, 0, sizeof(st_mobile_human_action_t));
}

#pragma mark - STCommonObjectContainerViewDelegate

- (void)commonObjectViewStartTrackingFrame:(CGRect)frame {
    _commonObjectViewAdded = YES;
    _commonObjectViewSetted = NO;
    
    CGRect rect = frame;
    _rect.left = (rect.origin.x + _margin) / _scale;
    _rect.top = rect.origin.y / _scale;
    _rect.right = (rect.origin.x + rect.size.width + _margin) / _scale;
    _rect.bottom = (rect.origin.y + rect.size.height) / _scale;
}

- (void)commonObjectViewFinishTrackingFrame:(CGRect)frame {
    _commonObjectViewAdded = NO;
}

#pragma mark - STBeautySliderDelegate

- (CGFloat)currentSliderValue:(float)value slider:(UISlider *)slider {
    switch (self.curBeautyBeautyType) {
        case STBeautyTypeNone:
        case STBeautyTypeWhiten:
        case STBeautyTypeRuddy:
        case STBeautyTypeDermabrasion:
        case STBeautyTypeDehighlight:
        case STBeautyTypeShrinkFace:
        case STBeautyTypeEnlargeEyes:
        case STBeautyTypeShrinkJaw:
        case STBeautyTypeThinFaceShape:
        case STBeautyTypeNarrowNose:
        case STBeautyTypeContrast:
        case STBeautyTypeSaturation:
        case STBeautyTypeNarrowFace:
        case STBeautyTypeAppleMusle:
        case STBeautyTypeProfileRhinoplasty:
        case STBeautyTypeBrightEye:
        case STBeautyTypeRemoveDarkCircles:
        case STBeautyTypeWhiteTeeth:
        case STBeautyTypeOpenCanthus:
        case STBeautyTypeRemoveNasolabialFolds:
            value = (value + 1) / 2.0;
            break;
        default:
            break;
    }
    return value;
}

#pragma mark - scroll title click events

- (void)onTapNoneSticker:(UITapGestureRecognizer *)tapGesture {
    [self cancelStickerAndObjectTrack];
    self.noneStickerImageView.highlighted = YES;
}

- (void)cancelStickerAndObjectTrack {
    [self handleStickerChanged:nil];
    self.objectTrackCollectionView.selectedModel.isSelected = NO;
    [self.objectTrackCollectionView reloadData];
    self.objectTrackCollectionView.selectedModel = nil;
    
    if (_hSticker) {
        self.isNullSticker = YES;
    }
    
    if (_hTracker) {
        if (self.commonObjectContainerView.currentCommonObjectView) {
            [self.commonObjectContainerView.currentCommonObjectView removeFromSuperview];
        }
    }
    self.bTracker = NO;
}

#pragma mark - touch events

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self.view];
    if (self.specialEffectsContainerViewIsShow) {
        if (!CGRectContainsPoint(CGRectMake(0, SCREEN_HEIGHT - STEFFECT_HEIGHT, SCREEN_WIDTH, STEFFECT_HEIGHT), point)) {
            [self hideContainerView];
        }
    }
    if (self.beautyContainerViewIsShow) {
        if (!CGRectContainsPoint(CGRectMake(0, SCREEN_HEIGHT - STEFFECT_HEIGHT, SCREEN_WIDTH, STEFFECT_HEIGHT), point)) {
            [self hideBeautyContainerView];
        }
    }
}

#pragma mark - button click

- (void)clickBottomViewButton:(STViewButton *)senderView {
    switch (senderView.tag) {
        case STViewTagSpecialEffectsBtn:
            self.beautyBtn.userInteractionEnabled = NO;
            if (!self.specialEffectsContainerViewIsShow) {
                [self hideBeautyContainerView];
                [self containerViewAppear];
            } else {
                [self hideContainerView];
            }
            self.beautyBtn.userInteractionEnabled = YES;
            break;
        case STViewTagBeautyBtn:
            self.specialEffectsBtn.userInteractionEnabled = NO;
            if (!self.beautyContainerViewIsShow) {
                [self hideContainerView];
                [self beautyContainerViewAppear];
            } else {
                [self hideBeautyContainerView];
            }
            self.specialEffectsBtn.userInteractionEnabled = YES;
            break;
    }
}

- (void)filterSliderValueChanged:(UISlider *)sender {
    _fFilterStrength = sender.value;
    _lblFilterStrength.text = [NSString stringWithFormat:@"%d", (int)(sender.value * 100)];
    
    if (_hFilter) {
        st_result_t iRet = ST_OK;
        iRet = st_mobile_gl_filter_set_param(_hFilter, ST_GL_FILTER_STRENGTH, sender.value);
        if (ST_OK != iRet) {
            NSLog(@"st_mobile_gl_filter_set_param %d" , iRet);
        }
    }
}

#pragma mark - animations

- (void)hideContainerView {
    self.specialEffectsBtn.hidden = NO;
    self.beautyBtn.hidden = NO;
    
    [UIView animateWithDuration:0.05 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.specialEffectsContainerView.frame = CGRectMake(0, SCREEN_HEIGHT, SCREEN_WIDTH, 180);
    } completion:^(BOOL finished) {
        self.specialEffectsContainerViewIsShow = NO;
    }];
    self.specialEffectsBtn.highlighted = NO;
}

- (void)containerViewAppear {
    self.filterStrengthView.hidden = YES;
    self.specialEffectsBtn.hidden = YES;
    self.beautyBtn.hidden = YES;
    
    [UIView animateWithDuration:0.05 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.specialEffectsContainerView.frame = CGRectMake(0, SCREEN_HEIGHT - STEFFECT_HEIGHT, SCREEN_WIDTH, 180);
    } completion:^(BOOL finished) {
        self.specialEffectsContainerViewIsShow = YES;
    }];
    self.specialEffectsBtn.highlighted = YES;
}

- (void)hideBeautyContainerView {
    self.filterStrengthView.hidden = YES;
    self.beautySlider.hidden = YES;
    
    self.beautyBtn.hidden = NO;
    self.specialEffectsBtn.hidden = NO;
    self.resetBtn.hidden = YES;
    
    [UIView animateWithDuration:0.05 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.beautyContainerView.frame = CGRectMake(0, SCREEN_HEIGHT, SCREEN_WIDTH, 250);
    } completion:^(BOOL finished) {
        self.beautyContainerViewIsShow = NO;
    }];
    
    self.beautyBtn.highlighted = NO;
}

- (void)beautyContainerViewAppear {
    if (self.curEffectBeautyType == self.beautyCollectionView.selectedModel.modelType) {
        self.beautySlider.hidden = NO;
    }
    
    self.beautyBtn.hidden = YES;
    self.specialEffectsBtn.hidden = YES;
    self.resetBtn.hidden = NO;
    
    self.filterCategoryView.center = CGPointMake(SCREEN_WIDTH / 2, self.filterCategoryView.center.y);
    self.filterView.center = CGPointMake(SCREEN_WIDTH * 3 / 2, self.filterView.center.y);
    
    [UIView animateWithDuration:0.05 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.beautyContainerView.frame = CGRectMake(0, SCREEN_HEIGHT - STEFFECT_HEIGHT, SCREEN_WIDTH, STEFFECT_HEIGHT);
    } completion:^(BOOL finished) {
        self.beautyContainerViewIsShow = YES;
    }];
    self.beautyBtn.highlighted = YES;
}

- (void)hideBeautyViewExcept:(UIView *)view {
    for (UIView *beautyView in self.arrBeautyViews) {
        beautyView.hidden = !(view == beautyView);
    }
}

- (void)releaseResources {
    if ([EAGLContext currentContext] != self.glContext) {
        [EAGLContext setCurrentContext:self.glContext];
    }
    
    if (_hSticker) {
        st_result_t iRet = ST_OK;
        iRet = st_mobile_sticker_remove_avatar_model(_hSticker);
        if (iRet != ST_OK) {
            NSLog(@"remove avatar model failed: %d", iRet);
        }
        st_mobile_sticker_destroy(_hSticker);
        _hSticker = NULL;
    }
    if (_hBeautify) {
        st_mobile_beautify_destroy(_hBeautify);
        _hBeautify = NULL;
    }
    
    if (_animalHandle) {
        st_mobile_tracker_animal_face_destroy(_animalHandle);
        _animalHandle = NULL;
    }
    
    if (_hDetector) {
        st_mobile_human_action_destroy(_hDetector);
        _hDetector = NULL;
    }
    
    if (_hAttribute) {
        st_mobile_face_attribute_destroy(_hAttribute);
        _hAttribute = NULL;
    }
    
    if (_hFilter) {
        st_mobile_gl_filter_destroy(_hFilter);
        _hFilter = NULL;
    }
    
    if (_hTracker) {
        st_mobile_object_tracker_destroy(_hTracker);
        _hTracker = NULL;
    }
    
    [self releaseResultTexture];
    
    if (_cvTextureCache) {
        CFRelease(_cvTextureCache);
        _cvTextureCache = NULL;
    }
    
    [EAGLContext setCurrentContext:nil];
    
    self.glContext = nil;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.commonObjectContainerView removeFromSuperview];
        self.commonObjectContainerView = nil;
        
        self.ciContext = nil;
    });
}

- (void)initResourceAndStartPreview {
    ///ST_MOBILE：设置预览时需要注意 EAGLContext 的初始化
    [self setupEAGLContext];
    
    // 设置SDK OpenGL 环境 , 只有在正确的 OpenGL 环境下 SDK 才会被正确初始化 .
    self.ciContext = [CIContext contextWithEAGLContext:self.glContext
                                               options:@{kCIContextWorkingColorSpace : [NSNull null]}];
    [EAGLContext setCurrentContext:self.glContext];
    
    // 初始化结果文理及纹理缓存
    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, self.glContext, NULL, &_cvTextureCache);
    
    if (err) {
        NSLog(@"CVOpenGLESTextureCacheCreate %d" , err);
    }
    
    [self initResultTexture];
    
    ///ST_MOBILE：初始化句柄之前需要验证License
    if ([self checkActiveCodeWithData:self.licenseData]) {
        ///ST_MOBILE：初始化相关的句柄
        [self setupHandle];
    }else{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误提示" message:@"使用 license 文件生成激活码时失败，可能是授权文件过期。" delegate:nil cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
        [alert show];
    }
    if ([self.motionManager isAccelerometerAvailable]) {
        [self.motionManager startAccelerometerUpdates];
    }
    if ([self.motionManager isDeviceMotionAvailable]) {
        [self.motionManager startDeviceMotionUpdates];
    }
    
    //默认选中cherry滤镜
    _filterView.filterCollectionView.arrModels = _filterView.filterCollectionView.arrPortraitFilterModels;
    [_filterView.filterCollectionView selectItemAtIndexPath:[NSIndexPath indexPathForRow:[self getBabyPinkFilterIndex] inSection:0] animated:NO scrollPosition:UICollectionViewScrollPositionNone];
    _filterStrengthView.hidden = YES;
}

- (void)setupEAGLContext {
    _result_score = 0.0;
    self.glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    self.commonObjectContainerView = [[STCommonObjectContainerView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)];
    self.commonObjectContainerView.delegate = self;
    [self.view insertSubview:self.commonObjectContainerView atIndex:1];
}

- (NSUInteger)getBabyPinkFilterIndex {
    __block NSUInteger index = 0;
    [_filterView.filterCollectionView.arrPortraitFilterModels enumerateObjectsUsingBlock:^(STCollectionViewDisplayModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.strName isEqualToString:@"babypink"]) {
            index = idx;
            *stop = YES;
        }
    }];
    return index;
}

- (st_rotate_type)getRotateType {
    BOOL isFrontCamera = self.shortVideoRecorder.captureDevicePosition == AVCaptureDevicePositionFront;
    BOOL isVideoMirrored = NO;
    if (isFrontCamera) {
        isVideoMirrored = self.shortVideoRecorder.previewMirrorFrontFacing;
    } else {
        isVideoMirrored = self.shortVideoRecorder.previewMirrorRearFacing;
    }
    switch (self.shortVideoRecorder.videoOrientation) {
        case UIDeviceOrientationPortrait:
            return ST_CLOCKWISE_ROTATE_0;
        case UIDeviceOrientationPortraitUpsideDown:
            return ST_CLOCKWISE_ROTATE_180;
        case UIDeviceOrientationLandscapeLeft:
            return ((isFrontCamera && isVideoMirrored) || (!isFrontCamera && !isVideoMirrored)) ? ST_CLOCKWISE_ROTATE_270 : ST_CLOCKWISE_ROTATE_90;
        case UIDeviceOrientationLandscapeRight:
            return ((isFrontCamera && isVideoMirrored) || (!isFrontCamera && !isVideoMirrored)) ? ST_CLOCKWISE_ROTATE_90 : ST_CLOCKWISE_ROTATE_270;
        default:
            return ST_CLOCKWISE_ROTATE_0;
    }
}

#pragma mark - reset
- (UIButton *)resetBtn {
    if (!_resetBtn) {
        _resetBtn = [[UIButton alloc] initWithFrame:CGRectMake(SCREEN_WIDTH - 100, SCREEN_HEIGHT - 50, 100, 30)];
        _resetBtn.center = CGPointMake(_resetBtn.center.x, self.beautyBtn.center.y);
        
        [_resetBtn setImage:[UIImage imageNamed:@"reset"] forState:UIControlStateNormal];
        [_resetBtn setTitle:@"重置" forState:UIControlStateNormal];
        _resetBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        [_resetBtn setTitleColor:UIColorFromRGB(0xffffff) forState:UIControlStateNormal];
        [_resetBtn addTarget:self action:@selector(resetBeautyValues:) forControlEvents:UIControlEventTouchUpInside];
        
        _resetBtn.hidden = YES;
    }
    return _resetBtn;
}

- (void)resetBeautyValues:(UIButton *)sender {
    switch (_curEffectBeautyType) {
        //reset filter to baby pink
        case STEffectsTypeBeautyFilter:
        {
            [self refreshFilterCategoryState:STEffectsTypeFilterPortrait];
            
            self.fFilterStrength = 0.65;
            self.lblFilterStrength.text = @"65";
            self.filterStrengthSlider.value = 0.65;
            
            if (self.filterView.filterCollectionView.selectedModel.modelType == STEffectsTypeFilterPortrait) {
                self.filterView.filterCollectionView.selectedModel.isSelected = NO;
                self.filterView.filterCollectionView.arrPortraitFilterModels[[self getBabyPinkFilterIndex]].isSelected = YES;
                [self.filterView.filterCollectionView reloadData];
                
            } else {
                self.filterStrengthView.hidden = YES;
                self.filterView.filterCollectionView.selectedModel.isSelected = NO;
                [self.filterView.filterCollectionView reloadData];
                self.filterView.filterCollectionView.selectedModel = nil;
                self.filterView.filterCollectionView.arrPortraitFilterModels[[self getBabyPinkFilterIndex]].isSelected = YES;
            }
            self.currentSelectedFilterModel = self.filterView.filterCollectionView.arrPortraitFilterModels[[self getBabyPinkFilterIndex]];
            self.filterView.filterCollectionView.selectedModel = self.currentSelectedFilterModel;
            self.curFilterModelPath = self.currentSelectedFilterModel.strPath;
            st_mobile_gl_filter_set_param(_hFilter, ST_GL_FILTER_STRENGTH, self.fFilterStrength);
        }
            
            break;
        case STEffectsTypeBeautyBase:
            self.fSmoothStrength = 0.74;
            self.fReddenStrength = 0.36;
            self.fWhitenStrength = 0.02;
            self.fDehighlightStrength = 0.0;
            
            self.baseBeautyModels[0].beautyValue = 2;
            self.baseBeautyModels[1].beautyValue = 36;
            self.baseBeautyModels[2].beautyValue = 74;
            self.baseBeautyModels[3].beautyValue = 0;
            
            break;
        case STEffectsTypeBeautyShape:
            self.fEnlargeEyeStrength = 0.13;
            self.fShrinkFaceStrength = 0.11;
            self.fShrinkJawStrength = 0.10;
            self.fNarrowFaceStrength = 0.0;
            
            self.beautyShapeModels[0].beautyValue = 11;
            self.beautyShapeModels[1].beautyValue = 13;
            self.beautyShapeModels[2].beautyValue = 10;
            self.beautyShapeModels[3].beautyValue = 0;
            
            break;
        case STEffectsTypeBeautyMicroSurgery:
            self.fThinFaceShapeStrength = 0.0;
            self.fChinStrength = 0.0;
            self.fHairLineStrength = 0.0;
            self.fNarrowNoseStrength = 0.0;
            self.fLongNoseStrength = 0.0;
            self.fMouthStrength = 0.0;
            self.fPhiltrumStrength = 0.0;
            
            self.fEyeDistanceStrength = 0.0;
            self.fEyeAngleStrength = 0.0;
            self.fOpenCanthusStrength = 0.0;
            self.fProfileRhinoplastyStrength = 0.0;
            self.fBrightEyeStrength = 0.0;
            self.fRemoveNasolabialFoldsStrength = 0.0;
            self.fRemoveDarkCirclesStrength = 0.0;
            self.fWhiteTeethStrength = 0.0;
            self.fAppleMusleStrength = 0.0;
            
            self.microSurgeryModels[0].beautyValue = 0;
            self.microSurgeryModels[1].beautyValue = 0;
            self.microSurgeryModels[2].beautyValue = 0;
            self.microSurgeryModels[3].beautyValue = 0;
            self.microSurgeryModels[4].beautyValue = 0;
            self.microSurgeryModels[5].beautyValue = 0;
            self.microSurgeryModels[6].beautyValue = 0;
            self.microSurgeryModels[7].beautyValue = 0;
            self.microSurgeryModels[8].beautyValue = 0;
            self.microSurgeryModels[9].beautyValue = 0;
            self.microSurgeryModels[10].beautyValue = 0;
            self.microSurgeryModels[11].beautyValue = 0;
            self.microSurgeryModels[12].beautyValue = 0;
            self.microSurgeryModels[13].beautyValue = 0;
            self.microSurgeryModels[14].beautyValue = 0;
            self.microSurgeryModels[15].beautyValue = 0;
            
            break;
        case STEffectsTypeBeautyAdjust:
            self.fContrastStrength = 0.0;
            self.fSaturationStrength = 0.0;
            
            self.adjustModels[0].beautyValue = 0;
            self.adjustModels[1].beautyValue = 0;
            
            break;
            
        default:
            break;
    }
    
    [self.beautyCollectionView reloadData];
//    self.beautySlider.value = self.beautyCollectionView.selectedModel.beautyValue / 100.0;
    
    switch (self.beautyCollectionView.selectedModel.beautyType) {
        case STBeautyTypeNone:
        case STBeautyTypeWhiten:
        case STBeautyTypeRuddy:
        case STBeautyTypeDermabrasion:
        case STBeautyTypeDehighlight:
        case STBeautyTypeShrinkFace:
        case STBeautyTypeEnlargeEyes:
        case STBeautyTypeShrinkJaw:
        case STBeautyTypeThinFaceShape:
        case STBeautyTypeNarrowNose:
        case STBeautyTypeContrast:
        case STBeautyTypeSaturation:
        case STBeautyTypeNarrowFace:
        case STBeautyTypeAppleMusle:
        case STBeautyTypeProfileRhinoplasty:
        case STBeautyTypeBrightEye:
        case STBeautyTypeRemoveDarkCircles:
        case STBeautyTypeWhiteTeeth:
        case STBeautyTypeOpenCanthus:
        case STBeautyTypeRemoveNasolabialFolds:
            
            self.beautySlider.value = self.beautyCollectionView.selectedModel.beautyValue / 50.0 - 1;
            
            break;
        case STBeautyTypeChin:
        case STBeautyTypeHairLine:
        case STBeautyTypeLengthNose:
        case STBeautyTypeMouthSize:
        case STBeautyTypeLengthPhiltrum:
        case STBeautyTypeEyeDistance:
        case STBeautyTypeEyeAngle:
            
            self.beautySlider.value = self.beautyCollectionView.selectedModel.beautyValue / 100.0;
            break;
    }
}

- (void)resetCommonObjectViewPosition {
    if (self.commonObjectContainerView.currentCommonObjectView) {
        _commonObjectViewSetted = NO;
        _commonObjectViewAdded = NO;
        self.commonObjectContainerView.currentCommonObjectView.hidden = NO;
        self.commonObjectContainerView.currentCommonObjectView.onFirst = YES;
        self.commonObjectContainerView.currentCommonObjectView.center = CGPointMake(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2);
    }
}

- (void)resetSettings {
    self.noneStickerImageView.highlighted = YES;
    self.lblFilterStrength.text = @"65";
    self.filterStrengthSlider.value = 0.65;
    self.fFilterStrength = 0.65;
    
    self.currentSelectedFilterModel.isSelected = NO;
    [self refreshFilterCategoryState:STEffectsTypeNone];
    
    self.fSmoothStrength = 0.74;
    self.fReddenStrength = 0.36;
    self.fWhitenStrength = 0.02;
    self.fDehighlightStrength = 0.0;
    
    self.fEnlargeEyeStrength = 0.13;
    self.fShrinkFaceStrength = 0.11;
    self.fShrinkJawStrength = 0.10;
    self.fThinFaceShapeStrength = 0.0;
    
    self.fChinStrength = 0.0;
    self.fHairLineStrength = 0.0;
    self.fNarrowNoseStrength = 0.0;
    self.fLongNoseStrength = 0.0;
    self.fMouthStrength = 0.0;
    self.fPhiltrumStrength = 0.0;
    
    self.fEyeDistanceStrength = 0.0;
    self.fEyeAngleStrength = 0.0;
    self.fOpenCanthusStrength = 0.0;
    self.fProfileRhinoplastyStrength = 0.0;
    self.fBrightEyeStrength = 0.0;
    self.fRemoveDarkCirclesStrength = 0.0;
    self.fRemoveNasolabialFoldsStrength = 0.0;
    self.fWhiteTeethStrength = 0.0;
    self.fAppleMusleStrength = 0.0;
    
    self.fContrastStrength = 0.0;
    self.fSaturationStrength = 0.0;
    
    self.baseBeautyModels[0].beautyValue = 2;
    self.baseBeautyModels[0].selected = NO;
    self.baseBeautyModels[1].beautyValue = 36;
    self.baseBeautyModels[1].selected = NO;
    self.baseBeautyModels[2].beautyValue = 74;
    self.baseBeautyModels[2].selected = NO;
    self.baseBeautyModels[3].beautyValue = 0;
    self.baseBeautyModels[3].selected = NO;
    
    self.microSurgeryModels[0].beautyValue = 0;
    self.microSurgeryModels[0].selected = NO;
    self.microSurgeryModels[1].beautyValue = 0;
    self.microSurgeryModels[1].selected = NO;
    self.microSurgeryModels[2].beautyValue = 0;
    self.microSurgeryModels[2].selected = NO;
    self.microSurgeryModels[3].beautyValue = 0;
    self.microSurgeryModels[3].selected = NO;
    self.microSurgeryModels[4].beautyValue = 0;
    self.microSurgeryModels[4].selected = NO;
    self.microSurgeryModels[5].beautyValue = 0;
    self.microSurgeryModels[5].selected = NO;
    self.microSurgeryModels[6].beautyValue = 0;
    self.microSurgeryModels[6].selected = NO;
    self.microSurgeryModels[7].beautyValue = 0;
    self.microSurgeryModels[7].selected = NO;
    self.microSurgeryModels[8].beautyValue = 0;
    self.microSurgeryModels[8].selected = NO;
    self.microSurgeryModels[9].beautyValue = 0;
    self.microSurgeryModels[9].selected = NO;
    self.microSurgeryModels[10].beautyValue = 0;
    self.microSurgeryModels[10].selected = NO;
    self.microSurgeryModels[11].beautyValue = 0;
    self.microSurgeryModels[11].selected = NO;
    self.microSurgeryModels[12].beautyValue = 0;
    self.microSurgeryModels[12].selected = NO;
    self.microSurgeryModels[13].beautyValue = 0;
    self.microSurgeryModels[13].selected = NO;
    self.microSurgeryModels[14].beautyValue = 0;
    self.microSurgeryModels[14].selected = NO;
    self.microSurgeryModels[15].beautyValue = 0;
    self.microSurgeryModels[15].selected = NO;
    
    self.beautyShapeModels[0].beautyValue = 11;
    self.beautyShapeModels[0].selected = NO;
    self.beautyShapeModels[1].beautyValue = 13;
    self.beautyShapeModels[1].selected = NO;
    self.beautyShapeModels[2].beautyValue = 10;
    self.beautyShapeModels[2].selected = NO;
    
    self.adjustModels[0].beautyValue = 0;
    self.adjustModels[0].selected = NO;
    self.adjustModels[1].beautyValue = 0;
    self.adjustModels[1].selected = NO;
    
    self.beautyCollectionView.selectedModel = nil;
    [self.beautyCollectionView reloadData];
    
    self.preFilterModelPath = nil;
    self.curFilterModelPath = nil;
}
// ================================================= senseTime 相关使用 end =================================================
@end

