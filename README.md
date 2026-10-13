# 클라이언트

Godot 4.7.2 일반판에서 `project.godot`를 연다. Windows·macOS·iOS·Android 공통 GDScript 프로젝트이며 Compatibility 렌더러를 사용한다.

현재 첫 화면은 `scenes/login.tscn`이다. 1280×720을 기준으로 가로 화면에서 확장되며 마을 배경은 비율을 유지해 채운다. PC 창 크기를 변경할 수 있다. 소셜 로그인 버튼은 클릭·터치를 받는다.

- 카카오·네이버: 모든 대상 플랫폼에 표시.
- Apple: iOS·macOS에 표시. 개발 전용 `--preview-apple`로 다른 OS에서도 UI 확인 가능.
- 카카오: Android·iOS는 공식 SDK의 저장 토큰 확인·카카오톡 로그인·카카오계정 대체 로그인, Windows·macOS는 웹 브라우저 인증을 사용한다. 서버 검증·자동 가입/로그인 성공 후 같은 첫 장면의 공통 진입 관문으로 표시한다. 실패만 공통 모달로 안내한다.
- 네이버: Android·iOS 공식 SDK의 저장 로그인 정보 재사용·네이버 앱 우선·브라우저 대체 로그인과 PC 브라우저 인증을 연결했다. 성공하면 카카오/자동 복원과 동일한 진입 관문을 사용하고 실패만 모달로 안내한다. 이번 패치의 빌드·컴파일·실기기 확인은 실행하지 않았다.
- 인증된 세션이면 우측 로그인 박스를 숨기고 하단 중앙에 “터치해서 들어가요.”를 표시한다. 부제와 동일한 Dongle 29px·왼쪽 문구의 색과 그림자를 공유한다. 진입 뒤 현재 계정을 조회하고 사장님/가게 이름이 없으면 `scenes/owner_setup.tscn`의 05번 책 화면을 연다. 미인증·만료·로그아웃은 기존 로그인 UI다.
- 책 왼쪽 3×3에는 확정 9종 PNG를 그대로 표시하고 오른쪽에 선택된 사장님·이름 입력을 제공한다. 풀·꽃만 움직이며 “시작할게요”에는 동작을 연결하지 않았다. 뒤로가기는 초안을 버리고 로그인 상태를 유지한 진입 관문으로 돌아간다. DB/계정/설정 파일에 선택·이름을 저장하지 않는다. 로그인 부제는 “구름이 지나가는 동안\n우리도 조금 쉬어요.”다.
- 새 책 배경은 원본과 동일한 `assets/backgrounds/owner-book.png.bytes`를 `owner_book_art.gd`에서 읽어 가져오기 캐시가 없는 직접 실행도 지원한다. 모든 내보내기에 이 파일을 포함하며 `.bytes`에는 Git LFS를 사용한다. 장면 스크립트가 로딩되지 않으면 빈 화면 대신 인증된 관문에서 재시도 안내를 표시한다.
- 진입 문구가 보이는 첫 화면에서만 우상단 로그아웃 버튼을 표시하고 실제 `SocialAuth.logout()`으로 자동 로그인 정보·서버 세션을 폐기한다. 로그인 확인 중에는 숨기며 인증/진입 처리 중에는 비활성화한다. 마지막 제공자 기록은 유지한다.
- Apple: 아직 준비 안내를 표시한다.
- 성공한 마지막 제공자만 앱 로컬 `user://login_history.cfg`에 저장하고 버튼 아래에 “마지막으로 들어온 문은 [해당 로고] 에요”로 표시한다. 기록이 없으면 행 전체를 숨긴다. 로그아웃 후에도 표시 기록은 유지하고 실제 토큰과 구분한다.
- 수동 로그아웃은 `SocialAuth.logout()`을 호출하면 안전한 로컬 인증 정리 후 로그인 화면으로 돌아간다. 이미 로그인 화면이면 이전 결과 모달을 닫는다. 모바일 표시 저장 실패이면 로그아웃/화면 이동을 완료로 처리하지 않는다.
- Android·iOS: 게임 `accessToken`은 메모리에서 15분 사용하고 `refreshToken`은 Android Keystore 기반 암호 저장/iOS Keychain에 보관한다. 재실행·전경 복귀·만료 전 갱신으로 자동 유지하며 성공 갱신마다 비활성 만료를 다시 30일로 연장한다.
- Windows·macOS도 모바일과 같은 자동 로그인을 사용한다. `accessToken`은 15분·메모리, `refreshToken`은 갱신 후 30일·OS 안전 저장소에 보관한다. Windows 사용자 DPAPI 암호화와 macOS Keychain을 사용하며 토큰을 일반 설정 파일이나 프로세스 인자에 넣지 않는다. [로그인 유지 정책](../setting/docs/development/SESSION_LIFECYCLE.md)의 예외·폐기·검증 상태를 따른다. Windows 암호화 헬퍼만 격리 실행 검증했으며 클라이언트/Godot 컴파일과 Mac 실행은 생략했다. 모바일 공통 브리지는 추후 다시 빌드해야 한다.
- 비밀번호 입력·가입 폼·가짜 로그인 세션 없음.
- 움직임: 도트 잎 34개가 흩날리고 뒤집히며 초록 잎 영역에 바람 흔들림을 적용한다. 굴뚝 3곳에서 선명한 계단형 연기가 커지면서 올라가고 서서히 사라진다. 입자는 초당 최대 24회 갱신하며 건물과 UI는 고정한다. 주민 걷기 애니메이션은 아직 없음.

