package com.ekinotv.app.ui

import android.graphics.Color
import android.os.Bundle
import android.widget.Toast
import androidx.fragment.app.FragmentActivity
import androidx.leanback.app.DetailsSupportFragment
import androidx.leanback.widget.Action
import androidx.leanback.widget.ArrayObjectAdapter
import androidx.leanback.widget.ClassPresenterSelector
import androidx.leanback.widget.DetailsOverviewRow
import androidx.leanback.widget.FullWidthDetailsOverviewRowPresenter
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
    private lateinit var rowsAdapter: ArrayObjectAdapter
    private lateinit var detailsPresenter: FullWidthDetailsOverviewRowPresenter

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        detailsPresenter = FullWidthDetailsOverviewRowPresenter(MovieDetailsDescriptionPresenter()).apply {
            backgroundColor = Color.parseColor("#1B222C")
            initialState = FullWidthDetailsOverviewRowPresenter.STATE_FULL
        }

        val presenterSelector = ClassPresenterSelector().apply {
            addClassPresenter(DetailsOverviewRow::class.java, detailsPresenter)
        }
        rowsAdapter = ArrayObjectAdapter(presenterSelector)
        adapter = rowsAdapter

        loadData()
    }

    private fun loadData() {
        val movieUrl = activity?.intent?.getStringExtra("MOVIE_URL").orEmpty()
        val initialTitle = activity?.intent?.getStringExtra("MOVIE_TITLE").orEmpty()
        val initialPoster = activity?.intent?.getStringExtra("MOVIE_POSTER").orEmpty()

        if (movieUrl.isEmpty()) {
            Toast.makeText(requireContext(), "Błąd: Brak adresu filmu", Toast.LENGTH_SHORT).show()
            activity?.finish()
            return
        }

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

        // Pobranie plakatu przez Coil
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

        // Pobranie źródeł i aktualizacja przycisków
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

                    detailsPresenter.setOnActionClickedListener { action ->
                        val idx = action.id.toInt()
                        val selectedSource = fullDetails.sources.getOrNull(idx)
                        if (selectedSource != null) {
                            PlaybackRouter.openSource(requireContext(), selectedSource.watchUrl)
                        }
                    }
                } else {
                    actionAdapter.add(Action(999L, "Brak bezpośrednich odtwarzaczy"))
                    detailsPresenter.setOnActionClickedListener {
                        PlaybackRouter.openSource(requireContext(), movieUrl)
                    }
                }
            } else {
                Toast.makeText(requireContext(), "Nie udało się pobrać szczegółów", Toast.LENGTH_SHORT).show()
            }
        }
    }
}
