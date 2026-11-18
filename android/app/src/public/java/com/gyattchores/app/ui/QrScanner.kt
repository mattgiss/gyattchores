package com.gyattchores.app.ui

import androidx.compose.runtime.Composable

/** The public edition has no camera code: joining another phone comes with the encrypted relay there later. */
@Composable
fun rememberQrScanner(onResult: (String?) -> Unit): () -> Unit = { onResult(null) }
