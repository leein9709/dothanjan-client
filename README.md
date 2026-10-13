# 클라이언트

Godot 4.7.2 일반판에서 `project.godot`를 연다. Windows·macOS·iOS·Android 공통 GDScript 프로젝트이며 Compatibility 렌더러를 사용한다.

현재 첫 화면은 `scenes/login.tscn`이다. 1280×720을 기준으로 가로 화면에서 확장되며 마을 배경은 비율을 유지해 채운다. PC 창 크기를 변경할 수 있다. 소셜 로그인 버튼은 클릭·터치를 받는다.

- 카카오·네이버: 모든 대상 플랫폼에 표시.
- Apple: iOS·macOS에 표시. 개발 전용 `--preview-apple`로 다른 OS에서도 UI 확인 가능.
- 로그인 버튼: 아직 외부 인증을 시작하지 않고 준비 중 안내 표시.
- 비밀번호 입력·가입 폼·가짜 로그인 세션 없음.
- 움직임: 도트 잎 34개가 흩날리고 뒤집히며 초록 잎 영역에 바람 흔들림을 적용한다. 굴뚝 3곳에서 선명한 계단형 연기가 커지면서 올라가고 서서히 사라진다. 입자는 초당 최대 24회 갱신하며 건물과 UI는 고정한다. 주민 걷기 애니메이션은 아직 없음.

`assets/`에는 실행에 쓰는 리소스만 둔다. `../setting/assets/art/`는 기존 선택 원본과 기획 자료를 보관한다. 공식 심볼의 클라이언트 사본은 `assets/branding/app-symbol.png`이며 원본과 동일하다. 새 마을 배경은 선택한 마을을 참조해 로그인용으로 생성한 파생 이미지이며 실제 탐방 맵 데이터가 아니다.

`scripts/social_auth.gd`는 제공자 연결 지점이며 비밀키를 넣지 않는다. `scripts/app_config.gd`는 환경별 API 주소와 공통 키보드 이동 액션을 관리한다. 실제 이동 장면과 조이스틱은 후속 범위다.

Windows 실행 및 빌드는 `../setting/scripts/` 도구를 사용한다. Mac에서는 동일 Godot 버전과 템플릿을 설치하고 프로젝트를 열어 실행한다. iOS 내보내기는 macOS·Xcode 및 Apple Team ID가 필요하다. 자세한 절차는 `../setting/docs/development/SETUP.md`를 따른다.

## 리소스 출처

- 로그인 마을 배경: 내장 이미지 생성 도구. 프롬프트 `../setting/assets/art/prompts/login-village-background.txt`.
- 앱 심볼: 사용자 채택 03. 원본 `../setting/assets/art/branding/dothanjan-app-symbol.png`.
- 로그인 상단 심볼: 배경·테두리 없는 `assets/branding/app-symbol-transparent.png`. 내장 이미지 생성 도구로 만든 투명 파생본이며 기존 앱 설치 아이콘·부트 이미지는 유지한다.
- Dongle 폰트: [Google Fonts](https://github.com/google/fonts/tree/main/ofl/dongle), SIL OFL. `assets/fonts/OFL-Dongle.txt` 동봉.
- Godot 엔진: [MIT 라이선스](https://godotengine.org/license/). 배포 시 엔진·의존 라이선스 고지를 포함한다.
