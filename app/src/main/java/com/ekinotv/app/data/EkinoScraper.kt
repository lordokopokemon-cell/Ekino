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
