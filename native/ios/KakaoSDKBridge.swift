import Foundation
import UIKit
import KakaoSDKCommon
import KakaoSDKAuth
import KakaoSDKUser

@objc(DTKakaoSDK)
final class DTKakaoSDK: NSObject {
    private static var initialized = false
    private static var busy = false

    @objc static func configure(_ key: String) {
        DispatchQueue.main.async {
            KakaoSDK.initSDK(appKey: key)
            initialized = true
        }
    }

    @objc(handleURL:)
    static func handleURL(_ url: URL) -> Bool {
        guard AuthApi.isKakaoTalkLoginUrl(url) else { return false }
        return AuthController.handleOpenUrl(url: url)
    }

    @objc static func login(_ completion: @escaping (String?, String?) -> Void) {
        DispatchQueue.main.async {
            guard initialized else { completion(nil, "not_configured"); return }
            guard !busy else { completion(nil, "login_in_progress"); return }
            busy = true
            let finish: (String?, String?) -> Void = { token, error in
                busy = false
                completion(token, error)
            }
            if AuthApi.hasToken() {
                UserApi.shared.accessTokenInfo { _, error in
                    if error == nil, let token = TokenManager.manager.getToken()?.accessToken {
                        finish(token, nil)
                    } else if let sdkError = error as? SdkError, sdkError.isInvalidTokenError() {
                        interactive(finish)
                    } else {
                        finish(nil, "provider_unavailable")
                    }
                }
            } else {
                interactive(finish)
            }
        }
    }

    private static func interactive(_ finish: @escaping (String?, String?) -> Void) {
        let complete: (OAuthToken?, Error?) -> Void = { token, error in
            if let token = token { finish(token.accessToken, nil) }
            else if cancelled(error) {
                finish(nil, "cancelled")
            } else { finish(nil, "login_failed") }
        }
        if UserApi.isKakaoTalkLoginAvailable() {
            UserApi.shared.loginWithKakaoTalk { token, error in
                if let token = token { finish(token.accessToken, nil) }
                else if cancelled(error) {
                    finish(nil, "cancelled")
                } else { UserApi.shared.loginWithKakaoAccount(completion: complete) }
            }
        } else {
            UserApi.shared.loginWithKakaoAccount(completion: complete)
        }
    }

    private static func cancelled(_ error: Error?) -> Bool {
        guard let sdkError = error as? SdkError else { return false }
        if case .ClientFailed(let reason, _) = sdkError { return reason == .Cancelled }
        return false
    }
}
