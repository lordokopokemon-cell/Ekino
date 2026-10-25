#!/bin/bash
set -e

# 1. Aktualizacja EkinoScraper (dodanie Horrorów, Komedii, Familijnych oraz Wyszukiwarki)
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

        val elements = doc.select("a[href*=/movie/show/], div#posters a")

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

    private suspend fun fetchPage(path: String): List<MovieItem> = withContext(Dispatchers.IO) {
        try {
            val doc = Jsoup.connect("$baseUrl$path")
                .userAgent(SessionManager.userAgent)
                .header("Referer", "https://ekino.ws/")
                .timeout(15000)
                .get()
            parseMovies(doc)
        } catch (e: Exception) {
            e.printStackTrace()
            emptyList()
        }
    }

    suspend fun getFeatured(): List<MovieItem> = withContext(Dispatchers.IO) {
        val items = fetchPage("")
        if (items.isNotEmpty()) items.take(12) else emptyList()
    }

    suspend fun getLatestMovies(): List<MovieItem> = fetchPage("/movie/cat/+")
    suspend fun getHorrorMovies(): List<MovieItem> = fetchPage("/movie/cat/kategoria%5B15%5D")
    suspend fun getComedyMovies(): List<MovieItem> = fetchPage("/movie/cat/kategoria%5B17%5D")
    suspend fun getFamilyMovies(): List<MovieItem> = fetchPage("/movie/cat/kategoria%5B12%5D")
    suspend fun get4kMovies(): List<MovieItem> = fetchPage("/movie/cat/kategoria%5B36%5D")

    suspend fun searchMovies(query: String): List<MovieItem> = withContext(Dispatchers.IO) {
        try {
            val doc = Jsoup.connect("$baseUrl/search/qf")
                .data("q", query)
                .userAgent(SessionManager.userAgent)
                .header("Referer", "https://ekino.ws/")
                .timeout(15000)
                .post()
            parseMovies(doc)
        } catch (e: Exception) {
            e.printStackTrace()
            emptyList()
        }
    }
}
FILE

# 2. Utworzenie SearchFragment.kt (Ekran wyszukiwarki Leanback)
cat << 'FILE' > app/src/main/java/com/ekinotv/app/ui/SearchFragment.kt
package com.ekinotv.app.ui

import android.os.Bundle
import androidx.leanback.app.SearchSupportFragment
import androidx.leanback.widget.ArrayObjectAdapter
import androidx.leanback.widget.HeaderItem
import androidx.leanback.widget.ListRow
import androidx.leanback.widget.ListRowPresenter
import androidx.leanback.widget.ObjectAdapter
import androidx.lifecycle.lifecycleScope
import com.ekinotv.app.data.EkinoScraper
import com.ekinotv.app.data.MovieItem
import com.ekinotv.app.player.PlaybackRouter
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class SearchFragment : SearchSupportFragment(), SearchSupportFragment.SearchResultProvider {

    private val scraper = EkinoScraper()
    private val rowsAdapter = ArrayObjectAdapter(ListRowPresenter())
    private var searchJob: Job? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setSearchResultProvider(this)

        setOnItemViewClickedListener { _, item, _, _ ->
            if (item is MovieItem) {
                PlaybackRouter.playMovie(requireContext(), item)
            }
        }
    }

    override fun getResultsAdapter(): ObjectAdapter = rowsAdapter

    override fun onQueryTextChange(newQuery: String?): Boolean {
        val query = newQuery?.trim().orEmpty()
        if (query.length >= 3) {
            executeSearch(query)
        }
        return true
    }

    override fun onQueryTextSubmit(query: String?): Boolean {
        val q = query?.trim().orEmpty()
        if (q.isNotEmpty()) {
            executeSearch(q)
        }
        return true
    }

    private fun executeSearch(query: String) {
        searchJob?.cancel()
        searchJob = lifecycleScope.launch {
            delay(400)
            val results = scraper.searchMovies(query)
            rowsAdapter.clear()
            if (results.isNotEmpty()) {
                val cardPresenter = CardPresenter()
                val listRowAdapter = ArrayObjectAdapter(cardPresenter).apply {
                    addAll(0, results)
                }
                rowsAdapter.add(ListRow(HeaderItem(0, "Wyniki dla: \"$query\""), listRowAdapter))
            }
        }
    }
}
FILE

