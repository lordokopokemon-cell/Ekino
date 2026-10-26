#!/bin/bash
set -e

# 1. Modele danych MovieDetails oraz PlayerSource
cat << 'FILE' > app/src/main/java/com/ekinotv/app/data/MovieDetails.kt
package com.ekinotv.app.data

import java.io.Serializable

data class PlayerSource(
    val host: String,
    val id: String,
    val version: String,
    val watchUrl: String
) : Serializable

data class MovieDetails(
    val title: String,
    val originalTitle: String,
    val description: String,
    val posterUrl: String,
    val pageUrl: String,
    val sources: List<PlayerSource>
) : Serializable
FILE

# 2. Rozbudowa EkinoScraper o metodę getMovieDetails
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

        val listItems = doc.select(".movies-list-item")
        for (item in listItems) {
            val titleElem = item.selectFirst(".title a") ?: item.selectFirst(".title")
            val linkElem = item.selectFirst(".cover-list a") ?: item.selectFirst("a[href*=/movie/show/], a[href*=/serie/show/], a[href*=/series/show/]")
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

        val elements = doc.select("#posters a, a[href*=/movie/show/], a[href*=/serie/show/], a[href*=/series/show/]")
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
    suspend fun getHorrorMovies(): List<MovieItem> = fetchPage("/movie/cat/kategoria%5B15%5D")
    suspend fun getComedyMovies(): List<MovieItem> = fetchPage("/movie/cat/kategoria%5B17%5D")
    suspend fun getFamilyMovies(): List<MovieItem> = fetchPage("/movie/cat/kategoria%5B12%5D")
    suspend fun get4kMovies(): List<MovieItem> = fetchPage("/movie/cat/kategoria%5B36%5D")

    suspend fun getSeries(): List<MovieItem> = withContext(Dispatchers.IO) {
        val candidates = listOf("/serie/cat/+", "/series/cat/+", "/seriale/cat/+", "/serie")
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

    suspend fun getFilteredMovies(
        type: String = "movie",
        genreId: String = "",
        version: String = "",
        year: String = ""
    ): List<MovieItem> = withContext(Dispatchers.IO) {
        val parts = mutableListOf<String>()
        if (genreId.isNotEmpty()) parts.add("kategoria%5B$genreId%5D")
        if (version.isNotEmpty()) parts.add("wersja%5B$version%5D")
        if (year.isNotEmpty()) parts.add("rok%5B$year%5D")

        val queryPart = if (parts.isNotEmpty()) parts.joinToString("+") + "+" else "+"
        val path = "/$type/cat/$queryPart"
        fetchPage(path)
    }

    // Pobieranie pełnych szczegółów filmu i źródeł odtwarzaczy
    suspend fun getMovieDetails(pageUrl: String): MovieDetails? = withContext(Dispatchers.IO) {
        try {
            val doc = Jsoup.connect(pageUrl)
                .userAgent(SessionManager.userAgent)
                .header("Referer", "https://ekino.ws/")
                .timeout(15000)
                .get()

            val title = doc.selectFirst("h1.title")?.text()?.trim().orEmpty()
            val origTitle = doc.selectFirst("h2.title")?.text()?.trim().orEmpty()
            val description = doc.selectFirst(".descriptionMovie")?.text()?.trim().orEmpty()
            val poster = doc.selectFirst(".img-shadow img, .cover-list img, div#posters img")?.attr("src").orEmpty()
            val fullPoster = if (poster.isNotEmpty()) (if (poster.startsWith("http")) poster else "$baseUrl$poster") else ""

            val sources = mutableListOf<PlayerSource>()
            val tabs = doc.select("#myTab li")

            for (tab in tabs) {
                val link = tab.selectFirst("a") ?: continue
                val targetPaneId = link.attr("href").removePrefix("#").trim()
                if (targetPaneId.isEmpty()) continue

                val version = tab.select("i[title]").attr("title").ifEmpty {
                    tab.select("img[title]").attr("title")
                }.ifEmpty { "Domyślna" }

                val pane = doc.getElementById(targetPaneId)
                val onclick = pane?.selectFirst("a[onClick*='ShowPlayer']")?.attr("onClick").orEmpty()

                val match = Regex("""ShowPlayer\s*\(\s*'([^']+)'\s*,\s*'([^']+)'\s*\)""").find(onclick)
                if (match != null) {
                    val host = match.groupValues[1]
                    val pid = match.groupValues[2]
                    val watchUrl = "$baseUrl/watch/f/$host/$pid"
                    sources.add(
                        PlayerSource(
                            host = host.uppercase(),
                            id = pid,
                            version = version,
                            watchUrl = watchUrl
                        )
                    )
                }
            }

            MovieDetails(
                title = title,
                originalTitle = origTitle,
                description = description,
                posterUrl = fullPoster,
                pageUrl = pageUrl,
                sources = sources
            )
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
FILE

# 3. Aktualizacja PlaybackRouter z metodą openSource
cat << 'FILE' > app/src/main/java/com/ekinotv/app/player/PlaybackRouter.kt
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
FILE

# 4. Presenter opisu filmu dla Leanback
cat << 'FILE' > app/src/main/java/com/ekinotv/app/ui/MovieDetailsDescriptionPresenter.kt
package com.ekinotv.app.ui

import androidx.leanback.widget.AbstractDetailsDescriptionPresenter
import com.ekinotv.app.data.MovieDetails

class MovieDetailsDescriptionPresenter : AbstractDetailsDescriptionPresenter() {
    override fun onBindDescription(vh: ViewHolder, item: Any) {
        val details = item as MovieDetails
        vh.title.text = details.title
        vh.subtitle.text = details.originalTitle
        vh.body.text = details.description
    }
}
FILE

# 5. Tworzenie ekranu szczegółów (DetailsSupportFragment & DetailsActivity)
cat << 'FILE' > app/src/main/java/com/ekinotv/app/ui/DetailsActivity.kt
package com.ekinotv.app.ui

import android.graphics.Color
import android.os.Bundle
import android.widget.Toast
import androidx.fragment.app.FragmentActivity
import androidx.leanback.app.DetailsSupportFragment
import androidx.leanback.widget.*
import androidx.lifecycle.lifecycleScope
import coil.Coil
import coil.request.ImageRequest
import coil.request.SuccessResult
import com.ekinotv.app.data.EkinoScraper
import com.ekinotv.app.data.MovieDetails
import com.ekinotv.app.player.PlaybackRouter
import kotlinx.coroutines.launch

class DetailsActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            supportFragmentManager.beginTransaction()
                .replace(android.R.id.content, MovieDetailsFragment())
                .commitNow()
        }
    }
}

class MovieDetailsFragment : DetailsSupportFragment() {

    private val scraper = EkinoScraper()
    private val rowsAdapter = ArrayObjectAdapter(ClassPresenterSelector())
    private lateinit var detailsPresenter: FullWidthDetailsOverviewRowPresenter

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        detailsPresenter = FullWidthDetailsOverviewRowPresenter(MovieDetailsDescriptionPresenter()).apply {
            backgroundColor = Color.parseColor("#1B222C")
            initialState = FullWidthDetailsOverviewRowPresenter.STATE_FULL
        }

        (rowsAdapter.presenterSelector as ClassPresenterSelector).addClassPresenter(
            DetailsOverviewRow::class.java,
            detailsPresenter
        )
        adapter = rowsAdapter

        loadData()
    }

    private fun loadData() {
        val movieUrl = intentString("MOVIE_URL")
        val initialTitle = intentString("MOVIE_TITLE")
        val initialPoster = intentString("MOVIE_POSTER")

        if (movieUrl.isEmpty()) {
            Toast.makeText(requireContext(), "Błąd: Brak adresu filmu", Toast.LENGTH_SHORT).show()
            activity?.finish()
            return
        }

        // Karta wstępna (ładuje się natychmiast)
        val initialDetails = MovieDetails(
            title = initialTitle,
            originalTitle = "Wczytywanie szczegółów...",
            description = "Trwa pobieranie opisu oraz dostępnych serwerów wideo...",
            posterUrl = initialPoster,
            pageUrl = movieUrl,
            sources = emptyList()
        )
        val detailsRow = DetailsOverviewRow(initialDetails)
        val actionAdapter = ArrayObjectAdapter()
        actionAdapter.add(Action(999L, "Ładowanie źródeł..."))
        detailsRow.actionsAdapter = actionAdapter
        rowsAdapter.add(detailsRow)

        // Załadowanie plakatu z Coil
        lifecycleScope.launch {
            if (initialPoster.isNotEmpty()) {
                val loader = Coil.imageLoader(requireContext())
                val req = ImageRequest.Builder(requireContext())
                    .data(initialPoster)
                    .allowHardware(false)
                    .build()
                val result = (loader.execute(req) as? SuccessResult)?.drawable
                if (result != null) {
                    detailsRow.imageDrawable = result
                }
            }
        }

        // Asynchroniczne pobranie pełnych danych filmu i źródeł
        lifecycleScope.launch {
            val fullDetails = scraper.getMovieDetails(movieUrl)
            if (fullDetails != null) {
                detailsRow.item = fullDetails

                actionAdapter.clear()
                if (fullDetails.sources.isNotEmpty()) {
                    fullDetails.sources.forEachIndexed { index, source ->
                        actionAdapter.add(
                            Action(
                                index.toLong(),
                                "${source.host}  (${source.version})"
                            )
                        )
                    }

                    detailsPresenter.onActionClickedListener = OnActionClickedListener { action ->
                        val idx = action.id.toInt()
                        val selectedSource = fullDetails.sources.getOrNull(idx)
                        if (selectedSource != null) {
                            PlaybackRouter.openSource(requireContext(), selectedSource.watchUrl)
                        }
                    }
                } else {
                    actionAdapter.add(Action(999L, "Brak bezpośrednich odtwarzaczy"))
                    detailsPresenter.onActionClickedListener = OnActionClickedListener {
                        PlaybackRouter.openSource(requireContext(), movieUrl)
                    }
                }
            } else {
                Toast.makeText(requireContext(), "Nie udało się pobrać szczegółów", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun intentString(key: String): String = activity?.intent?.getStringExtra(key).orEmpty()
}
FILE

# 6. Aktualizacja kliknięć kafelków: MainFragment -> DetailsActivity
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
import androidx.leanback.widget.SectionRow
import androidx.lifecycle.lifecycleScope
import com.ekinotv.app.data.EkinoScraper
import com.ekinotv.app.data.MovieItem
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
            startActivity(Intent(requireContext(), SearchActivity::class.java))
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
            val seriesDeferred = async { scraper.getSeries() }

            var headerId = 0L

            rowsAdapter.add(SectionRow(HeaderItem(headerId++, "FILMY")))

            val featured = featuredDeferred.await()
            if (featured.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, featured) }
                rowsAdapter.add(ListRow(HeaderItem(headerId++, "Hity i Polecane"), rowAdapter))
            }

            val latest = latestDeferred.await()
            if (latest.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, latest) }
                rowsAdapter.add(ListRow(HeaderItem(headerId++, "Najnowsze"), rowAdapter))
            }

            val horrors = horrorDeferred.await()
            if (horrors.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, horrors) }
                rowsAdapter.add(ListRow(HeaderItem(headerId++, "Horrory"), rowAdapter))
            }

            val comedies = comedyDeferred.await()
            if (comedies.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, comedies) }
                rowsAdapter.add(ListRow(HeaderItem(headerId++, "Komedie"), rowAdapter))
            }

            val family = familyDeferred.await()
            if (family.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, family) }
                rowsAdapter.add(ListRow(HeaderItem(headerId++, "Dla Dzieci i Rodziny"), rowAdapter))
            }

            val fourK = fourKDeferred.await()
            if (fourK.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, fourK) }
                rowsAdapter.add(ListRow(HeaderItem(headerId++, "4K Ultra HD"), rowAdapter))
            }

            rowsAdapter.add(SectionRow(HeaderItem(headerId++, "SERIALE")))

            val series = seriesDeferred.await()
            if (series.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, series) }
                rowsAdapter.add(ListRow(HeaderItem(headerId++, "Najnowsze Seriale"), rowAdapter))
            }

            rowsAdapter.add(SectionRow(HeaderItem(headerId++, "KATALOG I FILTROWANIE")))
            val filterRowAdapter = ArrayObjectAdapter(cardPresenter).apply {
                add(MovieItem(id = "ACTION_OPEN_FILTER", title = "🎯 Otwórz zaawansowane filtry", posterUrl = "", pageUrl = ""))
            }
            rowsAdapter.add(ListRow(HeaderItem(headerId++, "Wybierz gatunek, wersję i rok"), filterRowAdapter))
        }
    }

    private fun setupEventListeners() {
        onItemViewClickedListener = androidx.leanback.widget.OnItemViewClickedListener { _, item, _, _ ->
            if (item is MovieItem) {
                if (item.id == "ACTION_OPEN_FILTER") {
                    startActivity(Intent(requireContext(), FilterActivity::class.java))
                } else {
                    val intent = Intent(requireContext(), DetailsActivity::class.java).apply {
                        putExtra("MOVIE_TITLE", item.title)
                        putExtra("MOVIE_POSTER", item.posterUrl)
                        putExtra("MOVIE_URL", item.pageUrl)
                    }
                    startActivity(intent)
                }
            }
        }
    }
}
FILE

