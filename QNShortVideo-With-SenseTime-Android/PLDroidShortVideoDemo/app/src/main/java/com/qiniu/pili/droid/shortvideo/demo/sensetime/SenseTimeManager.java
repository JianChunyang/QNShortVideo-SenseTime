package com.qiniu.pili.droid.shortvideo.demo.sensetime;

import android.content.Context;
import android.graphics.Rect;
import android.hardware.Camera;
import android.hardware.SensorEvent;
import android.opengl.GLES20;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Message;
import android.util.Log;

import com.qiniu.pili.droid.shortvideo.demo.activity.VideoRecordActivity;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.gl.TextureProcessor;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.glutils.GlUtil;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.utils.Accelerometer;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.utils.Constants;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.utils.FileUtils;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.utils.STUtils;
import com.sensetime.stmobile.STBeautifyNative;
import com.sensetime.stmobile.STBeautyParamsType;
import com.sensetime.stmobile.STCommon;
import com.sensetime.stmobile.STFilterParamsType;
import com.sensetime.stmobile.STHumanActionParamsType;
import com.sensetime.stmobile.STMobileAnimalNative;
import com.sensetime.stmobile.STMobileAvatarNative;
import com.sensetime.stmobile.STMobileFaceAttributeNative;
import com.sensetime.stmobile.STMobileHumanActionNative;
import com.sensetime.stmobile.STMobileObjectTrackNative;
import com.sensetime.stmobile.STMobileStickerNative;
import com.sensetime.stmobile.STMobileStreamFilterNative;
import com.sensetime.stmobile.STRotateType;
import com.sensetime.stmobile.model.STHumanAction;
import com.sensetime.stmobile.model.STRect;
import com.sensetime.stmobile.model.STStickerInputParams;
import com.sensetime.stmobile.sticker_module_types.STCustomEvent;

import java.nio.ByteBuffer;
import java.util.Iterator;
import java.util.Queue;
import java.util.TreeMap;
import java.util.concurrent.LinkedBlockingQueue;

public class SenseTimeManager {
    private static final String TAG = "SenseTimeManager";

    private String mCurrentSticker;
    private String mCurrentFilterStyle;
    private float mCurrentFilterStrength = 0.65f;//阈值为[0,1]
    private float mFilterStrength = 0.65f;
    private String mFilterStyle;

    private STMobileStickerNative mStStickerNative = new STMobileStickerNative();
    private STBeautifyNative mStBeautifyNative = new STBeautifyNative();
    private STMobileHumanActionNative mSTHumanActionNative = new STMobileHumanActionNative();
    private STHumanAction mHumanActionBeautyOutput = new STHumanAction();
    private STMobileAnimalNative mStAnimalNative = new STMobileAnimalNative();
    private STMobileStreamFilterNative mSTMobileStreamFilterNative = new STMobileStreamFilterNative();
    private STMobileFaceAttributeNative mSTFaceAttributeNative = new STMobileFaceAttributeNative();
    private STMobileObjectTrackNative mSTMobileObjectTrackNative = new STMobileObjectTrackNative();
    private STMobileAvatarNative mSTMobileAvatarNative = new STMobileAvatarNative();

    private boolean mCameraChanging = false;

    private int mInputTextureId;

    private HandlerThread mProcessImageThread;
    private HandlerThread mHumanActionDetectThread;
    private Handler mProcessImageHandler;
    private static final int MESSAGE_PROCESS_IMAGE = 100;

    private byte[] mImageData;
    private byte[] mNv21ImageData;
    private boolean mNeedShowRect = true;
    private int mScreenIndexRectWidth = 0;
    private int mCustomEvent = 0;
    private SensorEvent mSensorEvent;

    private Rect mTargetRect = new Rect();
    private Rect mIndexRect = new Rect();
    private boolean mNeedSetObjectTarget = false;
    private boolean mIsObjectTracking = false;
    private int mImageWidth;
    private int mImageHeight;
    private int mImageRotation;
    private int mTexWidth;
    private int mTexHeight;
    private int mSurfaceWidth;
    private int mSurfaceHeight;
    private int mCameraID = Camera.CameraInfo.CAMERA_FACING_FRONT;

    private int[] mBeautifyTextureId;
    private int[] mTextureOutId;
    private int[] mFilterTextureOutId;
    private boolean mNeedBeautify = false;
    private boolean mNeedFaceAttribute = false;
    private boolean mNeedSticker = false;
    private boolean mNeedFilter = false;
    private boolean mNeedObject = false;
    private float[] mBeautifyParams = {0.36f, 0.74f, 0.02f, 0.13f, 0.11f, 0.1f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f};
    private Handler mHandler;
    private boolean mIsPaused = false;
    private long mDetectConfig = 0;
    private boolean mIsCreateHumanActionHandleSucceeded = false;
    private Object mHumanActionHandleLock = new Object();
    private Object mImageDataLock = new Object();
    private int mHumanActionCreateConfig = STMobileHumanActionNative.ST_MOBILE_HUMAN_ACTION_DEFAULT_CONFIG_VIDEO;
    private Context mContext;

