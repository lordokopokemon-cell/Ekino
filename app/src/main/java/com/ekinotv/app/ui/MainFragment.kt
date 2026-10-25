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
