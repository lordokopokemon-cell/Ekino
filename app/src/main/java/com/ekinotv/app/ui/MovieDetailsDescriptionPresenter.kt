package com.ekinotv.app.ui

import androidx.leanback.widget.AbstractDetailsDescriptionPresenter
import com.ekinotv.app.data.MovieDetails

class MovieDetailsDescriptionPresenter : AbstractDetailsDescriptionPresenter() {
    override fun onBindDescription(vh: ViewHolder, item: Any) {
        val details = item as MovieDetails
        vh.title.text = details.title
        vh.subtitle.text = details.originalTitle
        vh.body.text = details.description
    }
}