    private static final int MESSAGE_ADD_SUB_MODEL = 1001;
    private static final int MESSAGE_REMOVE_SUB_MODEL = 1002;
    private static final int MESSAGE_NEED_CHANGE_STICKER = 1003;
    private static final int MESSAGE_NEED_REMOVE_STICKER = 1004;
    private static final int MESSAGE_NEED_REMOVEALL_STICKERS = 1005;
    private static final int MESSAGE_NEED_ADD_STICKER = 1006;

    private HandlerThread mSubModelsManagerThread;
    private Handler mSubModelsManagerHandler;

    private HandlerThread mChangeStickerManagerThread;
    private Handler mChangeStickerManagerHandler;

    private TreeMap<Integer, String> mCurrentStickerMaps = new TreeMap<>();
    private int mParamType = 0;
    private Queue<STHumanAction> queue = new LinkedBlockingQueue<>();

    private TextureProcessor mTextureProcessor;

    public SenseTimeManager(Context context) {
        mContext = context;

        //初始化非OpengGL相关的句柄，包括人脸检测及人脸属性
        initHumanAction();    //因为人脸模型加载较慢，建议异步调用
        initObjectTrack();
        initHandlerManager();
    }

    /**
     * 初始化GL相关的句柄，包括美颜，贴纸，滤镜
     */
    public void onSurfaceCreated() {
        initBeauty();
        initSticker();
        initFilter();
    }

    /**
     * 根据显示区域大小调整一些参数信息
     *
     * @param width
     * @param height
     */
    public void adjustViewPort(int width, int height) {
        mSurfaceWidth = width;
        mSurfaceHeight = height;
        if (mTextureProcessor == null) {
            mTextureProcessor = new TextureProcessor();
            mTextureProcessor.setup();
        }
        mTextureProcessor.setViewportSize(width, height);
    }

    public void onSurfaceDestroyed() {
        mSTHumanActionNative.reset();
        destroyBeautifyNative();
        destroyStickerNative();
        destroyFilterNative();
        mTextureProcessor.release();
        mTextureProcessor = null;
    }

    public void onResume() {
        mIsPaused = false;
    }

    public void onPause() {
        mIsPaused = true;
        mImageData = null;
    }

    public void onDestroy() {
        //必须释放非opengGL句柄资源,负责内存泄漏
        synchronized (mHumanActionHandleLock) {
            mSTHumanActionNative.destroyInstance();
        }
        mSTFaceAttributeNative.destroyInstance();
        mSTMobileObjectTrackNative.destroyInstance();
        mStAnimalNative.destroyInstance();
        mSTMobileAvatarNative.destroyInstance();

        if (mCurrentStickerMaps != null) {
            mCurrentStickerMaps.clear();
            mCurrentStickerMaps = null;
        }
    }

    public void setHandler(Handler handler) {
        mHandler = handler;
    }

    public void switchCamera() {
        mCameraChanging = true;
        mCameraID = mCameraID == Camera.CameraInfo.CAMERA_FACING_FRONT ? Camera.CameraInfo.CAMERA_FACING_BACK : Camera.CameraInfo.CAMERA_FACING_FRONT;
        if(mNeedObject){
            resetIndexRect();
        } else {
            Message msg = mHandler.obtainMessage(VideoRecordActivity.MSG_CLEAR_OBJECT);
            mHandler.sendMessage(msg);
        }
    }

    public void setSensorEvent(SensorEvent event){
        mSensorEvent =  event;
    }

    public void enableBeautify(boolean needBeautify) {
        mNeedBeautify = needBeautify;
        setHumanActionDetectConfig(mNeedBeautify | mNeedFaceAttribute, mStStickerNative.getTriggerAction());
    }

    public void enableSticker(boolean needSticker) {
        mNeedSticker = needSticker;
        //reset humanAction config
        if (!needSticker) {
            setHumanActionDetectConfig(mNeedBeautify | mNeedFaceAttribute, mStStickerNative.getTriggerAction());
        }
    }

    public void enableFilter(boolean needFilter) {
        mNeedFilter = needFilter;
    }

    /**
     * 处理相机采集的 YUV 数据
     *
     * @param data 视频帧数据
     * @param width 视频帧宽度
     * @param height 视频帧高度
     * @param rotation 视频角度，顺时针 0/90/180/270 度
     */
    public void handlePreviewFrame(byte[] data, int width, int height, int rotation) {
        mImageWidth = height;
        mImageHeight = width;
        mImageRotation = rotation;

        if (mImageData == null || mImageData.length != mImageHeight * mImageWidth * 3 / 2) {
            mImageData = new byte[mImageWidth * mImageHeight * 3 / 2];
        }
        synchronized (mImageDataLock) {
            System.arraycopy(data, 0, mImageData, 0, data.length);
        }

        mProcessImageHandler.removeMessages(MESSAGE_PROCESS_IMAGE);
        mProcessImageHandler.sendEmptyMessage(MESSAGE_PROCESS_IMAGE);
    }

