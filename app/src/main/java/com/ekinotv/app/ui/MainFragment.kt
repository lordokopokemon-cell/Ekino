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
