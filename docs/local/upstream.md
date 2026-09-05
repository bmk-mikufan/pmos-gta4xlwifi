# 업스트림 협력 — chimac과의 작업 경계

## 현재 협력자

**Alexandru Chimac (chimac)** — Exynos 메인라인 포팅
- patchwork submitter: https://patchwork.kernel.org/project/linux-samsung-soc/list/?submitter=218332

### 작업 영역

| 모듈 | 진행도 | 담당 | 메모 |
|---|---|---|---|
| **chipid** | ✅ v1 제출 (9/14) | chimac | SoC 식별 (필수) |
| **pinctrl** | ✅ v3 제출 (1/2) | chimac | GPIO/핀 설정 (필수) |
| **clocks** | ✅ v3 제출 (7/22), 5주 리뷰 대기 | chimac | **핵심** — USB/디스플레이 선행 조건 |
| **arm64 dts** | ⚠️ v1 (9/14), v3 분리 중 | chimac | 클럭 ID v1↔v3 불일치 **주의** |
| **USB (dwc3/phy)** | 🔴 막혀 있음 | chimac | **이분법 도구로 조사 중** |
| **ACPM/mbox** | ⬜ 비어 있음 | **본인** | 협력 충돌 없음 — 자유 |
| **PMIC** | ⬜ 미정 | TBD | ACPM 완료 후 |
| **디스플레이** | ⬜ 미정 | TBD | Phase 5 (USB 완료 후) |

## 협력 주의사항

### USB PHY — 착수 전 조율 필수

chimac이 **현재 직접 작업 중**. 조율 없이 착수하면 충돌/중복 가능.

**할 수 있는 것:**
- Phase 2-3 USB PHY 레지스터 덤프 → 분석 결과 제시
- Phase 3-2 kexec 상속 부팅으로 현재 상태 파악
- USB 문제의 원인을 "클럭 미비"와 "PHY 드라이버"로 이분법 분리

**하지 말아야 할 것:**
- `phy_cfg_exynos9610` 드라이버 독자 구현 (그가 이미 함수 인터페이스 설계 중)

### ACPM — 완전한 자유

mbox + IPC 드라이버는:
- chimac이 지목했으나 착수하지 않음 ("needs mbox working")
- 다른 누구도 작업 중이 아님 → **완전히 비어있는 영역**

**협력 충돌 0** — 독자적으로 진행 가능.

### Tested-by / Reviewed-by 규칙

❌ **절대 금지**: 실제 테스트 없이 트레일러 달기

✅ **올바른 사용**:
```bash
# 직접 테스트한 결과만
Tested-by: User <15c33@csh-h.gne.go.kr>

# 코드 리뷰 (충돌 없는 범위)
Reviewed-by: User <...>    # 사용하지 말 것 (메인테이너만 사용)
```

## chimac 시리즈 (필수 적용)

### 적용 순서
```
1. chipid (2편)
2. pinctrl (3편)
3. clocks (5편)   ← 클럭 ID 매크로 포함
4. dts (3편)      ← ⚠️ 클럭 ID 버전 확인 필수 (docs/hardware.md)
```

**하나라도 빠지면 빌드 또는 부팅 실패.**

### 메시지 ID 확보 및 적용

```bash
# patchwork에서 Message-ID 복사
# 형태: 20260722-exynos9610-cmu-v3-0-XXXXXXXX@gmail.com

# 방법 A: mbox로 받아서 확인 후 적용
b4 am -o /tmp/patches <message-id>
less /tmp/patches/*.mbx        # 내용 확인
git am /tmp/patches/*.mbx

# 방법 B: 받아서 바로 적용
b4 shazam <message-id>
```

`b4 am`은:
- 스레드에서 최신 리비전 자동 선택
- `Reviewed-by`/`Acked-by` 트레일러 수집

### 적용 확인

```bash
# 네 파일이 모두 존재해야 다음 단계로
git log --oneline linux-next/master..HEAD
ls drivers/clk/samsung/clk-exynos9610.c
ls include/dt-bindings/clock/samsung,exynos9610.h
ls arch/arm64/boot/dts/exynos/exynos9610*.dts*
```

## 기여 방법

### 즉시 가능 (충돌 없음)

| 항목 | 우선도 | 비고 |
|---|---|---|
| **clocks v3 Tested-by** | 🔴 높음 | 5주째 A/R/T 전부 0. 테스터 부재가 정체의 원인일 수 있음 |
| **USB PHY 덤프 공유** | 🟡 중간 | chimac이 USB에서 막혀 있음 — 측정 결과가 그의 다음 단계 진전 도움 |
| **ACPM 측정 결과** | 🟡 중간 | chimac의 가정 검증/반증 |

⚠️ **실제로 테스트하지 않고 Tested-by를 달지 말 것.**

### b4 워크플로 (공식)

```bash
# 자신의 커밋을 시리즈로 준비
b4 prep -n <label> -f <tag>

# 트레일러 업데이트 (Reviewed-by 등)
b4 trailers -u

# 커버레터 편집
b4 prep --edit-cover

# 패치 생성
b4 send -o /tmp/tosend

# 스타일 체크
./scripts/checkpatch.pl /tmp/tosend/*

# 기존 v1과 비교 (v2 제출할 때)
b4 prep --compare-to v1

# CC 자동 생성
b4 prep --auto-to-cc

# 최종 검사
b4 prep --check

# 자기자신에게 먼저 발송 (테스트)
b4 send --reflect

# 본 발송
b4 send
```

## chimac에게 물어볼 것

### 확인할 사항들

1. **ACPM 로더**
   ```
   "다운스트림 acpm_ipc.c가 SRAM에서 initdata를 읽기만 하고 
    코어 펌웨어 로드는 하지 않는데, S-Boot가 안 올린다면 
    다운스트림에선 누가 올리는 건가요? 로더를 새로 써야 하는지 
    판단하려고 합니다."
   ```
   → 코드상의 모순을 묻는 질문 (추측 확인이 아님)

2. **USB PHY 진행도**
   ```
   "USB PHY 덤프/분석 결과를 공유할 준비가 되면 
    msgid로 회신하겠습니다."
   ```

3. **DTS 시리즈 버전**
   ```
   "clocks v1과 v3 사이 클럭 ID 변경이 있었나요? 
    대조 스크립트를 실행했습니다."
   ```

## 링크

- **chimac patchwork**: https://patchwork.kernel.org/project/linux-samsung-soc/list/?submitter=218332&state=*
- **clocks v1 (참고)**: https://lkml.org/lkml/2025/9/14/470
- **pinctrl v3**: https://lkml.org/lkml/2026/1/2/233
- **Exynos 커널 위키**: https://exynos.wiki.kernel.org/
- **b4 문서**: https://b4.docs.kernel.org/en/latest/

