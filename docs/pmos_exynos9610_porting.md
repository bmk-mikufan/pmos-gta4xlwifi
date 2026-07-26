# Exynos 9610 포팅 가이드

> postmarketOS Wiki 기반 (CC BY-SA 4.0)
> Samsung Exynos 9610: https://wiki.postmarketos.org/wiki/Samsung_Exynos_9610
> Exynos mainline porting: https://wiki.postmarketos.org/wiki/Exynos_mainline_porting
> Mainlining: https://wiki.postmarketos.org/wiki/Mainlining

---

## Exynos 9610 개요

| 항목 | 내용 |
|---|---|
| 제조사 | Samsung |
| 아키텍처 | aarch64 |
| CPU | 4x Cortex-A73 2.3 GHz + 4x Cortex-A53 1.7 GHz |
| GPU | Mali-G72 MP3 1053 MHz |
| 출시 | 2018년 3월 |
| 공정 | 10nm |
| Mainline 지원 | yes (WIP) |

**변형:**
- **Exynos 9609**: 9610의 언더클럭 버전 (Cortex-A73 2.2 GHz, Cortex-A53 1.6 GHz, GPU 850 MHz)
- **Exynos 9611**: 9610의 변형 (ISP 개선, GPU 850 MHz)

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
| Modem | Untested |
| Camera | Untested |

### Mainline Status

WIP patches for mainline support are available in LKML.

### Exynos 9610 기기 목록

| 기기 | 코드네임 | 카테고리 |
|---|---|---|
| Samsung Galaxy A50 | samsung-a50 | downstream |

### Exynos 9611 기기 목록

| 기기 | 코드네임 | 카테고리 |
|---|---|---|
| Samsung Galaxy A51 | samsung-a51 | downstream |
| Samsung Galaxy Tab S6 Lite (2020) | samsung-gta4xl | |
| Samsung Galaxy XCover Pro | samsung-xcoverpro | |

### Exynos 9609 기기 목록

| 기기 | 코드네임 | 카테고리 |
|---|---|---|
| Motorola One Action | motorola-troika | |

**참고:** `downstream` 카테고리는 아직 mainline 커널을 사용하지 않고 제조사 제공 커널을 사용함을 의미합니다.

---

## Exynos 메인라이닝 기본 정보

> 출처: https://wiki.postmarketos.org/wiki/Exynos_mainline_porting

### 지원되는 Exynos SoC (ARM64)

2014년까지 출시된 대부분의 Exynos ARM SoC는 mainline Linux에서 잘 지원됩니다.
ARM64의 경우 Samsung이 mainline 기여를 거의 하지 않아 지원이 제한적입니다.

**어느 정도 지원되는 ARM64 Exynos:**
- Exynos5433
- Exynos7 (Exynos7420 초기 개정판)
- **Exynos7885** (9610과 유사한 계열)
- Exynos850 (Exynos3830)
- Exynos8895
- Exynos990
- ExynosAuto v9 / v920
- Tesla FSD
- Google Tensor (S5E9845)

**참고:** Exynos 9610은 아직 메인라인 지원이 WIP 단계입니다. 아래 나열된 SoC들의 코드와 방식을 참고하여 포팅을 진행해야 합니다.

### Bootloaders

- **2020년 이전 기기:** S-BOOT (U-Boot 기반) -> Galaxy A50(A50s)는 S-BOOT 사용
- **2020년 이후 기기:** S-LK

**S-BOOT/S-LK 특이사항:**
- 2016년 이후 DECON 방식 기기: `HW_SW_TRIG_CONTROL` 비트를 설정해야 framebuffer가 새로고침됨
- 일부 개정판에서 `CNTFRQ_EL0`가 설정되지 않은 상태로 남음 -> exynos-usbdl 익스플로잇으로 설정하거나 timer 노드에 주파수 하드코딩 필요
- 부트로더가 device tree를 특정 형식으로 요구하고 부팅 전 수정함
- **2차 부트로더 사용을 강력히 권장:** `uniloader` (추천, 다양한 Exynos 변형 지원) 또는 `minimal_sboot_wrapper`

### Exynos SoC 메인라인 지원 표

