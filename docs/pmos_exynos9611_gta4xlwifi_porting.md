# Exynos 9611 (gta4xlwifi) 포팅 가이드

> 대상 기기: Samsung Galaxy Tab S6 Lite (2020) Wi-Fi - codename `gta4xlwifi`
> SoC: Samsung Exynos 9611
> postmarketOS Wiki 기반 (CC BY-SA 4.0)

**관련 위키 페이지:**
- https://wiki.postmarketos.org/wiki/Samsung_Exynos_9610 (9611 정보 포함)
- https://wiki.postmarketos.org/wiki/Exynos_mainline_porting
- https://wiki.postmarketos.org/wiki/Mainlining

---

## Exynos 9611 개요

Exynos 9611은 Exynos 9610의 변형으로, **ISP가 개선**되고 **GPU 클럭이 낮아진**(850 MHz) 버전입니다.
나머지 스펙은 Exynos 9610과 동일합니다.

| 항목 | 내용 |
|---|---|
| 제조사 | Samsung |
| 아키텍처 | aarch64 |
| CPU | 4x Cortex-A73 2.3 GHz + 4x Cortex-A53 1.7 GHz |
| GPU | Mali-G72 MP3 **850 MHz** (9610은 1053 MHz) |
| 출시 | 2018년 |
| 공정 | 10nm |
| Mainline 지원 | **WIP** (LKML에 패치 존재) |

### Exynos 9610 vs 9611 차이

| 항목 | Exynos 9610 | Exynos 9611 |
|---|---|---|
| GPU 클럭 | 1053 MHz | 850 MHz |
| ISP | 기본 | 개선됨 |
| CPU | 동일 (4xA73 2.3GHz + 4xA53 1.7GHz) | 동일 |

### Exynos 9609

Exynos 9609는 9610의 언더클럭 버전입니다 (Cortex-A73 2.2 GHz, Cortex-A53 1.6 GHz, GPU 850 MHz).
Motorola One Action (motorola-troika)에 사용됨.

### 지원 현황 (2026-01 기준)

| 구성 요소 | 상태 |
|---|---|
| CPU SMP / Frequency scaling / CPUidle | Partial |
| UART | Untested |
| Storage (eMMC, SD) | Untested |
| USB | Untested |
| Display | Untested |
| GPU | Untested |
| Pinctrl | Partial |
| I²C | Untested |
| SPI | Untested |
| Audio | Untested |
| Video | Untested |
| Thermal | Untested |
| WiFi | Untested |
| Bluetooth | Untested |
| Modem | Untested (Wi-Fi 모델은 Modem 없음) |
| Camera | Untested |

> **참고:** WiFi 모델(gta4xlwifi)은 Modem(셀룰러)이 없으므로 Modem 포팅 불필요.

### Exynos 9611 기기 목록

| 기기 | 코드네임 | 카테고리 |
|---|---|---|
| **Samsung Galaxy Tab S6 Lite (2020)** | **samsung-gta4xl** | **(등록 안 됨 / downstream)** |
| **Samsung Galaxy Tab S6 Lite (2020) Wi-Fi** | **gta4xlwifi** | **대상 기기** |
| Samsung Galaxy A51 | samsung-a51 | downstream |
| Samsung Galaxy XCover Pro | samsung-xcoverpro | |

> gta4xlwifi는 gta4xl (LTE 모델)의 Wi-Fi 전용 변형입니다.
> 하드웨어 차이는 Modem 유무뿐이므로, gta4xl용 DTS를 기반으로 gta4xlwifi용 DTS 작성 가능.

### Contributors

- Al3x (Exynos 9610 페이지 작성)

### Mainline Status

WIP patches for mainline support are available in LKML.

---

## Exynos 메인라이닝 기본 정보

> 출처: https://wiki.postmarketos.org/wiki/Exynos_mainline_porting

### 지원되는 Exynos SoC (ARM64)

2014년까지 출시된 대부분의 Exynos ARM SoC는 mainline Linux에서 잘 지원됩니다.
ARM64의 경우 Samsung이 mainline 기여를 거의 하지 않아 지원이 제한적입니다.

**어느 정도 지원되는 ARM64 Exynos:**

