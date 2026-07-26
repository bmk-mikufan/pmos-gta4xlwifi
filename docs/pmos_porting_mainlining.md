# postmarketOS 포팅(Porting) & 메인라이닝(Mainlining) 문서

> 출처: https://wiki.postmarketos.org/wiki/Main_Page
>
> 수집일: 2026-07-12 (Wayback Machine 2026-01-06 스냅샷 기준)

---

## 개요

postmarketOS는 Alpine Linux를 기반으로 스마트폰 및 기타 모바일 기기에서 동작하도록 확장한 Linux 배포판입니다.

### 주요 섹션 (Main Page)

- **Devices** - 지원 기기 목록
- **User Interfaces** - 사용자 인터페이스
- **Apps** - 애플리케이션
- **Gallery** - 갤러리
- **Community** - 커뮤니티
- **Installation** - 설치 가이드
- **Porting** - 포팅 (이 페이지는 현재 내용이 비어 있음)
- **Mainlining** - 메인라이닝 (상세 내용 있음)
- **More Guides** - 추가 가이드
- **Contributing** - 기여하기
- **Technical Reference** - 기술 참고 자료
- **Troubleshooting** - 문제 해결

---

## Porting (포팅)

> **참고:** postmarketOS 위키의 `Porting` 페이지 (`https://wiki.postmarketos.org/wiki/Porting`)는 현재 내용이 비어 있습니다 ("There is currently no text in this page").

실제 포팅 관련 내용은 아래 페이지들에서 다루고 있습니다:

