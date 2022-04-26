package com.visioncameraocr

import android.annotation.SuppressLint
import android.content.res.Resources.getSystem
import android.graphics.*
import android.media.Image
import android.util.Log
import androidx.camera.core.ImageProxy
import com.facebook.react.bridge.ReadableNativeMap
import com.facebook.react.bridge.WritableNativeArray
import com.facebook.react.bridge.WritableNativeMap
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.common.internal.ImageConvertUtils
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.mrousavy.camera.frameprocessor.FrameProcessorPlugin
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

class OCRFrameProcessorPlugin : FrameProcessorPlugin("scanOCR") {

    private fun getBlockArray(blocks: MutableList<Text.TextBlock>): WritableNativeArray {
        val blockArray = WritableNativeArray()

        for (block in blocks) {
            val blockMap = WritableNativeMap()

            blockMap.putString("text", block.text)
            blockMap.putArray(
                "recognizedLanguages",
                getRecognizedLanguages(block.recognizedLanguage)
            )
            blockMap.putArray("cornerPoints", block.cornerPoints?.let { getCornerPoints(it) })
            blockMap.putMap("frame", getFrame(block.boundingBox))
            blockMap.putArray("lines", getLineArray(block.lines))

            blockArray.pushMap(blockMap)
        }
        return blockArray
    }

    private fun getLineArray(lines: MutableList<Text.Line>): WritableNativeArray {
        val lineArray = WritableNativeArray()

        for (line in lines) {
            val lineMap = WritableNativeMap()

            lineMap.putString("text", line.text)
            lineMap.putArray("recognizedLanguages", getRecognizedLanguages(line.recognizedLanguage))
            lineMap.putArray("cornerPoints", line.cornerPoints?.let { getCornerPoints(it) })
            lineMap.putMap("frame", getFrame(line.boundingBox))
            lineMap.putArray("elements", getElementArray(line.elements))

            lineArray.pushMap(lineMap)
        }
        return lineArray
    }

    private fun getElementArray(elements: MutableList<Text.Element>): WritableNativeArray {
        val elementArray = WritableNativeArray()

        for (element in elements) {
            val elementMap = WritableNativeMap()

            elementMap.putString("text", element.text)
            elementMap.putArray("cornerPoints", element.cornerPoints?.let { getCornerPoints(it) })
            elementMap.putMap("frame", getFrame(element.boundingBox))
        }
        return elementArray
    }

    private fun getRecognizedLanguages(recognizedLanguage: String): WritableNativeArray {
        val recognizedLanguages = WritableNativeArray()
        recognizedLanguages.pushString(recognizedLanguage)
        return recognizedLanguages
    }

    private fun getCornerPoints(points: Array<Point>): WritableNativeArray {
        val cornerPoints = WritableNativeArray()

        for (point in points) {
            val pointMap = WritableNativeMap()
            pointMap.putInt("x", point.x)
            pointMap.putInt("y", point.y)
            cornerPoints.pushMap(pointMap)
        }
        return cornerPoints
    }

    private fun getFrame(boundingBox: Rect?): WritableNativeMap {
        val frame = WritableNativeMap()

        if (boundingBox != null) {
            frame.putDouble("x", boundingBox.exactCenterX().toDouble())
            frame.putDouble("y", boundingBox.exactCenterY().toDouble())
            frame.putInt("width", boundingBox.width())
            frame.putInt("height", boundingBox.height())
            frame.putInt("boundingCenterX", boundingBox.centerX())
            frame.putInt("boundingCenterY", boundingBox.centerY())
        }
        return frame
    }

    override fun callback(frame: ImageProxy, params: Array<Any>): Any? {

        val result = WritableNativeMap()
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

        @SuppressLint("UnsafeOptInUsageError")
        val mediaImage: Image? = frame.image

        if (mediaImage != null) {
            val inputImage = InputImage.fromMediaImage(mediaImage, frame.imageInfo.rotationDegrees)
            var bitmap = ImageConvertUtils.getInstance().getUpRightBitmap(inputImage)

            val realBitmapWidth = bitmap.width
            val realBitmapHeight = bitmap.height
            val previewSize = params[0] as ReadableNativeMap
            val captureSize = params[1] as ReadableNativeMap
            val previewWidth = previewSize.getDouble("width")
            val previewHeight = previewSize.getDouble("height")
            val captureWidth = captureSize.getDouble("width")
            val captureHeight = captureSize.getDouble("height")

            val scaleWidth = captureWidth / previewWidth
            val widthImage = bitmap.width * scaleWidth
            val aspecRatioCaptureView = captureHeight / captureWidth
            val heightImage = widthImage * aspecRatioCaptureView
            val originXImage = (bitmap.width - widthImage) / 2
            val originYImage = (bitmap.height - heightImage) / 2
            /// rect = CGRect (x: originXImage, y: originYImage, width: widthImage, height: heightImage)

            // capture bitmap
            bitmap = Bitmap.createBitmap(bitmap, originXImage.toInt(), originYImage.toInt(), widthImage.toInt(), heightImage.toInt())

            val image = InputImage.fromBitmap(bitmap, 0) /// Because before real rotate
            val task: Task<Text> = recognizer.process(image)
            try {
                val text: Text = Tasks.await<Text>(task)
                result.putString("text", text.text)
                result.putArray("blocks", getBlockArray(text.textBlocks))
                result.putDouble("xAxis", originXImage)
                result.putDouble("yAxis", originYImage)
                result.putDouble("frameWidth", realBitmapWidth.toDouble())
                result.putDouble("frameHeight", realBitmapHeight.toDouble())
            } catch (e: Exception) {
                return null
            }
        }

        val data = WritableNativeMap()
        data.putMap("result", result)
        return data
    }

}

