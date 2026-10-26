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
