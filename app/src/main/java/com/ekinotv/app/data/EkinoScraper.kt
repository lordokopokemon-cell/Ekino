package com.ekinotv.app.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.jsoup.Jsoup

class EkinoScraper {
    private val baseUrl = "https://ekino.ws"

    suspend fun getLatestMovies(): List<MovieItem> = withContext(Dispatchers.IO) {
        val movies = mutableListOf<MovieItem>()
        try {
            val doc = Jsoup.connect(baseUrl)
                .userAgent(SessionManager.userAgent)
                .get()

            val elements = doc.select("div.movie-item") 
            
            for (element in elements) {
                val title = element.select("div.title").text()
                val url = element.select("a").attr("href")
                val img = element.select("img").attr("src")
                
                if (title.isNotEmpty()) {
                    movies.add(
                        MovieItem(
                            id = url.hashCode().toString(),
                            title = title,
                            posterUrl = if (img.startsWith("http")) img else "$baseUrl$img",
                            pageUrl = if (url.startsWith("http")) url else "$baseUrl$url"
                        )
                    )
                }
            }
            
            if (movies.isEmpty()) {
                movies.add(MovieItem("1", "Testowy Film (Brak HTML)", "https://via.placeholder.com/200x300", "https://ekino.ws"))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return@withContext movies
    }
}