- **[Mainlining](#mainlining-메인라이닝)** - 메인라인 커널 포팅의 전반적인 과정
- **SoC별 포팅 가이드:**
  - [Qualcomm Mainline Porting](#qualcomm-mainline-porting)
  - [Exynos Mainline Porting](#exynos-mainline-porting)
  - MSM8916 Mainlining
  - MSM8996 Mainlining
  - SDM845 Mainlining
  - SM7150 Mainlining
- **Device-specific ports** - 개별 기기 페이지에서 해당 기기의 포팅 상태 확인 가능

---

## Mainlining (메인라이닝)

> 출처: https://wiki.postmarketos.org/wiki/Mainlining

Mainlining은 기기 제조사가 제공하는 커널("downstream" 커널)을 kernel.org에서 활발히 개발 중인 최신 버전("mainline" 커널)으로 교체하는 과정입니다. 이 과정에는 기기별 코드를 downstream 커널에서 mainline 커널로 포팅하고(가장 중요하게는) 정리(clean up)하는 작업이 포함됩니다. 일부 SoC의 경우 mainline에 이미 공통 지원이 존재하므로, 기기별 구성 요소에 집중할 수 있습니다.

### Why? (왜 메인라이닝을 해야 하는가?)

메인라이닝은 특히 특정 SoC에 처음으로 작업을 시작하는 경우 상당히 복잡한 과정입니다. 그러나 커뮤니티의 노력을 통해 점점 더 많은 SoC가 안정적인 메인라인 포트를 보유하게 되었습니다(아래 목록 참조).

일반적으로 기존 Android 커널을 가져와서 Android blob 없이 부팅하는 것은 비교적 간단합니다. 그러나 그 시점부터 작동하는 시스템을 만들기 위해서는 많은 작업이 필요하며, 결국 보안 패치나 일반적인 개선 사항을 받을 수 없습니다.

순수하게 실용적인 문제 외에도, downstream 코드는 Android 외부에서 유지보수되거나 사용될 목적으로 만들어지지 않았다는 냉혹한 현실이 있습니다. 코드 품질이 훨씬 낮은 경우가 많아 유지보수가 상당히 복잡해집니다. 대규모 드라이버 부분이 Android userspace의 독점 영역으로 이동되는 경우가 많으며, 이는 예상되는 Android 환경을 에뮬레이션하지 않고는 일반적으로 사용이 불가능합니다. 결국, 이러한 드라이버를 장기적으로 제대로 작동하게 만드는 노력은 mainline용으로 다시 작성하는 것만큼이나 많이 필요합니다.

SoC 또는 기기를 성공적으로 메인라이닝하면 다음과 같은 이점이 있습니다:
- Linux 커널이 제공하는 모든 개선 사항을 활용 가능
- 비교적 표준적인 Linux 배포판 실행 가능 (이론적으로는 기기 아키텍처를 지원하는 모든 Linux 배포판)
- 자체 커널 컴파일이나 번거로운 패치 작업 없이 커널 업데이트 및 개선 사항 활용
- 특히 GPU 지원: 거의 모든 GPU에서 최소한의 노력으로 GPU 지원 가능 (PowerVR 제외) - 이는 최신 폰 DE(Plasma Mobile 또는 Phosh)를 적절한 성능으로 사용하는 데 필요
- 메인라이닝은 훌륭한 학습 기회

기기의 SoC가 아래 목록에 있다면, 동일한 기능을 기기에서 작동시키고 궁극적으로 패치를 커널에 업스트림할 수 있는 상당한 기회가 있습니다.

### Overview (개요)

#### Supported SoCs (지원되는 SoC)

일부 SoC는 이미 상당히 잘 지원되며 postmarketOS에서 일부 기기에 사용됩니다. 이 중 하나로 시작하는 것이 더 쉬울 수 있습니다. 동일한 SoC로 작업하는 다른 사람들로부터 도움을 받을 수 있기 때문입니다. 아래 기능 매트릭스는 특정 SoC에 대해 이미 지원되는 기능을 보여줍니다. 각 SoC 페이지는 더 많은 정보, 시작 방법 및 연락처를 제공합니다.

**범례:**
- **Y (Yes)** - 지원됨
- **P (Partial)** - 부분 지원
- **N (No)** - 미지원
- **(공백)** - 정보 없음
- **- (Unavailable/N/A)** - 해당 기능이 SoC에 내장되지 않음 (예: WiFi/BT는 SDIO/UART를 통해 사용되며 SoC와 독립적으로 선택 가능)

> 참고: 아래 표시된 상태는 postmarketOS 커뮤니티의 누군가가 기기에서 특정 기능을 테스트했는지를 나타냅니다. 반드시 mainline 커널에서 지원되는 구성 요소는 아닙니다.

| SoC | Arch | Year | UART | USB | Storage | Display | CPU | GPU | Pinctrl | I²C | Audio | Video | Thermal | WiFi | BT | Modem | GPS | Camera | Suspend |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Allwinner A33 | armv7 | 2014 | Y | Y | Y | Y | P | P | Y | Y | P | Y | Y | - | - | - | - | P | P |
| Allwinner A523 | aarch64 | 2023 | Y | Y | Y | | P | Y | Y | Y | | | | | | | | | |
| Allwinner A64 | aarch64 | 2015 | Y | Y | Y | Y | P | P | Y | Y | Y | | Y | - | - | - | - | Y | P |
| Allwinner D1-H | riscv64 | 2020 | Y | Y | P | P | Y | Y | Y | Y | Y | P | Y | - | - | - | - | - | |
| Allwinner H3 | armv7 | 2014 | Y | Y | Y | Y | P | P | Y | Y | P | Y | Y | - | - | - | - | P | P |
| Allwinner H6 | aarch64 | 2017 | Y | Y | Y | Y | Y | Y | Y | Y | | P | | - | - | - | - | | |
| Allwinner H616 | aarch64 | 2021 | | | | | | | | | | | | | | | | | |
| Amlogic AML8726-MX | armv7 | 2012 | P | N | N | N | P | N | N | N | N | N | N | - | - | - | - | - | |
| Amlogic S805 | armv7 | 2014 | Y | Y | P | P | Y | Y | P | Y | N | P | Y | - | - | - | - | - | |
| Amlogic S812/S812-B/S812-S/S802 | armv7 | 2014 | Y | Y | P | P | Y | Y | P | Y | N | P | Y | - | - | - | - | - | |
| Broadcom BCM21553 | armv7 | 2011 | Y | | | | Y | | Y | | | | | - | - | - | Y | - | |
| Broadcom BCM23550 | armv7 | 2014 | Y | | P | | Y | | Y | | | | | - | - | - | Y | - | |
| Broadcom BCM2711 | aarch64 | 2019 | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | - | - | Y | Y |
| Broadcom BCM2712 | aarch64 | 2023 | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | - | - | Y | Y |
| Broadcom BCM28155 | armv7 | 2012 | Y | | | | Y | | Y | | | | | - | - | - | Y | - | |
| Broadcom BCM59011 | armv7 | 2014 | N | | | | Y | | Y | | | | | - | - | - | Y | - | |
| HiSilicon Hi3620 | armv7 | 2012 | Y | Y | Y | Y | Y | N | Y | Y | P | | Y | - | - | - | - | P | |
| Intel Atom Z3740D | x86_64 | 2013 | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | - | - | Y | Y |
| Marvell Armada PXA1908 | aarch64 | 2015 | Y | Y | Y | Y | Y | Y | Y | Y | Y | N | Y | P | Y | Y | Y | Y | N |
| MediaTek MT6580 | armv7 | 2015 | N | N | Y | | P | N | Y | P | N | N | P | Y | Y | Y | N | N | P |
| MediaTek MT6735 | aarch64 | 2015 | Y | Y | Y | Y | Y | P | Y | Y | Y | N | Y | Y | Y | Y | Y | P | |
| MediaTek MT6737 | aarch64 | 2016 | Y | Y | Y | P | Y | P | Y | Y | Y | N | Y | Y | Y | P | P | N | |
| MediaTek MT6739 | aarch64 | 2017 | Y | Y | Y | P | Y | Y | Y | Y | Y | | Y | Y | Y | Y | | | |
| MediaTek MT6765/MT6763 | aarch64 | 2018 | Y | Y | Y | P | Y | P | Y | Y | Y | | Y | | Y | | | | |
| MediaTek MT6789 | aarch64 | 2022 | | | | | | | | | | | | | | | | | |
| MediaTek MT6833 | aarch64 | 2022 | | | | | | | | | | | | | | | | | |
| MediaTek MT6853 | aarch64 | 2022 | | | | | | | | | | | | | | | | | |
| MediaTek MT6878 | aarch64 | 2022 | | | | | | | | | | | | | | | | | |
| MediaTek MT8111 | aarch64 | 2021 | Y | Y | Y | P | Y | Y | Y | Y | Y | | Y | - | - | - | - | | |
| MediaTek MT8127 | armv7 | 2014 | Y | Y | Y | P | Y | Y | Y | Y | Y | | Y | Y | Y | - | - | | - |
| MediaTek MT8135 | armv7 | 2014 | Y | Y | Y | Y | Y | Y | Y | Y | Y | | Y | Y | Y | - | - | | Y |
| MediaTek MT8163 | aarch64 | 2015 | Y | Y | Y | P | Y | Y | Y | Y | Y | | Y | Y | Y | - | - | | |
| MediaTek MT8167 | armv7 | 2017 | Y | Y | Y | P | Y | Y | Y | Y | Y | | Y | Y | Y | - | - | | |
| MediaTek MT8168 | aarch64 | 2020 | | | | | | | | | | | | | | | | | |
| MediaTek MT8173 | aarch64 | 2015 | Y | Y | Y | Y | Y | Y | Y | Y | Y | | Y | Y | Y | Y | - | | N |
| MediaTek MT8176 | aarch64 | 2016 | Y | Y | Y | P | Y | Y | Y | Y | Y | | Y | Y | Y | Y | - | | |
| MediaTek MT8183 | aarch64 | 2019 | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | - | Y | N |
| MediaTek MT8188 | aarch64 | 2022 | Y | P | Y | P | Y | P | Y | Y | | | | Y | Y | - | - | | |
| MediaTek MT8192 | aarch64 | 2020 | Y | Y | Y | P | Y | Y | Y | Y | | | | Y | Y | Y | - | | |
| MediaTek MT8195 | aarch64 | 2021 | Y | Y | Y | Y | Y | Y | Y | Y | Y | P | Y | Y | Y | Y | - | Y | Y |
| MediaTek MT8312 | armv7 | 2014 | Y | Y | Y | P | Y | Y | Y | | Y | | Y | | | - | - | | - |
| MediaTek MT8321 | armv7 | 2014 | Y | Y | Y | P | Y | Y | Y | | Y | | Y | | Y | | | | |
| MediaTek MT8735 | aarch64 | 2015 | Y | Y | Y | P | Y | Y | Y | Y | Y | | Y | Y | Y | Y | | | |
| MediaTek MT8768 | aarch64 | 2018 | | | | | | | | | | | | | | | | | |
| Nvidia Tegra 20 | armv7 | 2011 | Y | Y | Y | Y | Y | | Y | Y | Y | N | Y | Y | Y | Y | - | - | N | |
| Nvidia Tegra 30 | armv7 | 2012 | Y | Y | Y | Y | Y | | Y | Y | Y | N | Y | Y | Y | Y | - | - | | |
| Nvidia Tegra 114 | armv7 | 2013 | Y | Y | Y | Y | Y | | Y | Y | Y | N | Y | Y | Y | Y | - | - | | |
| Nvidia Tegra 124 | armv7 | 2014 | Y | Y | Y | Y | Y | | Y | Y | Y | N | Y | Y | Y | Y | - | - | N | |
| Nvidia Tegra 210 | aarch64 | 2015 | Y | Y | Y | Y | Y | Y | Y | Y | Y | N | Y | Y | Y | Y | - | - | N | |
| Nvidia Tegra 132 | aarch64 | 2014 | Y | Y | Y | Y | Y | | Y | Y | Y | N | Y | Y | Y | Y | - | - | | |
| Qualcomm APQ8064 | armv7 | 2013 | Y | Y | Y | Y | Y | N | Y | Y | N | | Y | Y | | N | - | | - |
| Qualcomm MSM8226 | armv7 | 2013 | Y | Y | Y | Y | P | Y | Y | Y | N | N | Y | Y | Y | N | Y | P | N |
| Qualcomm MSM8909 | armv7 | 2015 | Y | Y | Y | P | Y | P | Y | Y | N | | | P | N | N | - | N | - |
| Qualcomm MSM8916 | aarch64 | 2014 | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| Qualcomm MSM8917 | aarch64 | 2016 | Y | Y | Y | Y | Y | Y | Y | Y | Y | P | Y | Y | Y | P | P | Y | Y |
| Qualcomm MSM8937 | aarch64 | 2016 | Y | Y | Y | Y | Y | Y | Y | Y | Y | N | Y | Y | Y | P | N | Y | Y |
| Qualcomm MSM8939 | aarch64 | 2014 | Y | Y | Y | Y | P | Y | Y | Y | Y | | Y | Y | Y | Y | | | - |
| Qualcomm MSM8940 | aarch64 | 2016 | Y | Y | Y | Y | Y | Y | Y | Y | Y | N | Y | Y | Y | N | N | N | Y |
| Qualcomm MSM8953 | aarch64 | 2016 | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| Qualcomm MSM8960 | armv7 | 2012 | Y | Y | Y | | Y | | Y | Y | | | P | P | P | | - | | - |
| Qualcomm MSM8974 | armv7 | 2013 | Y | Y | Y | Y | P | P | Y | Y | N | N | Y | Y | Y | P | N | N | N |
| Qualcomm MSM8976 | aarch64 | 2016 | Y | P | Y | Y | P | Y | Y | Y | N | N | Y | Y | Y | P | - | N | N |
| Qualcomm MSM8992/MSM8994 | aarch64 | 2015 | Y | Y | P | P | Y | N | Y | | | | | | | N | - | N | |
| Qualcomm MSM8996 | aarch64 | 2016 | Y | Y | P | Y | P | Y | Y | Y | Y | Y | Y | - | - | P | - | P | N |
| Qualcomm MSM8998 | aarch64 | 2017 | Y | N | Y | P | P | N | Y | Y | Y | | Y | Y | Y | P | Y | | |
| Qualcomm QM215 | aarch64 | 2019 | Y | Y | Y | Y | Y | Y | Y | Y | Y | N | Y | Y | Y | P | N | Y | N |
| Qualcomm SC7180 | aarch64 | 2019 | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | - | - | N | Y |
| Qualcomm SC7180P | aarch64 | 2021 | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | - | - | N | Y |
| Qualcomm SC8280XP | aarch64 | 2021 | Y | Y | Y | Y | Y | Y | Y | Y | P | P | Y | P | P | Y | | P | P |
| Qualcomm SDM439 | aarch64 | 2018 | Y | Y | Y | P | Y | P | Y | Y | P | N | Y | Y | Y | N | N | N | |
| Qualcomm SDM630 | aarch64 | 2017 | Y | P | Y | Y | P | P | Y | Y | P | Y | Y | Y | Y | P | N | P | N |
| Qualcomm SDM636 | aarch64 | 2017 | Y | P | Y | Y | P | P | Y | Y | P | Y | Y | Y | Y | P | N | P | N |
| Qualcomm SDM660 | aarch64 | 2017 | Y | P | Y | Y | P | P | Y | Y | P | Y | Y | Y | Y | P | N | P | N |
| Qualcomm SDM670 | aarch64 | 2018 | N | P | P | Y | P | Y | Y | Y | P | P | Y | Y | Y | Y | | Y | |
| Qualcomm SDM710 | aarch64 | 2018 | | Y | Y | Y | Y | Y | Y | Y | | | | | Y | Y | Y | P | P |
| Qualcomm SM4250 | aarch64 | 2020 | | | | | Y | | | | | | | | | | | | |
| Qualcomm SM6115 | aarch64 | 2020 | | | | | | | | | | | | | | | - | | - |
| Qualcomm SM6125 | aarch64 | 2019 | | Y | Y | Y | P | N | Y | N | N | N | P | N | N | N | - | N | - |
| Qualcomm SM6150 | aarch64 | 2018 | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | | | Y | Y |
| Qualcomm SM6225 | aarch64 | 2021 | | N | N | P | P | N | N | N | N | N | N | N | N | N | - | N | - |
| Qualcomm SM6375 | aarch64 | 2021 | Y | Y | P | N | Y | N | Y | Y | N | N | P | Y | - | Y | - | N | - |
| Qualcomm SM7125 | aarch64 | 2020 | | Y | Y | Y | Y | Y | Y | Y | | Y | | Y | Y | P | - | | - |
| Qualcomm SM7150 | aarch64 | 2019/2020 | Y | Y | Y | Y | Y | Y | Y | Y | P | N | Y | Y | Y | Y | P | P | Y |
| Qualcomm SM7325 | aarch64 | 2021/2022 | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | P | | Y | |
| Qualcomm SM7635 | aarch64 | 2024 | Y | P | P | N | Y | N | Y | Y | N | N | Y | N | N | N | N | N | |
| Qualcomm SM7675 | aarch64 | 2024 | | | | | | | | | | | | | | | | | |
| Qualcomm SM8150 | aarch64 | 2019 | Y | Y | Y | Y | Y | Y | Y | Y | P | N | Y | Y | Y | P | P | P | Y |
| Qualcomm SM8250 | aarch64 | 2020/2021 | Y | Y | Y | P | Y | Y | Y | Y | Y | Y | | Y | Y | | - | | - |
| Qualcomm SM8350 | aarch64 | 2021 | | P | Y | | P | | Y | | | | | | | | - | | - |
| Qualcomm SM8450 | aarch64 | 2021 | Y | Y | Y | Y | Y | Y | Y | Y | Y | | Y | Y | Y | | - | | - |
| Qualcomm SM8475 | aarch64 | 2022 | Y | Y | Y | Y | Y | Y | Y | Y | | | Y | | | | - | | - |
| Qualcomm SM8550 | aarch64 | 2022 | Y | Y | Y | Y | Y | | Y | Y | | | Y | | | N | | | |
| Qualcomm SM8635 | aarch64 | 2024 | Y | P | Y | | Y | | Y | Y | | Y | Y | | | | | | |
| Qualcomm SM8650 | aarch64 | 2023 | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | N | N | N | |
| Qualcomm SM8750 | aarch64 | 2024 | Y | Y | Y | Y | Y | N | Y | Y | Y | Y | Y | | | | | | Y |
| Qualcomm SM8850 | aarch64 | 2025 | Y | Y | Y | Y | Y | P | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| Qualcomm Snapdragon 410/412 | aarch64 | 2014 | Y | Y | Y | Y | P | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | P | P |
| Qualcomm Snapdragon 690 5G | aarch64 | 2020 | Y | Y | Y | Y | Y | Y | Y | Y | N | N | P | Y | - | Y | | N | P |
| Qualcomm Snapdragon 835 | aarch64 | 2017 | Y | N | Y | P | P | N | Y | Y | Y | | Y | Y | Y | P | Y | | |
| Qualcomm Snapdragon 845/850 | aarch64 | 2018 | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | P | Y | Y | Y |
| Qualcomm X1E78100 | aarch64 | 2024 | Y | Y | Y | Y | Y | Y | Y | Y | | N | Y | Y | Y | - | - | N | N |
| Qualcomm X1E80100 | aarch64 | 2023 | | | | | | | | | | | | | | | | | |
| RDA Microelectronics RDA8810PL | armv7 | 2014 | Y | | | | Y | | Y | | | | | - | - | | - | | |
| Rockchip RK3066 | armv7 | 2012 | Y | Y | Y | P | Y | Y | Y | Y | P | | | Y | Y | | Y | | - |
| Rockchip RK3126 | armv7 | 2014 | Y | Y | Y | Y | Y | Y | Y | Y | Y | | | | | | | | |
| Rockchip RK3128 | armv7 | 2014 | Y | Y | Y | Y | Y | Y | Y | Y | Y | | | | | | | | |
| Rockchip RK3188 | armv7 | 2013 | Y | Y | Y | Y | Y | Y | Y | Y | Y | | | | | | | | |
| Rockchip RK3228A | armv7 | 2016 | | Y | Y | Y | Y | Y | | | Y | Y | Y | P | P | - | - | - | |
| Rockchip RK3228B | armv7 | 2016 | | Y | Y | Y | Y | Y | | | Y | Y | Y | P | P | - | - | - | |
| Rockchip RK3229 | armv7 | 2016 | | Y | Y | Y | Y | Y | | | Y | Y | Y | P | P | - | - | - | |
| Rockchip RK3288 | armv7 | 2014 | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | | - |
| Rockchip RK3399 | aarch64 | 2016 | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | - | - | - | - | Y | Y |
| Rockchip RK3566 | aarch64 | 2021 | Y | Y | Y | Y | Y | Y | Y | Y | Y | P | Y | - | - | - | - | | Y |
| Rockchip RK3568 | aarch64 | 2021 | Y | Y | Y | Y | Y | Y | Y | Y | Y | P | Y | - | - | - | - | | Y |
| Samsung Exynos 2200 | aarch64 | 2022 | N | P | N | P | P | N | Y | Y | N | N | N | N | N | N | - | N | N |
| Samsung Exynos 3250 | armv7 | 2014 | Y | Y | Y | Y | Y | Y | Y | Y | | | Y | | | | - | | Y |
| Samsung Exynos 3475 | armv7 | 2015 | Y | N | Y | P | P | Y | Y | Y | N | N | N | - | - | N | N | N | |
| Samsung Exynos 4210 | armv7 | 2011 | Y | Y | Y | Y | Y | Y | Y | Y | | | Y | - | - | - | - | | - |
| Samsung Exynos 4212 | armv7 | 2012 | Y | Y | Y | Y | Y | Y | Y | Y | Y | | Y | - | - | - | - | | Y |
| Samsung Exynos 4412 | armv7 | 2012 | Y | Y | Y | Y | Y | Y | Y | Y | Y | | Y | - | - | - | - | P | Y |
| Samsung Exynos 5250 | armv7 | 2012 | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | - | - | - | - | | Y |
| Samsung Exynos 5420 | armv7 | 2013 | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | - | - | - | - | | Y |
| Samsung Exynos 5422 | armv7 | 2014 | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | - | - | - | - | | Y |
| Samsung Exynos 5433 | aarch64 | 2014 | Y | Y | Y | Y | Y | Y | Y | Y | Y | | Y | | | | - | | Y |
| Samsung Exynos 7870 | aarch64 | 2016 | Y | Y | Y | P | Y | Y | Y | Y | N | N | N | - | - | N | N | N | N |
| Samsung Exynos 7885 | aarch64 | 2018 | Y | P | P | P | P | | Y | P | | | | | | | | | |
| Samsung Exynos 8895 | aarch64 | 2017 | Y | Y | P | P | P | | Y | Y | | | | | | | - | | - |
| Samsung Exynos 9810 | aarch64 | 2017 | | | | | Y | | Y | | | | | | | | - | | - |
| Samsung Exynos 990 | aarch64 | 2020 | Y | P | P | P | P | P | Y | Y | N | N | N | N | N | N | - | N | N |
| ST-Ericsson NovaThor U8500 | armv7 | 2011 | Y | Y | Y | Y | Y | Y | Y | Y | N | N | Y | - | - | N | - | N | Y |
| Texas Instruments OMAP3xxx | armv7 | 2008 | Y | Y | Y | Y | Y | N | Y | Y | Y | N | Y | - | - | - | - | Y | Y |
| Texas Instruments OMAP44xx | armv7 | 2011 | Y | Y | Y | Y | Y | N | Y | Y | Y | N | Y | - | - | - | - | P | Y |
| Unisoc Tiger T606 | aarch64 | 2021 | Y | P | Y | Y | Y | Y | Y | Y | P | N | Y | P | Y | P | N | N | - |
| Unisoc Tiger T616 | aarch64 | 2021 | Y | P | Y | Y | Y | Y | Y | Y | P | N | Y | P | Y | P | N | N | - |

#### Getting help (도움 받기)

Mainlining 관련 postmarketOS 논의는 주로 `#postmarketOS-mainline` 채널에서 이루어집니다. 위에 나열된 SoC 중 하나라면 어느 정도 도움을 줄 수 있는 사람이 있을 것입니다. 다만 일부 문제는 기기별 특수 문제나 아직 경험이 없는 구성 요소일 수 있으므로 스스로 해결해야 할 수도 있습니다.

Matrix에서 Linux 커널 개발 관련 대부분의 채널은 `#linux-kernel-devspace`에서 찾아볼 수 있습니다.

| SoC | 도움 요청 장소 |
|---|---|
| 일반 | #postmarketOS-mainline (위에 나열된 SoC로 제한될 수 있음) |
| Allwinner | #linux-sunxi on OFTC, linux-sunxi@googlegroups.com |
| Amlogic | #linux-amlogic on Libera.Chat, linux-amlogic@lists.infradead.org; 일반 정보: linux-meson.com |
| Broadcom Kona | knuxify, #bcm-kona-mainline:dissonant.dev on Matrix; bcm-kona-mainline on GitHub |
| Exynos | #replicant (구형), #linux-exynos on Libera.chat (forkbomb, Putti, krzk), #exynos-arm64-mainline:envs.net on Matrix, linux-samsung-soc@vger.kernel.org |
| Samsung Exynos 4 | Exynos entry + #exynos4xxx-mainline:matrix.org, #exynos4-mainline on OFTC |
| Samsung Exynos 5 | Exynos entry + #exynos5-mainline:matrix.org |
| Marvell PXA1908 | #pxa1908-mainline on OFTC |
| MediaTek | #linux-mediatek on Libera.chat, linux-mediatek@lists.infradead.org |
| MediaTek MT6735 | MediaTek entry + #mt6735-foss:matrix.org |
| MediaTek MT6878 | MediaTek entry + #mt6878-mainline:matrix.org |
| OMAP3 / OMAP4 | @pavelm, linux-omap@vger.kernel.org |
| Qualcomm (msm...) | #linux-msm on OFTC, linux-arm-msm@vger.kernel.org |
| Qualcomm Snapdragon 400 (MSM8226) | Qualcomm entry + #msm8226-mainline:postmarketos.org |
| Qualcomm Snapdragon 210 (MSM8909) | Qualcomm entry + #msm8916:postmarketos.org |
| Qualcomm Snapdragon 410/412 (MSM8916) | Qualcomm entry + #msm8916:postmarketos.org |
| Qualcomm Snapdragon 450/625/626/632 (MSM8953) | Qualcomm entry + #msm8953-mainline:matrix.org |
| Qualcomm Snapdragon 650/652/653 (MSM8956/MSM8976) | Qualcomm entry + @barni2000:matrix.org (DM 금지), #msm8956-mainline:tchncs.de |
| Qualcomm Snapdragon 600 (APQ8064) / S4 Plus (MSM8960) | Qualcomm entry + #linux-apq8064:matrix.org |
| Qualcomm Snapdragon 615/616 (MSM8939) | Qualcomm entry + #msm8916:postmarketos.org |
| Qualcomm Snapdragon 660/630/636 (SDM660/SDM630/SDM636) | Qualcomm entry + #sdm660-mainline:matrix.org |
| Qualcomm Snapdragon 670 (SDM670) | Qualcomm entry + #sargo/bonito porting:erebion.eu |
| Qualcomm Snapdragon 730/730G/732G (SM7150) | Qualcomm entry + #sm7150-mainline:matrix.org |
| Qualcomm Snapdragon 820/821 (MSM8996) | Qualcomm entry + #msm8996-mainline:matrix.org |
| Qualcomm Snapdragon 845 (SDM845) | Qualcomm entry + #sdm845:postmarketos.org |
| Qualcomm Snapdragon 855 (SM8150) | Qualcomm entry + #sm8150-mainline:matrix.org |
| Qualcomm Snapdragon 865/865+/870 (SM8250) | Qualcomm entry + #sm8250-mainline:matrix.org |
| Qualcomm Snapdragon 8 Gen 1/8+ Gen 1/7+ Gen 2 (SM8450/SM8475/SM7475) | Qualcomm entry + #sm8450-mainline:matrix.org |
| Qualcomm Snapdragon 8 Gen 3 (SM8650) | #linux-msm and #sm8650-mainline on Matrix or OFTC |
| Nvidia Tegra | matrix.org:#postmarketOS-on-transformers:matrix.org (Transformer 가족, 다른 Tegra 기기), #tegra on Libera.chat, linux-tegra@vger.kernel.org |

### Getting Started (시작하기)

1. **기기에 대한 정보를 최대한 많이 수집하세요:**
   - downstream 커널 소스
   - 사양
   - 회로도 (검색 엔진으로 찾을 수 있는 경우도 있음)
   - 이 모든 것은 기기를 mainline으로 포팅할 때 매우 중요합니다.

2. **직렬 디버깅(Serial debugging)은 특히 초기 단계(USB나 네트워크가 작동하기 전)에서 유용합니다.**
   - 일부 기기는 USB 포트나 오디오 잭을 통해 노출됩니다.
   - 다른 기기는 메인보드에 테스트 포인트가 있습니다.

3. **커널 트리 선택:**
   - **Mainline** (Linus Torvalds가 릴리스한 마지막 커널 버전): 최신이면서도 안정적인 좋은 절충안. `torvalds/linux.git`
   - **linux-next**: 여러 서브시스템에서 최근 병합된 변경 사항 모음; 매우 최신 SoC 작업 시 사용. `next/linux-next.git`
   - 특정 SoC에 맞는 WIP 변경 사항이 포함된 추가 Linux 커널 트리가 있을 수 있습니다.

4. **`envkernel.sh`로 커널 컴파일** - 커널 개발을 postmarketOS에 통합하는 데 매우 유용합니다.

5. 위에 나열된 SoC로 포팅을 시도하는 경우, **SoC 위키 페이지에서 추가 도움말과 지침을 확인하세요.**

6. **downstream 코드를 그대로 복사하지 마세요.**
   - 일반적으로 작동하지 않으며, 가장 중요하게는 mainline 커널 업스트림에 포함이 거부됩니다.
   - 대신 downstream 코드가 무엇을 하는지 이해하고, 유사한 코드를 참고하여 mainline용으로 처음부터 다시 작성하세요.

### Materials to look into (참고 자료)

> 참고: 임베디드 기기에 관한 Linux 아키텍처는 빠르게 발전하므로, 특정 정보는 2-3년 내에 구식이 될 수 있습니다.

#### 책

- *Mastering Linux Device Driver Development* (2021, John Madieu)
- *Linux Driver Development for Embedded Processors - Second Edition* (2018, Alberto Liberal De Los Ríos)

#### 소개

- Porting mainline Linux to mobile phones, Luca Weiss, 2022 (40:00) FOSDEM
- Running Mainline Linux on Snapdragon 410, Nikita Travkin, 2022 (40:00) FOSDEM
- From Android to mainline on the Snapdragon 845, Casey Connolly, 2022 (30:00) FOSDEM
- Qualcomm SoC upstreaming adventures in 2020
- Porting Linux to your favorite obscure Arm SoC, 2020
- Upstreaming a Qualcomm SoC, 2020
- Introduction into how mainlining is done, 2017 (52:37)

#### 기초

- Introduction into ARM architecture, 2017 (46:33)
- ARM64 SoC Linux Support Check-List, 2017 (42:38) - SoC 지원을 위해 수행해야 할 작업에 대한 단계별 가이드
- Upstreaming ARM64 SoC's easier than before, 2019 (19:03)
- Mainlining blog by ichernev
- How the ARM32 kernel starts by Linus Walleij

#### Device Tree 작성

- DTS 101: From Roots To Trees, Aka Devicetree for Beginners (34:06)
- Device Tree 101, 2021 (1:54:58)
- Device Tree (DT) introduction, 2013 (1:12:14)
- Device Tree: present, past, future, 2018 (37:28)
- Device tree bindings (필수) - `Documentation/devicetree/bindings` 디렉토리 확인
- Device Tree Usage (elinux.org)
- Device Tree Specification
- DT Resources on elinux.org

#### 클럭(Clocks)

- Common Clock Framework: How To Use It, 2013 (44:50) - 오래되고 기본적인 개요
- What The Clock! - Linux Clock Subsystem Internals, 2020 (33:12)
- Clock sources, Clock events, sched_clock() and delay timers at kernel.org

#### 전원 관리

- SAN19-421 Training: Device power management for idle

#### 카메라

- How V4L2 Transformed To Support Embedded Cameras - Laurent Pinchart (41:07)
- Software ISP FOSS Support for MIPI Cameras (42:03)
- Camera/ISP Drivers Using V4L2 Media Controller Framework (35m)

#### 다양한 주제

- Pin Control and GPIO, 2013 (48:03) - Linus Walleij
- Timekeeping in the Linux Kernel, 2017 (34:41)
- How Dealing with Modern Interrupt Architectures can Affect Your Sanity
- Linux Kernel Display Architecture, 2013 (56:53) - DRM/KMS, MIPI DSI, panels (약간 구식)
- Demystifying Linux MIPI DSI Subsystem, 2019 (41:57)
- Power Management Integrated Circuits, 2017 - PMICs, regulators, power supply, fuelgauge

#### 개발 도구

- Using Visual Studio Code for Embedded Development, 2021 (31:37)
  - VSCodium: https://marketplace.visualstudio.com/ 에서 수동으로 확장 다운로드

#### 패치 제출

- Submitting Patches wiki page
- Submitting patches: the essential guide to getting your code into the kernel
- Submitting Your First Patch to the Linux Kernel and Responding to Feedback
- Guide for git-send-email

### Upstreaming (업스트리밍)

메인라인 작업을 업스트림하는 것은 최신 Linux 커널 버전에 패치를 리베이스하는 유지보수 부담을 줄이는 데 핵심적입니다.

업스트리밍 패치는 `git send-email`을 사용하여 Linux Kernel Mailing List(LKML)로 보내야 합니다.
- git send-email 튜토리얼: https://git-send-email.io/
- 상세 개요: https://wiki.postmarketos.org/wiki/Submitting_Patches#Linux

### See also (참고 항목)

- Mainlining Guide (매우 일반적, 일부 내용은 이 페이지에 통합 중)
- MSM8916 Mainlining (MSM8916 특화, 유사 Qualcomm SoC에 도움됨)
- MSM8996 Mainlining
- SDM845 Mainlining
- Mainlining FAQ
- The Mainline Kernel
- Qualcomm mainline porting (아래 별도 섹션)
- Exynos mainline porting (아래 별도 섹션)
- pmaports#175 Google Galaxy Nexus (samsung-maguro): Mainlining progress
- pmaports#153 Google Pixel 3 XL (google-crosshatch): mainlining attempt

---

## Qualcomm Mainline Porting

> 출처: https://wiki.postmarketos.org/wiki/Qualcomm_mainline_porting
>
> 참고: Work in progress. 실제 시도 시 이 페이지를 개선하거나 비 Qualcomm 특화 mainlining 위키 페이지와 병합해 주세요.

Qualcomm SoC를 탑재한 기기는 일반적으로 mainline Linux 포팅에 적합한 후보입니다. SoC가 이미 지원된다면 적절한 양의 작동 기능으로 기기를 mainline에서 실행하는 데 보통 많은 작업이 필요하지 않습니다.

### Supported SoCs

위 **Mainlining** 섹션의 SoC 테이블에서 Qualcomm SoC 부분을 참조하세요.

### Prerequisites (전제 조건)

- **Downstream 커널 소스 코드**: mainline 커널 포팅 시 주요 참고 자료
- **보드 회로도**: 일반적으로 품질이 낮은 downstream 코드(device tree 포함)를 보완하는 추가 참고 자료. 모든 구성 요소의 배선을 확인할 수 있으며, downstream device tree에서 잘못 표현된 하드웨어(예: enable pin으로 모델링된 고정 레귤레이터)를 찾는 데 도움
- 유사한 기기의 **mainline 소스 코드**가 있으면 매우 도움됨: https://wiki.postmarketos.org/wiki/Mainlining#Supported_SoCs

### First steps (첫 단계)

mainline 커널 부팅 시 기기에서 피드백을 받을 방법을 찾아야 합니다. 디버깅에 필요합니다.

#### UART

가장 유용한 방법.早期 커널 메시지 및 부트로더 로그 확인 가능.
기기에서 UART 포트 위치를 찾아야 합니다.

#### Simple Framebuffer

비디오 모드 패널이 있고 부트로더가 연속 스플래시용 framebuffer를 설정한 경우 가장 쉬운 방법.
Linux가 화면에 로그를 출력할 수 있으며, 패널 드라이버를 작성하기 전에 제한적으로 화면 사용 가능.

#### RAM Console / ramoops

최후의 수단. 일반적으로 신뢰성이 낮고 많은 경우 작동이 상당히 어려움.

### Relevant chat log

opendata와 bshah의 채팅 로그를 기반으로 한 팁:

- fairphone2 DT를 복사하여 기기 정보 변경
- Nexus 4(apq8064)로 시작하는 경우 Nexus 7 2013이 가장 완성도 높은 기기
- `msm8974-regulator.dtsi`에서 레귤레이터 전압 확인 및 DTS 일치
- Android DTSi의 레귤레이터 설정 확인 후 dts에서 해당 레귤레이터 변경
- USB telnet으로 부팅할 수 있어야 함

### SoC-specific guides (SoC별 가이드)

- MSM8916 Mainlining
- MSM8996 Mainlining
- SDM845 Mainlining
- SM7150 Mainlining
- Qualcomm S4/Krait 200 mainlining

메인라이닝 절차는 상당히 유사하므로, 다른 SoC라도 어느 정도 따라갈 수 있습니다.

### See also

- pmaports#153 crosshatch: mainlining attempt
- Qualcomm SOC Mainlining Project

---

## Exynos Mainline Porting

> 출처: https://wiki.postmarketos.org/wiki/Exynos_mainline_porting

이 페이지는 Exynos SoC의 mainline 관련 정보, 데이터 및 링크를 제공합니다.
기기를 메인라인하려면 **Mainlining 가이드**를 먼저 따르세요.

2014년까지 출시된 대부분의 Exynos ARM SoC는 mainline Linux에서 잘 지원됩니다.
ARM64의 경우 Samsung이 mainline Linux에 코드를 올리려는 시도를 거의 하지 않아 지원되는 SoC가 거의 없습니다.

어느 정도 지원되는 ARM64 Exynos SoC:
- Exynos5433
- Exynos7 (Exynos7420의 초기 개정판)
- Exynos7885
- Exynos850 (Exynos3830)
- Exynos8895
- Exynos990
- ExynosAuto v9
- ExynosAuto v920
- Tesla FSD
- Category:Google Tensor SoC (S5E9845)

과거에는 좋은 지원이 있었으나 현재는 지원이 중단된 ARMv7 SoC:
- Exynos4415 (mainline 커널에서 지원 중단)
- Exynos5260 (SM-N750 Galaxy Note 3 Neo)
- Exynos5410
- Exynos5800

### Bootloaders

- 2020년 이전 기기: **S-BOOT** (U-Boot 기반)
- 2020년 이후 기기: **S-LK** (990 및 2300용 유출 있음)
- S-BOOT/S-LK의 특이사항:
  - 2016년 이후의 새 DECON 방식 기기: `HW_SW_TRIG_CONTROL` 비트 설정 필요
  - 일부 개정판에서 `CNTFRQ_EL0`가 설정되지 않은 상태로 남음
- 부트로더가 기기 트리를 특정 형식으로 요구하고 부팅 전 수정함
- **2차 부트로더 사용 권장**: uniloader, minimal_sboot_wrapper

### History

- Exynos 3110 (hummingbird) - S5PC110에서 개명, Cortex-A8
- Exynos 4210 - S5PC210, 듀얼 Cortex-A9
- Exynos 4412 - S5PC220, 쿼드 Cortex-A9
- Exynos 4x12 = Pega/Pegasus (4212 = Pega-D, 4412 = Pega-Q, 3250 = Pega-W)
- Exynos 5 = Cortex-A15 (일부는 Cortex-A9 포함)

### Samsung SoCs Table

| SoC | Arch | Year | Mainline | GPU |
|---|---|---|---|---|
| Exynos 2200 | aarch64 | 2022 | Yes | Xclipse 920 |
| Exynos 3250 | armv7 | 2014 | Yes | ARM Mali-400 GPU |
| Exynos 3475 | armv7 | 2015 | Yes | ARM Mali-T720 |
| Exynos 4210 | armv7 | 2011 | Yes | ARM Mali-400MP4 |
| Exynos 4212 | armv7 | 2012 | Yes | ARM Mali-400 GPU |
| Exynos 4412 | armv7 | 2012 | Yes | ARM Mali-400 GPU |
| Exynos 4415 | armv7 | 2014 | No | ARM Mali-400 GPU |
| Exynos 5250 | armv7 | 2012 | Yes | ARM Mali-T604MP4 |
| Exynos 5420 | armv7 | 2013 | Yes | Mali-T628 MP6 |
| Exynos 5422 | armv7 | 2014 | Yes | Mali-T628 MP6 |
| Exynos 5433 | aarch64 | 2014 | Yes | Mali-T760 |
| Exynos 7870 | aarch64 | 2016 | Yes | ARM Mali-T830 MP1 |
| Exynos 7885 | aarch64 | 2018 | Yes | ARM Mali-G71 MP2 |
| Exynos 8890 | aarch64 | 2016 | No | 650MHz Mali-T880 MP12 |
| Exynos 8895 | aarch64 | 2017 | Yes | Mali-G71 MP20 |
| Exynos 9110 | aarch64 | 2017 | No | Mali-T720 |
| Exynos 9810 | aarch64 | 2017 | Yes | Mali-G72 MP18 |
| Exynos 990 | aarch64 | 2020 | Yes | Mali-G77 |

### See also

- https://exynos.wiki.kernel.org
- knuxify의 lt01wifi 디스플레이 포팅 방법 블로그
- PabloPL: Exynos 7420, 7580, 8890 관련 브랜치
- dsankouski: Exynos 7880 관련 브랜치
- VDavid003: Exynos 7885 관련 브랜치
- ivoszbg: Exynos 8895 관련 브랜치
- krzk: 여러 Exynos SoC용 Samsung 커널 소스 브랜치

---

> 이 문서는 postmarketOS Wiki (CC BY-SA 4.0)의 내용을 기반으로 작성되었습니다.
> 최종 업데이트: 2026-01-06 (revision 79900 기준)
