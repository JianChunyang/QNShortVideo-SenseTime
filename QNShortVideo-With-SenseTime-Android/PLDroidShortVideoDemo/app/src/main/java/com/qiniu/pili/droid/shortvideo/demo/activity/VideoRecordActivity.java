package com.qiniu.pili.droid.shortvideo.demo.activity;

import android.app.Activity;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PixelFormat;
import android.graphics.PorterDuff;
import android.graphics.Rect;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.media.AudioFormat;
import android.opengl.GLSurfaceView;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.support.v7.app.AlertDialog;
import android.support.v7.widget.GridLayoutManager;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.support.v7.widget.StaggeredGridLayoutManager;
import android.text.TextUtils;
import android.util.Log;
import android.view.GestureDetector;
import android.view.MotionEvent;
import android.view.OrientationEventListener;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;
import android.widget.SeekBar;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;

import com.qiniu.pili.droid.shortvideo.PLAudioEncodeSetting;
import com.qiniu.pili.droid.shortvideo.PLCameraPreviewListener;
import com.qiniu.pili.droid.shortvideo.PLCameraSetting;
import com.qiniu.pili.droid.shortvideo.PLCaptureFrameListener;
import com.qiniu.pili.droid.shortvideo.PLDraft;
import com.qiniu.pili.droid.shortvideo.PLDraftBox;
import com.qiniu.pili.droid.shortvideo.PLFaceBeautySetting;
import com.qiniu.pili.droid.shortvideo.PLFocusListener;
import com.qiniu.pili.droid.shortvideo.PLMicrophoneSetting;
import com.qiniu.pili.droid.shortvideo.PLRecordSetting;
import com.qiniu.pili.droid.shortvideo.PLRecordStateListener;
import com.qiniu.pili.droid.shortvideo.PLShortVideoRecorder;
import com.qiniu.pili.droid.shortvideo.PLVideoEncodeSetting;
import com.qiniu.pili.droid.shortvideo.PLVideoFilterListener;
import com.qiniu.pili.droid.shortvideo.PLVideoFrame;
import com.qiniu.pili.droid.shortvideo.PLVideoSaveListener;
import com.qiniu.pili.droid.shortvideo.demo.R;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.utils.Accelerometer;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.view.BeautyItem;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.adapter.BeautyItemAdapter;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.adapter.BeautyOptionsAdapter;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.view.BeautyOptionsItem;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.utils.Constants;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.utils.FileUtils;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.adapter.FilterAdapter;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.view.FilterItem;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.utils.ImageUtils;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.view.IndicatorSeekBar;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.adapter.NativeStickerAdapter;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.utils.NetworkUtils;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.adapter.ObjectAdapter;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.view.ObjectItem;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.utils.STUtils;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.adapter.StickerAdapter;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.view.StickerItem;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.adapter.StickerOptionsAdapter;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.view.StickerOptionsItem;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.view.StickerState;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.view.VerticalSeekBar;
import com.qiniu.pili.droid.shortvideo.demo.sensetime.SenseTimeManager;
import com.qiniu.pili.droid.shortvideo.demo.utils.Config;
import com.qiniu.pili.droid.shortvideo.demo.utils.GetPathFromUri;
import com.qiniu.pili.droid.shortvideo.demo.utils.RecordSettings;
import com.qiniu.pili.droid.shortvideo.demo.utils.ToastUtils;
import com.qiniu.pili.droid.shortvideo.demo.view.CustomProgressDialog;
import com.qiniu.pili.droid.shortvideo.demo.view.FocusIndicator;
import com.qiniu.pili.droid.shortvideo.demo.view.SectionProgressBar;
import com.sensetime.sensearsourcemanager.SenseArMaterial;
import com.sensetime.sensearsourcemanager.SenseArMaterialService;
import com.sensetime.sensearsourcemanager.SenseArMaterialType;
import com.sensetime.stmobile.STMobileHumanActionNative;
import com.sensetime.stmobile.model.STPoint;

import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Stack;

import static com.qiniu.pili.droid.shortvideo.demo.utils.RecordSettings.RECORD_SPEED_ARRAY;
import static com.qiniu.pili.droid.shortvideo.demo.utils.RecordSettings.chooseCameraFacingId;

public class VideoRecordActivity extends Activity implements View.OnClickListener, PLRecordStateListener, PLVideoSaveListener, PLFocusListener {
    private static final String TAG = "VideoRecordActivity";
    public final static String APPID = "6dc0af51b69247d0af4b0a676e11b5ee";//正式服
    public final static String APPKEY = "e4156e4d61b040d2bcbf896c798d06e3";//正式服

    public static final String PREVIEW_SIZE_RATIO = "PreviewSizeRatio";
    public static final String PREVIEW_SIZE_LEVEL = "PreviewSizeLevel";
    public static final String ENCODING_MODE = "EncodingMode";
    public static final String ENCODING_SIZE_LEVEL = "EncodingSizeLevel";
    public static final String ENCODING_BITRATE_LEVEL = "EncodingBitrateLevel";
    public static final String AUDIO_CHANNEL_NUM = "AudioChannelNum";
    public static final String DRAFT = "draft";


    private PLShortVideoRecorder mShortVideoRecorder;

    private SectionProgressBar mSectionProgressBar;
    private CustomProgressDialog mProcessingDialog;
    private View mRecordBtn;
    private View mDeleteBtn;
    private View mConcatBtn;
    private View mSwitchCameraBtn;
    private View mSwitchFlashBtn;
    private FocusIndicator mFocusIndicator;

    private boolean mFlashEnabled;
    private boolean mIsEditVideo = false;

    private GestureDetector mGestureDetector;

    private PLCameraSetting mCameraSetting;
    private PLMicrophoneSetting mMicrophoneSetting;
    private PLRecordSetting mRecordSetting;
    private PLVideoEncodeSetting mVideoEncodeSetting;
    private PLAudioEncodeSetting mAudioEncodeSetting;
    private PLFaceBeautySetting mFaceBeautySetting;
    private ViewGroup mBottomControlPanel;

    private int mFocusIndicatorX;
    private int mFocusIndicatorY;

    private double mRecordSpeed;
    private TextView mSpeedTextView;

    private Stack<Long> mDurationRecordStack = new Stack();
    private Stack<Double> mDurationVideoStack = new Stack();

    private OrientationEventListener mOrientationListener;
    private boolean mSectionBegan;

