package com.ekinotv.app.player

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.widget.Toast
import com.ekinotv.app.data.MovieItem
import com.ekinotv.app.data.SessionManager

object PlaybackRouter {
    private const val TV_BRO_PACKAGE = "com.phlox.tvwebbrowser"

    fun playMovie(context: Context, movie: MovieItem) {
        if (SessionManager.isPremiumUser) {
            val intent = Intent(context, PlayerActivity::class.java).apply {
                putExtra("VIDEO_URL", movie.pageUrl)
            }
            context.startActivity(intent)
        } else {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(movie.pageUrl)).apply {
                setPackage(TV_BRO_PACKAGE)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            val packageManager = context.packageManager
            val resolvedActivity = packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)

            if (resolvedActivity != null) {
                context.startActivity(intent)
            } else {
                Toast.makeText(context, "Zainstaluj przeglądarkę TV Bro z Google Play!", Toast.LENGTH_LONG).show()
                val playStoreIntent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$TV_BRO_PACKAGE"))
                context.startActivity(playStoreIntent)
            }
        }
    }
}