    /**
     * 处理采集的纹理数据
     *
     * @param texId 预览的输入纹理
     * @param texWidth 纹理的宽
     * @param texHeight 纹理的高
     * @return 处理后的纹理
     */
    public int drawFrame(int texId, int texWidth, int texHeight) {
        if (mTexWidth != texWidth || mTexHeight != texHeight || mCameraChanging) {
            deleteInternalTextures();
            mTexWidth = texWidth;
            mTexHeight = texHeight;
            if (mCameraChanging) {
                mCameraChanging = false;
            }
        }
        if (mBeautifyTextureId == null) {
            mBeautifyTextureId = new int[1];
            GlUtil.initEffectTexture(mTexWidth, mTexHeight, mBeautifyTextureId, GLES20.GL_TEXTURE_2D);

        }
        if (mTextureOutId == null) {
            mTextureOutId = new int[1];
            GlUtil.initEffectTexture(mTexWidth, mTexHeight, mTextureOutId, GLES20.GL_TEXTURE_2D);
        }

        mInputTextureId = mTextureProcessor.draw(texId);

        if (mNeedBeautify || mNeedSticker || mNeedFaceAttribute) {
            STHumanAction humanAction = null;

            if(mIsCreateHumanActionHandleSucceeded) {
                if (mCameraChanging || mImageData == null || mImageData.length != mImageHeight * mImageWidth * 3 / 2) {
                    return mInputTextureId;
                }
                synchronized (mImageDataLock) {
                    if (mNv21ImageData == null || mNv21ImageData.length != mImageHeight * mImageWidth * 3 / 2) {
                        mNv21ImageData = new byte[mImageWidth * mImageHeight * 3 / 2];
                    }

                    if (mImageData != null && mNv21ImageData.length >= mImageData.length) {
                        System.arraycopy(mImageData, 0, mNv21ImageData, 0, mImageData.length);
                    }
                }

                if (mImageHeight * mImageWidth * 3 / 2 > mNv21ImageData.length) {
                    return mInputTextureId;
                }

                long startHumanAction = System.currentTimeMillis();
                humanAction = mSTHumanActionNative.humanActionDetect(mNv21ImageData, STCommon.ST_PIX_FMT_NV21,
                        mDetectConfig, getHumanActionOrientation(), mImageHeight, mImageWidth);
                Log.i(TAG, "human action cost time: " + (System.currentTimeMillis() - startHumanAction));

                /**
                 * HumanAction rotate && mirror:双输入场景中，buffer为相机原始数据，而texture已根据预览旋转和镜像处理，所以buffer和texture方向不一致，
                 * 根据buffer计算出的HumanAction不能直接使用，需要根据摄像头ID和摄像头方向处理后使用
                 */
                humanAction = STHumanAction.humanActionRotateAndMirror(humanAction, mImageWidth, mImageHeight, mCameraID, mImageRotation);
            }

            int orientation = getCurrentOrientation();

            if (mNeedBeautify) {// do beautify
                int result = mStBeautifyNative.processTexture(mInputTextureId, mTexWidth, mTexHeight, orientation, humanAction, mBeautifyTextureId[0], mHumanActionBeautyOutput);
                if (result == 0) {
                    mInputTextureId = mBeautifyTextureId[0];
                    humanAction = mHumanActionBeautyOutput;
                    Log.i(TAG, "replace enlarge eye and shrink face action");
                }
            }

            if (mCameraChanging) {
                return mInputTextureId;
            }

            //调用贴纸API绘制贴纸
            if (mNeedSticker) {
                /**
                 * 1.在切换贴纸时，调用STMobileStickerNative的changeSticker函数，传入贴纸路径(参考setShowSticker函数的使用)
                 * 2.切换贴纸后，使用STMobileStickerNative的getTriggerAction函数获取当前贴纸支持的手势和前后背景等信息，返回值为int类型
                 * 3.根据getTriggerAction函数返回值，重新配置humanActionDetect函数的config参数，使detect更高效
                 *
                 * 例：只检测人脸信息和当前贴纸支持的手势等信息时，使用如下配置：
                 * mDetectConfig = mSTMobileStickerNative.getTriggerAction()|STMobileHumanActionNative.ST_MOBILE_FACE_DETECT;
                 */

                int event = mCustomEvent;
                STStickerInputParams inputEvent;
                if ((mParamType & STMobileStickerNative.ST_INPUT_PARAM_CAMERA_QUATERNION) == STMobileStickerNative.ST_INPUT_PARAM_CAMERA_QUATERNION &&
                        mSensorEvent != null && mSensorEvent.values != null && mSensorEvent.values.length > 0) {
                    inputEvent = new STStickerInputParams(mSensorEvent.values, mCameraID == Camera.CameraInfo.CAMERA_FACING_FRONT, event);
                } else {
                    inputEvent = new STStickerInputParams(new float[]{0, 0, 0, 1}, mCameraID == Camera.CameraInfo.CAMERA_FACING_FRONT, event);
                }
                long stickerStartTime = System.currentTimeMillis();
                int result = mStStickerNative.processTexture(mInputTextureId, humanAction, orientation, orientation, mTexWidth, mTexHeight,
                        false, inputEvent, mTextureOutId[0]);
                if (event == mCustomEvent) {
                    mCustomEvent = 0;
                }

                Log.i(TAG, "sticker cost time: " + (System.currentTimeMillis() - stickerStartTime));

                if (result == 0) {
                    mInputTextureId = mTextureOutId[0];
                }
            }

        }

        if (mCurrentFilterStyle != mFilterStyle) {
            mCurrentFilterStyle = mFilterStyle;
            mSTMobileStreamFilterNative.setStyle(mCurrentFilterStyle);
        }
        if (mCurrentFilterStrength != mFilterStrength) {
            mCurrentFilterStrength = mFilterStrength;
            mSTMobileStreamFilterNative.setParam(STFilterParamsType.ST_FILTER_STRENGTH, mCurrentFilterStrength);
        }

        if (mFilterTextureOutId == null) {
            mFilterTextureOutId = new int[1];
            GlUtil.initEffectTexture(mTexWidth, mTexHeight, mFilterTextureOutId, GLES20.GL_TEXTURE_2D);
        }

        //滤镜
        if (mNeedFilter) {
            long filterStartTime = System.currentTimeMillis();
            //如果需要输出buffer推流或其他，设置该开关为true
            int result = mSTMobileStreamFilterNative.processTexture(mInputTextureId, mTexWidth, mTexHeight, mFilterTextureOutId[0]);
            Log.i(TAG, "filter cost time: " + (System.currentTimeMillis() - filterStartTime));
            if (result == 0) {
                mInputTextureId = mFilterTextureOutId[0];
            }
        }

        GLES20.glDisable(GLES20.GL_DEPTH_TEST);

        return mTextureProcessor.draw(mInputTextureId);
    }