| SoC | Arch | Year | Mainline | 비고 |
|---|---|---|---|---|
| Exynos5433 | aarch64 | 2014 | Yes | 최초 ARM64 Exynos |
| Exynos7 (7420) | aarch64 | 2015 | Yes | |
| **Exynos 7885** | **aarch64** | **2018** | **Yes** | **9611과 가장 유사 (mid-range, Mali GPU)** |
| Exynos850 (3830) | aarch64 | 2020 | Yes | 최신 참고 대상 |
| Exynos8895 | aarch64 | 2017 | Yes | |
| Exynos990 | aarch64 | 2020 | Yes | |
| ExynosAuto v9 / v920 | aarch64 | - | Yes | |
| Tesla FSD | aarch64 | - | Yes | |
| Google Tensor (S5E9845) | aarch64 | 2021 | Yes | |

> **Exynos 7885**가 9611과 가장 유사한 시기에 출시된 mid-range SoC로, Mali GPU를 사용하며 mainline 지원이 완료되어 있어 **최고의 참고 대상**입니다.

### Bootloaders

- **Galaxy Tab S6 Lite (2020)**: S-BOOT (U-Boot 기반, 2020년 이전 기기)

**S-BOOT 특이사항:**
- DECON 방식: `HW_SW_TRIG_CONTROL` 비트를 설정해야 framebuffer 새로고침
- 일부 개정판에서 `CNTFRQ_EL0` 미설정 -> `exynos-usbdl` 익스플로잇으로 설정하거나 timer 노드에 주파수 하드코딩
- 부트로더가 device tree를 특정 형식으로 요구하고 부팅 전 수정함
- **2차 부트로더 사용을 강력히 권장:**
  - `uniloader` (추천, 다양한 Exynos 변형 지원)
  - `minimal_sboot_wrapper` (Exynos 7885용, 9611에도 적용 가능)

### Useful Repositories

| 저장소 | 설명 |
|---|---|
| **krzk** | 여러 Exynos SoC용 Samsung 커널 소스 브랜치 |
| **VDavid003** | **Exynos 7885** 관련 브랜치 (가장 유용!) |
| ivoszbg | Exynos 8895 관련 브랜치 |
| dsankouski | Exynos 7880 관련 브랜치 |

### Exynos 메일링 리스트 및 채팅

| 채널 | 설명 |
|---|---|
| `#postmarketOS-mainline` | postmarketOS 메인라인 일반 |
| `#exynos-arm64-mainline:envs.net` (Matrix) | ARM64 Exynos 메인라이닝 |
| `#linux-exynos` on Libera.chat | Exynos Linux 일반 |
| `linux-samsung-soc@vger.kernel.org` | Samsung SoC 메일링 리스트 |
| `#exynos4xxx-mainline:matrix.org` | Exynos 4xxx |
| `#exynos5-mainline:matrix.org` | Exynos 5xxx |

---

## 전체 메인라이닝 가이드

> 출처: https://wiki.postmarketos.org/wiki/Mainlining

### 개요

Mainlining = 기기 제조사 제공 커널(downstream)을 kernel.org의 최신 커널(mainline)로 교체하는 과정.

**왜 메인라이닝을 해야 하는가?**
- 보안 패치 및 최신 커널 개선 사항 활용 가능
- GPU 지원 용이 (PowerVR 제외 거의 모든 GPU)
- 표준 Linux 배포판 실행 가능
- 단, downstream 코드를 그대로 복사하지 말고 **이해한 후 다시 작성**해야 함

### Phase 1: 준비

- [ ] **Samsung OSS**에서 Galaxy Tab S6 Lite (gta4xlwifi) 커널 소스 다운로드
  - https://opensource.samsung.com/ 에서 검색
- [ ] **LineageOS** 커널 소스 확보 (gta4xlwifi)
  - https://github.com/LineageOS/android_kernel_samsung_exynos9610
- [ ] **mainline Linux** 최신 버전 클론: `torvalds/linux.git`
- [ ] **krzk 저장소** 등 Exynos 관련 브랜치 확인
- [ ] **UART 위치 찾기**: 테스트 포인트 또는 서비스 매뉴얼 검색
- [ ] 기기 회로도/서비스 매뉴얼 검색

### Phase 2: 기본 부팅

- [ ] Exynos **7885** 또는 **Exynos850** DTS를 기반으로 Exynos 9611 DTS 작성
  - 최소 구성: CPU 클러스터, GIC, 타이머, UART, pinctrl