`assets/`에는 실행에 쓰는 리소스만 둔다. `../setting/assets/art/`는 기존 선택 원본과 기획 자료를 보관한다. 공식 심볼의 클라이언트 사본은 `assets/branding/app-symbol.png`이며 원본과 동일하다. 새 마을 배경은 선택한 마을을 참조해 로그인용으로 생성한 파생 이미지이며 실제 탐방 맵 데이터가 아니다.

`scripts/social_auth.gd`는 제공자 연결 지점이며 비밀키를 넣지 않는다. `scripts/app_config.gd`는 환경별 API 주소와 공통 키보드 이동 액션을 관리한다. 실제 이동 장면과 조이스틱은 후속 범위다.

Windows 실행 및 빌드는 `../setting/scripts/` 도구를 사용한다. Mac에서는 동일 Godot 버전과 템플릿을 설치하고 프로젝트를 열어 실행한다. iOS 내보내기는 macOS·Xcode 및 Apple Team ID가 필요하다. 자세한 절차는 `../setting/docs/development/SETUP.md`를 따른다.

카카오 공개 네이티브 키는 Git 제외 `config/kakao.local.cfg`에서 읽는다. 네이버 공식 모바일 SDK는 Client ID·Secret 초기화가 필요하므로 Git 제외 `config/naver.local.cfg`를 모바일에만 포함한다. PC 내보내기에서는 제외하며 DB 비밀값·카카오 시크릿은 포함하지 않는다. 두 SDK는 `native/android`, `native/ios`와 기존 `addons/kakao_login`의 공통 브리지로 구성한다. 이번 패치는 빌드·컴파일 없이 소스 점검만 수행했다. 세부 사항은 `../setting/docs/development/NAVER_LOGIN.md`를 따른다.

## 리소스 출처

- 로그인 마을 배경: 내장 이미지 생성 도구. 프롬프트 `../setting/assets/art/prompts/login-village-background.txt`.
- 앱 심볼: 사용자 채택 03. 원본 `../setting/assets/art/branding/dothanjan-app-symbol.png`.
- 로그인 상단 심볼: 배경·테두리 없는 `assets/branding/app-symbol-transparent.png`. 내장 이미지 생성 도구로 만든 투명 파생본이며 기존 앱 설치 아이콘·부트 이미지는 유지한다.
- Dongle 폰트: [Google Fonts](https://github.com/google/fonts/tree/main/ofl/dongle), SIL OFL. `assets/fonts/OFL-Dongle.txt` 동봉.
- Godot 엔진: [MIT 라이선스](https://godotengine.org/license/). 배포 시 엔진·의존 라이선스 고지를 포함한다.
