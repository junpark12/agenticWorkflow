---
# ================================================================
# 방법 A: 올인원 워크플로우
# ================================================================
# 하나의 .md 파일에 인프라 설정 + AI 지시사항을 모두 포함
# 컴파일: gh aw compile
# 결과:   .github/workflows/issue-triage.lock.yml 생성
# ================================================================

on:
  issues:
    types: [opened, edited]

permissions:
  contents: read
  issues: read

tools:
  github:
    toolsets: [default, issues]

network:
  allowed: []

safe-outputs:
  add-labels:
    allowed:
      - bug
      - enhancement
      - question
      - documentation
      - "priority:critical"
      - "priority:high"
      - "priority:medium"
      - "priority:low"
      - "area:auth"
      - "area:api"
      - "area:ui"
      - "area:infra"
      - "area:feature-flags"
  add-comment:
    max: 1
---

# Issue Triage

이슈 #${{ github.event.issue.number }} 을 분석하여 분류하세요.

## 핵심 원칙

**키워드가 아닌 맥락을 기반으로 판단하세요.**

- "bug"라는 단어가 포함되어 있어도, 실제로 버그 리포트가 아닐 수 있습니다
- "feature"라는 단어가 있어도, 기능 요청이 아니라 기존 기능의 문제일 수 있습니다
- 이슈의 제목과 본문 전체를 읽고, 작성자의 **의도**를 파악하세요

## 분류 기준

### 이슈 유형 (type)

1. **bug**: 기존 기능이 의도대로 동작하지 않는 경우
2. **enhancement**: 새로운 기능 요청 또는 기존 기능 개선 제안
3. **question**: 사용법, 설정, 동작 방식에 대한 질문
4. **documentation**: 문서 개선이 필요한 경우

### 우선순위 (priority)

- **critical**: 서비스 전체 장애, 데이터 손실, 보안 취약점
- **high**: 주요 기능 장애, 다수 사용자 영향
- **medium**: 부분적 기능 문제, 우회 가능
- **low**: 사소한 문제, UI 개선, 오타

### 영역 (area)

- **auth**: 인증, 로그인, 권한, 토큰
- **api**: API 엔드포인트, 응답, 요청
- **ui**: 화면, 버튼, 레이아웃, CSS
- **infra**: CI/CD, 배포, 서버, 인프라
- **feature-flags**: 기능 토글, 피처 플래그

## 판단 예시

> 제목: "feature flag가 동작하지 않습니다"
> 본문: "프로덕션에서 feature toggle 활성화 후 에러 발생"

→ `bug` ("feature"가 있지만 기능 요청이 아니라 기존 기능의 오작동)
→ `area:feature-flags`
→ `priority:high` (프로덕션 영향)

## 출력

1. **라벨 추가**: 유형 + 우선순위 + 영역
2. **코멘트 작성**: 분류 근거를 간단히 설명
