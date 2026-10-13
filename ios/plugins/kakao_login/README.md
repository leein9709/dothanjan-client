# iOS 카카오 로그인 플러그인

소스는 `client/native/ios/`에 있다(프로젝트 루트 기준). KakaoSDKCommon/Auth/User 2.29.0과 네이버 NidThirdPartyLogin 5.2.1을 SPM으로 연결하는 공통 Swift·Objective-C++ Godot 브리지다. 기존 폴더·타깃 이름은 유지하며 하나의 플러그인이 KakaoLogin·NaverLogin 싱글톤을 모두 등록한다. 각 앱 전환과 복귀 URL 처리, 네이버 저장 로그인 정보 재사용을 포함한다.

이 Windows PC에서는 iOS 바이너리를 컴파일할 수 없다. Mac에서 동일 Godot 4.7.2 소스·생성 헤더, Xcode 26, XcodeGen을 준비하고 `setting/scripts/Build-Kakao-iOS.sh`를 실행한다. `GODOT_SOURCE_ROOT`를 해당 엔진 소스 절대 경로로 지정한다. 원본 엔진과 같은 플래그의 debug/release 헤더·템플릿을 사용한다.

빌드 성공 시 debug/release XCFramework와 실제 `.gdip` 설정을 이 폴더에 배치한다. URL 스킴은 Git 제외 `config/kakao.local.cfg`로부터 생성한다. Godot iOS export에서 KakaoLogin을 활성화하고 Apple Team ID와 서명을 설정한다. Swift/SPM 및 전체 iOS 컴파일·실기기 테스트는 Mac에서 검증해야 한다.

네이버 URL Scheme은 Git 제외 `config/naver.local.cfg`의 `dothanjan-naver`를 사용한다. 패키징 스크립트는 두 SDK 정적 라이브러리와 네이버 SPM 리소스 번들·개인정보 매니페스트를 함께 배치한다. 실제 키가 들어가는 생성 `.gdip`·XCFramework·리소스 번들은 Git 제외다. 네이버 패치에서는 사용자 지시로 스크립트·컴파일을 실행하지 않았다.
