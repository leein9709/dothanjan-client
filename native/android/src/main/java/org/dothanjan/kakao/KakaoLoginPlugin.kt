package org.dothanjan.kakao

import com.kakao.sdk.auth.AuthApiClient
import com.kakao.sdk.auth.TokenManagerProvider
import com.kakao.sdk.auth.model.OAuthToken
import com.kakao.sdk.common.KakaoSdk
import com.kakao.sdk.common.model.ClientError
import com.kakao.sdk.common.model.ClientErrorCause
import com.kakao.sdk.common.model.KakaoSdkError
import com.kakao.sdk.common.util.Utility
import com.kakao.sdk.user.UserApiClient
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

class KakaoLoginPlugin(godot: Godot) : GodotPlugin(godot) {
    private var initialized = false
    private var busy = false
    override fun getPluginName() = "KakaoLogin"
    override fun getPluginSignals() = setOf(
        SignalInfo("login_success", String::class.java, Int::class.javaObjectType),
        SignalInfo("login_failure", String::class.java, Int::class.javaObjectType)
    )

    @UsedByGodot
    fun configure(nativeKey: String) {
        activity?.runOnUiThread {
            if (nativeKey.isNotBlank()) {
                KakaoSdk.init(activity!!.applicationContext, nativeKey)
                initialized = true
            }
        }
    }

    @UsedByGodot
    fun get_key_hash(): String = activity?.let { Utility.getKeyHash(it) } ?: ""

    @UsedByGodot
    fun login(attempt: Int) {
        activity?.runOnUiThread {
            if (!initialized) { emitSignal("login_failure", "not_configured", attempt); return@runOnUiThread }
            if (busy) { emitSignal("login_failure", "login_in_progress", attempt); return@runOnUiThread }
            busy = true
            if (AuthApiClient.instance.hasToken()) {
                UserApiClient.instance.accessTokenInfo { _, error ->
                    val token = TokenManagerProvider.instance.manager.getToken()?.accessToken
                    if (error == null && !token.isNullOrEmpty()) finish(token, null, attempt)
                    else if (error is KakaoSdkError && error.isInvalidTokenError()) interactive(attempt)
                    else finish(null, "provider_unavailable", attempt)
                }
            } else interactive(attempt)
        } ?: emitSignal("login_failure", "provider_unavailable", attempt)
    }

    private fun interactive(attempt: Int) {
        val context = activity ?: return finish(null, "provider_unavailable", attempt)
        val complete: (OAuthToken?, Throwable?) -> Unit = { token, error ->
            when {
                error is ClientError && error.reason == ClientErrorCause.Cancelled -> finish(null, "cancelled", attempt)
                token != null -> finish(token.accessToken, null, attempt)
                else -> finish(null, "login_failed", attempt)
            }
        }
        if (UserApiClient.instance.isKakaoTalkLoginAvailable(context)) {
            UserApiClient.instance.loginWithKakaoTalk(context) { token, error ->
                if (error is ClientError && error.reason == ClientErrorCause.Cancelled) finish(null, "cancelled", attempt)
                else if (token != null) finish(token.accessToken, null, attempt)
                else UserApiClient.instance.loginWithKakaoAccount(context, callback = complete)
            }
        } else UserApiClient.instance.loginWithKakaoAccount(context, callback = complete)
    }

    private fun finish(token: String?, error: String?, attempt: Int) {
        busy = false
        if (!token.isNullOrEmpty()) emitSignal("login_success", token, attempt)
        else emitSignal("login_failure", error ?: "login_failed", attempt)
    }
}