# 7. Aktualizacja SearchFragment -> DetailsActivity
cat << 'FILE' > app/src/main/java/com/ekinotv/app/ui/SearchFragment.kt
package com.ekinotv.app.ui

import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import androidx.leanback.app.SearchSupportFragment
import androidx.leanback.widget.ArrayObjectAdapter
import androidx.leanback.widget.HeaderItem
import androidx.leanback.widget.ListRow
import androidx.leanback.widget.ListRowPresenter
import androidx.leanback.widget.ObjectAdapter
import androidx.lifecycle.lifecycleScope
import com.ekinotv.app.data.EkinoScraper
import com.ekinotv.app.data.MovieItem
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
                val intent = Intent(requireContext(), DetailsActivity::class.java).apply {
                    putExtra("MOVIE_TITLE", item.title)
                    putExtra("MOVIE_POSTER", item.posterUrl)
                    putExtra("MOVIE_URL", item.pageUrl)
                }
                startActivity(intent)
            }
        }
    }

    override fun getResultsAdapter(): ObjectAdapter = rowsAdapter

    override fun onQueryTextChange(newQuery: String?): Boolean {
        val query = newQuery?.trim().orEmpty()
        if (query.length >= 2) {
            executeSearch(query)
        } else if (query.isEmpty()) {
            rowsAdapter.clear()
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
            delay(350)
            val results = scraper.searchMovies(query)
            rowsAdapter.clear()
            if (results.isNotEmpty()) {
                val cardPresenter = CardPresenter()
                val listRowAdapter = ArrayObjectAdapter(cardPresenter).apply {
                    addAll(0, results)
                }
                rowsAdapter.add(ListRow(HeaderItem(0, "Wyniki wyszukiwania dla: \"$query\" (${results.size})"), listRowAdapter))
            } else {
                Toast.makeText(requireContext(), "Brak wyników dla: $query", Toast.LENGTH_SHORT).show()
            }
        }
    }
}
FILE

