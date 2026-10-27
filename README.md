# 클라이언트

Godot 4.7.2 일반판에서 `project.godot`를 연다. Windows·macOS·iOS·Android 공통 GDScript 프로젝트이며 Compatibility 렌더러를 사용한다.

현재 첫 화면은 `scenes/login.tscn`이다. 1280×720을 기준으로 가로 화면에서 확장되며 마을 배경은 비율을 유지해 채운다. PC 창 크기를 변경할 수 있다. 소셜 로그인 버튼은 클릭·터치를 받는다.

- 카카오·네이버: 모든 대상 플랫폼에 표시.
- Apple: iOS·macOS에 표시. 개발 전용 `--preview-apple`로 다른 OS에서도 UI 확인 가능.
- 카카오: Android·iOS는 공식 SDK의 저장 토큰 확인·카카오톡 로그인·카카오계정 대체 로그인, Windows·macOS는 웹 브라우저 인증을 사용한다. 서버 검증·자동 가입/로그인 성공 후 같은 첫 장면의 공통 진입 관문으로 표시한다. 실패만 공통 모달로 안내한다.
- 네이버: Android·iOS 공식 SDK의 저장 로그인 정보 재사용·네이버 앱 우선·브라우저 대체 로그인과 PC 브라우저 인증을 연결했다. 성공하면 카카오/자동 복원과 동일한 진입 관문을 사용하고 실패만 모달로 안내한다. 이번 패치의 빌드·컴파일·실기기 확인은 실행하지 않았다.
- 인증된 세션이면 우측 로그인 박스를 숨기고 하단 중앙에 “터치해서 들어가요.”를 표시한다. 부제와 동일한 Dongle 29px·왼쪽 문구의 색과 그림자를 공유한다. 진입 뒤 현재 계정을 조회하고 사장님/가게 이름이 없으면 `scenes/owner_setup.tscn`의 05번 책 화면을 연다. 미인증·만료·로그아웃은 기존 로그인 UI다.
- 책 왼쪽 3×3의 확정 9종 중 선택하고 이름 중복확인을 마친 뒤 시작을 누르면, 공통 모달에서 사장님 이름과 찻집 이름을 최종 확인한다. 확인하면 서버에 영구 저장하고 책을 덮는 연출 후 카페로 들어간다. 취소는 저장하지 않는다. 확정 캐릭터/이름은 변경 불가이며 인게임에는 도감 복귀 버튼이 없다. 재접속은 저장된 프로필로 바로 카페에 진입한다.
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

