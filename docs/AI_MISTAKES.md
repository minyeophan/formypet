# AI 실수 기록

이 파일은 매 세션 시작 시 `docs/CONTEXT.md` 다음에 읽는다.

## 반복 실수

### BottomSheet open state 회귀

- BottomSheet를 조건부로 언마운트한 뒤 같은 렌더에서 ref effect로 열려고 하지 않는다.
- context 상태로 열리는 시트는 계속 마운트해 일관되게 제어하거나, 열릴 때만 마운트한다면 `index={0}`를 명확히 준다.
- 닫기 동작을 바꾼 뒤에는 `openModal()` 진입점을 모두 확인한다.
- 다음 검증: 홈 빠른 기록 버튼, 루틴 바로가기, `records.tsx` 추가 버튼에서 열림/닫힘을 직접 확인한다.

### 한글 mojibake 회귀

- 한글 UI 텍스트, 주석, Markdown은 UTF-8로 유지한다.
- PowerShell 기본 출력만 보고 파일이 깨졌다고 판단하지 않는다.
- 한글 파일은 `Get-Content -Encoding utf8` 또는 strict UTF-8 스캐너 기준으로 확인한다.
- PowerShell로 파일을 다시 쓸 때는 `-Encoding utf8`을 명시한다.
- 다음 검증: 한글 편집 뒤 `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1`를 실행한다.

스캐너가 잡아야 하는 의심 예시는 아래 같은 깨진 조각이다. 실제 문서 본문에는 남기지 않는다.

```text
좏 猷 留 쒓
```

## 기록 기준

같은 실수가 3회 이상 반복되면 아래 내용을 추가한다.

- 무엇이 깨졌는지
- 왜 깨졌는지
- 다음에 반드시 실행할 검증
