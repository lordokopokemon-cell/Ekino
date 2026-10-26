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
