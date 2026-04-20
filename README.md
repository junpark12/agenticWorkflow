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
gh aw secrets bootstrap               # 5. 필요한 시크릿 확인 & 설정
git add . && git push                 # 6. 커밋 & 푸시 (.md + .lock.yml 둘 다)
gh aw run issue-triage                # 7. 수동 실행 (테스트)
```

## 인증 설정 (필수)

> 공식 문서: https://github.github.com/gh-aw/reference/auth/

모든 AI 엔진은 GitHub Actions 시크릿 설정이 필요하다.
`engine:`을 지정하지 않으면 기본값 `copilot`이 사용된다.

### 엔진별 시크릿

| 엔진 | 시크릿 이름 | 값 |
|------|-----------|-----|
| `copilot` (기본) | `COPILOT_GITHUB_TOKEN` | GitHub Fine-grained PAT |
| `claude` | `ANTHROPIC_API_KEY` | Anthropic API 키 |
| `codex` | `OPENAI_API_KEY` | OpenAI API 키 |
| `gemini` | `GEMINI_API_KEY` | Google AI Studio API 키 |

### Copilot 엔진 설정 방법

1. **Fine-grained PAT 생성**
   - https://github.com/settings/personal-access-tokens/new 에서 생성
   - Resource owner: **개인 계정** (조직 아님)
   - Repository access: **Public repositories** (private repo에도 이렇게 설정해야 함)
   - Permissions → Account permissions → **Copilot Requests: Read**
   - 토큰 소유자에게 **활성 Copilot 라이선스**가 있어야 함

2. **레포 시크릿에 추가**
   ```bash
   gh aw secrets set COPILOT_GITHUB_TOKEN --value "<생성한-PAT>"
   ```

3. **확인**
   ```bash
   gh aw secrets bootstrap    # 워크플로우별 필요 시크릿 자동 확인
   ```

### 엔진 지정 방법 (frontmatter)

```yaml
---
engine: copilot    # GitHub Copilot (기본값, 생략 가능)
engine: claude     # Anthropic Claude
engine: codex      # OpenAI Codex
engine: gemini     # Google Gemini
---
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

## 예제: Judgment Calls (인프라 PR 위험도 판단)

"Judgment calls"란 **정해진 규칙이 없는 상황에서 상황에 맞게 판단을 내리는** 능력이다.
Context Interpretation이 "이게 뭐냐" (분류)라면, Judgment Calls는 "어떻게 할 것이냐" (의사결정)이다.

### 시나리오

`infra/` 하위 Bicep 파일이 변경되는 PR이 올라오면, 에이전트가 변경 내용을 분석하여
**운영 환경에 미치는 위험도를 판단**하고 라벨을 부여한다.

실제 워크플로우: [`.github/workflows/infra-pr-review.md`](.github/workflows/infra-pr-review.md)

### 동작 흐름

```
PR 생성 (infra/**/*.bicep 변경)
  │
  ▼
에이전트가 PR diff 분석
  │
  ├─ networkPolicy 제거?         → 🔴 risk:critical
  ├─ enablePrivateCluster: false? → 🔴 risk:critical
  ├─ VM 크기 축소?               → 🟠 risk:high
  ├─ K8s 버전 업그레이드?         → 🟡 risk:medium
  └─ 태그/코멘트만 변경?          → 🟢 risk:low
  │
  ▼
safe-outputs:
  ✅ risk:{level} 라벨 추가
  ✅ 분석 결과 코멘트
  ✅ 위험한 코드 라인에 리뷰 코멘트
```

### 전통적 자동화 vs Agentic

| PR 변경 내용 | 전통적 자동화 | Agentic (Judgment) |
|-------------|-------------|-------------------|
| `networkPolicy` 삭제 | 패턴 매칭 가능하지만 모든 속성을 규칙으로 작성해야 함 | diff를 읽고 "보안 정책 제거"로 판단 |
| `count: 3` → `count: 1` (prd) | 숫자 비교 규칙 필요 | "운영 환경 노드 축소 = 위험"으로 판단 |
| `serviceCidr` 변경 | 규칙 없으면 무시 | "immutable 속성 변경 = 클러스터 재생성 필요 = critical"로 판단 |
| 복합 변경 (네트워크 + SKU + 버전) | 각각 별도 규칙 필요, 종합 판단 불가 | 전체를 종합하여 가장 높은 위험도 적용 |

