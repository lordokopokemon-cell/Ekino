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
