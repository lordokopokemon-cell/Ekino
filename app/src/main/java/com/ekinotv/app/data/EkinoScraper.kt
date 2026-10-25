package com.ekinotv.app.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.jsoup.Jsoup

class EkinoScraper {
    private val baseUrl = "https://ekino.ws"

    suspend fun getLatestMovies(): List<MovieItem> = withContext(Dispatchers.IO) {
        val movies = mutableListOf<MovieItem>()
        val seenUrls = mutableSetOf<String>()

        try {
            val doc = Jsoup.connect(baseUrl)
                .userAgent(SessionManager.userAgent)
                .header("Referer", "https://ekino.ws/")
                .timeout(15000)
                .get()

            // Pobieramy wszystkie kafelki filmowe z sekcji plakatów i strony
            val elements = doc.select("a[href*=/movie/show/]")

            for (element in elements) {
                val url = element.attr("href")
                if (url.isEmpty() || seenUrls.contains(url)) continue

                var title = element.attr("title").trim()
                val imgElement = element.selectFirst("img")
                if (title.isEmpty() && imgElement != null) {
                    title = imgElement.attr("alt").trim()
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
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return@withContext movies
    }
}
