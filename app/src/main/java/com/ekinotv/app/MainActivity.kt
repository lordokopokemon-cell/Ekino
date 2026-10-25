package com.ekinotv.app

import android.os.Bundle
import androidx.fragment.app.FragmentActivity
import coil.Coil
import coil.ImageLoader
import com.ekinotv.app.data.SessionManager
import com.ekinotv.app.ui.MainFragment

class MainActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Przekazanie nagłówków HTTP do biblioteki Coil (omija blokady serwerów z plakatami)
        val imageLoader = ImageLoader.Builder(this)
            .okHttpClient(SessionManager.okHttpClient)
            .build()
        Coil.setImageLoader(imageLoader)

        if (savedInstanceState == null) {
            supportFragmentManager.beginTransaction()
                .replace(android.R.id.content, MainFragment())
                .commitNow()
        }
    }
}