- [ ] `uniloader` 또는 `minimal_sboot_wrapper`로 2차 부트로더 설정
- [ ] **UART**로 부팅 로그 확인 (초기 디버깅에 가장 중요)
- [ ] ramoops/pstore 설정 (UART가 안 될 경우 대비)

**중요:** 절대 downstream 코드를 복사하지 말 것. 대신 동작을 이해하고 mainline 스타일로 다시 작성.

### Phase 3: 필수 기능

- [ ] Pinctrl (GPIO) 설정
- [ ] I²C 설정
- [ ] eMMC / SD 카드 스토리지
- [ ] USB 컨트롤러
- [ ] 클럭(Clock) 프레임워크

### Phase 4: 고급 기능

- [ ] **Mali-G72 GPU** - panfrost 드라이버
- [ ] **MIPI-DSI 디스플레이** 패널
- [ ] 오디오 (I2S)
- [ ] **WiFi** (gta4xlwifi는 WiFi 전용, Modem 없음)
- [ ] Bluetooth
- [ ] 배터리/충전
- [ ] 카메라
- [ ] Suspend/전원 관리

### Phase 5: 업스트리밍

- [ ] 구성 요소별로 패치 분할 (하나의 큰 패치 금지)
- [ ] `git send-email`로 LKML 전송
- [ ] `linux-samsung-soc@vger.kernel.org`에 CC
- [ ] 피드백 반영 및 수정

---

## 참고 자료 (Mainlining 페이지에서 발췌)

### Device Tree

- DTS 101: From Roots To Trees (34:06)
- Device Tree 101, 2021 (1:54:58)
- Device Tree bindings: `Documentation/devicetree/bindings` 디렉토리
- Device Tree Usage (elinux.org)

### 영상 자료

- Porting mainline Linux to mobile phones, Luca Weiss, 2022 FOSDEM
- ARM64 SoC Linux Support Check-List, 2017 - **매우 유용한 단계별 가이드**
- Introduction into how mainlining is done, 2017

### 추천 도서

- Mastering Linux Device Driver Development (2021, John Madieu)
- Linux Driver Development for Embedded Processors (2018, Alberto Liberal De Los Ríos)

### Exynos 관련

- https://exynos.wiki.kernel.org
- knuxify의 디스플레이 포팅 블로그: https://knuxify.github.io/blog/2023/04/tab3-display.html

### 업스트리밍

- https://git-send-email.io/ (git send-email 튜토리얼)
- https://wiki.postmarketos.org/wiki/Submitting_Patches#Linux
- Documentation/process/submitting-patches.rst (커널 소스 내 문서)

---

## gta4xlwifi 관련 추가 정보

### Samsung OSS 커널 소스

Samsung Open Source Release Center에서 `SM-P610` (gta4xlwifi) 또는 `SM-P615` (gta4xl) 검색:
- https://opensource.samsung.com/

### LineageOS 커널

- https://github.com/LineageOS/android_kernel_samsung_exynos9610

### 유사 기기 참고

| 기기 | SoC | 코드네임 | 비고 |
|---|---|---|---|
| Galaxy Tab S6 Lite (LTE) | Exynos 9611 | gta4xl | WiFi 모델과 거의 동일 + Modem |
| Galaxy A51 | Exynos 9611 | samsung-a51 | 동일 SoC, phone |
| Galaxy A50 | Exynos 9610 | samsung-a50 | 매우 유사한 SoC |

### 알려진 포팅 프로젝트

- https://gitlab.com/postmarketOS/pmaports (pmaports 저장소)
- https://github.com/exynos9611-mainline (커뮤니티 메인라인 프로젝트 검색)

---

## 도움 요청

| 문제 | 연락처 |
|---|---|
| 일반 포팅 질문 | `#postmarketOS-mainline` Matrix/IRC |
| Exynos 질문 | `#exynos-arm64-mainline:envs.net` Matrix |
| Samsung SoC | `linux-samsung-soc@vger.kernel.org` |
| pmaports 이슈 | https://gitlab.com/postmarketOS/pmaports/-/issues |

---

## 참고 문헌

- https://wiki.postmarketos.org/wiki/Samsung_Exynos_9610
- https://wiki.postmarketos.org/wiki/Exynos_mainline_porting
- https://wiki.postmarketos.org/wiki/Mainlining
- https://exynos.wiki.kernel.org
- https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
