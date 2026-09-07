package dev.coolswood.openpanel

import java.net.HttpURLConnection
import java.net.URL

/** Outcome of a single POST to the `/track` endpoint. */
internal sealed class HttpResult {
    data class Ok(val code: Int) : HttpResult()

    /** 4xx other than 429 — the event itself is invalid, retrying is futile. */
    data class BadRequest(val code: Int) : HttpResult()

    /** Network error, 5xx or 429 — retry with backoff. */
    data class Retryable(val code: Int?, val error: Exception?) : HttpResult()
}

/** Minimal blocking HTTP POST on top of HttpURLConnection — zero dependencies. */
internal object HttpPoster {
    private const val TIMEOUT_MS = 10_000

    fun post(url: String, headers: Map<String, String>, body: String): HttpResult {
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = TIMEOUT_MS
                readTimeout = TIMEOUT_MS
                doOutput = true
                for ((key, value) in headers) setRequestProperty(key, value)
            }
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val code = connection.responseCode
            when {
                code in 200..299 -> HttpResult.Ok(code)
                code in 400..499 && code != 429 -> HttpResult.BadRequest(code)
                else -> HttpResult.Retryable(code, null)
            }
        } catch (e: Exception) {
            HttpResult.Retryable(null, e)
        } finally {
            connection?.disconnect()
        }
    }
}
