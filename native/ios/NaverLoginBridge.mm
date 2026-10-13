#include "core/config/engine.h"
#include "core/object/class_db.h"
#include "core/object/ref_counted.h"
#include "drivers/apple_embedded/godot_app_delegate.h"
#include "drivers/apple_embedded/app_delegate_service.h"
#import "DothanjanKakao-Swift.h"

class NaverLoginBridge;
static NaverLoginBridge *naver_bridge = nullptr;

@interface DTNaverAppService : GDTAppDelegateService
@end
@implementation DTNaverAppService
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    return [DTNaverSDK handleURL:url];
}
- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)contexts {
    for (UIOpenURLContext *context in contexts) [DTNaverSDK handleURL:context.URL];
}
@end

class NaverLoginBridge : public RefCounted {
    GDCLASS(NaverLoginBridge, RefCounted);
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("configure", "client_id", "client_secret", "app_name", "url_scheme"), &NaverLoginBridge::configure);
        ClassDB::bind_method(D_METHOD("login", "attempt"), &NaverLoginBridge::login);
        ClassDB::bind_method(D_METHOD("reauthenticate", "attempt"), &NaverLoginBridge::reauthenticate);
        ADD_SIGNAL(MethodInfo("login_success", PropertyInfo(Variant::STRING, "access_token"), PropertyInfo(Variant::STRING, "refresh_token"), PropertyInfo(Variant::INT, "attempt")));
        ADD_SIGNAL(MethodInfo("login_failure", PropertyInfo(Variant::STRING, "error_code"), PropertyInfo(Variant::INT, "attempt")));
    }
public:
    void configure(const String &client_id, const String &secret, const String &app_name, const String &scheme) {
        [DTNaverSDK configure:[NSString stringWithUTF8String:client_id.utf8().get_data()]
            secret:[NSString stringWithUTF8String:secret.utf8().get_data()]
            appName:[NSString stringWithUTF8String:app_name.utf8().get_data()]
            scheme:[NSString stringWithUTF8String:scheme.utf8().get_data()]];
    }
    void login(int attempt) {
        [DTNaverSDK login:^(NSString *access, NSString *refresh, NSString *error) {
            if (!naver_bridge) return;
            if (access.length && refresh.length) naver_bridge->call_deferred("emit_signal", "login_success", String::utf8(access.UTF8String), String::utf8(refresh.UTF8String), attempt);
            else naver_bridge->call_deferred("emit_signal", "login_failure", String::utf8(error ? error.UTF8String : "login_failed"), attempt);
        }];
    }
    void reauthenticate(int attempt) {
        [DTNaverSDK reauthenticate:^(NSString *access, NSString *refresh, NSString *error) {
            if (!naver_bridge) return;
            if (access.length && refresh.length) naver_bridge->call_deferred("emit_signal", "login_success", String::utf8(access.UTF8String), String::utf8(refresh.UTF8String), attempt);
            else naver_bridge->call_deferred("emit_signal", "login_failure", String::utf8(error ? error.UTF8String : "login_failed"), attempt);
        }];
    }
};

void init_dothanjan_naver() {
    ClassDB::register_class<NaverLoginBridge>();
    naver_bridge = memnew(NaverLoginBridge);
    Engine::get_singleton()->add_singleton(Engine::Singleton("NaverLogin", naver_bridge));
    [GDTApplicationDelegate addService:[DTNaverAppService new]];
}
void deinit_dothanjan_naver() {
    Engine::get_singleton()->remove_singleton("NaverLogin");
    memdelete(naver_bridge);
    naver_bridge = nullptr;
}
