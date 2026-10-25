#!/bin/bash
set -e

# 1. Aktualizacja SessionManager (dodanie nagłówków User-Agent i Referer dla grafik)
cat << 'FILE' > app/src/main/java/com/ekinotv/app/data/SessionManager.kt
package com.ekinotv.app.data

import okhttp3.Cookie
import okhttp3.CookieJar
import okhttp3.HttpUrl
import okhttp3.OkHttpClient

object SessionManager {
    var isPremiumUser: Boolean = false

    const val userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"

    private val cookieStore = mutableMapOf<String, List<Cookie>>()

    val cookieJar = object : CookieJar {
        override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) {
            cookieStore[url.host] = cookies
        }

        override fun loadForRequest(url: HttpUrl): List<Cookie> {
            return cookieStore[url.host] ?: emptyList()
        }
    }

    val okHttpClient: OkHttpClient = OkHttpClient.Builder()
        .cookieJar(cookieJar)
        .addInterceptor { chain ->
            val request = chain.request().newBuilder()
                .header("User-Agent", userAgent)
                .header("Referer", "https://ekino.ws/")
                .build()
            chain.proceed(request)
        }
        .build()
}
FILE

# 2. Aktualizacja EkinoScraper (właściwe selektory HTML dla ekino.ws)
cat << 'FILE' > app/src/main/java/com/ekinotv/app/data/EkinoScraper.kt
package com.ekinotv.app.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.jsoup.Jsoup

class EkinoScraper {
    private val baseUrl = "https://ekino.ws"

    suspend fun getLatestMovies(): List<MovieItem> = withContext(Dispatchers.IO) {
        val movies = mutableListOf<MovieItem>()
        val seenUrls = mutableSetOf<String>()

        try {
            val doc = Jsoup.connect(baseUrl)
                .userAgent(SessionManager.userAgent)
                .header("Referer", "https://ekino.ws/")
                .timeout(15000)
                .get()

            // Pobieramy wszystkie kafelki filmowe z sekcji plakatów i strony
            val elements = doc.select("a[href*=/movie/show/]")

            for (element in elements) {
                val url = element.attr("href")
                if (url.isEmpty() || seenUrls.contains(url)) continue

                var title = element.attr("title").trim()
                val imgElement = element.selectFirst("img")
                if (title.isEmpty() && imgElement != null) {
                    title = imgElement.attr("alt").trim()
                }

                val img = imgElement?.attr("src") ?: ""

                if (title.isNotEmpty() && img.isNotEmpty()) {
                    seenUrls.add(url)
                    val fullUrl = if (url.startsWith("http")) url else "$baseUrl$url"
                    val fullImg = if (img.startsWith("http")) img else "$baseUrl$img"

                    movies.add(
                        MovieItem(
                            id = url.substringAfterLast("/", url.hashCode().toString()),
                            title = title,
                            posterUrl = fullImg,
                            pageUrl = fullUrl
                        )
                    )
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return@withContext movies
    }
}
FILE

# 3. Aktualizacja MainActivity (podpięcie klienta HTTP pod ładowarkę okładek Coil)
cat << 'FILE' > app/src/main/java/com/ekinotv/app/MainActivity.kt
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
FILE

# 4. Wypchnięcie zmian do GitHuba
git add .
git commit -m "Aktualizacja selektorow ekino.ws i naglowkow Coil"
git push origin main
rm update_scraper.sh
echo "Zaktualizowano scraper! GitHub Actions rozpoczął budowanie nowego APK."
