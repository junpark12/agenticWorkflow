# GitHub Agentic Workflows 학습 노트

> 원문: https://thomasthornton.cloud/why-you-should-use-github-agentic-workflows/
> 공식 문서: https://github.github.com/gh-aw/

## 핵심 개념

GitHub Agentic Workflows는 **GitHub Actions 위에 구축**된 자연어 기반 워크플로우 시스템이다.

- YAML에 모든 로직을 넣는 대신, **마크다운으로 자연어 지시사항**을 작성
- `gh aw compile` 명령으로 `.lock.yml` 파일로 변환 → Actions가 실행
- Copilot CLI, Claude, Codex 같은 AI 에이전트가 마크다운을 읽고 판단

## 워크플로우 파일 구조

하나의 `.md` 파일이 두 영역으로 나뉜다:

```
.github/workflows/issue-triage.md
┌─── frontmatter (--- ~ ---) ──────────────────────────┐
│  YAML 형식 · 컴파일러(gh aw compile)가 읽는 부분      │
│                                                       │
│  on:           → 언제 실행?                            │
│  permissions:  → 어떤 권한? (에이전트는 read-only)      │
│  tools:        → 어떤 도구 허용?                       │
│  network:      → 어떤 네트워크 허용?                    │
│  safe-outputs: → 어떤 쓰기 동작 허용?                  │
│                                                       │
│  → .lock.yml (GitHub Actions YAML)로 변환됨           │
├───────────────────────────────────────────────────────┤
│  마크다운 본문 · AI 에이전트가 읽는 부분                │
│                                                       │
│  역할 정의, 판단 기준, 예시, 출력 형식 등               │
│                                                       │
│  → 런타임에 에이전트의 system prompt로 전달됨           │
└───────────────────────────────────────────────────────┘
```

- **frontmatter 변경** → 재컴파일 필요 (`gh aw compile`)
- **마크다운 본문 변경** → 재컴파일 불필요 (런타임에 읽힘)

## 실행 방법

```bash
gh extension install github/gh-aw    # 1. CLI 설치
gh aw init                            # 2. 레포 초기화
# .github/workflows/*.md 작성         # 3. 워크플로우 작성
gh aw compile                         # 4. .md → .lock.yml 컴파일
git add . && git push                 # 5. 커밋 & 푸시 (.md + .lock.yml 둘 다)
gh aw run issue-triage                # 6. 수동 실행 (테스트)
```

## 컴파일 후 생성되는 .lock.yml의 3-Job 구조

```
gh aw compile 실행 시:
  .github/workflows/issue-triage.md
    → .github/workflows/issue-triage.lock.yml (자동 생성)

.lock.yml 내부의 3개 Job:

  Job 1: agent (read-only)
    → AI 에이전트가 이슈를 읽고 맥락을 해석
    → 분류 결과를 structured output으로만 생성
    → 직접 쓰기 권한 없음

  Job 2: threat-detection (자동)
    → 에이전트 출력에서 prompt injection, secret leak 등 검사

  Job 3: safe-outputs (write 권한)
    → 검증된 출력만 실제로 적용 (라벨 추가, 코멘트 작성 등)
    → frontmatter의 safe-outputs 정책에 따라 허용된 것만 실행
```

## 보안 3계층

1. **Substrate trust** – 컨테이너화된 러너, 네트워크 방화벽, MCP 게이트웨이
2. **Configuration trust** – 도구/권한/트리거를 선언적으로 정의
3. **Plan trust** – SafeOutputs로 단계적, 검증된 쓰기만 허용

## 전통적 자동화가 어려운 4가지 영역

기존 자동화는 **모든 단계를 사전에 알 수 있을 때** 잘 동작한다.
하지만 아래 4가지가 필요한 경우에는 한계가 있다:

| 영역 | 설명 |
|------|------|
| **Context interpretation** | 맥락을 이해하고 해석해야 하는 경우 |
| **Judgment calls** | 상황에 따른 판단이 필요한 경우 |
| **Summarisation** | 정보를 요약해야 하는 경우 |
| **Narrative clarity** | 사람이 읽기 좋은 설명을 생성해야 하는 경우 |

---

## 예제: Context Interpretation (이슈 자동 트리아지)

"Context interpretation"이란 **텍스트의 표면적 키워드가 아니라, 전체 맥락을 이해해서 판단**하는 능력이다.

