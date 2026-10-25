#!/bin/bash
set -e

# 1. Rozbudowa EkinoScraper o właściwe kategorie serwisu
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

    // 1. Rząd: Polecane ze strony głównej
    suspend fun getFeatured(): List<MovieItem> = withContext(Dispatchers.IO) {
        val items = fetchPage("")
        if (items.isNotEmpty()) items.take(12) else emptyList()
    }

    // 2. Rząd: Najnowsze dodane filmy (/movie/cat/+)
    suspend fun getLatestMovies(): List<MovieItem> = fetchPage("/movie/cat/+")

    // 3. Rząd: Filmy HD (/movie/cat/kategoria[35])
    suspend fun getHdMovies(): List<MovieItem> = fetchPage("/movie/cat/kategoria%5B35%5D")

    // 4. Rząd: Filmy 4K (/movie/cat/kategoria[36])
    suspend fun get4kMovies(): List<MovieItem> = fetchPage("/movie/cat/kategoria%5B36%5D")
}
FILE

# 2. Aktualizacja MainFragment z 4 rzędami i aktywacją Search Orb
cat << 'FILE' > app/src/main/java/com/ekinotv/app/ui/MainFragment.kt
package com.ekinotv.app.ui

import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.widget.Toast
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

        // Aktywacja ikony wyszukiwarki (Search Orb) w lewym górnym rogu
        searchAffordanceColor = Color.parseColor("#E50914")
        setOnSearchClickedListener {
            Toast.makeText(requireContext(), "Wyszukiwarka zostanie podpięta w następnym kroku", Toast.LENGTH_SHORT).show()
        }

        setupEventListeners()
        loadAllCategories()
    }

    private fun loadAllCategories() {
        lifecycleScope.launch {
            val cardPresenter = CardPresenter()

            // Równoległe pobieranie 4 kategorii z serwera
            val featuredDeferred = async { scraper.getFeatured() }
            val latestDeferred = async { scraper.getLatestMovies() }
            val hdDeferred = async { scraper.getHdMovies() }
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

            val hd = hdDeferred.await()
            if (hd.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, hd) }
                rowsAdapter.add(ListRow(HeaderItem(2, "Filmy w jakości HD"), rowAdapter))
            }

            val fourK = fourKDeferred.await()
            if (fourK.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, fourK) }
                rowsAdapter.add(ListRow(HeaderItem(3, "Filmy 4K Ultra HD"), rowAdapter))
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

# 3. Wypchnięcie zmian do GitHuba
git add .
git commit -m "Pelna obsluga 4 kategorii i Search Orb"
git push origin main
rm update_full_categories.sh
echo "Gotowe! GitHub Actions buduje zaktualizowaną wersję aplikacji."
