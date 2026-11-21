package de.merkezcamii.vilsbiburg

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.roundToLong

/** Gebetszeiten für Vilsbiburg – gleiche Berechnung wie auf der Webseite (Diyanet-Methode). */
object Prayer {
    private const val LAT = 48.4497
    private const val LNG = 12.3556
    private const val FAJR = 18.0
    private const val ISHA = 17.0
    val ZONE: ZoneId = ZoneId.of("Europe/Berlin")
    val TR: Locale = Locale.forLanguageTag("tr-TR")

    val KEYS = listOf("imsak", "gunes", "ogle", "ikindi", "aksam", "yatsi")
    val NAMES = mapOf(
        "imsak" to "İmsak", "gunes" to "Güneş", "ogle" to "Öğle",
        "ikindi" to "İkindi", "aksam" to "Akşam", "yatsi" to "Yatsı"
    )
    private val TEMKIN = mapOf("imsak" to 0, "gunes" to -7, "ogle" to 5, "ikindi" to 4, "aksam" to 7, "yatsi" to 0)

    private const val D2R = Math.PI / 180.0
    private const val R2D = 180.0 / Math.PI
    private fun sin(d: Double) = kotlin.math.sin(d * D2R)
    private fun cos(d: Double) = kotlin.math.cos(d * D2R)
    private fun tan(d: Double) = kotlin.math.tan(d * D2R)
    private fun asin(x: Double) = kotlin.math.asin(x) * R2D
    private fun acos(x: Double) = kotlin.math.acos(x) * R2D
    private fun atan2(y: Double, x: Double) = kotlin.math.atan2(y, x) * R2D
    private fun acot(x: Double) = kotlin.math.atan(1.0 / x) * R2D
    private fun fix(a: Double, b: Double): Double {
        val r = a - b * floor(a / b)
        return if (r < 0) r + b else r
    }

    private class Sun(val decl: Double, val eqt: Double)

    private fun sunPos(jd: Double): Sun {
        val d = jd - 2451545.0
        val g = fix(357.529 + 0.98560028 * d, 360.0)
        val q = fix(280.459 + 0.98564736 * d, 360.0)
        val l = fix(q + 1.915 * sin(g) + 0.02 * sin(2 * g), 360.0)
        val e = 23.439 - 0.00000036 * d
        val ra = fix(atan2(cos(e) * sin(l), cos(l)) / 15.0, 24.0)
        return Sun(asin(sin(e) * sin(l)), q / 15.0 - ra)
    }

    private fun julian(year: Int, month: Int, day: Int): Double {
        var y = year
        var m = month
        if (m <= 2) { y -= 1; m += 12 }
        val a = floor(y / 100.0)
        val b = 2 - a + floor(a / 4.0)
        return floor(365.25 * (y + 4716)) + floor(30.6001 * (m + 1)) + day + b - 1524.5
    }

    fun compute(date: LocalDate): Map<String, Instant> {
        val jd = julian(date.year, date.monthValue, date.dayOfMonth) - LNG / (15.0 * 24.0)
        fun noon(t: Double) = fix(12 - sunPos(jd + t / 24).eqt, 24.0)
        fun at(angle: Double, t: Double, ccw: Boolean): Double {
            val s = sunPos(jd + t / 24)
            val v = (-sin(angle) - sin(s.decl) * sin(LAT)) / (cos(s.decl) * cos(LAT))
            val h = acos(v) / 15.0
            val n = noon(t)
            return n + (if (ccw) -h else h)
        }
        fun asr(t: Double): Double {
            val s = sunPos(jd + t / 24)
            return at(-acot(1 + tan(abs(LAT - s.decl))), t, false)
        }

        var t = mutableMapOf(
            "imsak" to 5.0, "gunes" to 6.0, "ogle" to 12.0,
            "ikindi" to 13.0, "aksam" to 18.0, "yatsi" to 18.0
        )
        repeat(2) {
            t = mutableMapOf(
                "imsak" to at(FAJR, t["imsak"]!!, true),
                "gunes" to at(0.833, t["gunes"]!!, true),
                "ogle" to noon(t["ogle"]!!),
                "ikindi" to asr(t["ikindi"]!!),
                "aksam" to at(0.833, t["aksam"]!!, false),
                "yatsi" to at(ISHA, t["yatsi"]!!, false)
            )
        }
        for (k in KEYS) t[k] = t[k]!! - LNG / 15.0
        val night = 24 - (t["aksam"]!! - t["gunes"]!!)
        val fp = FAJR / 60.0 * night
        val ip = ISHA / 60.0 * night
        if (t["imsak"]!!.isNaN() || t["gunes"]!! - t["imsak"]!! > fp) t["imsak"] = t["gunes"]!! - fp
        if (t["yatsi"]!!.isNaN() || t["yatsi"]!! - t["aksam"]!! > ip) t["yatsi"] = t["aksam"]!! + ip

        val midnightUtc = date.atStartOfDay(ZoneOffset.UTC).toInstant()
        return KEYS.associateWith { k ->
            val minutes = (t[k]!! * 60.0 + TEMKIN[k]!!).roundToLong()
            midnightUtc.plusSeconds(minutes * 60)
        }
    }

    private val hm = DateTimeFormatter.ofPattern("HH:mm", TR).withZone(ZONE)
    fun fmt(i: Instant): String = hm.format(i)

    fun miladi(date: LocalDate): String =
        DateTimeFormatter.ofPattern("d MMMM EEEE", TR).format(date)

    fun hicri(now: Instant): String = try {
        val f = android.icu.text.SimpleDateFormat(
            "d MMMM y",
            android.icu.util.ULocale("tr_TR@calendar=islamic-umalqura")
        )
        f.timeZone = android.icu.util.TimeZone.getTimeZone("Europe/Berlin")
        f.format(java.util.Date(now.toEpochMilli()))
    } catch (e: Exception) {
        ""
    }
}
