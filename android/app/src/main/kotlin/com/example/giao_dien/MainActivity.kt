package com.example.giao_dien

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import ai.onnxruntime.TensorInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.media.MediaPlayer
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Handler
import android.os.Looper
import android.speech.tts.UtteranceProgressListener
import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import android.os.SystemClock
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.speech.tts.TextToSpeech
import android.util.Base64
import androidx.exifinterface.media.ExifInterface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.KeyStore
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import java.util.Locale
import java.util.concurrent.Executors
import kotlin.math.min
import kotlin.math.roundToInt

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Flutter starts with the same logo/background; remove the native
            // overlay without fading a second copy over the first Flutter frame.
            splashScreen.setOnExitAnimationListener { view -> view.remove() }
        }
        super.onCreate(savedInstanceState)
    }

    private var textToSpeech: TextToSpeech? = null
    private var ttsReady = false
    private var gameMusic: MediaPlayer? = null
    private var gameMusicGain = 0.12f
    private val audioHandler = Handler(Looper.getMainLooper())
    private var spokenId: String? = null
    private var speechSerial = 0L
    private var audioPlaying = false
    private val gameSounds = SoundPool.Builder().setMaxStreams(4).setAudioAttributes(
        AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
    ).build()
    private val soundIds = mutableMapOf<String, Int>()
    private val loadedSounds = mutableSetOf<Int>()
    private val effectStreams = mutableListOf<Int>()

    private fun updateGameVolume() {
        val volume = if (spokenId == null) gameMusicGain else 0.025f
        gameMusic?.setVolume(volume, volume)
        val fxVolume = if (spokenId == null) 0.24f else 0.06f
        effectStreams.forEach { gameSounds.setVolume(it, fxVolume, fxVolume) }
    }

    private fun playGameEffect(id: Int) {
        if (!audioPlaying) return
        val volume = if (spokenId == null) 0.24f else 0.06f
        val stream = gameSounds.play(id, volume, volume, 1, 0, 1f)
        if (stream != 0) {
            effectStreams.add(stream)
            if (effectStreams.size > 4) effectStreams.removeAt(0)
        }
    }

    private fun stopGameAudio() {
        audioPlaying = false
        gameMusic?.release(); gameMusic = null
        effectStreams.forEach { gameSounds.stop(it) }
        effectStreams.clear()
    }
    private val inferenceExecutor = Executors.newSingleThreadExecutor()
    private val ortEnvironment: OrtEnvironment by lazy { OrtEnvironment.getEnvironment() }

    @Volatile
    private var e4Session: OrtSession? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        textToSpeech = TextToSpeech(this, this)
        configureTextToSpeech(flutterEngine)
        configureGameAudio(flutterEngine)
        configureSecureStorage(flutterEngine)
        configureOfflineE4(flutterEngine)
    }

    private fun configureGameAudio(flutterEngine: FlutterEngine) {
        gameSounds.setOnLoadCompleteListener { _, id, status ->
            audioHandler.post {
                if (status == 0) { loadedSounds.add(id); playGameEffect(id) }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vocab_vision/game_audio")
            .setMethodCallHandler { call, result ->
                if (call.method == "device") {
                    result.success(mapOf("model" to "${Build.MANUFACTURER} ${Build.MODEL}", "sdk" to Build.VERSION.SDK_INT))
                    return@setMethodCallHandler
                }
                if (call.method == "stop") {
                    stopGameAudio()
                    result.success(null)
                    return@setMethodCallHandler
                }
                if (call.method != "music" && call.method != "effect") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val asset = call.argument<String>("asset")
                if (asset == null || !asset.startsWith("assets/games/space_words/") || asset.contains("..")) {
                    result.error("INVALID_AUDIO", "File âm thanh game không hợp lệ.", null)
                    return@setMethodCallHandler
                }
                audioPlaying = true
                if (call.method == "effect") {
                    try {
                        val existing = soundIds[asset]
                        if (existing != null) {
                            if (loadedSounds.contains(existing)) playGameEffect(existing)
                        } else {
                            val lookup = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
                            assets.openFd(lookup).use { fd -> soundIds[asset] = gameSounds.load(fd, 1) }
                        }
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("GAME_AUDIO_ERROR", error.message, null)
                    }
                    return@setMethodCallHandler
                }
                val player = MediaPlayer()
                try {
                    val lookup = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
                    assets.openFd(lookup).use { fd -> player.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length) }
                    player.isLooping = true
                    gameMusicGain = if (asset.endsWith("/music_boss.mp3")) 0.18f else 0.12f
                    gameMusic?.release(); gameMusic = player
                    player.setOnPreparedListener { ready ->
                        if (gameMusic === ready && audioPlaying) { updateGameVolume(); ready.start() }
                    }
                    player.setOnErrorListener { failed, _, _ ->
                        if (gameMusic === failed) gameMusic = null
                        failed.release()
                        true
                    }
                    player.prepareAsync()
                    result.success(null)
                } catch (error: Exception) {
                    if (gameMusic === player) gameMusic = null
                    player.release()
                    result.error("GAME_AUDIO_ERROR", error.message, null)
                }
            }
    }

    private fun configureSecureStorage(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vocab_vision/secure_storage")
            .setMethodCallHandler { call, result ->
                val key = call.argument<String>("key")
                if (key.isNullOrBlank()) {
                    result.error("INVALID_KEY", "Khóa lưu trữ không hợp lệ.", null)
                    return@setMethodCallHandler
                }
                try {
                    when (call.method) {
                        "read" -> result.success(readSecureValue(key))
                        "write" -> {
                            val value = call.argument<String>("value")
                            if (value == null) {
                                result.error("INVALID_VALUE", "Giá trị lưu trữ bị thiếu.", null)
                            } else {
                                writeSecureValue(key, value)
                                result.success(null)
                            }
                        }
                        "delete" -> {
                            getSharedPreferences(SECURE_PREFS, MODE_PRIVATE)
                                .edit()
                                .remove(key)
                                .apply()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error(
                        "SECURE_STORAGE_ERROR",
                        error.message ?: "Không thể truy cập Android Keystore.",
                        null,
                    )
                }
            }
    }

    private fun readSecureValue(key: String): String? {
        val encoded = getSharedPreferences(SECURE_PREFS, MODE_PRIVATE).getString(key, null)
            ?: return null
        val payload = Base64.decode(encoded, Base64.NO_WRAP)
        require(payload.size > GCM_NONCE_BYTES) { "Dữ liệu secure storage không hợp lệ." }
        val nonce = payload.copyOfRange(0, GCM_NONCE_BYTES)
        val ciphertext = payload.copyOfRange(GCM_NONCE_BYTES, payload.size)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, secureKey(), GCMParameterSpec(GCM_TAG_BITS, nonce))
        return String(cipher.doFinal(ciphertext), Charsets.UTF_8)
    }

    private fun writeSecureValue(key: String, value: String) {
        val nonce = ByteArray(GCM_NONCE_BYTES).also { java.security.SecureRandom().nextBytes(it) }
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secureKey(), GCMParameterSpec(GCM_TAG_BITS, nonce))
        val ciphertext = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val payload = nonce + ciphertext
        getSharedPreferences(SECURE_PREFS, MODE_PRIVATE)
            .edit()
            .putString(key, Base64.encodeToString(payload, Base64.NO_WRAP))
            .apply()
    }

    private fun secureKey(): SecretKey {
        check(Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            "Android Keystore AES-GCM cần Android 6.0 trở lên."
        }
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val existing = keyStore.getKey(SECURE_KEY_ALIAS, null) as? SecretKey
        if (existing != null) return existing
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                SECURE_KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setUserAuthenticationRequired(false)
                .build(),
        )
        return generator.generateKey()
    }

    private fun configureTextToSpeech(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vocab_vision/tts")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "available" -> result.success(ttsReady && textToSpeech?.voice?.isNetworkConnectionRequired == false)
                    "speak" -> {
                        val text = call.argument<String>("text")
                        if (!ttsReady) {
                            result.error("TTS_NOT_READY", "Giọng tiếng Anh chưa sẵn sàng trên thiết bị.", null)
                        } else if (text.isNullOrBlank()) {
                            result.error("EMPTY_TEXT", "Không có từ để phát âm", null)
                        } else {
                            val utterance = "vocab-word-${++speechSerial}"
                            spokenId = utterance
                            updateGameVolume()
                            val status = textToSpeech?.speak(
                                text,
                                TextToSpeech.QUEUE_FLUSH,
                                null,
                                utterance,
                            )
                            if (status == TextToSpeech.ERROR) {
                                spokenId = null
                                updateGameVolume()
                                result.error("TTS_ERROR", "Không thể phát âm", null)
                            } else {
                                result.success(null)
                            }
                        }
                    }

                    "stop" -> {
                        textToSpeech?.stop()
                        spokenId = null
                        updateGameVolume()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun configureOfflineE4(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vocab_vision/e4")
            .setMethodCallHandler { call, result ->
                if (call.method != "predict") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val imagePath = call.argument<String>("imagePath")
                val confidence = call.argument<Double>("confidence") ?: 0.25
                if (imagePath.isNullOrBlank()) {
                    result.error("INVALID_IMAGE", "Không tìm thấy đường dẫn ảnh.", null)
                    return@setMethodCallHandler
                }
                if (confidence <= 0.0 || confidence > 1.0) {
                    result.error(
                        "INVALID_CONFIDENCE",
                        "Ngưỡng confidence phải nằm trong (0, 1].",
                        null,
                    )
                    return@setMethodCallHandler
                }

                inferenceExecutor.execute {
                    try {
                        val prediction = predictOffline(imagePath, confidence.toFloat())
                        runOnUiThread { result.success(prediction) }
                    } catch (error: Exception) {
                        val message = error.message ?: "Không thể chạy E4 offline."
                        runOnUiThread { result.error("E4_INFERENCE_ERROR", message, null) }
                    }
                }
            }
    }

    @Synchronized
    private fun getE4Session(): OrtSession {
        e4Session?.let { return it }

        val modelFile = File(filesDir, "e4_0256115f.onnx")
        if (!modelFile.exists()) {
            assets.open("e4.onnx").use { input ->
                modelFile.outputStream().use { output -> input.copyTo(output) }
            }
        }
        require(sha256(modelFile) == E4_ONNX_SHA256) {
            "Hash model E4 không khớp manifest; không chạy model không xác minh."
        }

        val session = OrtSession.SessionOptions().use { options ->
            options.setIntraOpNumThreads(4)
            options.setInterOpNumThreads(1)
            ortEnvironment.createSession(modelFile.absolutePath, options)
        }
        require(session.inputNames.single() == "images") {
            "Input ONNX không đúng tên 'images'."
        }
        require(session.outputNames.single() == "output0") {
            "Output ONNX không đúng tên 'output0'."
        }
        val inputInfo = session.inputInfo["images"]?.info as? TensorInfo
            ?: error("Không đọc được tensor input E4.")
        require(inputInfo.shape.contentEquals(longArrayOf(1, 3, INPUT_SIZE.toLong(), INPUT_SIZE.toLong()))) {
            "Input E4 không đúng shape [1, 3, 512, 512]."
        }

        return session.also { e4Session = it }
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(8192)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { byte ->
            "%02x".format(byte.toInt() and 0xff)
        }
    }

    private fun predictOffline(imagePath: String, confidenceThreshold: Float): Map<String, Any> {
        val startedAt = SystemClock.elapsedRealtimeNanos()
        val original = decodeOrientedBitmap(imagePath)
        try {
            val originalWidth = original.width
            val originalHeight = original.height
            require(originalWidth > 0 && originalHeight > 0) { "Kích thước ảnh không hợp lệ." }

            val scale = min(INPUT_SIZE.toFloat() / originalWidth, INPUT_SIZE.toFloat() / originalHeight)
            val resizedWidth = (originalWidth * scale).roundToInt()
            val resizedHeight = (originalHeight * scale).roundToInt()
            val padLeft = ((INPUT_SIZE - resizedWidth) / 2f - 0.1f).roundToInt()
            val padTop = ((INPUT_SIZE - resizedHeight) / 2f - 0.1f).roundToInt()

            val letterboxed = Bitmap.createBitmap(INPUT_SIZE, INPUT_SIZE, Bitmap.Config.ARGB_8888)
            try {
                Canvas(letterboxed).apply {
                    drawColor(Color.rgb(114, 114, 114))
                    drawBitmap(
                        original,
                        null,
                        android.graphics.Rect(
                            padLeft,
                            padTop,
                            padLeft + resizedWidth,
                            padTop + resizedHeight,
                        ),
                        Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG),
                    )
                }

                val pixels = IntArray(INPUT_SIZE * INPUT_SIZE)
                letterboxed.getPixels(pixels, 0, INPUT_SIZE, 0, 0, INPUT_SIZE, INPUT_SIZE)
                val planeSize = INPUT_SIZE * INPUT_SIZE
                val inputBuffer = ByteBuffer
                    .allocateDirect(planeSize * 3 * Float.SIZE_BYTES)
                    .order(ByteOrder.nativeOrder())
                    .asFloatBuffer()
                for (index in pixels.indices) {
                    val pixel = pixels[index]
                    inputBuffer.put(index, Color.red(pixel) / 255f)
                    inputBuffer.put(planeSize + index, Color.green(pixel) / 255f)
                    inputBuffer.put(planeSize * 2 + index, Color.blue(pixel) / 255f)
                }

                val session = getE4Session()
                val detections = mutableListOf<Map<String, Any>>()
                OnnxTensor.createTensor(
                    ortEnvironment,
                    inputBuffer,
                    longArrayOf(1, 3, INPUT_SIZE.toLong(), INPUT_SIZE.toLong()),
                ).use { inputTensor ->
                    session.run(mapOf("images" to inputTensor)).use { outputs ->
                        val output = outputs[0] as? OnnxTensor
                            ?: error("Output E4 không phải tensor.")
                        val outputInfo = output.info as TensorInfo
                        require(outputInfo.shape.contentEquals(longArrayOf(1, 300, 6))) {
                            "Output E4 không đúng shape [1, 300, 6]."
                        }
                        val values = output.floatBuffer
                            ?: error("Không đọc được output float32 của E4.")

                        for (row in 0 until 300) {
                            val offset = row * 6
                            val confidence = values.get(offset + 4)
                            if (confidence < confidenceThreshold) continue

                            val classId = values.get(offset + 5).roundToInt()
                            require(classId in CLASS_NAMES.indices) {
                                "E4 trả class ID ngoài 0..14: $classId."
                            }
                            val x1 = ((values.get(offset) - padLeft) / scale)
                                .coerceIn(0f, originalWidth.toFloat())
                            val y1 = ((values.get(offset + 1) - padTop) / scale)
                                .coerceIn(0f, originalHeight.toFloat())
                            val x2 = ((values.get(offset + 2) - padLeft) / scale)
                                .coerceIn(0f, originalWidth.toFloat())
                            val y2 = ((values.get(offset + 3) - padTop) / scale)
                                .coerceIn(0f, originalHeight.toFloat())
                            if (x2 <= x1 || y2 <= y1) continue

                            detections.add(
                                mapOf(
                                    "class_id" to classId,
                                    "label" to CLASS_NAMES[classId],
                                    "confidence" to confidence.toDouble(),
                                    "box" to listOf(
                                        x1.toDouble(),
                                        y1.toDouble(),
                                        x2.toDouble(),
                                        y2.toDouble(),
                                    ),
                                ),
                            )
                        }
                    }
                }
                detections.sortByDescending { it["confidence"] as Double }
                val latencyMs = (SystemClock.elapsedRealtimeNanos() - startedAt) / 1_000_000.0

                return mapOf(
                    "image_width" to originalWidth,
                    "image_height" to originalHeight,
                    "detections" to detections,
                    "model_id" to "e4",
                    "model_label" to "YOLO26-S — E4 (nhóm đề xuất)",
                    "latency_ms" to latencyMs,
                    "device" to "Android ${Build.MANUFACTURER} ${Build.MODEL} CPU • ONNX Runtime",
                    "latency_scope" to "decode + letterbox + inference + postprocess trên thiết bị",
                )
            } finally {
                letterboxed.recycle()
            }
        } finally {
            original.recycle()
        }
    }

    private fun decodeOrientedBitmap(imagePath: String): Bitmap {
        val bitmap = BitmapFactory.decodeFile(imagePath)
            ?: error("Tệp được chọn không phải ảnh hợp lệ.")
        val orientation = try {
            ExifInterface(imagePath).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        } catch (_: Exception) {
            ExifInterface.ORIENTATION_NORMAL
        }
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.setScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.setRotate(90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.setRotate(-90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.setRotate(-90f)
        }
        if (matrix.isIdentity) return bitmap

        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            .also { bitmap.recycle() }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            val language = textToSpeech?.setLanguage(Locale.US)
            ttsReady = language != null && language >= TextToSpeech.LANG_AVAILABLE
            textToSpeech?.setSpeechRate(0.8f)
            textToSpeech?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(id: String?) { audioHandler.post { updateGameVolume() } }
                private fun finish(id: String?) {
                    audioHandler.post {
                        if (spokenId == id) { spokenId = null; updateGameVolume() }
                    }
                }
                override fun onDone(id: String?) = finish(id)
                @Deprecated("Deprecated in Java")
                override fun onError(id: String?) = finish(id)
                override fun onError(id: String?, errorCode: Int) = finish(id)
                override fun onStop(id: String?, interrupted: Boolean) = finish(id)
            })
        }
    }

    override fun onDestroy() {
        stopGameAudio()
        gameSounds.release()
        inferenceExecutor.shutdownNow()
        e4Session?.close()
        e4Session = null
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        super.onDestroy()
    }

    companion object {
        private const val INPUT_SIZE = 512
        private const val SECURE_PREFS = "vocab_vision_secure"
        private const val SECURE_KEY_ALIAS = "vocab_vision_auth_v1"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_NONCE_BYTES = 12
        private const val GCM_TAG_BITS = 128
        private const val E4_ONNX_SHA256 =
            "0256115f2e4339527b665c0fd22ed5c4961aac2539b7889bb9ac297588a61e66"
        private val CLASS_NAMES = arrayOf(
            "abacus",
            "backpack",
            "chalk",
            "chalkboard",
            "crayon",
            "cup",
            "eraser",
            "glue_stick",
            "kids_chair",
            "notebook",
            "paintbrush",
            "pencil",
            "pencil_sharpener",
            "ruler",
            "scissors",
        )
    }
}
