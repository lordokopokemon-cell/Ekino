#!/bin/bash
set -e

# 1. Aktualizacja CardPresenter.kt (Wymiary +10% i 2-linijkowy tytuł)
cat << 'FILE' > app/src/main/java/com/ekinotv/app/ui/CardPresenter.kt
package com.ekinotv.app.ui

import android.text.TextUtils
import android.view.ViewGroup
import android.widget.TextView
import androidx.leanback.widget.ImageCardView
import androidx.leanback.widget.Presenter
import coil.load
import com.ekinotv.app.data.MovieItem

class CardPresenter : Presenter() {
    // Powiększenie o 10% (z 200x300 na 220x330)
    private val CARD_WIDTH = 220
    private val CARD_HEIGHT = 330

    override fun onCreateViewHolder(parent: ViewGroup): ViewHolder {
        val cardView = ImageCardView(parent.context).apply {
            isFocusable = true
            isFocusableInTouchMode = true
            setMainImageDimensions(CARD_WIDTH, CARD_HEIGHT)

            // Odblokowanie 2 linijek tekstu dla tytułu
            findViewById<TextView>(androidx.leanback.R.id.title_text)?.apply {
                maxLines = 2
                isSingleLine = false
                ellipsize = TextUtils.TruncateAt.END
            }
        }
        return ViewHolder(cardView)
    }

    override fun onBindViewHolder(viewHolder: ViewHolder, item: Any?) {
        val movie = item as? MovieItem ?: return
        val cardView = viewHolder.view as ImageCardView
        
        cardView.titleText = movie.title
        cardView.contentText = null // Zwolnienie miejsca pod 2 linie tytułu
        
        cardView.mainImageView.load(movie.posterUrl) {
            crossfade(true)
        }
    }

    override fun onUnbindViewHolder(viewHolder: ViewHolder) {
        val cardView = viewHolder.view as ImageCardView
        cardView.badgeImage = null
        cardView.setMainImage(null)
    }
}
FILE

# 2. Aktualizacja EkinoScraper.kt (obsługa seriali i gatunku Akcja)
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

        // Obsługa listy z wyszukiwarki, podstron i kafelków
        val listItems = doc.select(".movies-list-item")
        for (item in listItems) {
            val titleElem = item.selectFirst(".title a") ?: item.selectFirst(".title")
            val linkElem = item.selectFirst(".cover-list a") ?: item.selectFirst("a[href*=/movie/show/], a[href*=/series/show/], a[href*=/serie/show/]")
            val imgElem = item.selectFirst(".cover-list img") ?: item.selectFirst("img")

            val url = linkElem?.attr("href") ?: ""
            val title = titleElem?.text()?.trim().orEmpty()
            val img = imgElem?.attr("src") ?: ""

            if (url.isNotEmpty() && title.isNotEmpty() && img.isNotEmpty() && !seenUrls.contains(url)) {
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

        val elements = doc.select("#posters a, a[href*=/movie/show/], a[href*=/series/show/], a[href*=/serie/show/]")
        for (element in elements) {
            val url = element.attr("href")
            if (url.isEmpty() || seenUrls.contains(url)) continue

            var title = element.attr("title").trim()
            val imgElement = element.selectFirst("img")
            if (title.isEmpty() && imgElement != null) {
                title = imgElement.attr("alt").trim()
            }
            if (title.isEmpty()) {
                title = element.text().trim()
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
            emptyList()
        }
    }

    suspend fun getFeatured(): List<MovieItem> = withContext(Dispatchers.IO) {
        val items = fetchPage("")
        if (items.isNotEmpty()) items.take(12) else emptyList()
    }

    suspend fun getLatestMovies(): List<MovieItem> = fetchPage("/movie/cat/+")
    suspend fun getActionMovies(): List<MovieItem> = fetchPage("/movie/cat/kategoria%5B1%5D")
    suspend fun getHorrorMovies(): List<MovieItem> = fetchPage("/movie/cat/kategoria%5B15%5D")
    suspend fun getComedyMovies(): List<MovieItem> = fetchPage("/movie/cat/kategoria%5B17%5D")
    suspend fun getFamilyMovies(): List<MovieItem> = fetchPage("/movie/cat/kategoria%5B12%5D")
    suspend fun get4kMovies(): List<MovieItem> = fetchPage("/movie/cat/kategoria%5B36%5D")

    // Pobieranie seriali (sprawdza po kolei aktywne adresy serwisu)
    suspend fun getSeries(): List<MovieItem> = withContext(Dispatchers.IO) {
        val candidates = listOf("/serie/cat/+", "/series/cat/+", "/seriale/cat/+", "/serie", "/series")
        for (path in candidates) {
            val res = fetchPage(path)
            if (res.isNotEmpty()) return@withContext res
        }
        emptyList()
    }

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
            emptyList()
        }
    }
}
FILE

# 3. Aktualizacja MainFragment.kt (Podział na Filmy i Seriale w menu)
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

            // Pobieranie równoległe filmów i seriali
            val featuredDeferred = async { scraper.getFeatured() }
            val latestDeferred = async { scraper.getLatestMovies() }
            val actionDeferred = async { scraper.getActionMovies() }
            val horrorDeferred = async { scraper.getHorrorMovies() }
            val comedyDeferred = async { scraper.getComedyMovies() }
            val familyDeferred = async { scraper.getFamilyMovies() }
            val fourKDeferred = async { scraper.get4kMovies() }
            val seriesDeferred = async { scraper.getSeries() }

            var headerId = 0L

            // --- SEKCJA: FILMY ---
            val featured = featuredDeferred.await()
            if (featured.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, featured) }
                rowsAdapter.add(ListRow(HeaderItem(headerId++, "🎬 Filmy: Hity i Polecane"), rowAdapter))
            }

            val latest = latestDeferred.await()
            if (latest.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, latest) }
                rowsAdapter.add(ListRow(HeaderItem(headerId++, "🎬 Filmy: Najnowsze"), rowAdapter))
            }

            val action = actionDeferred.await()
            if (action.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, action) }
                rowsAdapter.add(ListRow(HeaderItem(headerId++, "🎬 Filmy: Akcja"), rowAdapter))
            }

            val horrors = horrorDeferred.await()
            if (horrors.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, horrors) }
                rowsAdapter.add(ListRow(HeaderItem(headerId++, "🎬 Filmy: Horrory"), rowAdapter))
            }

            val comedies = comedyDeferred.await()
            if (comedies.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, comedies) }
                rowsAdapter.add(ListRow(HeaderItem(headerId++, "🎬 Filmy: Komedie"), rowAdapter))
            }

            val family = familyDeferred.await()
            if (family.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, family) }
                rowsAdapter.add(ListRow(HeaderItem(headerId++, "🎬 Filmy: Dla Dzieci i Rodziny"), rowAdapter))
            }

            val fourK = fourKDeferred.await()
            if (fourK.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, fourK) }
                rowsAdapter.add(ListRow(HeaderItem(headerId++, "🎬 Filmy: 4K Ultra HD"), rowAdapter))
            }

            // --- SEKCJA: SERIALE ---
            val series = seriesDeferred.await()
            if (series.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, series) }
                rowsAdapter.add(ListRow(HeaderItem(headerId++, "📺 Seriale: Najnowsze"), rowAdapter))
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

# 4. Wypchnięcie zmian
git add .
git commit -m "Powiekszenie plakatow o 10%, 2 linie tytulu oraz sekcja Seriale"
git push origin main
rm update_ui_and_series.sh
echo "Wypchnięte! GitHub Actions buduje nową wersję."