| SoC | Arch | Year | Mainline | GPU |
|---|---|---|---|---|
| Exynos 2200 | aarch64 | 2022 | Yes | Xclipse 920 |
| Exynos 3250 | armv7 | 2014 | Yes | Mali-400 |
| Exynos 4210 | armv7 | 2011 | Yes | Mali-400MP4 |
| Exynos 4412 | armv7 | 2012 | Yes | Mali-400 |
| Exynos 5250 | armv7 | 2012 | Yes | Mali-T604MP4 |
| Exynos 5420 | armv7 | 2013 | Yes | Mali-T628 MP6 |
| Exynos 5433 | aarch64 | 2014 | Yes | Mali-T760 |
| Exynos 7870 | aarch64 | 2016 | Yes | Mali-T830 MP1 |
| **Exynos 7885** | aarch64 | 2018 | **Yes** | **Mali-G71 MP2** |
| Exynos 8895 | aarch64 | 2017 | Yes | Mali-G71 MP20 |
| Exynos 9810 | aarch64 | 2017 | Yes | Mali-G72 MP18 |
| Exynos 990 | aarch64 | 2020 | Yes | Mali-G77 |
| **Exynos 9610** | **aarch64** | **2018** | **WIP** | **Mali-G72 MP3** |

> Exynos 7885는 9610과 유사한 시기에 출시된 mid-range SoC로, mainline 지원이 완료되어 있어 9610 포팅에 가장 좋은 참고 대상입니다.

### 포팅 접근법

Samsung은 Exynos SoC에 대한 사용자 매뉴얼을 더 이상 공개하지 않습니다.
ARM64 Exynos SoC 메인라이닝 접근법:

1. **이미 지원되는 SoC의 device tree와 드라이버를 연구** (Exynos850, Exynos7885 등)
2. **Vendor kernel**에서 해당 SoC의 device tree와 드라이버를 확인
3. **참고 SoC와 비교**하면서 mainline에서 받아들여질 수 있는 형식으로 "번역"
4. **작게 시작**: 초기에는 꼭 필요한 요소만 포함하고, 디버그 출력 방법(pstore/ramoops, simple-framebuffer, serial)을 먼저 확보

### Useful Repositories

- **krzk**: 여러 Exynos SoC용 Samsung 커널 소스 브랜치
- **PabloPL**: Exynos 7420, 7580, 8890 관련 브랜치
- **dsankouski**: Exynos 7880 관련 브랜치
- **VDavid003**: Exynos 7885 관련 브랜치
- **ivoszbg**: Exynos 8895 관련 브랜치

### Exynos 메일링 리스트 및 채팅

- `#linux-exynos` on Libera.chat
- `#exynos-arm64-mainline:envs.net` on Matrix (모든 arm64 SoC)
- `linux-samsung-soc@vger.kernel.org`
- `#exynos4xxx-mainline:matrix.org` (Exynos 4xxx)
- `#exynos5-mainline:matrix.org` (Exynos 5xxx)

---

## 전체 메인라이닝 가이드

> 출처: https://wiki.postmarketos.org/wiki/Mainlining

### 개요

Mainlining은 기기 제조사 제공 커널(downstream)을 kernel.org의 최신 커널(mainline)로 교체하는 과정입니다.
SoC별 공통 지원이 이미 mainline에 존재하는 경우 기기별 구성 요소에만 집중하면 됩니다.

### Getting Started (시작하기)

1. **기기 정보 수집:**
   - Downstream 커널 소스 코드 (Samsung OSS에서 Galaxy A50 커널 소스 확보)
   - 기기 사양
   - 회로도 (가능한 경우)

2. **직렬 디버깅(Serial debugging) 준비:**
   - UART 포트 위치 확인 (테스트 포인트 또는 USB/오디오 잭)
   - 초기 단계에서 가장 유용한 디버깅 방법

3. **커널 트리 선택:**
   - **Mainline** (`torvalds/linux.git`): 안정적이고 최신
   - **linux-next** (`next/linux-next.git`): 최신 변경사항 포함, WIP SoC에 유용
   - Exynos 특화 WIP 트리 확인 (krzk 저장소 등)

4. **`envkernel.sh` 사용** - postmarketOS에 커널 개발 통합

5. **절대 downstream 코드를 그대로 복사하지 말 것:**
   - 작동하지 않으며 mainline 업스트림에서 거부됨
   - downstream 코드의 동작을 이해하고 유사 코드 참고하여 **처음부터 다시 작성**

### 참고 영상 및 자료

#### 소개
- Porting mainline Linux to mobile phones, Luca Weiss, 2022 FOSDEM
- Introduction into how mainlining is done, 2017

#### 기초
- ARM64 SoC Linux Support Check-List, 2017 - SoC 지원 단계별 가이드
- Introduction into ARM architecture, 2017

#### Device Tree
- DTS 101: From Roots To Trees
- Device Tree 101, 2021
- Device Tree bindings: `Documentation/devicetree/bindings` 디렉토리 참고
- Device Tree Usage (elinux.org)

#### Exynos 관련
- https://exynos.wiki.kernel.org
- knuxify의 lt01wifi 디스플레이 포팅 블로그: https://knuxify.github.io/blog/2023/04/tab3-display.html