### ⚙️ 사전 설정 (수동으로 해야 할 것들)

#### 1. 레포에 라벨 생성

GitHub에서 사용할 라벨을 미리 만들어야 한다.

```bash
# GitHub API로 라벨 생성
gh api repos/{owner}/{repo}/labels -f name="risk:critical" -f color="B60205" -f description="운영 장애 가능성"
gh api repos/{owner}/{repo}/labels -f name="risk:high"     -f color="D93F0B" -f description="운영 영향 있음"
gh api repos/{owner}/{repo}/labels -f name="risk:medium"   -f color="FBCA04" -f description="검토 권장"
gh api repos/{owner}/{repo}/labels -f name="risk:low"      -f color="0E8A16" -f description="안전한 변경"
gh api repos/{owner}/{repo}/labels -f name="infra"         -f color="1D76DB" -f description="인프라 변경"
```

#### 2. Merge 차단 구조 이해

에이전트가 `risk:critical` 라벨을 붙여도 **Agentic Workflow 자체는 성공**으로 끝난다.
라벨을 부여하는 것이 정상 동작이기 때문이다.

따라서 **라벨만으로는 merge가 차단되지 않는다**.
실제 차단은 아래 2단계 구조로 동작한다:

```
① infra-pr-review (Agentic Workflow)
   트리거: on: pull_request (PR 생성 시 자동 실행)
   → Bicep diff 분석, 위험도 판단
   → risk:{level} 라벨 부여 + 분석 코멘트
   → dispatch-workflow로 ②를 실행 (PR 번호 전달)
   → ✅ 성공 (라벨 부여 자체가 정상 동작)

② check-risk-label (일반 GitHub Actions)
   트리거: on: workflow_dispatch (①이 dispatch해야만 실행됨)
   → PR의 라벨을 확인
   → risk:critical 있으면 exit 1 → ❌ 실패 → merge 차단
   → risk:critical 없으면       → ✅ 성공 → merge 가능
```

**실행 순서가 보장되는 이유**:
②의 트리거가 `on: workflow_dispatch`이므로 PR 이벤트로는 실행되지 않는다.
반드시 ①이 완료된 후 dispatch해야만 ②가 실행되기 때문에 **항상 ① → ② 순서**로 동작한다.
②가 실행되는 시점에는 이미 ①이 라벨을 부여한 상태이다.
   → ①이 dispatch로 실행시킴
   → PR의 라벨을 확인
   → risk:critical 있으면 exit 1 → ❌ 실패 → merge 차단
   → risk:critical 없으면       → ✅ 성공 → merge 가능
```

Ruleset의 "Require status checks"는 ①과 ②가
**둘 다 성공해야 merge 가능**하도록 강제하는 역할이다:
- ① 필수 = 에이전트가 분석을 정상 완료했는지 확인
- ② 필수 = 에이전트의 판단 결과(라벨)에 따른 실제 차단

#### 3. Repository Rulesets 설정

**Settings → Rules → Rulesets → New ruleset**:

```
Ruleset name: Infra Safety Gate
Target: Default branch
Bypass list: (관리자만 bypass 허용)

Rules:
  ✅ Restrict updates
  ✅ Require a pull request before merging
  ✅ Require status checks to pass
     → Add check: "infra-pr-review"     ← Agentic 분석 완료 확인
     → Add check: "Check Risk Label"    ← 라벨 기반 merge 차단
```

> **risk:critical 라벨이 붙은 PR을 merge하려면**:
> 인프라 팀이 리뷰 후 `risk:critical` 라벨을 제거하고
> `check-risk-label` 워크플로우를 재실행해야 한다.

#### 4. 컴파일 & 푸시

```bash
gh aw compile                  # 새 워크플로우 컴파일
git add .
git commit -m "Add infra PR risk review workflow"
git push
```

#### 5. 테스트

```bash
# 테스트 브랜치에서 Bicep 파일 수정
git checkout -b test/infra-change
# infra/modules/aks.bicep에서 enablePrivateCluster: false 로 변경
git add . && git commit -m "test: disable private cluster"
git push -u origin test/infra-change