    public void setBeautyParam(int index, float value) {
        if (mBeautifyParams[index] != value) {
            mStBeautifyNative.setParam(Constants.beautyTypes[index], value);
            mBeautifyParams[index] = value;
        }
    }

    public void changeSticker(String sticker) {
        Log.i(TAG, "changeSticker : " + sticker);
        mChangeStickerManagerHandler.removeMessages(MESSAGE_NEED_CHANGE_STICKER);
        Message msg = mChangeStickerManagerHandler.obtainMessage(MESSAGE_NEED_CHANGE_STICKER);
        msg.obj = sticker;

        mChangeStickerManagerHandler.sendMessage(msg);
    }

    public int addSticker(String addSticker) {
        mCurrentSticker = addSticker;
        int stickerId = mStStickerNative.addSticker(mCurrentSticker);

        if(stickerId > 0){
            mParamType = mStStickerNative.getNeededInputParams();
            if(mCurrentStickerMaps != null){
                mCurrentStickerMaps.put(stickerId, mCurrentSticker);
            }
            setHumanActionDetectConfig(mNeedBeautify|mNeedFaceAttribute, mStStickerNative.getTriggerAction());

            Message message1 = mHandler.obtainMessage(VideoRecordActivity.MSG_NEED_UPDATE_STICKER_TIPS);
            mHandler.sendMessage(message1);

            return stickerId;
        }else {
            Message message2 = mHandler.obtainMessage(VideoRecordActivity.MSG_NEED_SHOW_TOO_MUCH_STICKER_TIPS);
            mHandler.sendMessage(message2);

            return -1;
        }
    }

    public void removeSticker(int packageId) {
        mChangeStickerManagerHandler.removeMessages(MESSAGE_NEED_REMOVE_STICKER);
        Message msg = mChangeStickerManagerHandler.obtainMessage(MESSAGE_NEED_REMOVE_STICKER);
        msg.obj = packageId;

        mChangeStickerManagerHandler.sendMessage(msg);

    }

    public void removeAllStickers() {
        mChangeStickerManagerHandler.removeMessages(MESSAGE_NEED_REMOVEALL_STICKERS);
        Message msg = mChangeStickerManagerHandler.obtainMessage(MESSAGE_NEED_REMOVEALL_STICKERS);
        mChangeStickerManagerHandler.sendMessage(msg);
    }


    public void setFilterStyle(String modelPath) {
        mFilterStyle = modelPath;
    }

    public void setFilterStrength(float strength) {
        mFilterStrength = strength;
    }

    public long getStickerTriggerAction() {
        return mStStickerNative.getTriggerAction();
    }

    public void enableObject(boolean enabled) {
        mNeedObject = enabled;

        if (mNeedObject) {
            resetIndexRect();
        }
    }

    public void setIndexRect(int x, int y, boolean needRect) {
        mIndexRect = new Rect(x, y, x + mScreenIndexRectWidth, y + mScreenIndexRectWidth);
        mNeedShowRect = needRect;
    }

    public Rect getIndexRect() {
        return mIndexRect;
    }

