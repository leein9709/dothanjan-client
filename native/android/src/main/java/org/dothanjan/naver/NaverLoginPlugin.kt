package org.dothanjan.naver

import com.navercorp.nid.NidOAuth
import com.navercorp.nid.core.data.datastore.NidOAuthInitializingCallback
import com.navercorp.nid.oauth.util.NidOAuthCallback
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

class NaverLoginPlugin(godot: Godot) : GodotPlugin(godot) {
    private var ready = false
    private var initializing = false
    private var busy = false
    private var pendingAttempt: Int? = null
    override fun getPluginName() = "NaverLogin"
    override fun getPluginSignals() = setOf(
        SignalInfo("login_success", String::class.java, String::class.java, Int::class.javaObjectType),
        SignalInfo("login_failure", String::class.java, Int::class.javaObjectType)
    )

    @UsedByGodot
    fun configure(clientId: String, clientSecret: String, appName: String) {
        activity?.runOnUiThread {
            if (ready || initializing || clientId.isBlank() || clientSecret.isBlank()) return@runOnUiThread
            initializing = true
            NidOAuth.setLogEnabled(false)
            NidOAuth.isShowMarketLink = false
            NidOAuth.initialize(activity!!.applicationContext, clientId, clientSecret, appName, object : NidOAuthInitializingCallback {
                override fun onSuccess() {
                    activity?.runOnUiThread {
                        ready = true
                        initializing = false
                        pendingAttempt?.let { attempt -> pendingAttempt = null; begin(attempt) }
                    }
                }
                override fun onFailure(e: Exception) {
                    activity?.runOnUiThread {
                        initializing = false
                        pendingAttempt?.let { attempt -> pendingAttempt = null; emitSignal("login_failure", "not_configured", attempt) }
                    }
                }
            })
        }
    }

    @UsedByGodot
    fun login(attempt: Int) {
        activity?.runOnUiThread {
            if (busy) { emitSignal("login_failure", "login_in_progress", attempt); return@runOnUiThread }
            if (initializing) { pendingAttempt = attempt; return@runOnUiThread }
            if (!ready) { emitSignal("login_failure", "not_configured", attempt); return@runOnUiThread }
            begin(attempt)
        } ?: emitSignal("login_failure", "provider_unavailable", attempt)
    }

    private fun begin(attempt: Int) {
        val context = activity ?: return emitSignal("login_failure", "provider_unavailable", attempt)
        busy = true
        val access = NidOAuth.getAccessToken()
        val refresh = NidOAuth.getRefreshToken()
        if (!access.isNullOrEmpty() && !refresh.isNullOrEmpty()) {
            busy = false
            emitSignal("login_success", access, refresh, attempt)
            return
        }
        // requestLogin reuses/refreshes saved SDK tokens; otherwise it prefers the Naver app
        // and falls back to a Custom Tab. Credentials and tokens are never logged.
        NidOAuth.requestLogin(context, object : NidOAuthCallback {
            override fun onSuccess() {
                busy = false
                val access = NidOAuth.getAccessToken()
                val refresh = NidOAuth.getRefreshToken()
                if (!access.isNullOrEmpty() && !refresh.isNullOrEmpty()) emitSignal("login_success", access, refresh, attempt)
                else emitSignal("login_failure", "login_failed", attempt)
            }
            override fun onFailure(errorCode: String, errorDesc: String) {
                busy = false
                val code = when (errorCode) {
                    "user_cancel", "CLIENT_USER_CANCEL", "access_denied" -> "cancelled"
                    "CLIENT_ERROR_CONNECTION_ERROR", "temporarily_unavailable", "server_error" -> "provider_unavailable"
                    else -> "login_failed"
                }
                emitSignal("login_failure", code, attempt)
            }
        })
    }

    @UsedByGodot
    fun reauthenticate(attempt: Int) {
        activity?.runOnUiThread {
            if (busy) { emitSignal("login_failure", "login_in_progress", attempt); return@runOnUiThread }
            busy = true
            NidOAuth.logout(object : NidOAuthCallback {
                override fun onSuccess() {
                    activity?.runOnUiThread { busy = false; begin(attempt) }
                }
                override fun onFailure(errorCode: String, errorDesc: String) {
                    busy = false
                    emitSignal("login_failure", "login_failed", attempt)
                }
            })
        } ?: emitSignal("login_failure", "provider_unavailable", attempt)
    }
}
