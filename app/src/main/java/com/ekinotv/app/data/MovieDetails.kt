package com.ekinotv.app.data

import java.io.Serializable

data class PlayerSource(
    val host: String,
    val id: String,
    val version: String,
    val watchUrl: String
) : Serializable

data class MovieDetails(
    val title: String,
    val originalTitle: String,
    val description: String,
    val posterUrl: String,
    val pageUrl: String,
    val sources: List<PlayerSource>
) : Serializable