    public void setObjectTrackRect() {
        mNeedSetObjectTarget = true;
        mIsObjectTracking = false;
        mTargetRect = STUtils.adjustToImageRectMin(getIndexRect(), mSurfaceWidth, mSurfaceHeight, mImageWidth, mImageHeight);
    }

    public void disableObjectTracking() {
        mIsObjectTracking = false;
    }

    public void resetIndexRect() {
        if (mImageWidth == 0) {
            return;
        }

        mScreenIndexRectWidth = mSurfaceWidth / 4;

        mIndexRect.left = (mSurfaceWidth - mScreenIndexRectWidth) / 2;
        mIndexRect.top = (mSurfaceHeight - mScreenIndexRectWidth) / 2;
        mIndexRect.right = mIndexRect.left + mScreenIndexRectWidth;
        mIndexRect.bottom = mIndexRect.top + mScreenIndexRectWidth;

        mNeedShowRect = true;
        mNeedSetObjectTarget = false;
        mIsObjectTracking = false;
    }

    public void changeCustomEvent() {
        mCustomEvent = STCustomEvent.ST_CUSTOM_EVENT_1 | STCustomEvent.ST_CUSTOM_EVENT_2;
    }

    private void initHandlerManager() {
        mProcessImageThread = new HandlerThread("ProcessImageThread");
        mProcessImageThread.start();
        mProcessImageHandler = new Handler(mProcessImageThread.getLooper()) {
            @Override
            public void handleMessage(Message msg) {
                if (msg.what == MESSAGE_PROCESS_IMAGE && !mIsPaused && !mCameraChanging) {
                    objectTrack();
                }
            }
        };

        mHumanActionDetectThread = new HandlerThread("mHumanActionDetectThread");
        mHumanActionDetectThread.start();

        mSubModelsManagerThread = new HandlerThread("SubModelManagerThread");
        mSubModelsManagerThread.start();
        mSubModelsManagerHandler = new Handler(mSubModelsManagerThread.getLooper()) {
            @Override
            public void handleMessage(Message msg) {
                if (!mIsPaused && !mCameraChanging && mIsCreateHumanActionHandleSucceeded) {
                    switch (msg.what) {
                        case MESSAGE_ADD_SUB_MODEL:
                            String modelName = (String) msg.obj;
                            if (modelName != null) {
                                addSubModel(modelName);
                            }
                            break;

                        case MESSAGE_REMOVE_SUB_MODEL:
                            int config = (int) msg.obj;
                            if (config != 0) {
                                removeSubModel(config);
                            }
                            break;

                        default:
                            break;
                    }
                }
            }
        };

        mChangeStickerManagerThread = new HandlerThread("ChangeStickerManagerThread");
        mChangeStickerManagerThread.start();
        mChangeStickerManagerHandler = new Handler(mChangeStickerManagerThread.getLooper()) {
            @Override
            public void handleMessage(Message msg) {
                if (!mIsPaused) {
                    switch (msg.what) {
                        case MESSAGE_NEED_CHANGE_STICKER:
                            mCurrentSticker = (String) msg.obj;
                            int result = mStStickerNative.changeSticker(mCurrentSticker);
                            Log.i(TAG, "change sticker result: " + result);
                            mParamType = mStStickerNative.getNeededInputParams();
                            setHumanActionDetectConfig(mNeedBeautify | mNeedFaceAttribute, mStStickerNative.getTriggerAction());

                            Message message = mHandler.obtainMessage(VideoRecordActivity.MSG_NEED_UPDATE_STICKER_TIPS);
                            mHandler.sendMessage(message);
                            break;
                        case MESSAGE_NEED_REMOVE_STICKER:
                            int packageId = (int) msg.obj;
                            result = mStStickerNative.removeSticker(packageId);

                            if (mCurrentStickerMaps != null && result == 0) {
                                mCurrentStickerMaps.remove(packageId);
                            }
                            setHumanActionDetectConfig(mNeedBeautify | mNeedFaceAttribute, mStStickerNative.getTriggerAction());
                            break;
                        case MESSAGE_NEED_REMOVEALL_STICKERS:
                            mStStickerNative.removeAllStickers();
                            if (mCurrentStickerMaps != null) {
                                mCurrentStickerMaps.clear();
                            }
                            setHumanActionDetectConfig(mNeedBeautify | mNeedFaceAttribute, mStStickerNative.getTriggerAction());
                            break;
                        default:
                            break;
                    }
                }
            }
        };
    }

