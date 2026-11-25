package com.vitologic.pokoin

import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var captureSounds: SoundPool? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        volumeControlStream = AudioManager.STREAM_MUSIC
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pokoin.scan/engine",
        ).setMethodCallHandler(ScanEnginePlugin(applicationContext))
        val sounds = SoundPool.Builder()
            .setMaxStreams(1)
            .setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build())
            .build()
        captureSounds = sounds
        val captureSound = sounds.load(this, R.raw.scanner_capture, 1)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pokoin.scan/sound")
            .setMethodCallHandler { call, result ->
                if (call.method == "capture") {
                    sounds.play(captureSound, 0.65f, 0.65f, 1, 0, 1f)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        captureSounds?.release()
        captureSounds = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
