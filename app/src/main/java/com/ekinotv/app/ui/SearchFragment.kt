package com.ekinotv.app.ui

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