    /**
     * 初始化贴纸资源
     */
    private void initSticker() {
        int result = mStStickerNative.createInstance(mContext);
        Log.d(TAG, "the result for createInstance for sticker is %d");

        if (mNeedSticker) {
            mStStickerNative.changeSticker(mCurrentSticker);
        }

        if(mNeedSticker && mCurrentStickerMaps.size() == 0){
            mStStickerNative.changeSticker(mCurrentSticker);
        }

        if (mNeedSticker && mCurrentStickerMaps != null) {
            TreeMap<Integer, String> currentStickerMap = new TreeMap<>();

            for (Integer index : mCurrentStickerMaps.keySet()) {
                String sticker = mCurrentStickerMaps.get(index);//得到每个key多对用value的值

                int packageId = mStStickerNative.addSticker(sticker);
                currentStickerMap.put(packageId, sticker);

                Message messageReplace = mHandler.obtainMessage(VideoRecordActivity.MSG_NEED_REPLACE_STICKER_MAP);
                messageReplace.arg1 = index;
                messageReplace.arg2 = packageId;
                mHandler.sendMessage(messageReplace);
            }

            mCurrentStickerMaps.clear();

            Iterator<Integer> iter = currentStickerMap.keySet().iterator();
            while (iter.hasNext()) {
                int key = iter.next();
                mCurrentStickerMaps.put(key, currentStickerMap.get(key));
            }
        }

//        从sd卡加载Avatar模型
//        mStStickerNative.loadAvatarModel(FileUtils.getAvatarCoreModelPath(mContext));

//        从资源文件加载Avatar模型
        mStStickerNative.loadAvatarModelFromAssetFile(FileUtils.MODEL_NAME_AVATAR_CORE, mContext.getAssets());

        setHumanActionDetectConfig(mNeedBeautify | mNeedFaceAttribute, mStStickerNative.getTriggerAction());
        Log.i(TAG, "the result for createInstance for initSticker is " + result);
    }