# 8. Aktualizacja GridActivity (siatka filtrów) -> DetailsActivity
cat << 'FILE' > app/src/main/java/com/ekinotv/app/ui/GridActivity.kt
package com.ekinotv.app.ui

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.fragment.app.FragmentActivity
import androidx.leanback.app.VerticalGridSupportFragment
import androidx.leanback.widget.ArrayObjectAdapter
import androidx.leanback.widget.FocusHighlight
import androidx.leanback.widget.VerticalGridPresenter
import androidx.lifecycle.lifecycleScope
import com.ekinotv.app.data.EkinoScraper
import com.ekinotv.app.data.MovieItem
import kotlinx.coroutines.launch

class GridActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            supportFragmentManager.beginTransaction()
                .replace(android.R.id.content, GridFragment())
                .commitNow()
        }
    }
}

class GridFragment : VerticalGridSupportFragment() {
    private val scraper = EkinoScraper()
    private val gridAdapter = ArrayObjectAdapter(CardPresenter())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val gridPresenter = VerticalGridPresenter(FocusHighlight.ZOOM_FACTOR_MEDIUM)
        gridPresenter.numberOfColumns = 5
        setGridPresenter(gridPresenter)
        adapter = gridAdapter

        setOnItemViewClickedListener { _, item, _, _ ->
            if (item is MovieItem) {
                val intent = Intent(requireContext(), DetailsActivity::class.java).apply {
                    putExtra("MOVIE_TITLE", item.title)
                    putExtra("MOVIE_POSTER", item.posterUrl)
                    putExtra("MOVIE_URL", item.pageUrl)
                }
                startActivity(intent)
            }
        }
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        val titleExtra = activity?.intent?.getStringExtra("TITLE") ?: "Wyniki filtrów"
        title = titleExtra

