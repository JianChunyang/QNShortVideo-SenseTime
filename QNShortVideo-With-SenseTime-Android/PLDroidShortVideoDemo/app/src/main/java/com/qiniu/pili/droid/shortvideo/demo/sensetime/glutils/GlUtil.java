package com.qiniu.pili.droid.shortvideo.demo.sensetime.glutils;

import android.opengl.GLES20;
import android.opengl.Matrix;

/**
 * Created by jerikc on 16/2/23.
 */
public class GlUtil {
    private static final String TAG = "GlUtil";
    /** Identity matrix for general use.  Don't modify or life will get weird. */

    public static final int NO_TEXTURE = -1;

    private static final int SIZEOF_FLOAT = 4;

    // in Qiniu sdk, we need to flip the texture from PLVideoFilterListener
    public static final String TEXTURE_VS =
            "attribute vec2 a_pos;\n" +
                    "attribute vec2 a_tex;\n" +
                    "varying vec2 v_tex_coord;\n" +
                    "uniform mat4 u_mvp;\n" +
                    "uniform mat4 u_tex_trans;\n" +
                    "void main() {\n" +
                    "   gl_Position = u_mvp * vec4(a_pos, 0.0, 1.0);\n" +
                    "   v_tex_coord = (u_tex_trans * vec4(a_tex, 0.0, 1.0)).st;\n" +
                    "}\n";

    public static final String TEXTURE_2D_FS =
            "precision mediump float;\n" +
                    "uniform sampler2D u_tex;\n" +
                    "varying vec2 v_tex_coord;\n" +
                    "void main() {\n" +
                    "  gl_FragColor = texture2D(u_tex, v_tex_coord);\n" +
                    "}\n";

    /**
     * Identity matrix for general use.  Don't modify or life will get weird.
     */
    public static final float[] IDENTITY_MATRIX;

    static {
        IDENTITY_MATRIX = new float[16];
        Matrix.setIdentityM(IDENTITY_MATRIX, 0);
    }

    private GlUtil() { // do not instantiate
    }

    public static void initEffectTexture(int width, int height, int[] textureId, int type) {
        int len = textureId.length;
        if (len > 0) {
            GLES20.glGenTextures(len, textureId, 0);
        }
        for (int i = 0; i < len; i++) {
            GLES20.glBindTexture(type, textureId[i]);
            GLES20.glTexParameterf(type,
                    GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR);
            GLES20.glTexParameterf(type,
                    GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR);
            GLES20.glTexParameterf(type,
                    GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE);
            GLES20.glTexParameterf(type,
                    GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE);
            GLES20.glTexImage2D(type, 0, GLES20.GL_RGBA, width, height, 0,
                    GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, null);
        }
    }

    /**
     * Create a FBO
     */
    public static int createFBO() {
        int[] fbo = new int[1];
        GLES20.glGenFramebuffers(1, fbo, 0);
        return fbo[0];
    }
}
