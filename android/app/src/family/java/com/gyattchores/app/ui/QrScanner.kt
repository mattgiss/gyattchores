package com.gyattchores.app.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.runtime.Composable
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions

/**
 * Opens the camera to read another phone's "Add a phone" code (ZXing, no Play services). It asks
 * for the camera itself. [onResult] gets the text, or null if they backed out.
 */
@Composable
fun rememberQrScanner(onResult: (String?) -> Unit): () -> Unit {
    val launcher = rememberLauncherForActivityResult(ScanContract()) { onResult(it.contents) }
    return {
        launcher.launch(ScanOptions().setDesiredBarcodeFormats(ScanOptions.QR_CODE)
            .setPrompt("Point the camera at the QR code on the other phone.")
            .setBeepEnabled(false).setOrientationLocked(false))
    }
}
