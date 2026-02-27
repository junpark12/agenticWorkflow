# Context Interpretation 예제: 이슈 자동 트리아지

## 왜 Context Interpretation이 필요한가?

"Context interpretation"이란 **텍스트의 표면적 키워드가 아니라, 전체 맥락을 이해해서 판단**하는 능력이다.

### 전통적 자동화의 한계 (keyword 기반)

```yaml
# ❌ 기존 방식: 키워드 매칭
# "bug"라는 단어가 있으면 무조건 bug 라벨을 붙인다
on:
  issues:
    types: [opened]

jobs:
  label:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            const title = context.payload.issue.title.toLowerCase();
            const body = context.payload.issue.body?.toLowerCase() || '';

            if (title.includes('bug') || body.includes('bug')) {
              await github.rest.issues.addLabels({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                labels: ['bug']
              });
            }
            if (title.includes('feature') || body.includes('feature')) {
              await github.rest.issues.addLabels({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                labels: ['enhancement']
              });
            }
```

### 이 방식이 실패하는 실제 사례들

| 이슈 제목 | 이슈 본문 | 기대 라벨 | 키워드 방식 결과 | 문제 |
|-----------|----------|----------|----------------|------|
| "이것은 bug가 아닙니다" | "단순 질문입니다" | `question` | `bug` ❌ | "bug"라는 단어가 있어서 오분류 |
| "로그인 시 앱이 멈춤" | "저장 버튼 클릭 후 무한 로딩" | `bug` | 라벨 없음 ❌ | "bug"라는 단어가 없어서 누락 |
| "feature flag 관련 에러" | "feature toggle이 동작하지 않음" | `bug` | `enhancement` ❌ | "feature"라는 단어로 오분류 |
| "성능 개선 제안" | "API 응답이 5초 이상 걸림" | `enhancement`, `performance` | 라벨 없음 ❌ | 키워드 미매칭 |
| "CI 파이프라인에서 bug fix가 반영 안됨" | "배포 문제" | `ci/cd` | `bug` ❌ | 문맥 무시 |

**→ 키워드 기반으로는 사람의 의도를 정확히 파악할 수 없다.**

---

## Agentic Workflow 방식 (Context Interpretation)

에이전트가 이슈의 **전체 맥락을 읽고 이해**해서 판단한다.

### 파일 구조

```
.github/
├── agents/
│   └── issue-triage.agent.md          ← 에이전트 정의 (자연어 지시사항)
└── workflows/
    └── shared/
        └── issue-triage-tools.md      ← 재사용 가능한 공유 컴포넌트 (import 전용)
```

### 동작 흐름

```
┌─────────────────────────────────────────────────────────┐
│  새 이슈 생성                                              │
│  제목: "feature flag 관련 에러"                              │
│  본문: "feature toggle이 동작하지 않음, 콘솔에 에러 발생"       │
└──────────────┬──────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────┐
│  Agentic Workflow 트리거                                   │
│  (on: issues - types: [opened])                          │
└──────────────┬──────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────┐
│  🤖 AI 에이전트의 Context Interpretation                   │
│                                                          │
│  1. 제목 분석: "feature flag 관련 에러"                      │
│     → "feature"가 있지만 기능 요청이 아님                     │
│     → "에러"가 핵심 → 뭔가 동작하지 않는 상황                  │
│                                                          │
│  2. 본문 분석: "동작하지 않음", "에러 발생"                    │
│     → 기존 기능의 오작동을 보고하는 것                         │
│                                                          │
│  3. 종합 판단:                                              │
│     → 이것은 feature request가 아니라 bug report             │
│     → 영향 범위: feature flag 시스템 전체                     │
│     → 우선순위: 높음 (기능 토글 장애는 배포에 영향)              │
└──────────────┬──────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────┐
│  safe-outputs를 통한 제어된 액션                             │
│                                                          │
│  ✅ 라벨: bug, priority:high, area:feature-flags          │
│  ✅ 담당팀: @platform-team (feature flag 관련)              │
│  ✅ 코멘트: 분류 근거 설명 (투명성)                           │
└─────────────────────────────────────────────────────────┘
```

### 핵심 차이점 요약

| 구분 | 전통적 자동화 (YAML) | Agentic Workflow |
|------|---------------------|------------------|
| 판단 방식 | 키워드 매칭 (`if contains "bug"`) | 전체 맥락을 읽고 의미를 이해 |
| "feature flag 에러" 처리 | `enhancement` (오분류) | `bug` (정확) |
| "이것은 bug가 아닙니다" 처리 | `bug` (오분류) | `question` (정확) |
| 우선순위 판단 | 불가능 (규칙 없으면 무시) | 영향도 기반으로 판단 |
| 담당팀 배정 | 키워드→팀 매핑 테이블 필요 | 이슈 내용에서 관련 영역 추론 |
| 유지보수 | 키워드/규칙 계속 추가 필요 | 지시사항 한 번 작성, 에이전트가 적응 |
