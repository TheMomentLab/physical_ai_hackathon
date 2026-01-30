# 🤖 Policies (정책 레퍼런스)

개별 정책 모델에 대한 상세 문서입니다.

## 문서 목록

1. **[ACT (Action Chunking Transformers)](./01_act_ko.md)** - Transformer 기반 모방 학습 정책
2. **[SmolVLA](./02_smolvla_ko.md)** - Vision-Language-Action 모델
3. **[GR00T N1.5](./03_groot_n1.5_ko.md)** - NVIDIA의 휴머노이드 로봇용 Foundation 모델

## 정책 선택 가이드

### ACT
- **장점**: 빠른 학습, 안정적인 성능
- **용도**: 단일 태스크 모방 학습
- **추천**: 대부분의 초급~중급 프로젝트

### SmolVLA
- **장점**: 언어 이해, 다양한 태스크 일반화
- **용도**: 멀티모달 학습, 복잡한 지시
- **추천**: 고급 프로젝트, 연구용

### GR00T N1.5
- **장점**: 휴머노이드 특화, 대규모 데이터셋 학습, 언어-비전 통합
- **용도**: 휴머노이드 로봇, 복잡한 조작 작업
- **추천**: 휴머노이드 프로젝트, 고성능 요구 환경

## 더 많은 정책

LeRobot은 더 많은 정책을 지원합니다:
- Diffusion Policy
- VQ-BeT
- HIL-SERL
- TDMPC

자세한 내용은 [공식 문서](https://huggingface.co/docs/lerobot)를 참조하세요.