    /**
     * 初始化美颜相关参数
     */
    private void initBeauty() {
        // 初始化beautify,preview的宽高
        int result = mStBeautifyNative.createInstance();
        if (result == 0) {
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_REDDEN_STRENGTH, mBeautifyParams[0]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_SMOOTH_STRENGTH, mBeautifyParams[1]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_WHITEN_STRENGTH, mBeautifyParams[2]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_ENLARGE_EYE_RATIO, mBeautifyParams[3]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_SHRINK_FACE_RATIO, mBeautifyParams[4]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_SHRINK_JAW_RATIO, mBeautifyParams[5]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_CONSTRACT_STRENGTH, mBeautifyParams[6]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_SATURATION_STRENGTH, mBeautifyParams[7]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_DEHIGHLIGHT_STRENGTH, mBeautifyParams[8]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_NARROW_FACE_STRENGTH, mBeautifyParams[9]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_3D_NARROW_NOSE_RATIO, mBeautifyParams[10]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_3D_NOSE_LENGTH_RATIO, mBeautifyParams[11]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_3D_CHIN_LENGTH_RATIO, mBeautifyParams[12]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_3D_MOUTH_SIZE_RATIO, mBeautifyParams[13]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_3D_PHILTRUM_LENGTH_RATIO, mBeautifyParams[14]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_3D_HAIRLINE_HEIGHT_RATIO, mBeautifyParams[15]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_3D_THIN_FACE_SHAPE_RATIO, mBeautifyParams[16]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_3D_EYE_DISTANCE_RATIO, mBeautifyParams[17]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_3D_EYE_ANGLE_RATIO, mBeautifyParams[18]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_3D_OPEN_CANTHUS_RATIO, mBeautifyParams[19]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_3D_PROFILE_RHINOPLASTY_RATIO, mBeautifyParams[20]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_3D_BRIGHT_EYE_RATIO, mBeautifyParams[21]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_3D_REMOVE_DARK_CIRCLES_RATIO, mBeautifyParams[22]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_3D_REMOVE_NASOLABIAL_FOLDS_RATIO, mBeautifyParams[23]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_3D_WHITE_TEETH_RATIO, mBeautifyParams[24]);
            mStBeautifyNative.setParam(STBeautyParamsType.ST_BEAUTIFY_3D_APPLE_MUSLE_RATIO, mBeautifyParams[25]);
        }
    }

    private void initHumanAction() {
        new Thread(new Runnable() {
            @Override
            public void run() {
                synchronized (mHumanActionHandleLock) {
                    //从sd读取model路径，创建handle
                    //int result = mSTHumanActionNative.createInstance(FileUtils.getTrackModelPath(mContext), mHumanActionCreateConfig);

                    //从asset资源文件夹读取model到内存，再使用底层st_mobile_human_action_create_from_buffer接口创建handle
                    int result = mSTHumanActionNative.createInstanceFromAssetFile(FileUtils.getActionModelName(), mHumanActionCreateConfig, mContext.getAssets());
                    Log.i(TAG, "the result for createInstance for human_action is " + result);

                    if (result == 0) {
                        result = mSTHumanActionNative.addSubModelFromAssetFile(FileUtils.MODEL_NAME_HAND, mContext.getAssets());
                        Log.i(TAG, "add hand model result is " + result);
                        result = mSTHumanActionNative.addSubModelFromAssetFile(FileUtils.MODEL_NAME_SEGMENT, mContext.getAssets());
                        Log.i(TAG, "add figure segment model result is " + result);

                        mIsCreateHumanActionHandleSucceeded = true;
                        mSTHumanActionNative.setParam(STHumanActionParamsType.ST_HUMAN_ACTION_PARAM_BACKGROUND_BLUR_STRENGTH, 0.35f);

                        //for test face morph
                        result = mSTHumanActionNative.addSubModelFromAssetFile(FileUtils.MODEL_NAME_FACE_EXTRA, mContext.getAssets());
                        Log.i(TAG, "add face extra model result is " + result);

                        //for test avatar
                        result = mSTHumanActionNative.addSubModelFromAssetFile(FileUtils.MODEL_NAME_EYEBALL_CONTOUR, mContext.getAssets());
                        Log.i(TAG, "add eyeball contour model result is " + result);
                    }
                }
            }
        }).start();
    }

    private void initFilter() {
        int result = mSTMobileStreamFilterNative.createInstance();
        mSTMobileStreamFilterNative.setStyle(mCurrentFilterStyle);

        mCurrentFilterStrength = mFilterStrength;
        mSTMobileStreamFilterNative.setParam(STFilterParamsType.ST_FILTER_STRENGTH, mCurrentFilterStrength);
    }

    private void initObjectTrack() {
        int result = mSTMobileObjectTrackNative.createInstance();
    }

    private void destroyBeautifyNative() {
        mStBeautifyNative.destroyBeautify();
    }

    private void destroyStickerNative() {
        mStStickerNative.removeAvatarModel();
        mStStickerNative.destroyInstance();
    }

    private void destroyFilterNative() {
        mSTMobileStreamFilterNative.destroyInstance();
    }

    private void addSubModel(final String modelName) {
        synchronized (mHumanActionHandleLock) {
            int result = mSTHumanActionNative.addSubModelFromAssetFile(modelName, mContext.getAssets());

            if (result == 0) {
                if (modelName.equals(FileUtils.MODEL_NAME_BODY_FOURTEEN)) {
                    mDetectConfig |= STMobileHumanActionNative.ST_MOBILE_BODY_KEYPOINTS;
                    mSTHumanActionNative.setParam(STHumanActionParamsType.ST_HUMAN_ACTION_PARAM_BODY_LIMIT, 3.0f);
                } else if (modelName.equals(FileUtils.MODEL_NAME_FACE_EXTRA)) {
                    mDetectConfig |= STMobileHumanActionNative.ST_MOBILE_DETECT_EXTRA_FACE_POINTS;
                } else if (modelName.equals(FileUtils.MODEL_NAME_EYEBALL_CONTOUR)) {
                    mDetectConfig |= STMobileHumanActionNative.ST_MOBILE_DETECT_EYEBALL_CONTOUR |
                            STMobileHumanActionNative.ST_MOBILE_DETECT_EYEBALL_CENTER;
                } else if (modelName.equals(FileUtils.MODEL_NAME_HAND)) {
                    mDetectConfig |= STMobileHumanActionNative.ST_MOBILE_HAND_DETECT_FULL;
                }
            }
        }
    }

    private void removeSubModel(final int config) {
        synchronized (mHumanActionHandleLock) {
            int result = mSTHumanActionNative.removeSubModelByConfig(config);
            if (config == STMobileHumanActionNative.ST_MOBILE_ENABLE_BODY_KEYPOINTS) {
                mDetectConfig &= ~STMobileHumanActionNative.ST_MOBILE_BODY_KEYPOINTS;
            } else if (config == STMobileHumanActionNative.ST_MOBILE_ENABLE_FACE_EXTRA_DETECT) {
                mDetectConfig &= ~STMobileHumanActionNative.ST_MOBILE_DETECT_EXTRA_FACE_POINTS;
            } else if (config == STMobileHumanActionNative.ST_MOBILE_ENABLE_EYEBALL_CONTOUR_DETECT) {
                mDetectConfig &= ~(STMobileHumanActionNative.ST_MOBILE_DETECT_EYEBALL_CONTOUR |
                        STMobileHumanActionNative.ST_MOBILE_DETECT_EYEBALL_CENTER);
            } else if (config == STMobileHumanActionNative.ST_MOBILE_ENABLE_HAND_DETECT) {
                mDetectConfig &= ~STMobileHumanActionNative.ST_MOBILE_HAND_DETECT_FULL;
            }
        }
    }

    private void deleteInternalTextures() {
        if (mBeautifyTextureId != null) {
            GLES20.glDeleteTextures(1, mBeautifyTextureId, 0);
            mBeautifyTextureId = null;
        }

        if (mTextureOutId != null) {
            GLES20.glDeleteTextures(1, mTextureOutId, 0);
            mTextureOutId = null;
        }

        if(mFilterTextureOutId != null){
            GLES20.glDeleteTextures(1, mFilterTextureOutId, 0);
            mFilterTextureOutId = null;
        }
    }

    /**
     * human action detect的配置选项,根据Sticker的TriggerAction和是否需要美颜配置
     *
     * @param needFaceDetect 是否需要开启face detect
     * @param config         sticker的TriggerAction
     */
    private void setHumanActionDetectConfig(boolean needFaceDetect, long config) {
        if (!mNeedSticker || mCurrentSticker == null) {
            config = 0;
        }

        if (needFaceDetect) {
            mDetectConfig = config | STMobileHumanActionNative.ST_MOBILE_FACE_DETECT;
        } else {
            mDetectConfig = config;
        }
    }

    private void objectTrack(){
        if(mImageData == null || mImageData.length == 0){
            return;
        }

        if(mNeedObject) {
            if (mNeedSetObjectTarget) {
                long startTimeSetTarget = System.currentTimeMillis();

                mTargetRect = STUtils.getObjectTrackInputRect(mTargetRect, mImageWidth, mImageHeight, mCameraID, mImageRotation);
                STRect inputRect = new STRect(mTargetRect.left, mTargetRect.top, mTargetRect.right, mTargetRect.bottom);

                mSTMobileObjectTrackNative.setTarget(mImageData, STCommon.ST_PIX_FMT_NV21, mImageHeight, mImageWidth, inputRect);
                Log.i(TAG, "setTarget cost time: " + (System.currentTimeMillis() - startTimeSetTarget) + " rotation = " + mImageRotation);
                mNeedSetObjectTarget = false;
                mIsObjectTracking = true;
            }

            Rect rect = new Rect(0, 0, 0, 0);

            if (mIsObjectTracking) {
                long startTimeObjectTrack = System.currentTimeMillis();
                float[] score = new float[1];
                STRect outputRect = mSTMobileObjectTrackNative.objectTrack(mImageData, STCommon.ST_PIX_FMT_NV21, mImageHeight, mImageWidth,score);
                Log.i(TAG, "objectTrack cost time: " + (System.currentTimeMillis() - startTimeObjectTrack));

                if(outputRect != null && score != null && score.length >0){
                    Rect outputTargetRect = new Rect(outputRect.getRect().left, outputRect.getRect().top,outputRect.getRect().right,outputRect.getRect().bottom);
                    outputTargetRect = STUtils.getObjectTrackOutputRect(outputTargetRect, mImageWidth, mImageHeight, mCameraID, mImageRotation);

                    rect = STUtils.adjustToScreenRectMin(outputTargetRect, mSurfaceWidth, mSurfaceHeight, mImageWidth, mImageHeight);

                    if(!mNeedShowRect){
                        Message msg = mHandler.obtainMessage(VideoRecordActivity.MSG_DRAW_OBJECT_IMAGE);
                        msg.obj = rect;
                        mHandler.sendMessage(msg);
                        mIndexRect = rect;
                    }
                }

            } else {
                if (mNeedShowRect) {
                    Message msg = mHandler.obtainMessage(VideoRecordActivity.MSG_DRAW_OBJECT_IMAGE_AND_RECT);
                    msg.obj = mIndexRect;
                    mHandler.sendMessage(msg);
                } else {
                    Message msg = mHandler.obtainMessage(VideoRecordActivity.MSG_DRAW_OBJECT_IMAGE);
                    msg.obj = rect;
                    mHandler.sendMessage(msg);
                    mIndexRect = rect;
                }
            }
        } else {

            if(!mNeedObject || !(mNeedBeautify || mNeedSticker || mNeedFaceAttribute)){
                Message msg = mHandler.obtainMessage(VideoRecordActivity.MSG_CLEAR_OBJECT);
                mHandler.sendMessage(msg);
            }
        }
    }

    /**
     * 用于humanActionDetect接口。根据传感器方向计算出在不同设备朝向时，人脸在buffer中的朝向
     * @return 人脸在buffer中的朝向
     */
    private int getHumanActionOrientation(){
        boolean frontCamera = (mCameraID == Camera.CameraInfo.CAMERA_FACING_FRONT);

        //获取重力传感器返回的方向
        int orientation = Accelerometer.getDirection();

        //在使用后置摄像头，且传感器方向为0或2时，后置摄像头与前置orentation相反
        if(!frontCamera && orientation == STRotateType.ST_CLOCKWISE_ROTATE_0){
            orientation = STRotateType.ST_CLOCKWISE_ROTATE_180;
        }else if(!frontCamera && orientation == STRotateType.ST_CLOCKWISE_ROTATE_180){
            orientation = STRotateType.ST_CLOCKWISE_ROTATE_0;
        }

        // 请注意前置摄像头与后置摄像头旋转定义不同 && 不同手机摄像头旋转定义不同
        if ((mImageRotation == 270 && (orientation & STRotateType.ST_CLOCKWISE_ROTATE_90) == STRotateType.ST_CLOCKWISE_ROTATE_90) ||
                (mImageRotation == 90 && (orientation & STRotateType.ST_CLOCKWISE_ROTATE_90) == STRotateType.ST_CLOCKWISE_ROTATE_0))
            orientation = (orientation ^ STRotateType.ST_CLOCKWISE_ROTATE_180);
        return orientation;
    }


    private int getCurrentOrientation() {
        int dir = Accelerometer.getDirection();
        int orientation = dir - 1;
        if (orientation < 0) {
            orientation = dir ^ 3;
        }

        return orientation;
    }
}
