package dev.coolswood.openpanel

import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Bundle

/**
 * Tracks application foreground/background transitions via activity
 * lifecycle callbacks: the app is in the foreground while at least one
 * activity is started.
 */
internal class LifecycleTracker(
    context: Context,
    private val onChange: (foreground: Boolean) -> Unit,
) {
    private val app = context.applicationContext as Application
    private var startedActivities = 0

    private val callbacks = object : Application.ActivityLifecycleCallbacks {
        override fun onActivityStarted(activity: Activity) {
            startedActivities++
            if (startedActivities == 1) onChange(true)
        }

        override fun onActivityStopped(activity: Activity) {
            if (startedActivities > 0) startedActivities--
            if (startedActivities == 0) onChange(false)
        }

        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
        override fun onActivityResumed(activity: Activity) = Unit
        override fun onActivityPaused(activity: Activity) = Unit
        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
        override fun onActivityDestroyed(activity: Activity) = Unit
    }

    init {
        app.registerActivityLifecycleCallbacks(callbacks)
    }

    fun dispose() {
        app.unregisterActivityLifecycleCallbacks(callbacks)
    }
}
