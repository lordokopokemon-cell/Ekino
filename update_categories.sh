#!/bin/bash
set -e

# 1. Poprawka Manifestu (gwarantuje widoczność ikony na Fire OS)
cat << 'FILE' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    
    <uses-feature
        android:name="android.hardware.touchscreen"
        android:required="false" />
    <uses-feature
        android:name="android.software.leanback"
        android:required="false" />

    <queries>
        <package android:name="com.phlox.tvwebbrowser" />
    </queries>

    <application
        android:allowBackup="true"
        android:icon="@drawable/app_banner"
        android:label="eKino"
        android:banner="@drawable/app_banner"
        android:theme="@style/Theme.Leanback"
        android:usesCleartextTraffic="true">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:screenOrientation="landscape">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
                <category android:name="android.intent.category.LEANBACK_LAUNCHER" />
            </intent-filter>
        </activity>
        
        <activity
            android:name=".player.PlayerActivity"
            android:exported="false"
            android:screenOrientation="landscape"
            android:configChanges="keyboard|keyboardHidden|navigation|orientation|screenSize"/>
    </application>
</manifest>
FILE

# 2. Aktualizacja EkinoScraper (wsparcie dla wielu kategorii i podstron)
cat << 'FILE' > app/src/main/java/com/ekinotv/app/data/EkinoScraper.kt
package com.ekinotv.app.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.jsoup.Jsoup
import org.jsoup.nodes.Document

class EkinoScraper {
    private val baseUrl = "https://ekino.ws"

    private fun parseMovies(doc: Document): List<MovieItem> {
        val movies = mutableListOf<MovieItem>()
        val seenUrls = mutableSetOf<String>()

        val elements = doc.select("a[href*=/movie/show/], a[href*=/series/show/], div#posters a")

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
        return movies
    }

    suspend fun getFeatured(): List<MovieItem> = withContext(Dispatchers.IO) {
        try {
            val doc = Jsoup.connect(baseUrl)
                .userAgent(SessionManager.userAgent)
                .header("Referer", "https://ekino.ws/")
                .timeout(15000)
                .get()
            val items = parseMovies(doc)
            if (items.isNotEmpty()) items.take(12) else emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    suspend fun getMovies(): List<MovieItem> = withContext(Dispatchers.IO) {
        try {
            val doc = Jsoup.connect("$baseUrl/movies")
                .userAgent(SessionManager.userAgent)
                .header("Referer", "https://ekino.ws/")
                .timeout(15000)
                .get()
            parseMovies(doc)
        } catch (e: Exception) {
            emptyList()
        }
    }

    suspend fun getSeries(): List<MovieItem> = withContext(Dispatchers.IO) {
        try {
            val doc = Jsoup.connect("$baseUrl/series")
                .userAgent(SessionManager.userAgent)
                .header("Referer", "https://ekino.ws/")
                .timeout(15000)
                .get()
            parseMovies(doc)
        } catch (e: Exception) {
            emptyList()
        }
    }
}
FILE

# 3. Aktualizacja MainFragment (wielorzędowy BrowseSupportFragment z nagłówkami)
cat << 'FILE' > app/src/main/java/com/ekinotv/app/ui/MainFragment.kt
package com.ekinotv.app.ui

import android.os.Bundle
import android.view.View
import androidx.leanback.app.BrowseSupportFragment
import androidx.leanback.widget.ArrayObjectAdapter
import androidx.leanback.widget.HeaderItem
import androidx.leanback.widget.ListRow
import androidx.leanback.widget.ListRowPresenter
import androidx.lifecycle.lifecycleScope
import com.ekinotv.app.data.EkinoScraper
import com.ekinotv.app.data.MovieItem
import com.ekinotv.app.player.PlaybackRouter
import kotlinx.coroutines.async
import kotlinx.coroutines.launch

class MainFragment : BrowseSupportFragment() {

    private val scraper = EkinoScraper()
    private val rowsAdapter = ArrayObjectAdapter(ListRowPresenter())

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        title = "eKino TV"
        headersState = HEADERS_ENABLED
        isHeadersTransitionOnBackEnabled = true
        adapter = rowsAdapter

        setupEventListeners()
        loadCategories()
    }

    private fun loadCategories() {
        lifecycleScope.launch {
            val cardPresenter = CardPresenter()

            // Asynchroniczne pobieranie danych dla wszystkich rzędów
            val featuredDeferred = async { scraper.getFeatured() }
            val moviesDeferred = async { scraper.getMovies() }
            val seriesDeferred = async { scraper.getSeries() }

            val featured = featuredDeferred.await()
            if (featured.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, featured) }
                rowsAdapter.add(ListRow(HeaderItem(0, "Hity i Polecane"), rowAdapter))
            }

            val movies = moviesDeferred.await()
            if (movies.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, movies) }
                rowsAdapter.add(ListRow(HeaderItem(1, "Najnowsze Filmy"), rowAdapter))
            }

            val series = seriesDeferred.await()
            if (series.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, series) }
                rowsAdapter.add(ListRow(HeaderItem(2, "Seriale"), rowAdapter))
            }
        }
    }

    private fun setupEventListeners() {
        onItemViewClickedListener = androidx.leanback.widget.OnItemViewClickedListener { _, item, _, _ ->
            if (item is MovieItem) {
                PlaybackRouter.playMovie(requireContext(), item)
            }
        }
    }
}
FILE

# 4. Wypchnięcie zmian do GitHuba
git add .
git commit -m "Poprawka widocznosci na Fire TV i dodanie wielu kategorii"
git push origin main
rm update_categories.sh
echo "Kod wysłany! GitHub Actions generuje nową paczkę."