- 공통 BGM: 사용자 제공 ‘도트한잔’ 음원. 실제 MP4/AAC 원본을 MP3로 변환한 `assets/audio/dothanjan-bgm.mp3`/동일 `.bytes`를 사용한다. `BackgroundMusic` 자동 로드로 첫 화면부터 인게임까지 재생 위치를 유지하고, 곡 종료 후 2초 쉬고 반복한다. 출처/원본/변환 기록은 `../setting/assets/audio/dothanjan-bgm.md`다. 기본 재생 음량은 -10 dB이며 장면/로그아웃 때 다시 시작하지 않는다.
- 로그인 마을 배경: 내장 이미지 생성 도구. 프롬프트 `../setting/assets/art/prompts/login-village-background.txt`.
- 앱 심볼: 사용자 채택 03. 원본 `../setting/assets/art/branding/dothanjan-app-symbol.png`.
- 로그인 상단 심볼: 배경·테두리 없는 `assets/branding/app-symbol-transparent.png`. 내장 이미지 생성 도구로 만든 투명 파생본이며 기존 앱 설치 아이콘·부트 이미지는 유지한다.
- Dongle 폰트: [Google Fonts](https://github.com/google/fonts/tree/main/ofl/dongle), SIL OFL. `assets/fonts/OFL-Dongle.txt` 동봉.
- Godot 엔진: [MIT 라이선스](https://godotengine.org/license/). 배포 시 엔진·의존 라이선스 고지를 포함한다.


Windows 한글 입력 회귀 대응: setting/Start-Game.cmd는 공식 Godot 4.7.1 실행 엔진을 사용한다. 4.7.2의 Windows 한글 음절 덮어쓰기 버그를 피하기 위한 병행 설치이며, 상세 설치/향후 Windows 템플릿 준비는 setting/docs/development/SETUP.md를 따른다.


찻집 이름 입력창 내부 오른쪽의 중복확인 버튼은 인증된 백엔드 조회를 사용한다. 빈 입력 또는 한글·영문 대소문자·숫자 이외 문자가 있으면 비활성화한다. 잘못된 형식 안내는 입력창 아래에 표시하고 허용 문자 세 종류를 강조한다. 입력 변경/한글 조합 시 확인 결과가 초기화되고, 확인 도중 수정된 이름의 응답은 반영하지 않는다. 중복확인 버튼은 입력 포커스를 가져가지 않으며, 명시적 확인 클릭 때 조합 중인 한글을 커서 위치에 포함한 이름을 먼저 보존한 뒤 편집을 끝낸다. OS 입력 알림이 처리되는 한 프레임 동안만 입력을 잠그며, 조합 종료로 값이 달라졌다면 이 클릭의 보존값을 한 번 복구한 후 조회한다. 평소 타이핑 값/커서는 재설정하지 않는다. 중복확인은 조회만 하며 예약/저장을 하지 않는다. 작은 발바닥과 “시작”을 표시하는 버튼은 책 오른쪽 페이지 세로 중앙, 오른쪽 가장자리에 반쯤 걸치며 안전 영역 안에 둔다. 현재 이름의 중복확인 성공 때만 활성화한다. 최종 확인 모달의 확인에서 영구 저장하고 책을 덮어 카페를 연다.

책 닫힘 전환은 `BookTransition`, 첫 카페는 `scenes/game.tscn`이다. 왼쪽 면을 덮고(1.45초), 중앙 초록 표지에 찻집 이름을 보여준 뒤(1초), 책과 이름이 함께 아래로 내려가며(0.95초) 준비된 카페를 드러낸다. 전환 중 입력을 차단하고 정지 원본 책은 숨겨 중복 윤곽을 방지한다. 05 꽃향기 머무는 찻집 파생 배경 및 원본 사장님을 유지한다. 배경/프롬프트는 `../setting/assets/art/backgrounds/cafe-01-interior-day-clear.md`, 소리는 원본 합성 WAV다. 영업·재화·산책은 후속 범위다.

책을 닫을 때 드러나는 배경은 원본과 동일 크기의 `assets/backgrounds/owner-book-clean-plate.png`/`.png.bytes`다. `owner_book_art.gd`가 완성 배경을 먼저 준비하고 `BookTransition`의 backdrop_texture로 전달한다. 책상 일부를 늘리는 처리 대신 실제 완성된 방 이미지를 사용한다. 생성 출처/프롬프트는 `../setting/assets/art/backgrounds/owner-book-clean-plate.md`에 보관한다.

카페 좌상단은 선택한 사장님 원본 이미지와 ‘도트한잔’/계정 가게 이름을 두 줄로 표시하는 프로필 카드다. 표시 전용으로 클릭 동작은 아직 연결하지 않는다. 모바일 안전 영역과 긴 이름의 말줄임을 반영한다.

카페 우상단의 세 줄 버튼은 오른쪽 슬라이드 메뉴를 연다. 목록은 현재 하단 로그아웃만 제공하며 기존 세션 정리 후 로그인 화면으로 복귀한다. 닫기·바깥 터치·Esc와 모바일 안전 영역을 지원하고 배경 음악은 이어진다. 구현은 `ui/tea_side_menu.gd`다.

프로필 카드는 276×98로 줄이고, 왼쪽 78×78 칸에는 원본 PNG의 얼굴·귀·상반신 영역을 AtlasTexture로 확대 표시한다. 원본/인게임 캐릭터 비율을 유지하며 게임 이름은 연하게, 가게 이름은 또렷하게 표시한다.
