# GitHub Agentic Workflows 학습 노트

> 원문: https://thomasthornton.cloud/why-you-should-use-github-agentic-workflows/

## 핵심 개념

GitHub Agentic Workflows는 **GitHub Actions 위에 구축**된 자연어 기반 워크플로우 시스템이다.

- YAML에 모든 로직을 넣는 대신, **마크다운으로 자연어 지시사항**을 작성
- `gh aw compile` 명령으로 `.lock.yml` 파일로 변환 → Actions가 실행
- Copilot CLI, Claude, Codex 같은 AI 에이전트가 마크다운을 읽고 판단

## 전통적 자동화가 어려운 4가지 영역

기존 자동화는 **모든 단계를 사전에 알 수 있을 때** 잘 동작한다.
하지만 아래 4가지가 필요한 경우에는 한계가 있다:

| 영역 | 설명 | 예제 폴더 |
|------|------|-----------|
| **Context interpretation** | 맥락을 이해하고 해석해야 하는 경우 | `examples/context-interpretation/` |
| **Judgment calls** | 상황에 따른 판단이 필요한 경우 | (TBD) |
| **Summarisation** | 정보를 요약해야 하는 경우 | (TBD) |
| **Narrative clarity** | 사람이 읽기 좋은 설명을 생성해야 하는 경우 | (TBD) |

## 보안 3계층

1. **Substrate trust** – 컨테이너화된 러너, 네트워크 방화벽, MCP 게이트웨이
2. **Configuration trust** – 도구/권한/트리거를 선언적으로 정의
3. **Plan trust** – SafeOutputs로 단계적, 검증된 쓰기만 허용

## 주요 기능

- `safe-outputs`: 에이전트가 PR/Issue/Label 등을 통제된 채널로만 제안
- Guardrails (frontmatter): 최소 권한, 도구 허용 목록, 네트워크 허용 목록
- Imports: 재사용 가능한 에이전트/스킬을 버전 고정하여 가져오기
- MCP servers: 전문 도구(Terraform 등)를 에이전트에 연결
