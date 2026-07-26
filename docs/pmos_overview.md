# postmarketOS 개요 및 포팅 기본

> 출처: https://wiki.postmarketos.org/wiki/Main_Page
> Installation: https://wiki.postmarketos.org/wiki/Installation
> Contributing: https://wiki.postmarketos.org/wiki/Contributing
> Devices: https://wiki.postmarketos.org/wiki/Devices

---

## postmarketOS란?

postmarketOS는 Alpine Linux를 기반으로 스마트폰 및 기타 모바일 기기에서 동작하도록 확장한 Linux 배포판입니다.

### 주요 섹션

| 섹션 | 설명 |
|---|---|
| **Devices** | 지원 기기 목록 |
| **User Interfaces** | 사용 가능한 UI (Plasma Mobile, Phosh, Sway 등) |
| **Apps** | 애플리케이션 |
| **Gallery** | 스크린샷 갤러리 |
| **Community** | 커뮤니티 참여 |
| **Installation** | 설치 가이드 |
| **Porting** | 포팅 (현재 위키 페이지는 비어 있음) |
| **Mainlining** | 메인라인 커널 포팅 |
| **More Guides** | 추가 가이드 |
| **Contributing** | 기여 방법 |
| **Technical Reference** | 기술 참고 자료 |
| **Troubleshooting** | 문제 해결 |

---

## Installation (설치)

> 출처: https://wiki.postmarketos.org/wiki/Installation

### 주의사항

postmarketOS는 Linux 애호가를 위한 프로젝트입니다. Android나 iOS처럼 완성된 경험을 기대하지 마세요.
통화 불가, SMS 미수신, 알람 미작동 등의 심각한 버그가 있을 수 있습니다.
**주 사용폰으로 사용하지 마세요.**

### 기기 찾기

설치 전에 기기의 위키 페이지를 반드시 읽으세요:
- 지원 기능 목록
- 설치 방법
- Devices 목록 또는 검색으로 확인
- 기기가 목록에 없거나 non-booting 상태면 아직 미지원 -> Porting 가이드 참고

### 릴리스 채널 선택

| 채널 | 설명 |
|---|---|
| **stable** | 최신 안정 릴리스 (Alpine Linux 기반, 현재 v25.12) |
| **edge** | 롤링 릴리스 (Alpine edge 저장소 기반, 최신 업데이트, 덜 안정적) |

### 설치 방법

#### 1. 프리빌드 이미지 사용
- main/community 카테고리 기기 대상
- 가장 빠르고 간단: 플래시만 하면 됨

#### 2. pmbootstrap으로 설치
- 모든 기기 지원 (이미지 없는 기기도 가능)
- UI, 패키지 등 커스터마이징 가능
- 개발자/고급 사용자에게 적합

#### 3. 기타 설치 방법
- **PC 설치:** OS Installer (그래픽 설치 프로그램)
- **Web Flasher:** Chromium 기반 브라우저에서 웹플래싱
- **Recovery .zip:** Android recovery 호환 zip으로 설치
- **UBports Installer:** 일부 main/community 기기

### 참고
- Dual Booting
- Upgrade to a newer postmarketOS release
- Existing Alpine installation
- Porting to a new device

---

## Porting (포팅) 개요

> postmarketOS 위키의 `Porting` 페이지는 현재 내용이 비어 있습니다.
> 실제 포팅 관련 내용은 아래 페이지들에서 다루고 있습니다.

### 포팅 관련 페이지

| 페이지 | 설명 |
|---|---|
| **Mainlining** | 메인라인 커널 포팅 전반 |
| **Qualcomm Mainline Porting** | Qualcomm SoC 포팅 가이드 |
| **Exynos Mainline Porting** | Exynos SoC 포팅 가이드 |
| **MSM8916 Mainlining** | MSM8916 특화 포팅 |
| **MSM8996 Mainlining** | MSM8996 특화 포팅 |
| **SDM845 Mainlining** | SDM845 특화 포팅 |
| **SM7150 Mainlining** | SM7150 특화 포팅 |

### 포팅 기본 흐름

1. 기기 선택 및 정보 수집
2. pmbootstrap으로 기기 포트 생성
3. Downstream 커널 컴파일 및 부팅 테스트
4. Mainline 커널 포팅 (Mainlining 참고)
5. 기기별 기능 구현 (디스플레이, 오디오, WiFi 등)
6. UI 부팅 확인
7. 업스트리밍

---

## Contributing (기여)

> 출처: https://wiki.postmarketos.org/wiki/Contributing

postmarketOS에 기여하는 방법:
- 코드 기여 (커널 패치, 패키지, UI 등)
- 위키 문서화
- 버그 리포트
- 테스팅
- 커뮤니티 지원

자세한 내용은 위키의 Contributing 페이지 및 각 서브페이지 참고.

---

## 참고 링크

- https://wiki.postmarketos.org/wiki/Main_Page
- https://wiki.postmarketos.org/wiki/Installation
- https://wiki.postmarketos.org/wiki/Devices
- https://wiki.postmarketos.org/wiki/Contributing
- https://postmarketos.org/
