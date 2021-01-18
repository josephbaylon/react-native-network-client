package com.mattermost.networkclient.uploads

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactContext
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter


class ProgressListener(private val reactContext: ReactContext) : ProgressListenerInterface {

    override fun emitProgressEvent(progress: Int) {
        val params = Arguments.createMap()
        params.putString("progress", "$progress")
        reactContext.getJSModule(RCTDeviceEventEmitter::class.java).emit("NativeClient-UploadProgress", params)
    }

    override fun update(bytesRead: Long, contentLength: Long) {
        val progress = ((100 * bytesRead) / contentLength).toInt()
        emitProgressEvent(progress)
    }
}

