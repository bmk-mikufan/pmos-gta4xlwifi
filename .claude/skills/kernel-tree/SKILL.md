---
name: kernel-tree
description: 커널 소스 트리를 sparse-checkout으로 가볍게 받고 탐색한다. 다운스트림이나 메인라인 커널을 새로 클론하거나, 조사 범위를 넓혀야 할 때, 또는 grep이 너무 느리거나 결과가 폭발할 때 사용.
---

# 커널 트리 sparse checkout

Linux 트리는 파일 8만 개다. 전체를 받거나 전체에 `grep -r`을 돌리면
컨텍스트가 한 번에 소진된다.

## 클론

```bash
git clone --depth 1 --filter=blob:none --sparse <repo> <dir>
cd <dir>
git sparse-checkout set <path1> <path2> ...
```

`--filter=blob:none`이 핵심이다. 파일 내용을 필요할 때만 받는다.
다운스트림 커널 기준 1.5GB → 14MB.

## 이 프로젝트의 트리

**다운스트림** (하드웨어 사실의 원천):
```bash
git clone --depth 1 --filter=blob:none --sparse -b lineage-20 \
  https://github.com/LineageOS/android_kernel_samsung_gta4xl.git ds
cd ds && git sparse-checkout set \
  arch/arm64/configs \
  arch/arm64/boot/dts/samsung \
  arch/arm64/boot/dts/exynos \
  drivers/usb/dwc3 drivers/phy/samsung \
  drivers/muic drivers/usb/typec/sm5713 \
  drivers/soc/samsung/acpm firmware
```

**메인라인**:
```bash
git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/torvalds/linux.git ml
cd ml && git sparse-checkout set \
  drivers/phy/samsung drivers/usb/dwc3 \
  drivers/firmware/samsung drivers/clk/samsung \
  drivers/gpu/drm/exynos drivers/gpu/drm/panel \
  arch/arm64/boot/dts/exynos
```

## 탐색 순서

1. **위치 먼저** (sparse 범위 밖도 검색된다):
   ```bash
   git ls-tree -r --name-only HEAD | grep -i <패턴>
   ```
2. 필요하면 확장: `git sparse-checkout add <path>`
3. 현재 범위 확인: `git sparse-checkout list`
4. 파일 안에서는 줄번호부터:
   ```bash
   grep -n "<패턴>" <file>
   sed -n 'A,Bp' <file>
   ```

## 큰 파일 다루기

DTS는 3000줄이 넘는다. 구조부터 파악한다:
```bash
grep -n "fragment@\|^\s*compatible = \|^&" <file.dts> | head -40
grep -n "^static\|^struct\|^config " <file.c> | head -40
```

## 금지

- `git clone` (full) — 수 GB
- `grep -r <패턴> .` — 범위 지정 없이
- `cat <대형 파일>`
- `find / -name ...`