# PR 생성
gh pr create --title "test: AKS 네트워크 설정 변경" --body "Private cluster 비활성화 테스트"
# → 에이전트가 자동으로 risk:critical 라벨 + 분석 코멘트 추가
```

---

## 예제: Summarisation (이슈 히스토리 요약)

"Summarisation"이란 **단순 집계가 아니라 내용을 이해하고 의미 있게 압축**하는 능력이다.
댓글 수, 날짜 같은 메타데이터만으로는 불가능하고, 논의 흐름의 맥락을 파악해야 한다.

### 시나리오

이슈에 새 담당자(assignee)가 지정되는 순간, 에이전트가 지금까지의 댓글 히스토리를 분석하여
**신규 담당자가 빠르게 상황을 파악할 수 있는 TL;DR 요약 코멘트**를 자동으로 작성한다.

실제 워크플로우: [`.github/workflows/issue-summary.md`](.github/workflows/issue-summary.md)

### 동작 흐름

```
이슈에 담당자 지정 (issues: assigned)
  │
  ▼
에이전트가 이슈 본문 + 전체 댓글 읽기
  │
  ├─ 댓글 10개 미만? → "요약 생략" 코멘트 후 종료
  │
  ▼
핵심 정보 추출
  ├─ 문제 정의 (한 줄 요약)
  ├─ 재현 조건 / 환경
  ├─ 시도된 해결책 & 결과
  ├─ 현재 상태 (진행 중 / 블로킹 / 해결 대기)
  └─ 미결 사항
  │
  ├─ CVE 번호 언급? → web-fetch로 nvd.nist.gov 조회
  ├─ 외부 링크 포함? → web-fetch로 내용 요약
  └─ 기술 용어 불명확? → web-fetch로 공식 문서 확인
  │
  ▼
safe-outputs:
  ✅ TL;DR 요약 코멘트 (구조화된 형식)
```

### 전통적 자동화 vs Agentic

| 상황 | 전통적 자동화 | Agentic (Summarisation) |
|------|-------------|------------------------|
| 댓글 50개짜리 이슈 | 댓글 수만 카운트 가능 | 논의 흐름 파악 후 핵심만 추출 |
| "+1", "same issue" 반복 댓글 | 모두 동일하게 처리 | 중복 댓글 무시하고 의미있는 것만 요약 |
| 시도된 해결책 추적 | 불가 | "방법 A 시도 → 실패, 방법 B 시도 → 성공" 정리 |
| CVE 번호가 댓글에 언급됨 | 텍스트로만 표시 | 외부 DB 조회 후 심각도/설명 보강 |
| 해결된 이슈 | 상태만 확인 | 해결 방법을 첫 번째로 강조 |

### ⚙️ 주요 설정

#### tools

```yaml
tools:
  github:
    toolsets: [default, issues]  # 이슈 댓글 읽기
  web-fetch: {}                   # 특정 URL 직접 조회
```

> `web-search`는 copilot 엔진에서 미지원.
> URL을 알고 있는 경우(CVE, 공식 문서)는 `web-fetch`로 직접 가져온다.

#### network

```yaml
network:
  allowed:
    - defaults
    - github                      # 에코시스템 식별자 (github.com 전체)
    - "nvd.nist.gov"              # CVE 정보
    - "learn.microsoft.com"       # Azure 공식 문서
    - "kubernetes.io"             # K8s 공식 문서
```

> 개별 도메인 대신 에코시스템 식별자(`github`) 사용 권장 — 컴파일러 경고 방지.

#### 허용 expressions

`github.event.assignee.login`은 허용 목록에 없어 사용 불가.
담당자 정보는 `github.actor`(이벤트를 트리거한 사람)로 대체.

```yaml
# ❌ 컴파일 에러
새로 배정된 담당자: `${{ github.event.assignee.login }}`

# ✅ 허용
새로 배정된 담당자: `${{ github.actor }}`
```

#### 4. 테스트

```bash
# 댓글 10개 이상인 이슈에 담당자 지정
gh issue edit {issue_number} --add-assignee {username}
# → 에이전트가 자동으로 TL;DR 요약 코멘트 추가
```

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
