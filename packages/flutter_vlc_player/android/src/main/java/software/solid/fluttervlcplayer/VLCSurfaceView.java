package software.solid.fluttervlcplayer;

import android.content.Context;
import android.view.SurfaceHolder;
import android.view.SurfaceView;

import org.videolan.libvlc.MediaPlayer;
import org.videolan.libvlc.interfaces.IVLCVout;

/**
 * SurfaceView-backed video output.
 *
 * <p>The upstream plugin renders into a SurfaceTexture. That fails on TV
 * boxes built around Amlogic SoCs: in direct-rendering mode the decoder
 * writes vendor-compressed (AFBC) buffers meant for the display plane, and
 * a GL external texture samples them as colour noise; with direct
 * rendering off, nothing reaches the surface at all. Both were observed on
 * a Skyworth 4K Google TV box.
 *
 * <p>A SurfaceView puts the video back on its own hardware layer — the
 * path every TV app uses, YouTube included. Flutter's hybrid composition
 * composites it in the native view hierarchy and still draws the player
 * controls above it.
 */
public class VLCSurfaceView extends SurfaceView
        implements SurfaceHolder.Callback, IVLCVout.OnNewVideoLayoutListener {

    private MediaPlayer mMediaPlayer;
    private boolean mSurfaceReady;

    public VLCSurfaceView(final Context context) {
        super(context);
        getHolder().addCallback(this);
        setFocusable(false);
    }

    public void setMediaPlayer(MediaPlayer mediaPlayer) {
        if (mediaPlayer == null && mMediaPlayer != null) {
            detach();
        }
        mMediaPlayer = mediaPlayer;
        attachIfReady();
    }

    private void attachIfReady() {
        if (mMediaPlayer == null || !mSurfaceReady) return;
        final IVLCVout vout = mMediaPlayer.getVLCVout();
        if (vout.areViewsAttached()) return;
        vout.setVideoView(this);
        vout.attachViews(this);
        mMediaPlayer.setVideoTrackEnabled(true);
    }

    private void detach() {
        try {
            mMediaPlayer.getVLCVout().detachViews();
        } catch (Exception ignored) {
            // Already detached, or the player is being torn down.
        }
    }

    public void dispose() {
        getHolder().removeCallback(this);
        if (mMediaPlayer != null) {
            detach();
        }
        mMediaPlayer = null;
        mSurfaceReady = false;
    }

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        mSurfaceReady = true;
        attachIfReady();
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        if (mMediaPlayer == null || width * height == 0) return;
        mMediaPlayer.getVLCVout().setWindowSize(width, height);
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        mSurfaceReady = false;
        if (mMediaPlayer != null) {
            detach();
        }
    }

    @Override
    public void onNewVideoLayout(IVLCVout vlcVout, int width, int height,
                                 int visibleWidth, int visibleHeight,
                                 int sarNum, int sarDen) {
        // The surface is full-bleed and the Dart side already constrains it
        // to the right aspect ratio, so there is no layout work to do here.
    }
}