#### 업스트리밍
- `git send-email` 사용: https://git-send-email.io/
- Submitting Patches: https://wiki.postmarketos.org/wiki/Submitting_Patches#Linux
- Linux Kernel Mailing List (LKML)에 패치 전송

---

## Qualcomm 포팅 참고 (범용 팁)

> 출처: https://wiki.postmarketos.org/wiki/Qualcomm_mainline_porting

Qualcomm 포팅 가이드는 Exynos와 아키텍처가 다르지만, **전반적인 접근법과 디버깅 방법**은 동일하게 적용됩니다.

### 첫 단계 - 디버깅 출력 확보

mainline 커널 부팅 시 기기에서 피드백을 받을 방법이 반드시 필요합니다.

#### 1. UART (가장 유용)
초기 커널 메시지 및 부트로더 로그 확인 가능.
Galaxy A50의 UART 위치를 찾아야 합니다.

#### 2. Simple Framebuffer
부트로더가 framebuffer를 설정한 경우 가장 쉬운 방법.
패널 드라이버 없이도 화면에 로그 출력 가능.

#### 3. RAM Console / ramoops (최후의 수단)
신뢰성이 낮고 많은 경우 작동이 어려움.

### 전제 조건

- **Downstream 커널 소스 코드** (Samsung OSS, LineageOS 등)
- **회로도** (있다면 매우 도움됨 - 구성 요소 배선 및 잘못 모델링된 레귤레이터 확인)
- **유사 기기의 mainline 소스 코드** (Exynos 7885, Exynos850 등)

### 일반적인 접근법

1. 참고 기기의 DTS(DT) 복사 후 기기 정보 변경
2. 레귤레이터 전압 등 하드웨어 설정을 vendor DTS와 비교하여 조정
3. USB 디버깅 또는 UART로 부팅 로그 확인
4. 부팅 가능할 때까지 반복

---

## Exynos 9610 포팅 로드맵

### Phase 1: 준비

- [ ] Samsung OSS에서 Galaxy A50(A50s) 커널 소스 다운로드
- [ ] LineageOS 커널 소스 확보
- [ ] mainline Linux 최신 버전 클론
- [ ] krzk 저장소 등 Exynos 관련 브랜치 확인
- [ ] UART 위치 찾기 (테스트 포인트 확인)
- [ ] 기기 회로도/서비스 매뉴얼 검색

### Phase 2: 기본 부팅

- [ ] Exynos 7885 또는 Exynos850 DTS를 기반으로 Exynos 9610 DTS 작성 (최소한의 구성)
- [ ] CPU 클러스터, GIC, 타이머, UART만 포함
- [ ] `uniloader` 또는 `minimal_sboot_wrapper`로 2차 부트로더 설정
- [ ] UART로 부팅 로그 확인
- [ ] ramoops/pstore 설정

### Phase 3: 필수 기능

- [ ] Pinctrl 설정
- [ ] I²C 설정
- [ ] eMMC/스토리지 컨트롤러
- [ ] USB 컨트롤러
- [ ] 기본 클럭(clock) 지원

### Phase 4: 고급 기능

- [ ] Mali-G72 GPU (panfrost 드라이버)
- [ ] MIPI-DSI 디스플레이 패널
- [ ] 오디오
- [ ] WiFi/Bluetooth
- [ ] Modem (Call, SMS, Internet)
- [ ] 카메라
- [ ] Suspend/전원 관리

### Phase 5: 업스트리밍

- [ ] 각 구성 요소별 패치 분할
- [ ] 커밋 메시지 작성 규칙 준수
- [ ] Exynos 메일링 리스트, linux-samsung-soc에 패치 전송
- [ ] 피드백 반영 및 수정

### 도움 요청 채널

| 채널 | 설명 |
|---|---|
| `#postmarketOS-mainline` | postmarketOS 메인라인 일반 |
| `#exynos-arm64-mainline:envs.net` (Matrix) | ARM64 Exynos 메인라이닝 |
| `#linux-exynos` on Libera.chat | Exynos Linux 일반 |
| `linux-samsung-soc@vger.kernel.org` | Samsung SoC 메일링 리스트 |
| `#exynos4xxx-mainline:matrix.org` / `#exynos5-mainline:matrix.org` | Exynos 4/5 세대 |
| postmarketOS GitLab issues | pmaports 이슈 트래커 |

---

## 참고 문헌

- https://wiki.postmarketos.org/wiki/Samsung_Exynos_9610
- https://wiki.postmarketos.org/wiki/Exynos_mainline_porting
- https://wiki.postmarketos.org/wiki/Mainlining
- https://wiki.postmarketos.org/wiki/Qualcomm_mainline_porting
- https://exynos.wiki.kernel.org
- https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
