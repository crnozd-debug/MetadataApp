package com.example.metadata_app

import android.media.MediaMetadataRetriever
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.metadata_app/media"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getMediaMetadata" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARG", "path gerekli", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val retriever = MediaMetadataRetriever()
                            retriever.setDataSource(path)

                            val metadata = mapOf(
                                "title"     to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE) ?: ""),
                                "artist"    to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST) ?: ""),
                                "album"     to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM) ?: ""),
                                "year"      to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_YEAR) ?: ""),
                                "genre"     to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_GENRE) ?: ""),
                                "duration"  to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION) ?: ""),
                                "bitrate"   to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE) ?: ""),
                                "mimeType"  to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE) ?: ""),
                                "width"     to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH) ?: ""),
                                "height"    to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT) ?: ""),
                                "rotation"  to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION) ?: ""),
                                "hasVideo"  to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO) ?: ""),
                                "hasAudio"  to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) ?: ""),
                                "numTracks" to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_NUM_TRACKS) ?: ""),
                                "date"      to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DATE) ?: ""),
                                "location"  to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_LOCATION) ?: ""),
                                "author"    to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_AUTHOR) ?: ""),
                                "composer"  to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_COMPOSER) ?: ""),
                                "albumArtist" to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUMARTIST) ?: ""),
                                "discNumber"  to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DISC_NUMBER) ?: ""),
                                "numTracks2"  to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_NUM_TRACKS) ?: ""),
                            )

                            retriever.release()
                            result.success(metadata)
                        } catch (e: Exception) {
                            result.error("RETRIEVER_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