        val type = activity?.intent?.getStringExtra("TYPE") ?: "movie"
        val genreId = activity?.intent?.getStringExtra("GENRE_ID") ?: ""
        val version = activity?.intent?.getStringExtra("VERSION") ?: ""
        val year = activity?.intent?.getStringExtra("YEAR") ?: ""

        lifecycleScope.launch {
            val movies = scraper.getFilteredMovies(type, genreId, version, year)
            if (movies.isNotEmpty()) {
                gridAdapter.addAll(0, movies)
            } else {
                Toast.makeText(requireContext(), "Brak wyników dla wybranych kryteriów", Toast.LENGTH_LONG).show()
            }
        }
    }
}
FILE

# 9. Rejestracja DetailsActivity w AndroidManifest.xml
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
            android:name=".ui.FilterActivity"
            android:exported="false"
            android:screenOrientation="landscape"
            android:configChanges="keyboard|keyboardHidden|navigation|orientation|screenSize" />

        <activity
            android:name=".ui.GridActivity"
            android:exported="false"
            android:screenOrientation="landscape"
            android:configChanges="keyboard|keyboardHidden|navigation|orientation|screenSize" />

        <activity
            android:name=".ui.DetailsActivity"
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

# 10. Wypchnięcie całości na GitHub
git add .
git commit -m "Pelny ekran szczegolow (DetailsSupportFragment) z wyborem zrodel i opisem"
git push origin main
rm setup_details_screen.sh
echo "Wypchnięte! Sprawdź Actions na GitHubie."
