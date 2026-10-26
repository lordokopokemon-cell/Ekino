#!/bin/bash
set -e

# 1. Rozbudowa EkinoScraper o metodę getFilteredMovies
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

    // Zaawansowany silnik filtrów
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
}
FILE

# 2. CardPresenter - obsługa kafelka filtrów
cat << 'FILE' > app/src/main/java/com/ekinotv/app/ui/CardPresenter.kt
package com.ekinotv.app.ui

import android.text.TextUtils
import android.view.ViewGroup
import android.widget.TextView
import androidx.leanback.widget.ImageCardView
import androidx.leanback.widget.Presenter
import coil.load
import com.ekinotv.app.R
import com.ekinotv.app.data.MovieItem

class CardPresenter : Presenter() {
    private val CARD_WIDTH = 220
    private val CARD_HEIGHT = 330

    override fun onCreateViewHolder(parent: ViewGroup): ViewHolder {
        val cardView = ImageCardView(parent.context).apply {
            isFocusable = true
            isFocusableInTouchMode = true
            setMainImageDimensions(CARD_WIDTH, CARD_HEIGHT)

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

        if (movie.id == "ACTION_OPEN_FILTER") {
            cardView.contentText = "Gatunek • Lektor • Rok"
            cardView.mainImageView.setImageResource(R.drawable.app_banner)
            return
        }

        cardView.contentText = null
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

# 3. Ekran kreatora filtrów (GuidedStepSupportFragment)
cat << 'FILE' > app/src/main/java/com/ekinotv/app/ui/FilterActivity.kt
package com.ekinotv.app.ui

import android.content.Intent
import android.os.Bundle
import androidx.fragment.app.FragmentActivity
import androidx.leanback.app.GuidedStepSupportFragment
import androidx.leanback.widget.GuidanceStylist
import androidx.leanback.widget.GuidedAction

class FilterActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            GuidedStepSupportFragment.addAsRoot(this, FilterStepFragment(), android.R.id.content)
        }
    }
}

class FilterStepFragment : GuidedStepSupportFragment() {

    private var selectedType = "movie"
    private var selectedTypeName = "Filmy"

    private var selectedGenreId = ""
    private var selectedGenreName = "Wszystkie"

    private var selectedVersion = ""
    private var selectedVersionName = "Dowolna"

    private var selectedYear = ""
    private var selectedYearName = "Dowolny"

    companion object {
        private const val ACTION_TYPE = 1L
        private const val ACTION_GENRE = 2L
        private const val ACTION_VERSION = 3L
        private const val ACTION_YEAR = 4L
        private const val ACTION_SUBMIT = 5L

        private const val OFFSET_TYPE = 100L
        private const val OFFSET_GENRE = 200L
        private const val OFFSET_VERSION = 300L
        private const val OFFSET_YEAR = 400L
    }

    private val genres = listOf(
        "Wszystkie" to "",
        "Akcja" to "1",
        "Animacja" to "2",
        "Baśń" to "3",
        "Biograficzny" to "4",
        "Dla dzieci" to "5",
        "Dla młodzieży" to "6",
        "Dokumentalny" to "8",
        "Dramat" to "9",
        "Familijny" to "12",
        "Fantasy" to "13",
        "Historyczny" to "14",
        "Horror" to "15",
        "Katastroficzny" to "16",
        "Komedia" to "17",
        "Kostiumowy" to "18",
        "Kryminał" to "19",
        "Melodramat" to "20",
        "Musical" to "21",
        "Muzyczny" to "22",
        "Przygodowy" to "23",
        "Przyrodniczy" to "24",
        "Psychologiczny" to "25",
        "Romans" to "26",
        "Sci-fi" to "28",
        "Sensacyjny" to "29",
        "Sportowy" to "30",
        "Thriller" to "31",
        "Western" to "32",
        "Wojenny" to "33",
        "HD" to "35",
        "4K / FHD" to "36"
    )

    private val versions = listOf(
        "Dowolna wersja" to "",
        "Lektor" to "Lektor",
        "Dubbing" to "Dubbing",
        "Napisy PL" to "Napisy",
        "Film polski" to "PL",
        "Oryginał (ENG)" to "ENG"
    )

    private val years = listOf("Dowolny rok" to "") + (2026 downTo 2010).map { it.toString() to it.toString() }

    override fun onCreateGuidance(savedInstanceState: Bundle?): GuidanceStylist.Guidance {
        return GuidanceStylist.Guidance(
            "Filtrowanie bazy",
            "Wybierz kryteria i zatwierdź przyciskiem na dole",
            "eKino TV",
            null
        )
    }

