---
name: kconfig
description: Kernel config 수정 (merge_config.sh + 의존성 검증)
trigger: kconfig|CONFIG|kernel.*config|merge.*config
---

# kconfig 스킬

**목적**: `merge_config.sh` + `make olddefconfig` + 자동 검증으로 커널 설정을 안전하게 수정.

**금지**: `make menuconfig`, `pmbootstrap kconfig edit` (TUI는 행이 걸림)

**위키 경고**: `config-*.aarch64` 파일을 직접 편집하면 **의존성이 해결되지 않고 변경이 조용히 무시된다.**

---

## 절차

### 1단계 — 베이스 config 확보

```bash
source ~/code/pmbootstrap/helpers/envkernel.sh
cd ~/code/linux

# pmaports 기본 설정
cp ~/code/pmaports/device/testing/linux-postmarketos-exynos9610/config-*.aarch64 \
   .output/.config

# 또는 defconfig (부트로더 패치 후)
make exynos_defconfig
```

### 2단계 — fragment 작성

**필요한 심볼들을 파일로 정리:**

```bash
cat > /tmp/debug.fragment << 'EOF'
CONFIG_PSTORE=y
CONFIG_PSTORE_CONSOLE=y
CONFIG_PSTORE_RAM=y
CONFIG_PSTORE_PMSG=y
CONFIG_KEXEC=y
CONFIG_DEVMEM=y
# CONFIG_STRICT_DEVMEM is not set
EOF
```

**또는 USB/디스플레이 설정:**

```bash
cat > /tmp/usb.fragment << 'EOF'
CONFIG_USB_GADGET=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_U_SERIAL=y
CONFIG_USB_CONFIGFS_ACM=y
CONFIG_USB_G_SERIAL=y
CONFIG_USB_ETH=y
EOF
```

### 3단계 — 병합 + 의존성 검증 (★ 중요)

```bash
./scripts/kconfig/merge_config.sh -m .output/.config /tmp/debug.fragment
make olddefconfig
```

**예상 출력:**
```
Merging .output/.config and /tmp/debug.fragment
Value requested for CONFIG_KEXEC not in final .config
Requested value:  CONFIG_KEXEC=y
Actual value:
```

**출력이 있으면 의존성 미충족.** ← 이것이 위키가 경고한 "silently ignored" 방지 메커니즘.

### 4단계 — 의존성 추적 (필요시)

만약 `CONFIG_KEXEC=y`가 최종 config에 들어가지 않으면:

```bash
# Kconfig에서 depends on 줄 확인
grep -B2 -A12 "^config KEXEC" arch/arm64/Kconfig

# 또는 USB ACM 등
grep -B2 -A12 "^config USB_CONFIGFS_ACM" drivers/usb/gadget/Kconfig

# depends on 줄을 보고 상위 심볼을 fragment 앞쪽에 추가
```

**예: ACM은 다음 순서대로 전부 필요:**
```
CONFIG_USB_GADGET=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_U_SERIAL=y
CONFIG_USB_CONFIGFS_ACM=y
```

### 5단계 — 최종 확인

```bash
grep -E "^CONFIG_(PSTORE|KEXEC|DEVMEM)" .output/.config
grep "STRICT_DEVMEM" .output/.config
```

**출력 예시 (정상):**
```
CONFIG_PSTORE=y
CONFIG_PSTORE_CONSOLE=y
CONFIG_PSTORE_RAM=y
CONFIG_PSTORE_PMSG=y
CONFIG_KEXEC=y
CONFIG_DEVMEM=y
# CONFIG_STRICT_DEVMEM is not set
```

### 6단계 — 패키지에 반영 (Phase 6)

```bash
cp .output/.config \
   ~/code/pmaports/device/testing/linux-postmarketos-exynos9610/config-....aarch64

# ★ 체크섬 재생성 필수 (빼먹으면 빌드 실패)
pmbootstrap checksum linux-postmarketos-exynos9610

# 비대화형 검증 (kconfig edit 대신)
pmbootstrap kconfig check linux-postmarketos-exynos9610
```

---

## 금지 명령

| 명령 | 이유 |
|---|---|
| `pmbootstrap kconfig edit` | TUI, Alpine chroot에서 행이 걸림 |
| `make menuconfig` | 동일 (TUI 필요) |
| `make nconfig` | 동일 |
| 직접 `.config` 편집 | 의존성 해결 안 됨 — 위키 경고 |

---

## TUI가 필요한 경우

**심볼 이름을 모를 때** — grep으로 대부분 해결 가능:

```bash
# ACM 관련 심볼 찾기
grep -rn "config.*ACM" drivers/usb/gadget/Kconfig

# PSTORE 관련
grep -rn "^config PSTORE" fs/pstore/Kconfig
```

정 안 되면:
```bash
pmbootstrap kconfig edit -n    # nconfig (검색 지원)
```

---

## 참고

- **위키**: https://wiki.postmarketos.org/wiki/Kernel_configuration#Automatically_merging_kernel_configuration
- **script**: `linux/scripts/kconfig/merge_config.sh`