# 3. Utworzenie SearchActivity.kt
cat << 'FILE' > app/src/main/java/com/ekinotv/app/ui/SearchActivity.kt
package com.ekinotv.app.ui

import android.os.Bundle
import androidx.fragment.app.FragmentActivity

class SearchActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            supportFragmentManager.beginTransaction()
                .replace(android.R.id.content, SearchFragment())
                .commitNow()
        }
    }
}
FILE

# 4. Aktualizacja MainFragment.kt z 6 rzędami i podpiętą lupą
cat << 'FILE' > app/src/main/java/com/ekinotv/app/ui/MainFragment.kt
package com.ekinotv.app.ui

import android.content.Intent
import android.graphics.Color
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

        searchAffordanceColor = Color.parseColor("#E50914")
        setOnSearchClickedListener {
            val intent = Intent(requireContext(), SearchActivity::class.java)
            startActivity(intent)
        }

        setupEventListeners()
        loadCategories()
    }

    private fun loadCategories() {
        lifecycleScope.launch {
            val cardPresenter = CardPresenter()

            val featuredDeferred = async { scraper.getFeatured() }
            val latestDeferred = async { scraper.getLatestMovies() }
            val horrorDeferred = async { scraper.getHorrorMovies() }
            val comedyDeferred = async { scraper.getComedyMovies() }
            val familyDeferred = async { scraper.getFamilyMovies() }
            val fourKDeferred = async { scraper.get4kMovies() }

            val featured = featuredDeferred.await()
            if (featured.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, featured) }
                rowsAdapter.add(ListRow(HeaderItem(0, "Hity i Polecane"), rowAdapter))
            }

            val latest = latestDeferred.await()
            if (latest.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, latest) }
                rowsAdapter.add(ListRow(HeaderItem(1, "Najnowsze Filmy"), rowAdapter))
            }

            val horrors = horrorDeferred.await()
            if (horrors.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, horrors) }
                rowsAdapter.add(ListRow(HeaderItem(2, "Horrory"), rowAdapter))
            }

            val comedies = comedyDeferred.await()
            if (comedies.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, comedies) }
                rowsAdapter.add(ListRow(HeaderItem(3, "Komedie"), rowAdapter))
            }

            val family = familyDeferred.await()
            if (family.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, family) }
                rowsAdapter.add(ListRow(HeaderItem(4, "Dla Dzieci i Rodziny"), rowAdapter))
            }

            val fourK = fourKDeferred.await()
            if (fourK.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, fourK) }
                rowsAdapter.add(ListRow(HeaderItem(5, "Filmy 4K Ultra HD"), rowAdapter))
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

# 5. Aktualizacja AndroidManifest.xml (rejestracja SearchActivity)
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
            android:name=".ui.SearchActivity"
            android:exported="false"
            android:screenOrientation="landscape"
            android:configChanges="keyboard|keyboardHidden|navigation|orientation|screenSize" />
        
        <activity
            android:name=".player.PlayerActivity"
            android:exported="false"
            android:screenOrientation="landscape"
            android:configChanges="keyboard|keyboardHidden|navigation|orientation|screenSize"/>
    </application>
</manifest>
FILE

# 6. Wypchnięcie zmian do GitHuba
git add .
git commit -m "Dodanie kategorii Horror, Komedia, Familijne i wyszukiwarki"
git push origin main
rm update_genres_and_search.sh
echo "Wypchnięte! Nowy build z kategoriami i szukajką w toku."