    override fun onCreateActions(actions: MutableList<GuidedAction>, savedInstanceState: Bundle?) {
        val typeSubActions = listOf(
            GuidedAction.Builder(context).id(OFFSET_TYPE + 0).title("Filmy").build(),
            GuidedAction.Builder(context).id(OFFSET_TYPE + 1).title("Seriale").build()
        )
        actions.add(
            GuidedAction.Builder(context)
                .id(ACTION_TYPE)
                .title("Rodzaj")
                .description(selectedTypeName)
                .subActions(typeSubActions)
                .build()
        )

        val genreSubActions = genres.mapIndexed { idx, pair ->
            GuidedAction.Builder(context).id(OFFSET_GENRE + idx).title(pair.first).build()
        }
        actions.add(
            GuidedAction.Builder(context)
                .id(ACTION_GENRE)
                .title("Gatunek")
                .description(selectedGenreName)
                .subActions(genreSubActions)
                .build()
        )

        val versionSubActions = versions.mapIndexed { idx, pair ->
            GuidedAction.Builder(context).id(OFFSET_VERSION + idx).title(pair.first).build()
        }
        actions.add(
            GuidedAction.Builder(context)
                .id(ACTION_VERSION)
                .title("Wersja językowa")
                .description(selectedVersionName)
                .subActions(versionSubActions)
                .build()
        )

        val yearSubActions = years.mapIndexed { idx, pair ->
            GuidedAction.Builder(context).id(OFFSET_YEAR + idx).title(pair.first).build()
        }
        actions.add(
            GuidedAction.Builder(context)
                .id(ACTION_YEAR)
                .title("Rok produkcji")
                .description(selectedYearName)
                .subActions(yearSubActions)
                .build()
        )

        actions.add(
            GuidedAction.Builder(context)
                .id(ACTION_SUBMIT)
                .title("🔍 Szukaj według filtrów")
                .description("Pokaż pasujące pozycje")
                .build()
        )
    }

    override fun onSubGuidedActionClicked(action: GuidedAction): Boolean {
        when (action.id) {
            in OFFSET_TYPE until (OFFSET_TYPE + 2) -> {
                val isMovie = action.id == OFFSET_TYPE
                selectedType = if (isMovie) "movie" else "serie"
                selectedTypeName = if (isMovie) "Filmy" else "Seriale"
                findActionById(ACTION_TYPE)?.description = selectedTypeName
                notifyActionChanged(findActionPositionById(ACTION_TYPE))
                return true
            }
            in OFFSET_GENRE until (OFFSET_GENRE + genres.size) -> {
                val idx = (action.id - OFFSET_GENRE).toInt()
                val pair = genres[idx]
                selectedGenreName = pair.first
                selectedGenreId = pair.second
                findActionById(ACTION_GENRE)?.description = selectedGenreName
                notifyActionChanged(findActionPositionById(ACTION_GENRE))
                return true
            }
            in OFFSET_VERSION until (OFFSET_VERSION + versions.size) -> {
                val idx = (action.id - OFFSET_VERSION).toInt()
                val pair = versions[idx]
                selectedVersionName = pair.first
                selectedVersion = pair.second
                findActionById(ACTION_VERSION)?.description = selectedVersionName
                notifyActionChanged(findActionPositionById(ACTION_VERSION))
                return true
            }
            in OFFSET_YEAR until (OFFSET_YEAR + years.size) -> {
                val idx = (action.id - OFFSET_YEAR).toInt()
                val pair = years[idx]
                selectedYearName = pair.first
                selectedYear = pair.second
                findActionById(ACTION_YEAR)?.description = selectedYearName
                notifyActionChanged(findActionPositionById(ACTION_YEAR))
                return true
            }
        }
        return super.onSubGuidedActionClicked(action)
    }

    override fun onGuidedActionClicked(action: GuidedAction) {
        if (action.id == ACTION_SUBMIT) {
            val intent = Intent(requireContext(), GridActivity::class.java).apply {
                putExtra("TYPE", selectedType)
                putExtra("GENRE_ID", selectedGenreId)
                putExtra("VERSION", selectedVersion)
                putExtra("YEAR", selectedYear)
                val titleSummary = "$selectedTypeName: $selectedGenreName ($selectedVersionName, $selectedYearName)"
                putExtra("TITLE", titleSummary)
            }
            startActivity(intent)
        }
    }
}
FILE

# 4. Ekran wyników w pełnej siatce (VerticalGridSupportFragment)
cat << 'FILE' > app/src/main/java/com/ekinotv/app/ui/GridActivity.kt
package com.ekinotv.app.ui

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
import com.ekinotv.app.player.PlaybackRouter
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
                PlaybackRouter.playMovie(requireContext(), item)
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

# 5. Aktualizacja MainFragment z SectionRow i kafelkiem filtrów
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

            // --- SEKCJA: FILMY ---
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

            // --- SEKCJA: SERIALE ---
            rowsAdapter.add(SectionRow(HeaderItem(headerId++, "SERIALE")))

            val series = seriesDeferred.await()
            if (series.isNotEmpty()) {
                val rowAdapter = ArrayObjectAdapter(cardPresenter).apply { addAll(0, series) }
                rowsAdapter.add(ListRow(HeaderItem(headerId++, "Najnowsze Seriale"), rowAdapter))
            }

            // --- SEKCJA: FILTROWANIE ---
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
                    PlaybackRouter.playMovie(requireContext(), item)
                }
            }
        }
    }
}
FILE

# 6. Rejestracja aktywności w AndroidManifest.xml
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
            android:name=".player.PlayerActivity"
            android:exported="false"
            android:screenOrientation="landscape"
            android:configChanges="keyboard|keyboardHidden|navigation|orientation|screenSize"/>
    </application>
</manifest>
FILE

# 7. Wypchnięcie zmian
git add .
git commit -m "Wdrozenie SectionRow oraz pelnego modulu filtrowania z siatka wynikow"
git push origin main
rm setup_filtering_and_sections.sh
echo "Wypchnięte! Sprawdź budowanie na GitHub Actions."