### ❌ 전통적 방식의 한계 (키워드 매칭)

```yaml
# 키워드 기반: "bug"라는 단어가 있으면 무조건 bug 라벨
- uses: actions/github-script@v7
  with:
    script: |
      const text = `${issue.title} ${issue.body}`.toLowerCase();
      const rules = [
        { keywords: ['bug', 'error', 'crash'], label: 'bug' },
        { keywords: ['feature', 'enhancement'],  label: 'enhancement' },
      ];
      for (const rule of rules) {
        if (rule.keywords.some(kw => text.includes(kw))) {
          labels.push(rule.label);
        }
      }
```

이 방식이 실패하는 사례들:

| 이슈 제목 | 기대 라벨 | 키워드 결과 | 문제 |
|-----------|----------|------------|------|
| "이것은 bug가 아닙니다" | `question` | `bug` ❌ | 부정 문맥 무시 |
| "로그인 시 앱이 멈춤" | `bug` | 라벨 없음 ❌ | "bug" 키워드 없어서 누락 |
| "feature flag 관련 에러" | `bug` | `enhancement` ❌ | "feature" 키워드로 오분류 |
| "대시보드가 좀 이상해요" | `bug` | 라벨 없음 ❌ | 비공식 표현 인식 불가 |

### ✅ Agentic Workflow 방식 (맥락 이해)

에이전트가 이슈의 전체 맥락을 읽고 의미를 파악해서 판단한다.
실제 워크플로우: [`.github/workflows/issue-triage.md`](.github/workflows/issue-triage.md)

```
이슈: "feature flag 시스템 장애"
본문: "프로덕션에서 feature toggle 활성화 후 500 에러 발생. 롤백 필요."

에이전트의 추론:
  1. "feature"가 있지만 → 기능 요청이 아님
  2. "장애", "500 에러", "롤백 필요" → 심각한 버그
  3. "프로덕션 전체 사용자 영향" → critical 우선순위

결과: bug, area:feature-flags, priority:critical ✅
```

### 테스트 시나리오

#### 시나리오 1: 부정 문맥 (Negation)

> 제목: "이것은 bug가 아닌 것 같은데 질문이 있습니다"
> 본문: "로그인 페이지에서 비밀번호가 8자 이상이어야 하나요?"

| 키워드 방식 | Agentic 방식 |
|-----------|-------------|
| `bug` ❌ ("bug" 포함) | `question`, `area:auth`, `priority:low` ✅ |

#### 시나리오 2: 암시적 버그 (Implicit Bug)

> 제목: "저장 버튼을 누르면 아무 반응이 없어요"
> 본문: "프로필 편집 후 저장 클릭해도 아무 일도 일어나지 않습니다."

| 키워드 방식 | Agentic 방식 |
|-----------|-------------|
| 라벨 없음 ❌ ("bug" 키워드 없음) | `bug`, `area:ui`, `priority:high` ✅ |

#### 시나리오 3: 복합 의도 (Mixed Intent)

> 제목: "API 타임아웃 문제 + 개선 제안"
> 본문: "30초 타임아웃 발생. 페이지네이션 추가해주시면 좋겠습니다."

| 키워드 방식 | Agentic 방식 |
|-----------|-------------|
| `enhancement` ⚠️ (부분만 정확) | `bug` + `enhancement`, `area:api`, `priority:medium` ✅ |

#### 시나리오 4: 비공식 표현 (Linguistic Context)

> 제목: "대시보드가 좀 이상해요"
> 본문: "어제까지 잘 되던 차트가 갑자기 데이터를 안 보여줍니다."

| 키워드 방식 | Agentic 방식 |
|-----------|-------------|
| 라벨 없음 ❌ (매칭 안됨) | `bug`, `area:ui`, `priority:high` ✅ |

### 핵심 차이 요약

| 구분 | 전통적 자동화 | Agentic Workflow |
|------|-------------|------------------|
| 판단 방식 | 키워드 매칭 | 전체 맥락 이해 |
| 부정 표현 | 인식 불가 | "bug가 아닙니다" → bug 아님 |
| 암시적 의미 | 인식 불가 | "멈춤", "안 됨" → bug |
| 복합 의도 | 하나만 분류 | 여러 유형 동시 분류 |
| 우선순위 | 규칙 없으면 불가 | 영향도 기반 추론 |
| 유지보수 | 규칙 계속 추가 | 지시사항 한 번 작성 |

