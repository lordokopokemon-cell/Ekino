package com.ekinotv.app.ui

import android.text.TextUtils
import android.view.ViewGroup
import android.widget.TextView
import androidx.leanback.widget.ImageCardView
import androidx.leanback.widget.Presenter
import coil.load
import com.ekinotv.app.data.MovieItem

class CardPresenter : Presenter() {
    // Powiększenie o 10% (z 200x300 na 220x330)
    private val CARD_WIDTH = 220
    private val CARD_HEIGHT = 330

    override fun onCreateViewHolder(parent: ViewGroup): ViewHolder {
        val cardView = ImageCardView(parent.context).apply {
            isFocusable = true
            isFocusableInTouchMode = true
            setMainImageDimensions(CARD_WIDTH, CARD_HEIGHT)

            // Odblokowanie 2 linijek tekstu dla tytułu
            findViewById<TextView>(androidx.leanback.R.id.title_text)?.apply {
                maxLines = 2
                isSingleLine = false
                ellipsize = TextUtils.TruncateAt.END
            }
        }
        return ViewHolder(cardView)
    }

    override fun onBindViewHolder(viewHolder: ViewHolder, item: Any?) {
        val movie = item as? MovieItem ?: return
        val cardView = viewHolder.view as ImageCardView
        
        cardView.titleText = movie.title
        cardView.contentText = null // Zwolnienie miejsca pod 2 linie tytułu
        
        cardView.mainImageView.load(movie.posterUrl) {
            crossfade(true)
        }
    }

    override fun onUnbindViewHolder(viewHolder: ViewHolder) {
        val cardView = viewHolder.view as ImageCardView
        cardView.badgeImage = null
        cardView.setMainImage(null)
    }
}
