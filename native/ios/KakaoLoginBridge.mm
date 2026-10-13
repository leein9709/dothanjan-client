#include "core/config/engine.h"
#include "core/object/class_db.h"
#include "core/object/ref_counted.h"
#include "drivers/apple_embedded/godot_app_delegate.h"
#include "drivers/apple_embedded/app_delegate_service.h"
#import "DothanjanKakao-Swift.h"

class KakaoLoginBridge;
static KakaoLoginBridge *bridge = nullptr;
void init_dothanjan_naver();
void deinit_dothanjan_naver();
void init_dothanjan_session_store();
void deinit_dothanjan_session_store();

@interface DTKakaoAppService : GDTAppDelegateService
@end
@implementation DTKakaoAppService
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    return [DTKakaoSDK handleURL:url];
}
- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)contexts {
    for (UIOpenURLContext *context in contexts) [DTKakaoSDK handleURL:context.URL];
}
@end

class KakaoLoginBridge : public RefCounted {
    GDCLASS(KakaoLoginBridge, RefCounted);
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("configure", "native_key"), &KakaoLoginBridge::configure);
        ClassDB::bind_method(D_METHOD("login", "attempt"), &KakaoLoginBridge::login);
        ADD_SIGNAL(MethodInfo("login_success", PropertyInfo(Variant::STRING, "providerAccessToken"), PropertyInfo(Variant::INT, "attempt")));
        ADD_SIGNAL(MethodInfo("login_failure", PropertyInfo(Variant::STRING, "error_code"), PropertyInfo(Variant::INT, "attempt")));
    }
public:
    void configure(const String &key) {
        [DTKakaoSDK configure:[NSString stringWithUTF8String:key.utf8().get_data()]];
    }
    void login(int attempt) {
        [DTKakaoSDK login:^(NSString *token, NSString *error) {
            if (!bridge) return;
            // Defer the signal to Godot's message queue rather than invoking GDScript on UIKit's thread.
            if (token.length) bridge->call_deferred("emit_signal", "login_success", String::utf8(token.UTF8String), attempt);
            else bridge->call_deferred("emit_signal", "login_failure", String::utf8(error ? error.UTF8String : "login_failed"), attempt);
        }];
    }
};

// Godot's generated plugin registration declares these with C++ linkage.
void init_dothanjan_kakao() {
    ClassDB::register_class<KakaoLoginBridge>();
    bridge = memnew(KakaoLoginBridge);
    Engine::get_singleton()->add_singleton(Engine::Singleton("KakaoLogin", bridge));
    [GDTApplicationDelegate addService:[DTKakaoAppService new]];
    init_dothanjan_naver();
    init_dothanjan_session_store();
}
void deinit_dothanjan_kakao() {
    deinit_dothanjan_session_store();
    deinit_dothanjan_naver();
    Engine::get_singleton()->remove_singleton("KakaoLogin");
    memdelete(bridge);
    bridge = nullptr;
}
