# 소셜 로그인 아이콘

- 카카오: 노란 원 + 검은 TALK 말풍선.
- 네이버: 초록 원 + 흰 N.
- Apple: 검은 원 + 흰 Apple 심볼.

사용자 첨부는 `setting/assets/art/references/login-icons/`에 보존했다(프로젝트 루트 기준). SVG에는 로고만 있고 원형 배경은 `login.gd`에서 그린다. 1280×720 기준 원 지름 60, 버튼 클릭 영역 80×80, 원 사이 간격 24다. 2개·3개 모두 같은 패널 안에서 가로 중앙 정렬한다.

로고 경로는 [Simple Icons](https://github.com/simple-icons/simple-icons)에서 2026-10-12에 가져왔다. 동봉한 `LICENSE-Simple-Icons.md` 참고. 원본 SVG는 `setting/assets/art/sources/social-icons/`에 보관한다. 카카오는 사각 배경 경로를 제외하고 말풍선·TALK 경로를 분리했다. 사용자 첨부 PNG는 변형하지 않았다.

- https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/kakaotalk.svg
- https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/naver.svg
- https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/apple.svg
