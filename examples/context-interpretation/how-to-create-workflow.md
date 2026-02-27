# Agent 파일 기반으로 Workflow 만드는 2가지 방법

## 방법 비교

```
방법 A: 올인원 (단순)              방법 B: 분리 (재사용 가능)
─────────────────────             ─────────────────────────
.github/workflows/                .github/agents/
└── issue-triage.md               │  └── issue-triage.agent.md  ← AI 행동 지시만
    (frontmatter + 지시사항        │                                (on: 없음)
     모두 한 파일에)               .github/workflows/
                                  └── issue-triage.md           ← 인프라 설정
                                      (on: + imports: agent)
```

### 방법 A가 적합한 경우
- 워크플로우가 하나뿐이고, 에이전트 재사용 불필요
- 빠르게 시작하고 싶을 때

### 방법 B가 적합한 경우
- 같은 에이전트를 여러 워크플로우에서 공유
  (예: issue-triage 로직을 여러 repo에서 import)
- 인프라 설정(permissions, triggers)과 AI 지시사항을 분리하고 싶을 때

---

## 실행 흐름 (공통)

```bash
# 1. gh-aw CLI 설치
gh extension install github/gh-aw

# 2. 레포 초기화
gh aw init

# 3. 워크플로우 파일 작성 (.github/workflows/*.md)

# 4. 컴파일 → .lock.yml 생성
gh aw compile

# 5. 커밋 & 푸시 (.md + .lock.yml 둘 다)
git add .github/workflows/issue-triage.md .github/workflows/issue-triage.lock.yml
git commit -m "Add issue triage agentic workflow"
git push

# 6. 수동 실행 (테스트) 또는 트리거 대기
gh aw run issue-triage
```

## 핵심 규칙
- **컴파일 대상은 `.github/workflows/*.md`** (agents/ 아님!)
- `.lock.yml`이 실제 GitHub Actions가 실행하는 파일
- frontmatter 변경 → 재컴파일 필요
- 마크다운 본문 변경 → 재컴파일 불필요 (런타임에 읽힘)
