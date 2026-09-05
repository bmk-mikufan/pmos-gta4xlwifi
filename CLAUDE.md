# gta4xlwifi mainline porting

Samsung Galaxy Tab S6 Lite Wi-Fi (SM-P610, Exynos 9611) → mainline Linux + postmarketOS.
부트로더는 uniLoader. 빌드는 Windows + WSL2.

## 현재 목표
커널이 `/init` 진입 직후 하드 리셋되는 문제 해결. 이게 유일한 블로커다.
**`HANDOFF.md`를 먼저 읽을 것** — 배제된 가설, 남은 가설, 다음 실험이 거기 있다.
(ACPM/mbox/USB2 PHY 드라이버는 작성·빌드까지 끝났으나, 리셋 때문에 실기기 검증 불가.)

## 확신도 표기 — 반드시 지킬 것
- ✅ 검증됨: 소스에서 직접 확인
- 🟡 추정: 미검증 추론
- ❌ 미확인: 측정 필요

**추정을 검증된 사실처럼 쓰지 말 것.** 특히 레지스터 주소와 전압값.
새 사실이 확정되면 `docs/local/findings/`에 기록하고 표기를 갱신한다.

## 절대 규칙

1. **커널 트리 전체에 `grep -r` 금지.** 경로를 명시하거나 sparse-checkout 확장.
   → 절차는 `kernel-tree` 스킬
2. **`make menuconfig` / `pmbootstrap kconfig edit` 실행 금지.** TUI는 행이 걸린다.
   → kconfig 수정은 `kconfig` 스킬
3. **config 파일 직접 편집 금지.** 의존성이 조용히 무시된다 (pmOS 위키 경고).
4. **DTS에 레귤레이터 노드를 추가하지 말 것.** 위키 명시 경고, 하드웨어 손상 위험.
   불가피하면 `regulator_summary` 실측값으로 min=max 고정.
5. **파일 전체 `cat` 금지.** `grep -n`으로 위치 찾고 `sed -n 'A,Bp'`로 구간만.
6. **빌드 로그는 필터링 후 최대 50줄.** `grep -iE "error|failed"`
7. **소스 조사는 `source-digger` 서브에이전트에 위임.** 메인 컨텍스트 보호.

## 참조 문서 (필요할 때만 읽을 것)

| 파일 | 내용 |
|---|---|
| `HANDOFF.md` | **인수인계 요약 — 제일 먼저 읽을 것** |
| `docs/포팅_작업_기록.md` | 날짜별 전체 작업 기록 |
| `docs/local/workflow.md` | Phase 0~7 전체 절차, 명령, 주소 |
| `docs/local/hardware.md` | 검증된 하드웨어 사실 (DTS, 레지스터, 패널) |
| `docs/local/upstream.md` | chimac 패치 상태, 협업 경계 |
| `docs/local/findings/` | 측정 결과 축적 |

## 협업 경계

업스트림 작업자 Alexandru Chimac(chimac)이 clocks/pinctrl/USB를 진행 중.
- **USB PHY 패치**: 그가 막혀 있는 영역 → 착수 전 조율
- **ACPM/mbox**: 비어 있음 → 자유
- `Tested-by`는 실제 테스트 없이 절대 달지 말 것

## 미해결 (측정으로만 해결됨)

`docs/local/workflow.md` 말미의 표 참조. 1·3·4·5가 나머지를 막고 있다.
