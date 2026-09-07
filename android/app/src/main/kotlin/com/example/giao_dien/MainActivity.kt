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
import android.os.Build
import android.os.SystemClock
import android.speech.tts.TextToSpeech
import androidx.exifinterface.media.ExifInterface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Locale
import java.util.concurrent.Executors
import kotlin.math.min
import kotlin.math.roundToInt

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private var textToSpeech: TextToSpeech? = null
    private val inferenceExecutor = Executors.newSingleThreadExecutor()
    private val ortEnvironment: OrtEnvironment by lazy { OrtEnvironment.getEnvironment() }

    @Volatile
    private var e4Session: OrtSession? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        textToSpeech = TextToSpeech(this, this)
        configureTextToSpeech(flutterEngine)
        configureOfflineE4(flutterEngine)
    }

    private fun configureTextToSpeech(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vocab_vision/tts")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        val text = call.argument<String>("text")
                        if (text.isNullOrBlank()) {
                            result.error("EMPTY_TEXT", "Không có từ để phát âm", null)
                        } else {
                            val status = textToSpeech?.speak(
                                text,
                                TextToSpeech.QUEUE_FLUSH,
                                null,
                                "vocab-word",
                            )
                            if (status == TextToSpeech.ERROR) {
                                result.error("TTS_ERROR", "Không thể phát âm", null)
                            } else {
                                result.success(null)
                            }
                        }
                    }

                    "stop" -> {
                        textToSpeech?.stop()
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
            textToSpeech?.language = Locale.US
            textToSpeech?.setSpeechRate(0.8f)
        }
    }

    override fun onDestroy() {
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
