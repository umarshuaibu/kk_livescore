package com.datalinx.kklivescore.fans

import android.view.LayoutInflater
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

class ListTileNativeAdFactory(
    private val inflater: LayoutInflater
) : NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: Map<String, Any>?
    ): NativeAdView {

        val adView = inflater.inflate(
            R.layout.native_ad_list_tile,
            null
        ) as NativeAdView

        adView.headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        adView.bodyView = adView.findViewById<TextView>(R.id.ad_body)
        adView.iconView = adView.findViewById<ImageView>(R.id.ad_app_icon)

        (adView.headlineView as TextView).text = nativeAd.headline
        (adView.bodyView as TextView).text = nativeAd.body
        (adView.iconView as ImageView).setImageDrawable(nativeAd.icon?.drawable)

        adView.setNativeAd(nativeAd)
        return adView
    }
}