## 주요 기능 참고

- `safe-outputs`: 에이전트가 PR/Issue/Label 등을 통제된 채널로만 제안
  - 공식 문서: https://github.github.com/gh-aw/reference/safe-outputs/
- Guardrails (frontmatter): 최소 권한, 도구 허용 목록, 네트워크 허용 목록
- Imports: 재사용 가능한 컴포넌트를 버전 고정하여 가져오기
- MCP servers: 전문 도구(Terraform 등)를 에이전트에 연결

---

## Frontmatter 설정 참고: tools

> 공식 문서: https://github.github.com/gh-aw/reference/tools/

에이전트가 사용할 수 있는 도구를 제한한다. 선언하지 않은 도구는 사용 불가.

### 기본 도구

```yaml
tools:
  # 파일 편집
  edit:

  # 셸 명령 실행
  bash:                              # 기본 안전 명령만 (echo, ls, cat, grep 등)
  bash: []                           # 모든 명령 비활성화
  bash: ["echo", "ls", "git status"] # 특정 명령만 허용
  bash: ["git:*"]                    # git 계열 명령 모두 허용
  bash: [":*"]                       # 모든 명령 허용 (주의!)

  # 웹 접근
  web-fetch:                         # 웹 페이지 내용 가져오기
  web-search:                        # 웹 검색 (엔진에 따라 MCP 필요)

  # GitHub API
  github:
    toolsets: [default, issues]      # 사용할 GitHub API 그룹 지정

  # 브라우저 자동화
  playwright:
    version: "1.56.1"               # Chromium 기반 브라우저 테스트
```

### 내장 MCP 도구

```yaml
tools:
  agentic-workflows:    # 워크플로우 로그 분석, 디버깅 (actions: read 필요)
  cache-memory:          # 워크플로우 실행 간 데이터 유지
  repo-memory:           # 레포 단위 컨텍스트 유지
```

### 커스텀 MCP 서버

```yaml
mcp-servers:
  slack:
    command: "npx"
    args: ["-y", "@slack/mcp-server"]
    env:
      SLACK_BOT_TOKEN: "${{ secrets.SLACK_BOT_TOKEN }}"
    allowed: ["send_message", "get_channel_history"]

  terraform:
    container: "hashicorp/terraform-mcp-server:0.3.3"
    env:
      TF_LOG: "INFO"
    allowed: ["*"]
```

---

## Frontmatter 설정 참고: network

> 공식 문서: https://github.github.com/gh-aw/reference/network/

에이전트의 네트워크 접근을 제한한다. 허용하지 않은 도메인은 차단.

### 기본 패턴

```yaml
# 기본 인프라만 허용 (인증서, JSON 스키마, Ubuntu 미러 등)
network:
  allowed:
    - defaults

# 네트워크 접근 완전 차단
network: {}

# 에코시스템 + 커스텀 도메인 조합
network:
  allowed:
    - defaults              # 기본 인프라
    - python                # PyPI/pip 전체
    - node                  # npm/yarn/pnpm 전체
    - "api.example.com"     # 특정 도메인
```

### 사용 가능한 에코시스템 식별자

| 식별자 | 포함 범위 |
|--------|----------|
| `defaults` | 기본 인프라 (인증서, 스키마, Ubuntu, 패키지 미러) |
| `github` | GitHub 도메인 전체 |
| `containers` | Docker Hub, GHCR, Quay |
| `python` | PyPI, pip |
| `node` | npm, yarn, pnpm |
| `go` | proxy.golang.org |
| `rust` | crates.io |
| `java` | Maven Central |
| `ruby` | RubyGems |
| `dotnet` | NuGet |
| `terraform` | HashiCorp, Terraform |
| `playwright` | Playwright 테스트 프레임워크 |
| `linux-distros` | Debian, Alpine 등 패키지 레포 |

### 차단 (blocked)

```yaml
# 허용 목록에서 특정 도메인/에코시스템 제외
network:
  allowed:
    - defaults
    - node
  blocked:
    - python                # Python 에코시스템 차단
    - "cdn.example.com"     # 특정 도메인 차단
```

### 와일드카드

```yaml
network:
  allowed:
    - "*.cdn.example.com"   # 모든 서브도메인 매칭
```
