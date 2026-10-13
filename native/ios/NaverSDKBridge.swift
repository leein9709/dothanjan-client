import Foundation
import UIKit
import NidThirdPartyLogin

@objc(DTNaverSDK)
final class DTNaverSDK: NSObject {
    private static var initialized = false
    private static var busy = false

    @objc static func configure(_ clientId: String, secret: String, appName: String, scheme: String) {
        DispatchQueue.main.async {
            guard !initialized, !clientId.isEmpty, !secret.isEmpty else { return }
            NidOAuth.shared.initialize(appName: appName, clientId: clientId, clientSecret: secret, urlScheme: scheme)
            NidOAuth.shared.setLoginBehavior(.appPreferredWithInAppBrowserFallback)
            initialized = true
        }
    }

    @objc(handleURL:)
    static func handleURL(_ url: URL) -> Bool {
        guard initialized else { return false }
        return NidOAuth.shared.handleURL(url)
    }

    @objc static func login(_ completion: @escaping (String?, String?, String?) -> Void) {
        DispatchQueue.main.async {
            guard initialized else { completion(nil, nil, "not_configured"); return }
            guard !busy else { completion(nil, nil, "login_in_progress"); return }
            busy = true
            if let access = NidOAuth.shared.accessToken, let refresh = NidOAuth.shared.refreshToken {
                busy = false
                completion(access.tokenString, refresh.tokenString, nil)
                return
            }
            // SDK handles stored token reuse/refresh, Naver app login and browser fallback.
            NidOAuth.shared.requestLogin { result in
                busy = false
                switch result {
                case .success(let tokens):
                    completion(tokens.accessToken.tokenString, tokens.refreshToken.tokenString, nil)
                case .failure(let error):
                    switch error {
                    case .clientError(.canceledByUser): completion(nil, nil, "cancelled")
                    case .serverError(.authError(let code, _)):
                        completion(nil, nil, code == "access_denied" ? "cancelled" : "login_failed")
                    case .serverError(.networkError(_)), .serverError(.webAuthenticationInternalError(_)):
                        completion(nil, nil, "provider_unavailable")
                    default: completion(nil, nil, "login_failed")
                    }
                }
            }
        }
    }

    @objc static func reauthenticate(_ completion: @escaping (String?, String?, String?) -> Void) {
        DispatchQueue.main.async {
            guard !busy else { completion(nil, nil, "login_in_progress"); return }
            NidOAuth.shared.logout()
            login(completion)
        }
    }
}