    public PLCameraPreviewListener mPreviewListener = new PLCameraPreviewListener(){
        @Override
        public boolean onPreviewFrame(byte[] data, int width, int height, int rotation, int fmt, long timestampNs){
            if (mSTManager != null) {
                mSTManager.handlePreviewFrame(data, width, height, rotation);
            }
            return true;
        }
    };


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);
        setContentView(R.layout.activity_record);

        mSectionProgressBar = (SectionProgressBar) findViewById(R.id.record_progressbar);
        GLSurfaceView preview = (GLSurfaceView) findViewById(R.id.preview);

        mRecordBtn = findViewById(R.id.record);
        mDeleteBtn = findViewById(R.id.delete);
        mConcatBtn = findViewById(R.id.concat);
        mSwitchCameraBtn = findViewById(R.id.switch_camera);
        mSwitchFlashBtn = findViewById(R.id.switch_flash);
        mFocusIndicator = (FocusIndicator) findViewById(R.id.focus_indicator);
        mBottomControlPanel = (ViewGroup) findViewById(R.id.bottom_control_panel);
        mStickerOptionsSwitchIcon = (ImageView) findViewById(R.id.iv_sticker_options_switch);
        mBeautyOptionsSwitchIcon = (ImageView) findViewById(R.id.iv_beauty_options_switch);

        mProcessingDialog = new CustomProgressDialog(this);
        mProcessingDialog.setOnCancelListener(new DialogInterface.OnCancelListener() {
            @Override
            public void onCancel(DialogInterface dialog) {
                mShortVideoRecorder.cancelConcat();
            }
        });

        mShortVideoRecorder = new PLShortVideoRecorder();
        mShortVideoRecorder.setRecordStateListener(this);

        mRecordSpeed = RECORD_SPEED_ARRAY[2];
        mSpeedTextView = (TextView) findViewById(R.id.normal_speed_text);

        String draftTag = getIntent().getStringExtra(DRAFT);
        if (draftTag == null) {
            int previewSizeRatioPos = getIntent().getIntExtra(PREVIEW_SIZE_RATIO, 0);
            int previewSizeLevelPos = getIntent().getIntExtra(PREVIEW_SIZE_LEVEL, 0);
            int encodingModePos = getIntent().getIntExtra(ENCODING_MODE, 0);
            int encodingSizeLevelPos = getIntent().getIntExtra(ENCODING_SIZE_LEVEL, 0);
            int encodingBitrateLevelPos = getIntent().getIntExtra(ENCODING_BITRATE_LEVEL, 0);
            int audioChannelNumPos = getIntent().getIntExtra(AUDIO_CHANNEL_NUM, 0);

            mCameraSetting = new PLCameraSetting();
            PLCameraSetting.CAMERA_FACING_ID facingId = chooseCameraFacingId();
            mCameraSetting.setCameraId(facingId);
            mCameraSetting.setCameraPreviewSizeRatio(PLCameraSetting.CAMERA_PREVIEW_SIZE_RATIO.RATIO_16_9);
            mCameraSetting.setCameraPreviewSizeLevel(PLCameraSetting.CAMERA_PREVIEW_SIZE_LEVEL.PREVIEW_SIZE_LEVEL_720P);

            mMicrophoneSetting = new PLMicrophoneSetting();
            mMicrophoneSetting.setChannelConfig(RecordSettings.AUDIO_CHANNEL_NUM_ARRAY[audioChannelNumPos] == 1 ?
                    AudioFormat.CHANNEL_IN_MONO : AudioFormat.CHANNEL_IN_STEREO);

            mVideoEncodeSetting = new PLVideoEncodeSetting(this);
            mVideoEncodeSetting.setEncodingSizeLevel(PLVideoEncodeSetting.VIDEO_ENCODING_SIZE_LEVEL.VIDEO_ENCODING_SIZE_LEVEL_720P_3);
            mVideoEncodeSetting.setEncodingBitrate(2000 * 1000);
            mVideoEncodeSetting.setHWCodecEnabled(encodingModePos == 0);
            mVideoEncodeSetting.setConstFrameRateEnabled(true);

            mAudioEncodeSetting = new PLAudioEncodeSetting();
            mAudioEncodeSetting.setHWCodecEnabled(encodingModePos == 0);
            mAudioEncodeSetting.setChannels(RecordSettings.AUDIO_CHANNEL_NUM_ARRAY[audioChannelNumPos]);

            mRecordSetting = new PLRecordSetting();
            mRecordSetting.setMaxRecordDuration(RecordSettings.DEFAULT_MAX_RECORD_DURATION);
            mRecordSetting.setRecordSpeedVariable(true);
            mRecordSetting.setVideoCacheDir(Config.VIDEO_STORAGE_DIR);
            mRecordSetting.setVideoFilepath(Config.RECORD_FILE_PATH);

            mFaceBeautySetting = new PLFaceBeautySetting(1.0f, 0.5f, 0.5f);

            mShortVideoRecorder.prepare(preview, mCameraSetting, mMicrophoneSetting, mVideoEncodeSetting,
                    mAudioEncodeSetting, null, mRecordSetting);
            mSectionProgressBar.setFirstPointTime(RecordSettings.DEFAULT_MIN_RECORD_DURATION);
            onSectionCountChanged(0, 0);
        } else {
            PLDraft draft = PLDraftBox.getInstance(this).getDraftByTag(draftTag);
            if (draft == null) {
                ToastUtils.s(this, getString(R.string.toast_draft_recover_fail));
                finish();
            }

            mCameraSetting = draft.getCameraSetting();
            mMicrophoneSetting = draft.getMicrophoneSetting();
            mVideoEncodeSetting = draft.getVideoEncodeSetting();
            mAudioEncodeSetting = draft.getAudioEncodeSetting();
            mRecordSetting = draft.getRecordSetting();
            mFaceBeautySetting = draft.getFaceBeautySetting();

            if (mShortVideoRecorder.recoverFromDraft(preview, draft)) {
                long draftDuration = 0;
                for (int i = 0; i < draft.getSectionCount(); ++i) {
                    long currentDuration = draft.getSectionDuration(i);
                    draftDuration += draft.getSectionDuration(i);
                    onSectionIncreased(currentDuration, draftDuration, i + 1);
                    if (!mDurationRecordStack.isEmpty()) {
                        mDurationRecordStack.pop();
                    }
                }
                mSectionProgressBar.setFirstPointTime(draftDuration);
                ToastUtils.s(this, getString(R.string.toast_draft_recover_success));
            } else {
                onSectionCountChanged(0, 0);
                mSectionProgressBar.setFirstPointTime(RecordSettings.DEFAULT_MIN_RECORD_DURATION );
                ToastUtils.s(this, getString(R.string.toast_draft_recover_fail));
            }
        }
        mShortVideoRecorder.setRecordSpeed(mRecordSpeed);
        mSectionProgressBar.setProceedingSpeed(mRecordSpeed);
        mSectionProgressBar.setTotalTime(this, mRecordSetting.getMaxRecordDuration());

        mShortVideoRecorder.setFocusListener(this);
        mShortVideoRecorder.setCameraPreviewListener(mPreviewListener);
        mShortVideoRecorder.setVideoFilterListener(new PLVideoFilterListener() {
            @Override
            public void onSurfaceCreated() {
                mSTManager.onSurfaceCreated();
            }

            @Override
            public void onSurfaceChanged(int width, int height) {
                mSTManager.adjustViewPort(width, height);
            }

            @Override
            public void onSurfaceDestroy() {
                mSTManager.onSurfaceDestroyed();
            }

            @Override
            public int onDrawFrame(int texId, int texWidth, int texHeight, long timeStampNs, float[] transformMatrix) {
                return mSTManager.drawFrame(texId, texWidth, texHeight);
            }
        });


        mRecordBtn.setOnTouchListener(new View.OnTouchListener() {
            private long mSectionBeginTSMs;

            @Override
            public boolean onTouch(View v, MotionEvent event) {
                int action = event.getAction();
                if (action == MotionEvent.ACTION_DOWN) {
                    if (!mSectionBegan && mShortVideoRecorder.beginSection()) {
                        mSectionBegan = true;
                        mSectionBeginTSMs = System.currentTimeMillis();
                        mSectionProgressBar.setCurrentState(SectionProgressBar.State.START);
                        updateRecordingBtns(true);
                    } else {
                        ToastUtils.s(VideoRecordActivity.this, "无法开始视频段录制");
                    }
                } else if (action == MotionEvent.ACTION_UP) {
                    if (mSectionBegan) {
                        long sectionRecordDurationMs = System.currentTimeMillis() - mSectionBeginTSMs;
                        long totalRecordDurationMs = sectionRecordDurationMs + (mDurationRecordStack.isEmpty() ? 0 : mDurationRecordStack.peek().longValue());
                        double sectionVideoDurationMs = sectionRecordDurationMs / mRecordSpeed;
                        double totalVideoDurationMs = sectionVideoDurationMs + (mDurationVideoStack.isEmpty() ? 0 : mDurationVideoStack.peek().doubleValue());
                        mDurationRecordStack.push(new Long(totalRecordDurationMs));
                        mDurationVideoStack.push(new Double(totalVideoDurationMs));
                        if (mRecordSetting.IsRecordSpeedVariable()) {
                            Log.d(TAG,"SectionRecordDuration: " + sectionRecordDurationMs + "; sectionVideoDuration: " + sectionVideoDurationMs + "; totalVideoDurationMs: " + totalVideoDurationMs + "Section count: " + mDurationVideoStack.size());
                            mSectionProgressBar.addBreakPointTime((long) totalVideoDurationMs);
                        } else {
                            mSectionProgressBar.addBreakPointTime(totalRecordDurationMs);
                        }

                        mSectionProgressBar.setCurrentState(SectionProgressBar.State.PAUSE);
                        mShortVideoRecorder.endSection();
                        mSectionBegan = false;
                    }
                }

                return false;
            }
        });
        mGestureDetector = new GestureDetector(this, new GestureDetector.SimpleOnGestureListener() {
            @Override
            public boolean onSingleTapUp(MotionEvent e) {
                mFocusIndicatorX = (int) e.getX() - mFocusIndicator.getWidth() / 2;
                mFocusIndicatorY = (int) e.getY() - mFocusIndicator.getHeight() / 2;
                mShortVideoRecorder.manualFocus(mFocusIndicator.getWidth(), mFocusIndicator.getHeight(), (int) e.getX(), (int) e.getY());
                return false;
            }
        });

        mOrientationListener = new OrientationEventListener(this, SensorManager.SENSOR_DELAY_NORMAL) {
            @Override
            public void onOrientationChanged(int orientation) {
                int rotation = getScreenRotation(orientation);
                if (!mSectionProgressBar.isRecorded() && !mSectionBegan) {
                    mVideoEncodeSetting.setRotationInMetadata(rotation);
                }
            }
        };
        if (mOrientationListener.canDetectOrientation()) {
            mOrientationListener.enable();
        }

        // 初始化商汤 SDK
        initSenseTime();
    }

    @Override
    protected void onResume() {
        super.onResume();
        mAccelerometer.start();
        mSensorManager.registerListener(mSensorEventListener, mRotation, SensorManager.SENSOR_DELAY_GAME);
        mRecordBtn.setEnabled(false);
        mShortVideoRecorder.resume();
        mSTManager.onResume();
    }

    @Override
    protected void onPause() {
        super.onPause();

        mSensorManager.unregisterListener(mSensorEventListener);
        mSTManager.onPause();

        updateRecordingBtns(false);
        mShortVideoRecorder.pause();
        mAccelerometer.stop();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        mSTManager.onDestroy();
        mShortVideoRecorder.destroy();
        mOrientationListener.disable();
    }

    public void onClickDelete(View v) {
        if (!mShortVideoRecorder.deleteLastSection()) {
            ToastUtils.s(this, "回删视频段失败");
        }
    }

    public void onClickConcat(View v) {
        mProcessingDialog.show();
        showChooseDialog();
    }

    public void onClickSwitchCamera(View v) {
        mShortVideoRecorder.switchCamera();
        mFocusIndicator.focusCancel();
        if (mSTManager != null) {
            mSTManager.switchCamera();
        }
    }

    public void onClickSwitchFlash(View v) {
        mFlashEnabled = !mFlashEnabled;
        mShortVideoRecorder.setFlashEnabled(mFlashEnabled);
        mSwitchFlashBtn.setActivated(mFlashEnabled);
    }

    public void onClickAddMixAudio(View v) {
        Intent intent = new Intent();
        if (Build.VERSION.SDK_INT < 19) {
            intent.setAction(Intent.ACTION_GET_CONTENT);
            intent.setType("audio/*");
        } else {
            intent.setAction(Intent.ACTION_OPEN_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("audio/*");
        }
        startActivityForResult(Intent.createChooser(intent, "请选择混音文件："), 0);
    }

    private int getScreenRotation(int orientation) {
        int screenRotation = 0;
        boolean isPortraitScreen = getResources().getConfiguration().orientation == ActivityInfo.SCREEN_ORIENTATION_PORTRAIT;
        if (orientation >= 315 || orientation < 45) {
            screenRotation = isPortraitScreen ? 0 : 90;
        } else if (orientation >= 45 && orientation < 135) {
            screenRotation = isPortraitScreen ? 90 : 180;
        } else if (orientation >= 135 && orientation < 225) {
            screenRotation = isPortraitScreen ? 180 : 270;
        } else if (orientation >= 225 && orientation < 315) {
            screenRotation = isPortraitScreen ? 270 : 0;
        }
        return screenRotation;
    }

    private void updateRecordingBtns(boolean isRecording) {
        mSwitchCameraBtn.setEnabled(!isRecording);
        mRecordBtn.setActivated(isRecording);
    }

    public void onCaptureFrame(View v) {
        mShortVideoRecorder.captureFrame(new PLCaptureFrameListener() {
            @Override
            public void onFrameCaptured(PLVideoFrame capturedFrame) {
                if (capturedFrame == null) {
                    Log.e(TAG, "capture frame failed");
                    return;
                }

                Log.i(TAG, "captured frame width: " + capturedFrame.getWidth() + " height: " + capturedFrame.getHeight() + " timestamp: " + capturedFrame.getTimestampMs());
                try {
                    FileOutputStream fos = new FileOutputStream(Config.CAPTURED_FRAME_FILE_PATH);
                    capturedFrame.toBitmap().compress(Bitmap.CompressFormat.JPEG, 100, fos);
                    fos.close();
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            ToastUtils.s(VideoRecordActivity.this, "截帧已保存到路径：" + Config.CAPTURED_FRAME_FILE_PATH);
                        }
                    });
                } catch (FileNotFoundException e) {
                    e.printStackTrace();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        });
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (resultCode == Activity.RESULT_OK) {
            String selectedFilepath = GetPathFromUri.getPath(this, data.getData());
            Log.i(TAG, "Select file: " + selectedFilepath);
            if (selectedFilepath != null && !"".equals(selectedFilepath)) {
                mShortVideoRecorder.setMusicFile(selectedFilepath);
            }
        }
    }

    @Override
    public void onReady() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                mSwitchFlashBtn.setVisibility(mShortVideoRecorder.isFlashSupport() ? View.VISIBLE : View.GONE);
                mFlashEnabled = false;
                mSwitchFlashBtn.setActivated(mFlashEnabled);
                mRecordBtn.setEnabled(true);
                ToastUtils.s(VideoRecordActivity.this, "可以开始拍摄咯");
            }
        });
    }

    @Override
    public void onError(final int code) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                ToastUtils.toastErrorCode(VideoRecordActivity.this, code);
            }
        });
    }

    @Override
    public void onDurationTooShort() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                ToastUtils.s(VideoRecordActivity.this, "该视频段太短了");
            }
        });
    }

    @Override
    public void onRecordStarted() {
        Log.i(TAG, "record start time: " + System.currentTimeMillis());
    }

    @Override
    public void onRecordStopped() {
        Log.i(TAG, "record stop time: " + System.currentTimeMillis());
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                updateRecordingBtns(false);
            }
        });
    }

    @Override
    public void onSectionRecording(long sectionDurationMs, long videoDurationMs, int sectionCount) {
        Log.d(TAG, "sectionDurationMs: " + sectionDurationMs + "; videoDurationMs: " + videoDurationMs + "; sectionCount: " + sectionCount);
    }

    @Override
    public void onSectionIncreased(long incDuration, long totalDuration, int sectionCount) {
        double videoSectionDuration = mDurationVideoStack.isEmpty() ? 0 : mDurationVideoStack.peek().doubleValue();
        if ((videoSectionDuration + incDuration / mRecordSpeed) >= mRecordSetting.getMaxRecordDuration()) {
            videoSectionDuration = mRecordSetting.getMaxRecordDuration();
        }
        Log.d(TAG, "videoSectionDuration: " + videoSectionDuration + "; incDuration: " + incDuration);
        onSectionCountChanged(sectionCount, (long) videoSectionDuration);
    }

    @Override
    public void onSectionDecreased(long decDuration, long totalDuration, int sectionCount) {
        mSectionProgressBar.removeLastBreakPoint();
        if (!mDurationVideoStack.isEmpty()) {
            mDurationVideoStack.pop();
        }
        if (!mDurationRecordStack.isEmpty()) {
            mDurationRecordStack.pop();
        }
        double currentDuration = mDurationVideoStack.isEmpty() ? 0 : mDurationVideoStack.peek().doubleValue();
        onSectionCountChanged(sectionCount, (long) currentDuration);
    }

    @Override
    public void onRecordCompleted() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                ToastUtils.s(VideoRecordActivity.this, "已达到拍摄总时长");
            }
        });
    }

    @Override
    public void onProgressUpdate(final float percentage) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                mProcessingDialog.setProgress((int) (100 * percentage));
            }
        });
    }

    @Override
    public void onSaveVideoFailed(final int errorCode) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                mProcessingDialog.dismiss();
                ToastUtils.s(VideoRecordActivity.this, "拼接视频段失败: " + errorCode);
            }
        });
    }

    @Override
    public void onSaveVideoCanceled() {
        mProcessingDialog.dismiss();
    }

    @Override
    public void onSaveVideoSuccess(final String filePath) {
        Log.i(TAG, "concat sections success filePath: " + filePath);
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                mProcessingDialog.dismiss();
                int screenOrientation = (ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE == getRequestedOrientation()) ? 0 : 1;
                if (mIsEditVideo) {
                    VideoEditActivity.start(VideoRecordActivity.this, filePath, screenOrientation);
                } else {
                    PlaybackActivity.start(VideoRecordActivity.this, filePath, screenOrientation);
                }
            }
        });
    }

    private void onSectionCountChanged(final int count, final long totalTime) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                mDeleteBtn.setEnabled(count > 0);
                mConcatBtn.setEnabled(totalTime >= (RecordSettings.DEFAULT_MIN_RECORD_DURATION));
            }
        });
    }

    private void showChooseDialog() {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle(getString(R.string.if_edit_video));
        builder.setPositiveButton(getString(R.string.dlg_yes), new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                mIsEditVideo = true;
                mShortVideoRecorder.concatSections(VideoRecordActivity.this);
            }
        });
        builder.setNegativeButton(getString(R.string.dlg_no), new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                mIsEditVideo = false;
                mShortVideoRecorder.concatSections(VideoRecordActivity.this);
            }
        });
        builder.setCancelable(false);
        builder.create().show();
    }

    public void onSpeedClicked(View view) {
        if (!mVideoEncodeSetting.IsConstFrameRateEnabled() || !mRecordSetting.IsRecordSpeedVariable()) {
            if (mSectionProgressBar.isRecorded()) {
                ToastUtils.s(this, "变帧率模式下，无法在拍摄中途修改拍摄倍数！");
                return;
            }
        }

        if (mSpeedTextView != null) {
            mSpeedTextView.setTextColor(getResources().getColor(R.color.speedTextNormal));
        }

        TextView textView = (TextView) view;
        textView.setTextColor(getResources().getColor(R.color.colorAccent));
        mSpeedTextView = textView;

        switch (view.getId()) {
            case R.id.super_slow_speed_text:
                mRecordSpeed = RECORD_SPEED_ARRAY[0];
                break;
            case R.id.slow_speed_text:
                mRecordSpeed = RECORD_SPEED_ARRAY[1];
                break;
            case R.id.normal_speed_text:
                mRecordSpeed = RECORD_SPEED_ARRAY[2];
                break;
            case R.id.fast_speed_text:
                mRecordSpeed = RECORD_SPEED_ARRAY[3];
                break;
            case R.id.super_fast_speed_text:
                mRecordSpeed = RECORD_SPEED_ARRAY[4];
                break;
        }

        mShortVideoRecorder.setRecordSpeed(mRecordSpeed);
        if (mRecordSetting.IsRecordSpeedVariable() && mVideoEncodeSetting.IsConstFrameRateEnabled()) {
            mSectionProgressBar.setProceedingSpeed(mRecordSpeed);
            mRecordSetting.setMaxRecordDuration(RecordSettings.DEFAULT_MAX_RECORD_DURATION);
            mSectionProgressBar.setFirstPointTime(RecordSettings.DEFAULT_MIN_RECORD_DURATION);
        } else {
            mRecordSetting.setMaxRecordDuration((long) (RecordSettings.DEFAULT_MAX_RECORD_DURATION * mRecordSpeed));
            mSectionProgressBar.setFirstPointTime((long) (RecordSettings.DEFAULT_MIN_RECORD_DURATION * mRecordSpeed));
        }

        mSectionProgressBar.setTotalTime(this, mRecordSetting.getMaxRecordDuration());
    }

    @Override
    public void onManualFocusStart(boolean result) {
        if (result) {
            Log.i(TAG, "manual focus begin success");
            FrameLayout.LayoutParams lp = (FrameLayout.LayoutParams) mFocusIndicator.getLayoutParams();
            lp.leftMargin = mFocusIndicatorX;
            lp.topMargin = mFocusIndicatorY;
            mFocusIndicator.setLayoutParams(lp);
            mFocusIndicator.focus();
        } else {
            mFocusIndicator.focusCancel();
            Log.i(TAG, "manual focus not supported");
        }
    }

    @Override
    public void onManualFocusStop(boolean result) {
        Log.i(TAG, "manual focus end result: " + result);
        if (result) {
            mFocusIndicator.focusSuccess();
        } else {
            mFocusIndicator.focusFail();
        }
    }

    @Override
    public void onManualFocusCancel() {
        Log.i(TAG, "manual focus canceled");
        mFocusIndicator.focusCancel();
    }

    @Override
    public void onAutoFocusStart() {
        Log.i(TAG, "auto focus start");
    }

    @Override
    public void onAutoFocusStop() {
        Log.i(TAG, "auto focus stop");
    }




    // -------- SenseTime 相关 ---------- //
    private Context mContext;
    private SenseTimeManager mSTManager;
    private SensorManager mSensorManager;
    private Accelerometer mAccelerometer = null;
    private SurfaceView mSurfaceViewOverlap;
    private Sensor mRotation;
    private ArrayList<StickerOptionsItem> mStickerOptionsList = new ArrayList<>();
    private HashMap<String, BeautyItemAdapter> mBeautyItemAdapters = new HashMap<>();
    private HashMap<String, ArrayList<BeautyItem>> mBeautyLists = new HashMap<>();
    private HashMap<Integer, String> mBeautyOption = new HashMap<>();
    private HashMap<Integer, Integer> mBeautyOptionSelectedIndex = new HashMap<>();

    private float[] mBeautifyParams = {0.36f, 0.74f, 0.02f, 0.13f, 0.11f, 0.1f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f};

    public final static String GROUP_2D = "3cd2dae0f6c211e8877702f2beb67403";
    public final static String GROUP_3D = "4e869010f6c211e888ea020d88863a42";
    public final static String GROUP_HAND = "5aea6840f6c211e899f602f2be7c2171";
    public final static String GROUP_BG = "65365cf0f6c211e8877702f2beb67403";
    public final static String GROUP_FACE = "6d036ef0f6c211e899f602f2be7c2171";
    public final static String GROUP_AVATAR = "46028a20f6c211e888ea020d88863a42";
    public final static String GROUP_BEAUTY = "73bffb50f6c211e899f602f2be7c2171";
    public final static String GROUP_PARTICLE = "7c6089f0f6c211e8877702f2beb67403";

    private RecyclerView mStickersRecycleView;
    private RecyclerView mStickerOptionsRecycleView, mFilterOptionsRecycleView;
    private RecyclerView mBeautyBaseRecycleView;
    private StickerOptionsAdapter mStickerOptionsAdapter;
    private BeautyOptionsAdapter mBeautyOptionsAdapter;
    private BeautyItemAdapter mBeautyBaseAdapter, mBeautyProfessionalAdapter, mAdjustAdapter, mMicroAdapter;
    private ArrayList<BeautyOptionsItem> mBeautyOptionsList;

    private HashMap<String, StickerAdapter> mStickerAdapters = new HashMap<>();
    //    private HashMap<String, NewStickerAdapter> mNewStickerAdapters = new HashMap<>();
    private HashMap<String, NativeStickerAdapter> mNativeStickerAdapters = new HashMap<>();
    private HashMap<String, ArrayList<StickerItem>> mStickerLists = new HashMap<>();
    private ArrayList<StickerItem> mNewStickers;

    private HashMap<String, FilterAdapter> mFilterAdapters = new HashMap<>();
    private HashMap<String, ArrayList<FilterItem>> mFilterLists = new HashMap<>();

    private ObjectAdapter mObjectAdapter;
    private List<ObjectItem> mObjectList;
    private boolean mNeedObject = false;

    private TextView mAttributeText;

    private LinearLayout mFilterGroupsLinearLayout, mFilterGroupPortrait, mFilterGroupStillLife, mFilterGroupScenery, mFilterGroupFood;
    private RelativeLayout mFilterIconsRelativeLayout, mFilterStrengthLayout;
    private ImageView mFilterGroupBack;
    private TextView mFilterGroupName, mFilterStrengthText;
    private SeekBar mFilterStrengthBar;
    private VerticalSeekBar mVerticalSeekBar;
    private int mCurrentFilterGroupIndex = -1;
    private int mCurrentFilterIndex = -1;
    private int mCurrentObjectIndex = -1;

    private RelativeLayout mTipsLayout;
    private TextView mTipsTextView, mResetTextView;
    private ImageView mTipsImageView;
    private IndicatorSeekBar mIndicatorSeekbar;
    private Handler mTipsHandler = new Handler();
    private Runnable mTipsRunnable;

    public static final int MSG_SAVING_IMG = 1;
    public static final int MSG_SAVED_IMG = 2;
    public static final int MSG_DRAW_OBJECT_IMAGE_AND_RECT = 3;
    public static final int MSG_DRAW_OBJECT_IMAGE = 4;
    public static final int MSG_CLEAR_OBJECT = 5;
    public static final int MSG_MISSED_OBJECT_TRACK = 6;
    public static final int MSG_DRAW_FACE_EXTRA_POINTS = 7;
    private static final int MSG_NEED_UPDATE_TIMER = 8;
    private static final int MSG_NEED_START_CAPTURE = 9;
    private static final int MSG_NEED_START_RECORDING = 10;
    private static final int MSG_STOP_RECORDING = 11;
    public static final int MSG_HIDE_VERTICALSEEKBAR = 12;

    public final static int MSG_UPDATE_HAND_ACTION_INFO = 100;
    public final static int MSG_RESET_HAND_ACTION_INFO = 101;
    public final static int MSG_UPDATE_BODY_ACTION_INFO = 102;
    public final static int MSG_UPDATE_FACE_EXPRESSION_INFO = 103;
    public final static int MSG_NEED_UPDATE_STICKER_TIPS = 104;
    //    public final static int MSG_NEED_UPDATE_STICKER_MAP = 105;
    public final static int MSG_NEED_REPLACE_STICKER_MAP = 106;
    public final static int MSG_NEED_SHOW_TOO_MUCH_STICKER_TIPS = 107;

    private Bitmap mGuideBitmap;
    private Paint mPaint = new Paint();

    private int mIndexX = 0, mIndexY = 0;
    private boolean mCanMove = false;

    private LinearLayout mStickerOptionsSwitch;
    private RelativeLayout mStickerOptions;
    private RecyclerView mStickerIcons;
    private boolean mIsStickerOptionsOpen = false;

    private int mCurrentStickerOptionsIndex = -1;
    private int mCurrentStickerPosition = -1;
    private int mCurrentNewStickerPosition = -1;
    private int mCurrentBeautyIndex = Constants.ST_BEAUTIFY_WHITEN_STRENGTH;

    private LinearLayout mBeautyOptionsSwitch, mBaseBeautyOptions;
    private RecyclerView mFilterIcons, mBeautyOptionsRecycleView;
    private boolean mIsBeautyOptionsOpen = false;
    private int mBeautyOptionsPosition = 0;
    private ArrayList<SeekBar> mBeautyParamsSeekBarList = new ArrayList<SeekBar>();

    private boolean mIsSettingOptionsOpen = false;

    private ImageView mBeautyOptionsSwitchIcon, mStickerOptionsSwitchIcon;
    private TextView mBeautyOptionsSwitchText, mStickerOptionsSwitchText;
    private RelativeLayout mFilterAndBeautyOptionView;
    private Switch mPerformanceInfoSwitch;
    private LinearLayout mSelectOptions;

    private Map<Integer, Integer> mStickerPackageMap;

    long timeDown = 0;
    int downX, downY;

    //记录用户最后一次点击的素材id ,包括还未下载的，方便下载完成后，直接应用素材
    private String preMaterialId = "";

    class BeautyItemDecoration extends RecyclerView.ItemDecoration {
        private int space;

        public BeautyItemDecoration(int space) {
            this.space = space;
        }

        @Override
        public void getItemOffsets(Rect outRect, View view, RecyclerView parent, RecyclerView.State state) {
            super.getItemOffsets(outRect, view, parent, state);
            outRect.left = space;
            outRect.right = space;
        }
    }

    class SpaceItemDecoration extends RecyclerView.ItemDecoration {
        private int space;

        public SpaceItemDecoration(int space) {
            this.space = space;
        }

        @Override
        public void getItemOffsets(Rect outRect, View view, RecyclerView parent, RecyclerView.State state) {
            super.getItemOffsets(outRect, view, parent, state);
            if (parent.getChildAdapterPosition(view) != 0) {
                outRect.top = space;
            }
        }
    }

    private SensorEventListener mSensorEventListener = new SensorEventListener() {
        @Override
        public void onSensorChanged(SensorEvent event) {
            mSTManager.setSensorEvent(event);
        }

        @Override
        public void onAccuracyChanged(Sensor sensor, int accuracy) {

        }
    };

    private Handler mHandler = new Handler() {
        @Override
        public void handleMessage(final Message msg) {
            super.handleMessage(msg);

            switch (msg.what) {
                case MSG_DRAW_OBJECT_IMAGE_AND_RECT:
                    Rect indexRect = (Rect) msg.obj;
                    drawObjectImage(indexRect, true);

                    break;
                case MSG_DRAW_OBJECT_IMAGE:
                    Rect rect = (Rect) msg.obj;
                    drawObjectImage(rect, false);

                    break;
                case MSG_CLEAR_OBJECT:
                    clearObjectImage();

                    break;
                case MSG_MISSED_OBJECT_TRACK:
                    mObjectAdapter.setSelectedPosition(1);
                    mObjectAdapter.notifyDataSetChanged();
                    break;

                case MSG_DRAW_FACE_EXTRA_POINTS:
                    STPoint[] points = (STPoint[]) msg.obj;
                    drawFaceExtraPoints(points);
                    break;

                case MSG_NEED_UPDATE_STICKER_TIPS:
                    long action = mSTManager.getStickerTriggerAction();
                    showActiveTips(action);
                    break;

                case MSG_NEED_SHOW_TOO_MUCH_STICKER_TIPS:
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            Toast.makeText(mContext, "添加太多贴纸了", Toast.LENGTH_SHORT).show();
                        }
                    });
                    break;

                case MSG_NEED_REPLACE_STICKER_MAP:
                    int oldPackageId = msg.arg1;
                    int newPackageId = msg.arg2;

                    for (Integer index : mStickerPackageMap.keySet()) {
                        int stickerId = mStickerPackageMap.get(index);//得到每个key多对用value的值

                        if (stickerId == oldPackageId) {
                            mStickerPackageMap.put(index, newPackageId);
                        }
                    }
                    break;

                case MSG_HIDE_VERTICALSEEKBAR:
                    performVerticalSeekBarVisiable(false);
            }
        }
    };

    public void initSenseTime() {
        mContext = this;
        mAccelerometer = new Accelerometer(getApplicationContext());
        mSTManager = new SenseTimeManager(getApplicationContext());

        new Thread(){
            public void run() {
                FileUtils.copyStickerFiles(mContext, "newEngine");
            }
        }.start();

        initView();
        initStickerListFromNet();
        initEvents();

        resetFilterView();
        setDefaultFilter();

        mSensorManager = (SensorManager) getSystemService(Context.SENSOR_SERVICE);
        //todo 判断是否存在rotation vector sensor
        mRotation = mSensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR);
    }

    private void initView() {
        //copy model file to sdcard
        FileUtils.copyModelFiles(this);
        mSurfaceViewOverlap = (SurfaceView) findViewById(R.id.surfaceViewOverlap);

        mSTManager.setHandler(mHandler);

        mIndicatorSeekbar = (IndicatorSeekBar) findViewById(R.id.beauty_item_seekbar);
        mIndicatorSeekbar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                if (fromUser) {
                    if (checkMicroType()) {
                        mIndicatorSeekbar.updateTextview(STUtils.convertToDisplay(progress));
                        mSTManager.setBeautyParam(mCurrentBeautyIndex, (float) STUtils.convertToDisplay(progress) / 100f);
                        mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(mBeautyOptionSelectedIndex.get(mBeautyOptionsPosition)).setProgress(STUtils.convertToDisplay(progress));
                    } else {
                        mIndicatorSeekbar.updateTextview(progress);
                        mSTManager.setBeautyParam(mCurrentBeautyIndex, (float) progress / 100f);
                        mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(mBeautyOptionSelectedIndex.get(mBeautyOptionsPosition)).setProgress(progress);
                    }
                    mBeautyItemAdapters.get(mBeautyOption.get(mBeautyOptionsPosition)).notifyItemChanged(mBeautyOptionSelectedIndex.get(mBeautyOptionsPosition));
                }
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {

            }

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {

            }
        });

        mBeautyBaseRecycleView = (RecyclerView) findViewById(R.id.rv_beauty_base);
        LinearLayoutManager ms = new LinearLayoutManager(this);
        ms.setOrientation(LinearLayoutManager.HORIZONTAL);
        mBeautyBaseRecycleView.setLayoutManager(ms);
        mBeautyBaseRecycleView.addItemDecoration(new BeautyItemDecoration(STUtils.dip2px(this, 15)));

        ArrayList mBeautyBaseItem = new ArrayList<BeautyItem>();
        mBeautyBaseItem.add(new BeautyItem("美白", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_whiten_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_whiten_selected)));
        mBeautyBaseItem.add(new BeautyItem("红润", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_redden_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_redden_selected)));
        mBeautyBaseItem.add(new BeautyItem("磨皮", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_smooth_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_smooth_selected)));
        mBeautyBaseItem.add(new BeautyItem("去高光", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_dehighlight_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_dehighlight_selected)));

        ((BeautyItem) mBeautyBaseItem.get(0)).setProgress((int) (mBeautifyParams[2] * 100));
        ((BeautyItem) mBeautyBaseItem.get(1)).setProgress((int) (mBeautifyParams[0] * 100));
        ((BeautyItem) mBeautyBaseItem.get(2)).setProgress((int) (mBeautifyParams[1] * 100));
        ((BeautyItem) mBeautyBaseItem.get(3)).setProgress((int) (mBeautifyParams[8] * 100));

        mIndicatorSeekbar.getSeekBar().setProgress((int) (mBeautifyParams[2] * 100));
        mIndicatorSeekbar.updateTextview((int) (mBeautifyParams[2] * 100));

        mBeautyLists.put("baseBeauty", mBeautyBaseItem);
        mBeautyBaseAdapter = new BeautyItemAdapter(this, mBeautyBaseItem);
        mBeautyItemAdapters.put("baseBeauty", mBeautyBaseAdapter);
        mBeautyOption.put(0, "baseBeauty");
        mBeautyBaseRecycleView.setAdapter(mBeautyBaseAdapter);

        ArrayList mProfessionalBeautyItem = new ArrayList<>();
        mProfessionalBeautyItem.add(new BeautyItem("瘦脸", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_shrink_face_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_shrink_face_selected)));
        mProfessionalBeautyItem.add(new BeautyItem("大眼", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_enlargeeye_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_enlargeeye_selected)));
        mProfessionalBeautyItem.add(new BeautyItem("小脸", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_small_face_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_small_face_selected)));
        mProfessionalBeautyItem.add(new BeautyItem("窄脸", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_narrow_face_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_narrow_face_selected)));

        ((BeautyItem) mProfessionalBeautyItem.get(0)).setProgress((int) (mBeautifyParams[4] * 100));
        ((BeautyItem) mProfessionalBeautyItem.get(1)).setProgress((int) (mBeautifyParams[3] * 100));
        ((BeautyItem) mProfessionalBeautyItem.get(2)).setProgress((int) (mBeautifyParams[5] * 100));
        ((BeautyItem) mProfessionalBeautyItem.get(3)).setProgress((int) (mBeautifyParams[9] * 100));

        mBeautyLists.put("professionalBeauty", mProfessionalBeautyItem);
        mBeautyProfessionalAdapter = new BeautyItemAdapter(this, mProfessionalBeautyItem);
        mBeautyItemAdapters.put("professionalBeauty", mBeautyProfessionalAdapter);
        mBeautyOption.put(1, "professionalBeauty");

        ArrayList mMicroBeautyItem = new ArrayList<>();
        mMicroBeautyItem.add(new BeautyItem("瘦脸型", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_thin_face_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_thin_face_selected)));
        mMicroBeautyItem.add(new BeautyItem("下巴", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_chin_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_chin_selected)));
        mMicroBeautyItem.add(new BeautyItem("额头", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_forehead_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_forehead_selected)));
        mMicroBeautyItem.add(new BeautyItem("苹果肌", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_apple_musle_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_apple_musle_selected)));
        mMicroBeautyItem.add(new BeautyItem("瘦鼻翼", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_thin_nose_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_thin_nose_selected)));
        mMicroBeautyItem.add(new BeautyItem("长鼻", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_long_nose_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_long_nose_selected)));
        mMicroBeautyItem.add(new BeautyItem("侧脸隆鼻", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_profile_rhinoplasty_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_profile_rhinoplasty_selected)));
        mMicroBeautyItem.add(new BeautyItem("嘴型", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_mouth_type_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_mouth_type_selected)));
        mMicroBeautyItem.add(new BeautyItem("缩人中", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_philtrum_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_philtrum_selected)));
        mMicroBeautyItem.add(new BeautyItem("眼距", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_eye_distance_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_eye_distance_selected)));
        mMicroBeautyItem.add(new BeautyItem("眼睛角度", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_eye_angle_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_eye_angle_selected)));
        mMicroBeautyItem.add(new BeautyItem("开眼角", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_open_canthus_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_open_canthus_selected)));
        mMicroBeautyItem.add(new BeautyItem("亮眼", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_bright_eye_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_bright_eye_selected)));
        mMicroBeautyItem.add(new BeautyItem("祛黑眼圈", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_remove_dark_circles_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_remove_dark_circles_selected)));
        mMicroBeautyItem.add(new BeautyItem("祛法令纹", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_remove_nasolabial_folds_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_remove_nasolabial_folds_selected)));
        mMicroBeautyItem.add(new BeautyItem("白牙", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_white_teeth_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_white_teeth_selected)));

        for(int i = 0; i < 16; i++){
            ((BeautyItem)mMicroBeautyItem.get(i)).setProgress((int)(mBeautifyParams[i+10]* 100));
        }

        mBeautyLists.put("microBeauty", mMicroBeautyItem);
        mMicroAdapter = new BeautyItemAdapter(this, mMicroBeautyItem);
        mBeautyItemAdapters.put("microBeauty", mMicroAdapter);
        mBeautyOption.put(2, "microBeauty");

        ArrayList mAdjustBeautyItem = new ArrayList<>();
        mAdjustBeautyItem.add(new BeautyItem("对比度", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_contrast_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_contrast_selected)));
        mAdjustBeautyItem.add(new BeautyItem("饱和度", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_saturation_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.beauty_saturation_selected)));
        ((BeautyItem) mAdjustBeautyItem.get(0)).setProgress((int) (mBeautifyParams[6] * 100));
        ((BeautyItem) mAdjustBeautyItem.get(1)).setProgress((int) (mBeautifyParams[7] * 100));
        mBeautyLists.put("adjustBeauty", mAdjustBeautyItem);
        mAdjustAdapter = new BeautyItemAdapter(this, mAdjustBeautyItem);
        mBeautyItemAdapters.put("adjustBeauty", mAdjustAdapter);
        mBeautyOption.put(4, "adjustBeauty");

        mBeautyOptionSelectedIndex.put(0, 0);
        mBeautyOptionSelectedIndex.put(1, 0);
        mBeautyOptionSelectedIndex.put(2, 0);
        mBeautyOptionSelectedIndex.put(4, 0);

        mStickerOptionsRecycleView = (RecyclerView) findViewById(R.id.rv_sticker_options);
        mStickerOptionsRecycleView.setLayoutManager(new StaggeredGridLayoutManager(1, StaggeredGridLayoutManager.HORIZONTAL));
        mStickerOptionsRecycleView.addItemDecoration(new SpaceItemDecoration(0));

        mStickersRecycleView = (RecyclerView) findViewById(R.id.rv_sticker_icons);
        mStickersRecycleView.setLayoutManager(new GridLayoutManager(this, 6));
        mStickersRecycleView.addItemDecoration(new SpaceItemDecoration(0));

        mFilterOptionsRecycleView = (RecyclerView) findViewById(R.id.rv_filter_icons);
        mFilterOptionsRecycleView.setLayoutManager(new StaggeredGridLayoutManager(1, StaggeredGridLayoutManager.HORIZONTAL));
        mFilterOptionsRecycleView.addItemDecoration(new SpaceItemDecoration(0));
        mNewStickers = FileUtils.getStickerFiles(this, "newEngine");
        //new
        //使用本地模型加载
        mStickerOptionsList.add(0, new StickerOptionsItem("sticker_new_engine", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.sticker_local_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.sticker_local_selected)));
        //2d
        mStickerOptionsList.add(1, new StickerOptionsItem(GROUP_2D, BitmapFactory.decodeResource(mContext.getResources(), R.drawable.sticker_2d_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.sticker_2d_selected)));
        //3d
        mStickerOptionsList.add(2, new StickerOptionsItem(GROUP_3D, BitmapFactory.decodeResource(mContext.getResources(), R.drawable.sticker_3d_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.sticker_3d_selected)));
        //手势贴纸
        mStickerOptionsList.add(3, new StickerOptionsItem(GROUP_HAND, BitmapFactory.decodeResource(mContext.getResources(), R.drawable.sticker_hand_action_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.sticker_hand_action_selected)));
        //背景贴纸
        mStickerOptionsList.add(4, new StickerOptionsItem(GROUP_BG, BitmapFactory.decodeResource(mContext.getResources(), R.drawable.sticker_bg_segment_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.sticker_bg_segment_selected)));
        //脸部变形贴纸
        mStickerOptionsList.add(5, new StickerOptionsItem(GROUP_FACE, BitmapFactory.decodeResource(mContext.getResources(), R.drawable.sticker_dedormation_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.sticker_dedormation_selected)));
        //avatar
        mStickerOptionsList.add(6, new StickerOptionsItem(GROUP_AVATAR, BitmapFactory.decodeResource(mContext.getResources(), R.drawable.sticker_avatar_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.sticker_avatar_selected)));
        //美妆贴纸
        mStickerOptionsList.add(7, new StickerOptionsItem(GROUP_BEAUTY, BitmapFactory.decodeResource(mContext.getResources(), R.drawable.sticker_face_morph_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.sticker_face_morph_selected)));
        //粒子贴纸
        mStickerOptionsList.add(8, new StickerOptionsItem(GROUP_PARTICLE, BitmapFactory.decodeResource(mContext.getResources(), R.drawable.particles_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.particles_selected)));
        //通用物体跟踪
        mStickerOptionsList.add(9, new StickerOptionsItem("object_track", BitmapFactory.decodeResource(mContext.getResources(), R.drawable.object_track_unselected), BitmapFactory.decodeResource(mContext.getResources(), R.drawable.object_track_selected)));

        mNativeStickerAdapters.put("sticker_new_engine", new NativeStickerAdapter(mNewStickers, this));

        mStickersRecycleView.setAdapter(mNativeStickerAdapters.get("sticker_new_engine"));
        mNativeStickerAdapters.get("sticker_new_engine").notifyDataSetChanged();
        initNativeStickerAdapter("sticker_new_engine", 0);
        mStickerOptionsAdapter = new StickerOptionsAdapter(mStickerOptionsList, this);
        mStickerOptionsAdapter.setSelectedPosition(0);
        mStickerOptionsAdapter.notifyDataSetChanged();

        findViewById(R.id.iv_close_sticker).setBackground(getResources().getDrawable(R.drawable.close_sticker_selected));

        mFilterAndBeautyOptionView = (RelativeLayout) findViewById(R.id.rv_beauty_and_filter_options);

        mBeautyOptionsRecycleView = (RecyclerView) findViewById(R.id.rv_beauty_options);
        mBeautyOptionsRecycleView.setLayoutManager(new StaggeredGridLayoutManager(1, StaggeredGridLayoutManager.HORIZONTAL));
        mBeautyOptionsRecycleView.addItemDecoration(new SpaceItemDecoration(0));

        mBeautyOptionsList = new ArrayList<>();
        mBeautyOptionsList.add(0, new BeautyOptionsItem("基础美颜"));
        mBeautyOptionsList.add(1, new BeautyOptionsItem("美形"));
        mBeautyOptionsList.add(2, new BeautyOptionsItem("微整形"));
        mBeautyOptionsList.add(3, new BeautyOptionsItem("滤镜"));
        mBeautyOptionsList.add(4, new BeautyOptionsItem("调整"));

        mBeautyOptionsAdapter = new BeautyOptionsAdapter(mBeautyOptionsList, this);
        mBeautyOptionsRecycleView.setAdapter(mBeautyOptionsAdapter);

        mFilterLists.put("filter_portrait", FileUtils.getFilterFiles(this, "filter_portrait"));
        mFilterLists.put("filter_scenery", FileUtils.getFilterFiles(this, "filter_scenery"));
        mFilterLists.put("filter_still_life", FileUtils.getFilterFiles(this, "filter_still_life"));
        mFilterLists.put("filter_food", FileUtils.getFilterFiles(this, "filter_food"));

        mFilterAdapters.put("filter_portrait", new FilterAdapter(mFilterLists.get("filter_portrait"), this));
        mFilterAdapters.put("filter_scenery", new FilterAdapter(mFilterLists.get("filter_scenery"), this));
        mFilterAdapters.put("filter_still_life", new FilterAdapter(mFilterLists.get("filter_still_life"), this));
        mFilterAdapters.put("filter_food", new FilterAdapter(mFilterLists.get("filter_food"), this));

        mFilterIconsRelativeLayout = (RelativeLayout) findViewById(R.id.rl_filter_icons);
        mFilterGroupsLinearLayout = (LinearLayout) findViewById(R.id.ll_filter_groups);
        mFilterGroupPortrait = (LinearLayout) findViewById(R.id.ll_filter_group_portrait);
        mFilterGroupPortrait.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                mFilterGroupsLinearLayout.setVisibility(View.INVISIBLE);
                mFilterIconsRelativeLayout.setVisibility(View.VISIBLE);

                if (mCurrentFilterGroupIndex == 0 && mCurrentFilterIndex != -1) {
                    mFilterStrengthLayout.setVisibility(View.VISIBLE);
                }

                mFilterOptionsRecycleView.setLayoutManager(new StaggeredGridLayoutManager(1, StaggeredGridLayoutManager.HORIZONTAL));
                mFilterOptionsRecycleView.setAdapter(mFilterAdapters.get("filter_portrait"));
                mFilterGroupBack.setImageDrawable(getResources().getDrawable(R.drawable.icon_portrait_selected));
                mFilterGroupName.setText("人像");
            }
        });
        mFilterGroupScenery = (LinearLayout) findViewById(R.id.ll_filter_group_scenery);
        mFilterGroupScenery.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                mFilterGroupsLinearLayout.setVisibility(View.INVISIBLE);
                mFilterIconsRelativeLayout.setVisibility(View.VISIBLE);

                if (mCurrentFilterGroupIndex == 1 && mCurrentFilterIndex != -1) {
                    mFilterStrengthLayout.setVisibility(View.VISIBLE);
                }

                mFilterOptionsRecycleView.setLayoutManager(new StaggeredGridLayoutManager(1, StaggeredGridLayoutManager.HORIZONTAL));
                mFilterOptionsRecycleView.setAdapter(mFilterAdapters.get("filter_scenery"));
                mFilterGroupBack.setImageDrawable(getResources().getDrawable(R.drawable.icon_scenery_selected));
                mFilterGroupName.setText("风景");
            }
        });
        mFilterGroupStillLife = (LinearLayout) findViewById(R.id.ll_filter_group_still_life);
        mFilterGroupStillLife.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                mFilterGroupsLinearLayout.setVisibility(View.INVISIBLE);
                mFilterIconsRelativeLayout.setVisibility(View.VISIBLE);

                if (mCurrentFilterGroupIndex == 2 && mCurrentFilterIndex != -1) {
                    mFilterStrengthLayout.setVisibility(View.VISIBLE);
                }

                mFilterOptionsRecycleView.setLayoutManager(new StaggeredGridLayoutManager(1, StaggeredGridLayoutManager.HORIZONTAL));
                mFilterOptionsRecycleView.setAdapter(mFilterAdapters.get("filter_still_life"));
                mFilterGroupBack.setImageDrawable(getResources().getDrawable(R.drawable.icon_still_life_selected));
                mFilterGroupName.setText("静物");
            }
        });
        mFilterGroupFood = (LinearLayout) findViewById(R.id.ll_filter_group_food);
        mFilterGroupFood.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                mFilterGroupsLinearLayout.setVisibility(View.INVISIBLE);
                mFilterIconsRelativeLayout.setVisibility(View.VISIBLE);

                if (mCurrentFilterGroupIndex == 3 && mCurrentFilterIndex != -1) {
                    mFilterStrengthLayout.setVisibility(View.VISIBLE);
                }

                mFilterOptionsRecycleView.setLayoutManager(new StaggeredGridLayoutManager(1, StaggeredGridLayoutManager.HORIZONTAL));
                mFilterOptionsRecycleView.setAdapter(mFilterAdapters.get("filter_food"));
                mFilterGroupBack.setImageDrawable(getResources().getDrawable(R.drawable.icon_food_selected));
                mFilterGroupName.setText("食物");
            }
        });

        mFilterGroupBack = (ImageView) findViewById(R.id.iv_filter_group);
        mFilterGroupBack.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                mFilterGroupsLinearLayout.setVisibility(View.VISIBLE);
                mFilterIconsRelativeLayout.setVisibility(View.INVISIBLE);
                mFilterStrengthLayout.setVisibility(View.INVISIBLE);


            }
        });
        mFilterGroupName = (TextView) findViewById(R.id.tv_filter_group);
        mFilterStrengthText = (TextView) findViewById(R.id.tv_filter_strength);

        mFilterStrengthLayout = (RelativeLayout) findViewById(R.id.rv_filter_strength);
        mFilterStrengthBar = (SeekBar) findViewById(R.id.sb_filter_strength);
        mFilterStrengthBar.setProgress(65);
        mFilterStrengthText.setText("65");
        mFilterStrengthBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                mSTManager.setFilterStrength((float) progress / 100);
                mFilterStrengthText.setText(progress + "");
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {
            }

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {
            }
        });


        mStickerOptionsRecycleView.setAdapter(mStickerOptionsAdapter);

        mObjectList = FileUtils.getObjectList();
        mObjectAdapter = new ObjectAdapter(mObjectList, this);
        mObjectAdapter.setSelectedPosition(-1);

        mFilterOptionsRecycleView.setAdapter(mFilterAdapters.get("filter_portrait"));

        mTipsLayout = (RelativeLayout) findViewById(R.id.tv_layout_tips);
        mAttributeText = (TextView) findViewById(R.id.tv_face_attribute);
        mAttributeText.setVisibility(View.VISIBLE);
        mTipsTextView = (TextView) findViewById(R.id.tv_text_tips);
        mTipsImageView = (ImageView) findViewById(R.id.iv_image_tips);
        mTipsLayout.setVisibility(View.GONE);

        mSelectOptions = (LinearLayout) findViewById(R.id.ll_select_options);
        mSelectOptions.setBackgroundColor(Color.parseColor("#00000000"));

        mBeautyOptionsSwitch = (LinearLayout) findViewById(R.id.ll_beauty_options_switch);
        mBeautyOptionsSwitch.setOnClickListener(this);
        mFilterIcons = (RecyclerView) findViewById(R.id.rv_filter_icons);

        mBaseBeautyOptions = (LinearLayout) findViewById(R.id.ll_base_beauty_options);
        mBaseBeautyOptions.setOnClickListener(null);
        mIsBeautyOptionsOpen = false;

        mStickerOptionsSwitch = (LinearLayout) findViewById(R.id.ll_sticker_options_switch);
        mStickerOptionsSwitch.setOnClickListener(this);
        mStickerOptions = (RelativeLayout) findViewById(R.id.rl_sticker_options);
        mStickerIcons = (RecyclerView) findViewById(R.id.rv_sticker_icons);
        mIsStickerOptionsOpen = false;
        mResetTextView = (TextView) findViewById(R.id.reset);
    }

    private void initStickerListFromNet() {
        SenseArMaterialService.shareInstance().authorizeWithAppId(this, APPID, APPKEY, new SenseArMaterialService.OnAuthorizedListener() {
            @Override
            public void onSuccess() {
                Log.d(TAG, "鉴权成功！");
//                fetchAllGroups();
                fetchGroupMaterialList(mStickerOptionsList);
            }

            @Override
            public void onFailure(SenseArMaterialService.AuthorizeErrorCode errorCode, String errorMsg) {
                Log.d(TAG, String.format(Locale.getDefault(), "鉴权失败！%d, %s", errorCode, errorMsg));
            }
        });
    }

    private void initEvents() {
        mSurfaceViewOverlap.setZOrderOnTop(true);
        mSurfaceViewOverlap.setZOrderMediaOverlay(true);
        mSurfaceViewOverlap.getHolder().setFormat(PixelFormat.TRANSLUCENT);

        mPaint = new Paint();
        mPaint.setColor(Color.rgb(240, 100, 100));
        int strokeWidth = 10;
        mPaint.setStrokeWidth(strokeWidth);
        mPaint.setStyle(Paint.Style.STROKE);

        initStickerTabListener();

        mFilterAdapters.get("filter_portrait").setClickFilterListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                resetFilterView();
                int position = Integer.parseInt(v.getTag().toString());
                mFilterAdapters.get("filter_portrait").setSelectedPosition(position);
                mCurrentFilterGroupIndex = 0;
                mCurrentFilterIndex = -1;

                if (position == 0) {
                    mSTManager.enableFilter(false);
                } else {
                    mSTManager.setFilterStyle(mFilterLists.get("filter_portrait").get(position).model);
                    mSTManager.enableFilter(true);
                    mCurrentFilterIndex = position;

                    mFilterStrengthLayout.setVisibility(View.VISIBLE);

                    ((ImageView) findViewById(R.id.iv_filter_group_portrait)).setImageDrawable(getResources().getDrawable(R.drawable.icon_portrait_selected));
                    ((TextView) findViewById(R.id.tv_filter_group_portrait)).setTextColor(Color.parseColor("#c460e1"));
                }

                mFilterAdapters.get("filter_portrait").notifyDataSetChanged();
            }
        });

        mFilterAdapters.get("filter_scenery").setClickFilterListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                resetFilterView();
                int position = Integer.parseInt(v.getTag().toString());
                mFilterAdapters.get("filter_scenery").setSelectedPosition(position);
                mCurrentFilterGroupIndex = 1;
                mCurrentFilterIndex = -1;

                if (position == 0) {
                    mSTManager.enableFilter(false);
                } else {
                    mSTManager.setFilterStyle(mFilterLists.get("filter_scenery").get(position).model);
                    mSTManager.enableFilter(true);
                    mCurrentFilterIndex = position;

                    mFilterStrengthLayout.setVisibility(View.VISIBLE);

                    ((ImageView) findViewById(R.id.iv_filter_group_scenery)).setImageDrawable(getResources().getDrawable(R.drawable.icon_scenery_selected));
                    ((TextView) findViewById(R.id.tv_filter_group_scenery)).setTextColor(Color.parseColor("#c460e1"));
                }

                mFilterAdapters.get("filter_scenery").notifyDataSetChanged();
            }
        });

        mFilterAdapters.get("filter_still_life").setClickFilterListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                resetFilterView();
                int position = Integer.parseInt(v.getTag().toString());
                mFilterAdapters.get("filter_still_life").setSelectedPosition(position);
                mCurrentFilterGroupIndex = 2;
                mCurrentFilterIndex = -1;

                if (position == 0) {
                    mSTManager.enableFilter(false);
                } else {
                    mSTManager.setFilterStyle(mFilterLists.get("filter_still_life").get(position).model);
                    mSTManager.enableFilter(true);
                    mCurrentFilterIndex = position;

                    mFilterStrengthLayout.setVisibility(View.VISIBLE);

//
                    ((ImageView) findViewById(R.id.iv_filter_group_still_life)).setImageDrawable(getResources().getDrawable(R.drawable.icon_still_life_selected));
                    ((TextView) findViewById(R.id.tv_filter_group_still_life)).setTextColor(Color.parseColor("#c460e1"));
                }

                mFilterAdapters.get("filter_still_life").notifyDataSetChanged();
            }
        });

        mFilterAdapters.get("filter_food").setClickFilterListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                resetFilterView();
                int position = Integer.parseInt(v.getTag().toString());
                mFilterAdapters.get("filter_food").setSelectedPosition(position);
                mCurrentFilterGroupIndex = 3;
                mCurrentFilterIndex = -1;

                if (position == 0) {
                    mSTManager.enableFilter(false);
                } else {
                    mSTManager.setFilterStyle(mFilterLists.get("filter_food").get(position).model);
                    mSTManager.enableFilter(true);
                    mCurrentFilterIndex = position;

                    mFilterStrengthLayout.setVisibility(View.VISIBLE);

                    ((ImageView) findViewById(R.id.iv_filter_group_food)).setImageDrawable(getResources().getDrawable(R.drawable.icon_food_selected));
                    ((TextView) findViewById(R.id.tv_filter_group_food)).setTextColor(Color.parseColor("#c460e1"));
                }

                mFilterAdapters.get("filter_food").notifyDataSetChanged();
            }
        });

        mBeautyOptionsAdapter.setClickBeautyListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                int position = Integer.parseInt(v.getTag().toString());
                mBeautyOptionsAdapter.setSelectedPosition(position);
                mBeautyOptionsPosition = position;
                mResetTextView.setVisibility(View.VISIBLE);
                if (mBeautyOptionsPosition != 3) {
                    calculateBeautyIndex(mBeautyOptionsPosition, mBeautyOptionSelectedIndex.get(mBeautyOptionsPosition));
                    mIndicatorSeekbar.setVisibility(View.VISIBLE);
                    if (mBeautyOptionsPosition == 2 && mBeautyOptionSelectedIndex.get(mBeautyOptionsPosition) != 0 && mBeautyOptionSelectedIndex.get(mBeautyOptionsPosition) != 3) {
                        mIndicatorSeekbar.getSeekBar().setProgress(STUtils.convertToData(mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(mBeautyOptionSelectedIndex.get(position)).getProgress()));
                    } else {
                        mIndicatorSeekbar.getSeekBar().setProgress(mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(mBeautyOptionSelectedIndex.get(position)).getProgress());
                    }
                    mIndicatorSeekbar.updateTextview(mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(mBeautyOptionSelectedIndex.get(position)).getProgress());
                } else {
                    mIndicatorSeekbar.setVisibility(View.INVISIBLE);
                }
                mFilterIconsRelativeLayout.setVisibility(View.INVISIBLE);
                mFilterStrengthLayout.setVisibility(View.INVISIBLE);
                if (position == 0) {
                    mFilterGroupsLinearLayout.setVisibility(View.INVISIBLE);
                    mBaseBeautyOptions.setVisibility(View.VISIBLE);
                    mBeautyBaseRecycleView.setAdapter(mBeautyItemAdapters.get("baseBeauty"));
                    mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_WHITEN_STRENGTH, (mBeautifyParams[2]));
                } else if (position == 1) {
                    mFilterGroupsLinearLayout.setVisibility(View.INVISIBLE);
                    mBaseBeautyOptions.setVisibility(View.VISIBLE);
                    mBeautyBaseRecycleView.setAdapter(mBeautyItemAdapters.get("professionalBeauty"));
                } else if (position == 2) {
                    mFilterGroupsLinearLayout.setVisibility(View.INVISIBLE);
                    mBaseBeautyOptions.setVisibility(View.VISIBLE);
                    mBeautyBaseRecycleView.setAdapter(mBeautyItemAdapters.get("microBeauty"));
                } else if (position == 3) {
                    mFilterGroupsLinearLayout.setVisibility(View.VISIBLE);
                    mBaseBeautyOptions.setVisibility(View.INVISIBLE);
                } else if (position == 4) {
                    mFilterGroupsLinearLayout.setVisibility(View.INVISIBLE);
                    mBaseBeautyOptions.setVisibility(View.VISIBLE);
                    mBeautyBaseRecycleView.setAdapter(mBeautyItemAdapters.get("adjustBeauty"));
                }
                mBeautyOptionsAdapter.notifyDataSetChanged();
            }
        });


        mObjectAdapter.setClickObjectListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                int position = Integer.parseInt(v.getTag().toString());

                if (mCurrentObjectIndex == position) {
                    mCurrentObjectIndex = -1;
                    mObjectAdapter.setSelectedPosition(-1);
                    mObjectAdapter.notifyDataSetChanged();
                    mSTManager.enableObject(false);
                } else {
                    mObjectAdapter.setSelectedPosition(position);

                    mNeedObject = true;
                    mSTManager.enableObject(true);
                    mGuideBitmap = BitmapFactory.decodeResource(mContext.getResources(), mObjectList.get(position).drawableID);
                    mSTManager.resetIndexRect();

                    mObjectAdapter.notifyDataSetChanged();

                    mCurrentObjectIndex = position;
                }

            }
        });

        for (Map.Entry<String, BeautyItemAdapter> entry : mBeautyItemAdapters.entrySet()) {
            final BeautyItemAdapter adapter = entry.getValue();
            adapter.setClickBeautyListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    int position = Integer.parseInt(v.getTag().toString());
                    adapter.setSelectedPosition(position);
                    mBeautyOptionSelectedIndex.put(mBeautyOptionsPosition, position);
                    if(checkMicroType()){
                        mIndicatorSeekbar.getSeekBar().setProgress(STUtils.convertToData(mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(position).getProgress()));
                    } else {
                        mIndicatorSeekbar.getSeekBar().setProgress(mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(position).getProgress());
                    }
                    mIndicatorSeekbar.updateTextview(mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(position).getProgress());
                    calculateBeautyIndex(mBeautyOptionsPosition, position);
                    adapter.notifyDataSetChanged();
                }
            });
        }

        findViewById(R.id.rv_close_sticker).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                //重置所有状态为未选中状态
                resetStickerAdapter();
                resetNewStickerAdapter();
                mCurrentStickerPosition = -1;
                mCurrentNewStickerPosition = -1;
                mSTManager.removeAllStickers();
                mSTManager.enableSticker(false);

                mCurrentObjectIndex = -1;
                mObjectAdapter.setSelectedPosition(-1);
                mObjectAdapter.notifyDataSetChanged();
                mSTManager.enableObject(false);

                findViewById(R.id.iv_close_sticker).setBackground(getResources().getDrawable(R.drawable.close_sticker_selected));
            }
        });

        mSTManager.enableBeautify(true);

        mResetTextView.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (mBeautyOptionsPosition != 3) {
                    resetSetBeautyParam(mBeautyOptionsPosition);
                    resetBeautyLists(mBeautyOptionsPosition);
                    mBeautyItemAdapters.get(mBeautyOption.get(mBeautyOptionsPosition)).notifyDataSetChanged();
                    if (checkMicroType()) {
                        mIndicatorSeekbar.getSeekBar().setProgress(STUtils.convertToData(mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(mBeautyOptionSelectedIndex.get(mBeautyOptionsPosition)).getProgress()));
                    } else {
                        mIndicatorSeekbar.getSeekBar().setProgress(mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(mBeautyOptionSelectedIndex.get(mBeautyOptionsPosition)).getProgress());
                    }
                    mIndicatorSeekbar.updateTextview(mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(mBeautyOptionSelectedIndex.get(mBeautyOptionsPosition)).getProgress());
                } else {
                    setDefaultFilter();
                    mFilterStrengthBar.setProgress(65);
                }
            }
        });
    }

    public void setDefaultFilter() {
        resetFilterView();
        if (mFilterLists.get("filter_portrait").size() > 0) {
            for (int i = 0; i < mFilterLists.get("filter_portrait").size(); i++) {
                if (mFilterLists.get("filter_portrait").get(i).name.equals("babypink")) {
                    mCurrentFilterIndex = i;
                }
            }

            if (mCurrentFilterIndex > 0) {
                mCurrentFilterGroupIndex = 0;
                mFilterAdapters.get("filter_portrait").setSelectedPosition(mCurrentFilterIndex);
                mSTManager.setFilterStyle(mFilterLists.get("filter_portrait").get(mCurrentFilterIndex).model);
                mSTManager.enableFilter(true);

                ((ImageView) findViewById(R.id.iv_filter_group_portrait)).setImageDrawable(getResources().getDrawable(R.drawable.icon_portrait_selected));
                ((TextView) findViewById(R.id.tv_filter_group_portrait)).setTextColor(Color.parseColor("#c460e1"));
                mFilterAdapters.get("filter_portrait").notifyDataSetChanged();
            }
        }
    }

    private void showActiveTips(long actionNum) {
        if (actionNum != -1 && actionNum != 0) {
            mTipsLayout.setVisibility(View.VISIBLE);
        }

        String triggerTips = "";
        mTipsImageView.setImageDrawable(null);

        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_EYE_BLINK) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_blink);
            triggerTips = triggerTips + "眨眼 ";
            //mTipsTextView.setText("请眨眨眼~");
        }
        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_MOUTH_AH) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_mouth);
            //mTipsTextView.setText("张嘴有惊喜~");
            triggerTips = triggerTips + "张嘴 ";
        }
        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_HEAD_YAW) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_shake);
            triggerTips = triggerTips + "摇头 ";
        }
        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_HEAD_PITCH) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_nod);
            //mTipsTextView.setText("请点点头~");
            triggerTips = triggerTips + "点头 ";
        }
        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_BROW_JUMP) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_frown);
            //mTipsTextView.setText("挑眉有惊喜~");
            triggerTips = triggerTips + "挑眉 ";
        }
        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_HAND_PALM) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_palm_selected);
            //mTipsTextView.setText("请伸出手掌~");
            triggerTips = triggerTips + "手掌 ";
        }
        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_HAND_LOVE) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_heart_hand_selected);
            //mTipsTextView.setText("双手比个爱心吧~");
            triggerTips = triggerTips + "双手爱心 ";
        }
        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_HAND_HOLDUP) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_palm_up_selected);
            //mTipsTextView.setText("请托手~");
            triggerTips = triggerTips + "托手 ";
        }
        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_HAND_CONGRATULATE) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_congratulate_selected);
            //mTipsTextView.setText("抱个拳吧~");
            triggerTips = triggerTips + "抱拳 ";
        }
        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_HAND_FINGER_HEART) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_finger_heart_selected);
            //mTipsTextView.setText("单手比个爱心吧~");
            triggerTips = triggerTips + "单手爱心 ";
        }
        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_HAND_GOOD) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_thumb_selected);
            //mTipsTextView.setText("请伸出大拇指~");
            triggerTips = triggerTips + "大拇指 ";
        }
        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_HAND_OK) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_ok_selected);
            //mTipsTextView.setText("请亮出OK手势~");
            triggerTips = triggerTips + "OK ";
        }
        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_HAND_SCISSOR) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_scissor_selected);
            //mTipsTextView.setText("请比个剪刀手~");
            triggerTips = triggerTips + "剪刀手 ";
        }
        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_HAND_PISTOL) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_pistol_selected);
            //mTipsTextView.setText("手枪");
            triggerTips = triggerTips + "手枪 ";
        }
        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_HAND_FINGER_INDEX) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_one_finger_selected);
            //mTipsTextView.setText("请伸出食指~");
            triggerTips = triggerTips + "食指 ";
        }
        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_HAND_FIST) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_first_selected);
            //mTipsTextView.setText("请举起拳头~");
            triggerTips = triggerTips + "请举起拳头~ ";
        }
        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_HAND_666) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_sixsixsix_selected);
            //mTipsTextView.setText("请亮出666手势~");
            triggerTips = triggerTips + "请亮出666手势~ ";
        }
        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_HAND_BLESS) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_handbless_selected);
            //mTipsTextView.setText("请双手合十~");
            triggerTips = triggerTips + "请双手合十~";
        }
        if ((actionNum & STMobileHumanActionNative.ST_MOBILE_HAND_ILOVEYOU) > 0) {
            mTipsImageView.setImageResource(R.drawable.ic_trigger_love_selected);
            //mTipsTextView.setText("请亮出我爱你手势~");
            triggerTips = triggerTips + "请亮出我爱你手势~";
        }
        mTipsTextView.setText(triggerTips);

        mTipsLayout.setVisibility(View.VISIBLE);
        if (mTipsRunnable != null) {
            mTipsHandler.removeCallbacks(mTipsRunnable);
        }

        mTipsRunnable = new Runnable() {
            @Override
            public void run() {
                mTipsLayout.setVisibility(View.GONE);
            }
        };

        mTipsHandler.postDelayed(mTipsRunnable, 2000);
    }

    private void performVerticalSeekBarVisiable(boolean isVisiable) {
        if (isVisiable) {
            mHandler.removeMessages(MSG_HIDE_VERTICALSEEKBAR);
            mHandler.sendEmptyMessageDelayed(MSG_HIDE_VERTICALSEEKBAR, 2000);
            mVerticalSeekBar.setVisibility(View.VISIBLE);
        } else {
            mVerticalSeekBar.setVisibility(View.GONE);
        }
    }

    private void resetSetBeautyParam(int beautyOptionsPosition) {
        switch (beautyOptionsPosition) {
            case 0:
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_WHITEN_STRENGTH, (mBeautifyParams[2]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_REDDEN_STRENGTH, (mBeautifyParams[0]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_SMOOTH_STRENGTH, (mBeautifyParams[1]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_DEHIGHLIGHT_STRENGTH, (mBeautifyParams[8]));
                break;
            case 1:
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_SHRINK_FACE_RATIO, (mBeautifyParams[4]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_ENLARGE_EYE_RATIO, (mBeautifyParams[3]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_SHRINK_JAW_RATIO, (mBeautifyParams[5]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_NARROW_FACE_STRENGTH, (mBeautifyParams[9]));
                break;
            case 2:
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_3D_NARROW_NOSE_RATIO, (mBeautifyParams[10]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_3D_NOSE_LENGTH_RATIO, (mBeautifyParams[11]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_3D_CHIN_LENGTH_RATIO, (mBeautifyParams[12]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_3D_MOUTH_SIZE_RATIO, (mBeautifyParams[13]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_3D_PHILTRUM_LENGTH_RATIO, (mBeautifyParams[14]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_3D_HAIRLINE_HEIGHT_RATIO, (mBeautifyParams[15]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_3D_THIN_FACE_SHAPE_RATIO, (mBeautifyParams[16]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_3D_EYE_DISTANCE_RATIO, (mBeautifyParams[17]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_3D_EYE_ANGLE_RATIO, (mBeautifyParams[18]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_3D_OPEN_CANTHUS_RATIO, (mBeautifyParams[19]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_3D_PROFILE_RHINOPLASTY_RATIO, (mBeautifyParams[20]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_3D_BRIGHT_EYE_RATIO, (mBeautifyParams[21]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_3D_REMOVE_DARK_CIRCLES_RATIO, (mBeautifyParams[22]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_3D_REMOVE_NASOLABIAL_FOLDS_RATIO, (mBeautifyParams[23]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_3D_WHITE_TEETH_RATIO, (mBeautifyParams[24]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_3D_APPLE_MUSLE_RATIO, (mBeautifyParams[25]));
                break;
            case 4:
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_CONSTRACT_STRENGTH, (mBeautifyParams[6]));
                mSTManager.setBeautyParam(Constants.ST_BEAUTIFY_SATURATION_STRENGTH, (mBeautifyParams[7]));
                break;
        }
    }

    private void resetBeautyLists(int beautyOptionsPosition) {
        switch (beautyOptionsPosition) {
            case 0:
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(0).setProgress((int) (mBeautifyParams[2] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(1).setProgress((int) (mBeautifyParams[0] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(2).setProgress((int) (mBeautifyParams[1] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(3).setProgress((int) (mBeautifyParams[8] * 100));
                break;
            case 1:
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(0).setProgress((int) (mBeautifyParams[4] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(1).setProgress((int) (mBeautifyParams[3] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(2).setProgress((int) (mBeautifyParams[5] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(3).setProgress((int) (mBeautifyParams[9] * 100));
                break;
            case 2:
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(0).setProgress((int) (mBeautifyParams[10] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(1).setProgress((int) (mBeautifyParams[11] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(2).setProgress((int) (mBeautifyParams[12] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(3).setProgress((int) (mBeautifyParams[13] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(4).setProgress((int) (mBeautifyParams[14] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(5).setProgress((int) (mBeautifyParams[15] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(6).setProgress((int) (mBeautifyParams[16] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(7).setProgress((int) (mBeautifyParams[17] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(8).setProgress((int) (mBeautifyParams[18] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(9).setProgress((int) (mBeautifyParams[19] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(10).setProgress((int) (mBeautifyParams[20] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(11).setProgress((int) (mBeautifyParams[21] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(12).setProgress((int) (mBeautifyParams[22] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(13).setProgress((int) (mBeautifyParams[23] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(14).setProgress((int) (mBeautifyParams[24] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(15).setProgress((int) (mBeautifyParams[25] * 100));
                break;
            case 4:
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(0).setProgress((int) (mBeautifyParams[6] * 100));
                mBeautyLists.get(mBeautyOption.get(mBeautyOptionsPosition)).get(1).setProgress((int) (mBeautifyParams[7] * 100));
                break;
        }
    }

    private void calculateBeautyIndex(int beautyOptionPosition, int selectPosition) {
        switch (beautyOptionPosition) {
            case 0:
                switch (selectPosition) {
                    case 0:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_WHITEN_STRENGTH;
                        break;
                    case 1:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_REDDEN_STRENGTH;
                        break;
                    case 2:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_SMOOTH_STRENGTH;
                        break;
                    case 3:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_DEHIGHLIGHT_STRENGTH;
                        break;
                }
                break;
            case 1:
                switch (selectPosition) {
                    case 0:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_SHRINK_FACE_RATIO;
                        break;
                    case 1:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_ENLARGE_EYE_RATIO;
                        break;
                    case 2:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_SHRINK_JAW_RATIO;
                        break;
                    case 3:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_NARROW_FACE_STRENGTH;
                        break;
                }
                break;
            case 2:
                switch (selectPosition) {
                    case 0:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_3D_THIN_FACE_SHAPE_RATIO;
                        break;
                    case 1:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_3D_CHIN_LENGTH_RATIO;
                        break;
                    case 2:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_3D_HAIRLINE_HEIGHT_RATIO;
                        break;
                    case 3:
                        mCurrentBeautyIndex = Constants. ST_BEAUTIFY_3D_APPLE_MUSLE_RATIO;
                        break;
                    case 4:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_3D_NARROW_NOSE_RATIO;
                        break;
                    case 5:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_3D_NOSE_LENGTH_RATIO;
                        break;
                    case 6:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_3D_PROFILE_RHINOPLASTY_RATIO;
                        break;
                    case 7:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_3D_MOUTH_SIZE_RATIO;
                        break;
                    case 8:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_3D_PHILTRUM_LENGTH_RATIO;
                        break;
                    case 9:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_3D_EYE_DISTANCE_RATIO;
                        break;
                    case 10:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_3D_EYE_ANGLE_RATIO;
                        break;
                    case 11:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_3D_OPEN_CANTHUS_RATIO;
                        break;
                    case 12:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_3D_BRIGHT_EYE_RATIO;
                        break;
                    case 13:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_3D_REMOVE_DARK_CIRCLES_RATIO;
                        break;
                    case 14:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_3D_REMOVE_NASOLABIAL_FOLDS_RATIO;
                        break;
                    case 15:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_3D_WHITE_TEETH_RATIO;
                        break;
                }
                break;
            case 4:
                switch (selectPosition) {
                    case 0:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_CONSTRACT_STRENGTH;
                        break;
                    case 1:
                        mCurrentBeautyIndex = Constants.ST_BEAUTIFY_SATURATION_STRENGTH;
                        break;
                }
                break;
        }
    }

    public void notifyStickerViewState(StickerItem stickerItem,int position,String name){
        RecyclerView.ViewHolder viewHolder = mStickersRecycleView.findViewHolderForAdapterPosition(position);
        //排除不必要变更
        if (viewHolder == null || mStickersRecycleView.getAdapter() != mStickerAdapters.get(name))
            return;
        View itemView = viewHolder.itemView;
        ImageView normalState = (ImageView) itemView.findViewById(R.id.normalState);
        ImageView downloadingState = (ImageView) itemView.findViewById(R.id.downloadingState);
        ViewGroup loadingStateParent = (ViewGroup) itemView.findViewById(R.id.loadingStateParent);
        switch (stickerItem.state) {
            case NORMAL_STATE:
                //设置为等待下载状态
                if (normalState.getVisibility() != View.VISIBLE) {
                    Log.i("StickerAdapter", "NORMAL_STATE");
                    normalState.setVisibility(View.VISIBLE);
                    downloadingState.setVisibility((View.INVISIBLE));
                    downloadingState.setActivated(false);
                    loadingStateParent.setVisibility((View.INVISIBLE));
                }
                break;
            case LOADING_STATE:
                //设置为loading 状态
                if (downloadingState.getVisibility() != View.VISIBLE) {
                    Log.i("StickerAdapter", "LOADING_STATE");
                    normalState.setVisibility(View.INVISIBLE);
                    downloadingState.setActivated(true);
                    downloadingState.setVisibility((View.VISIBLE));
                    loadingStateParent.setVisibility((View.VISIBLE));
                }
                break;
            case DONE_STATE:
                //设置为下载完成状态
                if (normalState.getVisibility() != View.INVISIBLE || downloadingState.getVisibility() != View.INVISIBLE) {
                    Log.i("StickerAdapter", "DONE_STATE");
                    normalState.setVisibility(View.INVISIBLE);
                    downloadingState.setVisibility((View.INVISIBLE));
                    downloadingState.setActivated(false);
                    loadingStateParent.setVisibility((View.INVISIBLE));
                }
                break;
        }
    }

    private void initStickerListener(final String groupId, final int index, final List<SenseArMaterial> materials) {
        mStickerAdapters.get(groupId).setClickStickerListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (!NetworkUtils.isNetworkAvailable(getApplicationContext())) {
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            Toast.makeText(getApplicationContext(), "Network unavailable.", Toast.LENGTH_LONG).show();

                        }
                    });
                }
                mTipsLayout.setVisibility(View.GONE);
                final int position = Integer.parseInt(v.getTag().toString());
                final StickerItem stickerItem = mStickerAdapters.get(groupId).getItem(position);
                if (stickerItem != null && stickerItem.state == StickerState.LOADING_STATE) {
                    Log.d(TAG, String.format(Locale.getDefault(), "正在下载，请稍后点击!"));
                    return;
                }

                if (mCurrentStickerOptionsIndex == index && mCurrentStickerPosition == position) {
                    preMaterialId = "";
                    mStickerAdapters.get(groupId).setSelectedPosition(-1);
                    mCurrentStickerOptionsIndex = -1;
                    mCurrentStickerPosition = -1;

                    findViewById(R.id.iv_close_sticker).setBackground(getResources().getDrawable(R.drawable.close_sticker_selected));
                    mSTManager.enableSticker(false);
                    mSTManager.removeAllStickers();
                    mStickerAdapters.get(groupId).notifyDataSetChanged();
                    return;
                }
                SenseArMaterial sarm = materials.get(position);
                preMaterialId = sarm.id;
                //如果素材还未下载，点击时需要下载
                if (stickerItem.state == StickerState.NORMAL_STATE) {
                    stickerItem.state = StickerState.LOADING_STATE;
                    notifyStickerViewState(stickerItem, position,groupId);
//                    mStickerAdapters.get(groupId).notifyDataSetChanged();
                    SenseArMaterialService.shareInstance().downloadMaterial(VideoRecordActivity.this, sarm, new SenseArMaterialService.DownloadMaterialListener() {
                        @Override
                        public void onSuccess(final SenseArMaterial material) {
                            runOnUiThread(new Runnable() {
                                @Override
                                public void run() {
                                    stickerItem.path = material.cachedPath;
                                    stickerItem.state = StickerState.DONE_STATE;
                                    //如果本次下载是用户用户最后一次选中项，则直接应用
                                    if (preMaterialId.equals(material.id)) {
                                        resetNewStickerAdapter();
                                        resetStickerAdapter();
                                        mCurrentStickerOptionsIndex = index;
                                        mCurrentStickerPosition = position;
                                        findViewById(R.id.iv_close_sticker).setBackground(getResources().getDrawable(R.drawable.close_sticker));

                                        mStickerAdapters.get(groupId).setSelectedPosition(position);
                                        mSTManager.enableSticker(true);
                                        mSTManager.changeSticker(stickerItem.path);
                                    }
                                    notifyStickerViewState(stickerItem, position, groupId);
//                                    mStickerAdapters.get(groupId).notifyDataSetChanged();
                                }
                            });
                            Log.d(TAG, String.format(Locale.getDefault(), "素材下载成功:%s,cached path is %s", material.materials, material.cachedPath));
                        }

                        @Override
                        public void onFailure(SenseArMaterial material, final int code, String message) {
                            Log.d(TAG, String.format(Locale.getDefault(), "素材下载失败:%s", material.materials));
                            runOnUiThread(new Runnable() {
                                @Override
                                public void run() {
                                    stickerItem.state = StickerState.NORMAL_STATE;
//                                    mStickerAdapters.get(groupId).notifyDataSetChanged();
                                    notifyStickerViewState(stickerItem, position, groupId);
                                }
                            });
                        }

                        @Override
                        public void onProgress(SenseArMaterial material, float progress, int size) {

                        }
                    });
                } else if (stickerItem.state == StickerState.DONE_STATE) {
                    resetNewStickerAdapter();
                    resetStickerAdapter();
                    mCurrentStickerOptionsIndex = index;
                    mCurrentStickerPosition = position;

                    findViewById(R.id.iv_close_sticker).setBackground(getResources().getDrawable(R.drawable.close_sticker));

                    mStickerAdapters.get(groupId).setSelectedPosition(position);
                    mSTManager.enableSticker(true);
                    mSTManager.changeSticker(mStickerLists.get(groupId).get(position).path);
                }
            }
        });
    }


    private void fetchGroupMaterialList(final List<StickerOptionsItem> groups) {
        for (int i = 0; i < groups.size(); i++) {
            final StickerOptionsItem groupId = groups.get(i);
            if (groupId.name.equals("sticker_new_engine")) {
                //使用本地加载
            }else if(groupId.name.equals("object_track")){
                //使用本地object 追踪模型
            }else {
                //使用网络下载
                final int j = i;
                SenseArMaterialService.shareInstance().fetchMaterialsFromGroupId("", groupId.name, SenseArMaterialType.Effect, new SenseArMaterialService.FetchMaterialListener() {
                    @Override
                    public void onSuccess(final List<SenseArMaterial> materials) {
                        fetchGroupMaterialInfo(groupId.name, materials, j);
                    }

                    @Override
                    public void onFailure(int code, String message) {
                        Log.d(TAG, String.format(Locale.getDefault(), "下载素材信息失败！%d, %s", code, TextUtils.isEmpty(message)?"":message));
                    }
                });
            }
        }
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (mStickerOptionsRecycleView.getAdapter() == null) {
                    mStickerOptionsRecycleView.setAdapter(mStickerOptionsAdapter);
                }
                mStickerOptionsAdapter.setSelectedPosition(0);
                mStickerOptionsAdapter.notifyDataSetChanged();
            }
        });
    }

    private void fetchGroupMaterialInfo(final String groupId, final List<SenseArMaterial> materials, final int index) {
        if (materials == null || materials.size() <= 0) {
            return;
        }
        final ArrayList<StickerItem> stickerList = new ArrayList<>();
        mStickerLists.put(groupId, stickerList);
        mStickerAdapters.put(groupId, new StickerAdapter(mStickerLists.get(groupId), getApplicationContext()));
        mStickerAdapters.get(groupId).setSelectedPosition(-1);
        Log.d(TAG, "group id is " + groupId + " materials size is " + materials.size());
        initStickerListener(groupId, index, materials);
        for (int i = 0; i < materials.size(); i++) {
            SenseArMaterial sarm = materials.get(i);
            Bitmap bitmap = null;
            try {
                bitmap = ImageUtils.getImageSync(sarm.thumbnail, VideoRecordActivity.this);

            } catch (Exception e) {
                e.printStackTrace();
            }
            if (bitmap == null) {
                bitmap = BitmapFactory.decodeResource(getResources(), R.drawable.none);
            }
            String path = "";
            //如果已经下载则传入路径地址
            if (SenseArMaterialService.shareInstance().isMaterialDownloaded(VideoRecordActivity.this, sarm)) {
                path = SenseArMaterialService.shareInstance().getMaterialCachedPath(VideoRecordActivity.this, sarm);
            }
            sarm.cachedPath = path;
            stickerList.add(new StickerItem(sarm.name, bitmap, path));
        }
    }

    private void initStickerTabListener() {
        //tab 切换事件订阅
        mStickerOptionsAdapter.setClickStickerListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (mStickerOptionsList == null || mStickerOptionsList.size() <= 0) {
                    Log.d(TAG, "group 列表不能为空");
                    return;
                }
                int position = Integer.parseInt(v.getTag().toString());
                mStickerOptionsAdapter.setSelectedPosition(position);
                mStickersRecycleView.setLayoutManager(new GridLayoutManager(mContext, 6));

                //更新这一次的选择
                StickerOptionsItem selectedItem = mStickerOptionsAdapter.getPositionItem(position);
                Log.d("selectedItem", selectedItem.name);
                if (selectedItem == null) {
                    Log.d(TAG, "选择项目不能为空!");
                    return;
                }
                RecyclerView.Adapter selectedAdapter;
                if (selectedItem.name.equals("sticker_new_engine")) {
                    selectedAdapter = mNativeStickerAdapters.get(selectedItem.name);
                }else if(selectedItem.name.equals("object_track")){
                    selectedAdapter = mObjectAdapter;
                } else {
                    selectedAdapter = mStickerAdapters.get(selectedItem.name);
                }

                if (selectedAdapter == null) {
                    Log.d(TAG, "贴纸adapter 不能为空");
                    Toast.makeText(getApplicationContext(),"列表正在拉取，或拉取出错!",Toast.LENGTH_SHORT).show();
                    return;
                }

                mStickersRecycleView.setAdapter(selectedAdapter);
                mStickerOptionsAdapter.notifyDataSetChanged();
                selectedAdapter.notifyDataSetChanged();
            }
        });
    }

    private void initNativeStickerAdapter(final String stickerClassName, final int index){
        mNativeStickerAdapters.get(stickerClassName).setSelectedPosition(-1);
        mNativeStickerAdapters.get(stickerClassName).setClickStickerListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                mTipsLayout.setVisibility(View.GONE);
                resetNewStickerAdapter();
                resetStickerAdapter();
                int position = Integer.parseInt(v.getTag().toString());

                if(mCurrentStickerOptionsIndex == index && mCurrentStickerPosition == position){
                    mNativeStickerAdapters.get(stickerClassName).setSelectedPosition(-1);
                    mCurrentStickerOptionsIndex = -1;
                    mCurrentStickerPosition = -1;

                    findViewById(R.id.iv_close_sticker).setBackground(getResources().getDrawable(R.drawable.close_sticker_selected));
                    mSTManager.enableSticker(false);
                    mSTManager.changeSticker(null);

                }else{
                    mCurrentStickerOptionsIndex = index;
                    mCurrentStickerPosition = position;

                    findViewById(R.id.iv_close_sticker).setBackground(getResources().getDrawable(R.drawable.close_sticker));

                    mNativeStickerAdapters.get(stickerClassName).setSelectedPosition(position);
                    mSTManager.enableSticker(true);
                    mSTManager.changeSticker(mNewStickers.get(position).path);
                }

                mNativeStickerAdapters.get(stickerClassName).notifyDataSetChanged();
            }
        });
    }

    private void resetStickerAdapter() {

        if (mCurrentStickerPosition != -1) {
            mSTManager.removeAllStickers();
            mCurrentStickerPosition = -1;
        }

        //重置所有状态为为选中状态
        for (StickerOptionsItem optionsItem : mStickerOptionsList) {
            if (optionsItem.name.equals("sticker_new_engine")) {
                continue;
            }else if(optionsItem.name.equals("object_track")){
                continue;
            }
            else {
                if (mStickerAdapters.get(optionsItem.name) != null) {
                    mStickerAdapters.get(optionsItem.name).setSelectedPosition(-1);
                    mStickerAdapters.get(optionsItem.name).notifyDataSetChanged();
                }
            }
        }
    }

    private void resetNewStickerAdapter() {

        mSTManager.removeAllStickers();
        mCurrentNewStickerPosition = -1;

        if (mStickerPackageMap != null) {
            mStickerPackageMap.clear();
        }

        if (mNativeStickerAdapters.get("sticker_new_engine") != null) {
            mNativeStickerAdapters.get("sticker_new_engine").setSelectedPosition(-1);
            mNativeStickerAdapters.get("sticker_new_engine").notifyDataSetChanged();
        }
    }

    private void resetFilterView() {
        ((ImageView) findViewById(R.id.iv_filter_group_portrait)).setImageDrawable(getResources().getDrawable(R.drawable.icon_portrait_unselected));
        ((TextView) findViewById(R.id.tv_filter_group_portrait)).setTextColor(Color.parseColor("#ffffff"));

        ((ImageView) findViewById(R.id.iv_filter_group_scenery)).setImageDrawable(getResources().getDrawable(R.drawable.icon_scenery_unselected));
        ((TextView) findViewById(R.id.tv_filter_group_scenery)).setTextColor(Color.parseColor("#ffffff"));

        ((ImageView) findViewById(R.id.iv_filter_group_still_life)).setImageDrawable(getResources().getDrawable(R.drawable.icon_still_life_unselected));
        ((TextView) findViewById(R.id.tv_filter_group_still_life)).setTextColor(Color.parseColor("#ffffff"));

        ((ImageView) findViewById(R.id.iv_filter_group_food)).setImageDrawable(getResources().getDrawable(R.drawable.icon_food_unselected));
        ((TextView) findViewById(R.id.tv_filter_group_food)).setTextColor(Color.parseColor("#ffffff"));

        mFilterAdapters.get("filter_portrait").setSelectedPosition(-1);
        mFilterAdapters.get("filter_portrait").notifyDataSetChanged();
        mFilterAdapters.get("filter_scenery").setSelectedPosition(-1);
        mFilterAdapters.get("filter_scenery").notifyDataSetChanged();
        mFilterAdapters.get("filter_still_life").setSelectedPosition(-1);
        mFilterAdapters.get("filter_still_life").notifyDataSetChanged();
        mFilterAdapters.get("filter_food").setSelectedPosition(-1);
        mFilterAdapters.get("filter_food").notifyDataSetChanged();

        mFilterStrengthLayout.setVisibility(View.INVISIBLE);
    }

    private boolean checkMicroType(){
        int type = mBeautyOptionSelectedIndex.get(mBeautyOptionsPosition);
        boolean ans = ((type != 0) && (type != 4) && (type != 6) && (type != 11) && (type != 12) && (type != 13) && (type != 14) && (type != 15) && (type != 3));
        return ans && (2 == mBeautyOptionsPosition);
    }

    private void closeTableView() {
        mStickerOptionsSwitch.setVisibility(View.VISIBLE);
        mBeautyOptionsSwitch.setVisibility(View.VISIBLE);
        mSelectOptions.setBackgroundColor(Color.parseColor("#00000000"));
        mSelectOptions.setVisibility(View.VISIBLE);

        mStickerOptions.setVisibility(View.INVISIBLE);
        mStickerIcons.setVisibility(View.INVISIBLE);

        mStickerOptionsSwitchIcon = (ImageView) findViewById(R.id.iv_sticker_options_switch);
        mBeautyOptionsSwitchIcon = (ImageView) findViewById(R.id.iv_beauty_options_switch);
        mStickerOptionsSwitchText = (TextView) findViewById(R.id.tv_sticker_options_switch);
        mBeautyOptionsSwitchText = (TextView) findViewById(R.id.tv_beauty_options_switch);

        mStickerOptionsSwitchIcon.setImageDrawable(getResources().getDrawable(R.drawable.sticker));
        mStickerOptionsSwitchText.setTextColor(Color.parseColor("#ffffff"));
        mIsStickerOptionsOpen = false;

        mFilterGroupsLinearLayout.setVisibility(View.INVISIBLE);
        mFilterIconsRelativeLayout.setVisibility(View.INVISIBLE);
        mFilterStrengthLayout.setVisibility(View.INVISIBLE);
        mFilterAndBeautyOptionView.setVisibility(View.INVISIBLE);
        mBaseBeautyOptions.setVisibility(View.INVISIBLE);
        mBeautyOptionsSwitchIcon.setImageDrawable(getResources().getDrawable(R.drawable.beauty));
        mBeautyOptionsSwitchText.setTextColor(Color.parseColor("#ffffff"));
        mIsBeautyOptionsOpen = false;
        mIndicatorSeekbar.setVisibility(View.INVISIBLE);
        mIsSettingOptionsOpen = false;

        mResetTextView.setVisibility(View.INVISIBLE);
    }

    private void drawObjectImage(final Rect rect, final boolean needDrawRect) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (!mSurfaceViewOverlap.getHolder().getSurface().isValid()) {
                    return;
                }
                Canvas canvas = mSurfaceViewOverlap.getHolder().lockCanvas();
                if (canvas == null)
                    return;

                canvas.drawColor(0, PorterDuff.Mode.CLEAR);
                if (needDrawRect) {
                    canvas.drawRect(rect, mPaint);
                }
                canvas.drawBitmap(mGuideBitmap, new Rect(0, 0, mGuideBitmap.getWidth(), mGuideBitmap.getHeight()), rect, mPaint);

                mSurfaceViewOverlap.getHolder().unlockCanvasAndPost(canvas);
            }
        });
    }

    private void clearObjectImage() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (!mSurfaceViewOverlap.getHolder().getSurface().isValid()) {
                    return;
                }
                Canvas canvas = mSurfaceViewOverlap.getHolder().lockCanvas();
                if (canvas == null)
                    return;

                canvas.drawColor(0, PorterDuff.Mode.CLEAR);
                mSurfaceViewOverlap.getHolder().unlockCanvasAndPost(canvas);
            }
        });
    }

    private void drawFaceExtraPoints(final STPoint[] points) {
        if (points == null || points.length == 0) {
            return;
        }

        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (!mSurfaceViewOverlap.getHolder().getSurface().isValid()) {
                    return;
                }
                Canvas canvas = mSurfaceViewOverlap.getHolder().lockCanvas();
                if (canvas == null)
                    return;

                canvas.drawColor(0, PorterDuff.Mode.CLEAR);
                STUtils.drawPoints(canvas, mPaint, points);

                mSurfaceViewOverlap.getHolder().unlockCanvasAndPost(canvas);
            }
        });
    }

    @Override
    public void onClick(View v){
        switch(v.getId()){
            case R.id.ll_sticker_options_switch:
                mStickerOptionsSwitch.setVisibility(View.INVISIBLE);
                mBeautyOptionsSwitch.setVisibility(View.INVISIBLE);
                mSelectOptions.setBackgroundColor(Color.parseColor("#00000000"));
                mSelectOptions.setVisibility(View.GONE);
                mIndicatorSeekbar.setVisibility(View.INVISIBLE);
                mStickerOptions.setVisibility(View.VISIBLE);
                mStickerIcons.setVisibility(View.VISIBLE);
                mIsStickerOptionsOpen = true;
                mFilterGroupsLinearLayout.setVisibility(View.INVISIBLE);
                mFilterIconsRelativeLayout.setVisibility(View.INVISIBLE);
                mFilterStrengthLayout.setVisibility(View.INVISIBLE);
                mFilterAndBeautyOptionView.setVisibility(View.INVISIBLE);
                mBaseBeautyOptions.setVisibility(View.INVISIBLE);
                mResetTextView.setVisibility(View.INVISIBLE);
                mIsBeautyOptionsOpen = false;
                mIsSettingOptionsOpen = false;
                break;

            case R.id.ll_beauty_options_switch:
                mStickerOptionsSwitch.setVisibility(View.INVISIBLE);
                mBeautyOptionsSwitch.setVisibility(View.INVISIBLE);
                mSelectOptions.setBackgroundColor(Color.parseColor("#00000000"));
                mSelectOptions.setVisibility(View.GONE);
                mBaseBeautyOptions.setVisibility(View.VISIBLE);
                mIndicatorSeekbar.setVisibility(View.VISIBLE);
                if (mBeautyOptionsPosition == 3) {
                    mBaseBeautyOptions.setVisibility(View.INVISIBLE);
                    mFilterGroupsLinearLayout.setVisibility(View.VISIBLE);
                    mFilterIconsRelativeLayout.setVisibility(View.INVISIBLE);
                    mFilterStrengthLayout.setVisibility(View.INVISIBLE);
                    mIndicatorSeekbar.setVisibility(View.INVISIBLE);
                }
                mFilterAndBeautyOptionView.setVisibility(View.VISIBLE);
                mIsBeautyOptionsOpen = true;
                mResetTextView.setVisibility(View.VISIBLE);
                mIsStickerOptionsOpen = false;
                mIsSettingOptionsOpen = false;
                break;
            default:
                break;
        }
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        int eventAction = event.getAction();
        Rect indexRect = mSTManager.getIndexRect();

        if (mIsStickerOptionsOpen || mIsBeautyOptionsOpen || mIsSettingOptionsOpen) {
            closeTableView();
        }

        if (event.getPointerCount() == 1) {
            switch (eventAction) {
                case MotionEvent.ACTION_DOWN:
                    if ((int) event.getX() >= indexRect.left && (int) event.getX() <= indexRect.right &&
                            (int) event.getY() >= indexRect.top && (int) event.getY() <= indexRect.bottom) {
                        mIndexX = (int) event.getX();
                        mIndexY = (int) event.getY();
                        mSTManager.setIndexRect(mIndexX - indexRect.width() / 2, mIndexY - indexRect.width() / 2, true);
                        mCanMove = true;
                        mSTManager.disableObjectTracking();
                    } else {
                        timeDown = System.currentTimeMillis();
                        downX = (int) event.getX();
                        downY = (int) event.getY();
                    }

                    mSTManager.changeCustomEvent();
                    break;
                case MotionEvent.ACTION_MOVE:
                    if (mCanMove) {
                        mIndexX = (int) event.getX();
                        mIndexY = (int) event.getY();
                        mSTManager.setIndexRect(mIndexX - indexRect.width() / 2, mIndexY - indexRect.width() / 2, true);
                    }
                    break;
                case MotionEvent.ACTION_UP:
                    if (mCanMove) {
                        mIndexX = (int) event.getX();
                        mIndexY = (int) event.getY();
                        mSTManager.setIndexRect(mIndexX - indexRect.width() / 2, mIndexY - indexRect.width() / 2, false);
                        mSTManager.setObjectTrackRect();

                        mCanMove = false;
                    }
            }
        }
        return true;
    }
}

