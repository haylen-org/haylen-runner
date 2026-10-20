package com.haylen.plugins.qrscanner

import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import dev.haylen.HaylenBridge
import dev.haylen.HaylenPermission
import dev.haylen.HaylenPlugin
import dev.haylen.HaylenPluginContext
import org.json.JSONObject

// Native part of the QR Scanner plugin on Android, which shows the code scanner of Google Play services until it reads a QR code. The scanner brings its own screen and needs no camera permission of the app, so the permission `camera` of the plugin names no permission of the manifest and is always granted. The `haylen` library creates the class from the `meta-data` of its manifest, and loads it when the app process starts.
class QrScannerPlugin : HaylenPlugin() {
    override fun onLoad(context: HaylenPluginContext) {
        context.registerPermission(HaylenPermission("camera", "the camera"))
        context.register("scan") { _, reply ->
            val activity = context.activity() ?: throw HaylenBridge.Failure("The app has no activity yet.", "noWindow", null)
            val options = GmsBarcodeScannerOptions.Builder().setBarcodeFormats(Barcode.FORMAT_QR_CODE).build()
            context.coverApp()
            GmsBarcodeScanning.getClient(activity, options).startScan()
                .addOnSuccessListener { code ->
                    context.uncoverApp()
                    reply.success(JSONObject().put("text", code.rawValue ?: ""))
                }
                .addOnCanceledListener {
                    context.uncoverApp()
                    reply.failure("The scan was cancelled.", "cancelled", null)
                }
                .addOnFailureListener { error ->
                    context.uncoverApp()
                    reply.failure("This device cannot scan codes: ${error.message}", "unsupported", null)
                }
        }
    }
}
