package com.ekinotv.app.player

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import com.ekinotv.app.data.MovieItem

object PlaybackRouter {
    fun openSource(context: Context, watchUrl: String) {
        try {
            val tvBroIntent = Intent(Intent.ACTION_VIEW, Uri.parse(watchUrl)).apply {
                setPackage("com.phlox.tvwebbrowser")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(tvBroIntent)
        } catch (e: Exception) {
            // Fallback: uruchomienie w domyślnej przeglądarce jeśli TV Bro nie jest zainstalowana
            try {
                val genericIntent = Intent(Intent.ACTION_VIEW, Uri.parse(watchUrl)).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(genericIntent)
            } catch (ex: Exception) {
                Toast.makeText(context, "Brak obsługiwanej przeglądarki TV (zainstaluj TV Bro)", Toast.LENGTH_LONG).show()
            }
        }
    }

    fun playMovie(context: Context, movie: MovieItem) {
        openSource(context, movie.pageUrl)
    }
}
