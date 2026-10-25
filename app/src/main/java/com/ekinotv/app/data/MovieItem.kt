package com.ekinotv.app.data

import java.io.Serializable

data class MovieItem(
    val id: String,
    val title: String,
    val posterUrl: String,
    val pageUrl: String
) : Serializable
