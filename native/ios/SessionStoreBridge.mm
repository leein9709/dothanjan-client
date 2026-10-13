#include "core/config/engine.h"
#include "core/object/class_db.h"
#include "core/object/ref_counted.h"
#import <Foundation/Foundation.h>
#import <Security/Security.h>

static NSDictionary *session_query() {
    return @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: @"org.dothanjan.mobile.session.v1",
        (__bridge id)kSecAttrAccount: @"credential_bundle",
        (__bridge id)kSecAttrSynchronizable: @NO};
}
static bool ensure_current_install() {
    // Keychain can survive uninstall. A fresh installation starts signed out.
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults boolForKey:@"dothanjan.session.install.v1"]) return true;
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)session_query());
    if (status != errSecSuccess && status != errSecItemNotFound) return false;
    [defaults setBool:YES forKey:@"dothanjan.session.install.v1"];
    return true;
}

class MobileSessionStore : public RefCounted {
    GDCLASS(MobileSessionStore, RefCounted);
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("load_credentials"), &MobileSessionStore::load_credentials);
        ClassDB::bind_method(D_METHOD("save_credentials", "payload"), &MobileSessionStore::save_credentials);
        ClassDB::bind_method(D_METHOD("clear_credentials"), &MobileSessionStore::clear_credentials);
    }
public:
    String load_credentials() {
        @autoreleasepool {
            if (!ensure_current_install()) return "!storage_error";
            NSMutableDictionary *query = [session_query() mutableCopy];
            query[(__bridge id)kSecReturnData] = @YES;
            query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
            CFTypeRef result = nullptr;
            OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
            if (status == errSecItemNotFound) return "";
            if (status != errSecSuccess || !result) return "!storage_error";
            NSData *data = (__bridge NSData *)result;
            NSString *value = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            String payload = value ? String::utf8(value.UTF8String) : String("!storage_error");
            CFRelease(result);
            return payload;
        }
    }
    bool save_credentials(const String &payload) {
        @autoreleasepool {
            if (!ensure_current_install()) return false;
            NSString *value = [NSString stringWithUTF8String:payload.utf8().get_data()];
            NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
            if (!data || data.length > 8192) return false;
            NSDictionary *attributes = @{(__bridge id)kSecValueData: data,
                (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly};
            OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)session_query(), (__bridge CFDictionaryRef)attributes);
            if (status == errSecItemNotFound) {
                NSMutableDictionary *item = [session_query() mutableCopy];
                [item addEntriesFromDictionary:attributes];
                status = SecItemAdd((__bridge CFDictionaryRef)item, nullptr);
            }
            return status == errSecSuccess;
        }
    }
    bool clear_credentials() {
        @autoreleasepool {
            if (!ensure_current_install()) return false;
            OSStatus status = SecItemDelete((__bridge CFDictionaryRef)session_query());
            return status == errSecSuccess || status == errSecItemNotFound;
        }
    }
};
static MobileSessionStore *session_store = nullptr;
void init_dothanjan_session_store() {
    ClassDB::register_class<MobileSessionStore>();
    session_store = memnew(MobileSessionStore);
    Engine::get_singleton()->add_singleton(Engine::Singleton("SessionStore", session_store));
}
void deinit_dothanjan_session_store() {
    Engine::get_singleton()->remove_singleton("SessionStore");
    memdelete(session_store);
    session_store = nullptr;
}
