# LeRobot 한국어 문서

이 디렉토리는 LeRobot 프로젝트의 한국어 문서를 포함하고 있습니다.

> 📋 **중요**: 시작하기 전에 [시스템 설정 매핑 문서](./system_mapping.md)를 확인하세요!  
> 모든 포트, 카메라, 캘리브레이션 ID가 정의되어 있습니다.

---

## 📚 문서 구조

### 🚀 [01. Getting Started (시작하기)](./01_getting_started/)
처음 시작하는 분들을 위한 필수 설정 가이드

- **[01. Installation (설치)](./01_getting_started/01_installation_ko.md)** - Miniforge, Python 환경, LeRobot 라이브러리 설치
- **[02. SO-101 Robot Setup (로봇 설정)](./01_getting_started/02_so-101_setup_ko.md)** - 부품 준비, 조립, 모터 구성, 캘리브레이션
- **[03. Cameras (카메라)](./01_getting_started/03_cameras_ko.md)** - 카메라 찾기, OpenCV/RealSense 설정, 휴대폰 카메라 사용
- **[04. USB Port Management (USB 포트 관리)](./01_getting_started/04_usb_port_management_ko.md)** - udev rule 설정, persistent device name 사용

### 📖 [02. Tutorials (튜토리얼)](./02_tutorials/)
실습 중심의 단계별 가이드

- **[01. Imitation Learning (모방 학습)](./02_tutorials/01_imitation_learning_ko.md)** - 텔레오퍼레이션, 데이터셋 기록, 정책 학습, 평가
- **[02. HIL-SERL Workflow (HIL-SERL 워크플로)](./02_tutorials/02_hil_serl_workflow_ko.md)** - 데모 수집, 보상 분류기, 인간 개입 학습

### 🔧 [03. Guides (가이드)](./03_guides/)
고급 기능 및 커스터마이징 가이드

- **[01. Custom Policies (커스텀 정책)](./03_guides/01_custom_policies_ko.md)** - 정책 패키지 구조, 구성, 구현 방법
- **[02. Custom Hardware (커스텀 하드웨어)](./03_guides/02_custom_hardware_ko.md)** - 로봇 인터페이스, feature 설계, 플러그인 배포
- **[03. RL in Simulation (시뮬레이션 RL)](./03_guides/03_rl_in_simulation_ko.md)** - gym_hil 환경, 데모 수집, Actor/Learner 학습
- **[04. Multi-GPU Training (멀티 GPU 학습)](./03_guides/04_multi_gpu_training_ko.md)** - Accelerate 설정, 멀티 GPU 실행
- **[05. PEFT Finetuning (효율적 파인튜닝)](./03_guides/05_peft_finetuning_ko.md)** - PEFT 개요, SmolVLA 예시, 타깃 모듈 설정

### 🤖 [04. Policies (정책 레퍼런스)](./04_policies/)
개별 정책 모델 상세 문서

- **[01. ACT (Action Chunking Transformers)](./04_policies/01_act_ko.md)** - ACT 아키텍처, 학습, 평가 방법
- **[02. SmolVLA](./04_policies/02_smolvla_ko.md)** - SmolVLA 개요, 환경 설정, 데이터셋 수집, 파인튜닝
- **[03. GR00T N1.5](./04_policies/03_groot_n1.5_ko.md)** - NVIDIA 휴머노이드 Foundation 모델, 학습 및 평가

---

## 🎯 빠른 시작

LeRobot을 처음 시작한다면 다음 순서로 진행하세요:

1. **[설치](./01_getting_started/01_installation_ko.md)** - 개발 환경 구축
2. **[로봇 설정](./01_getting_started/02_so-101_setup_ko.md)** - SO-101 조립 및 설정
3. **[카메라 설정](./01_getting_started/03_cameras_ko.md)** - 비전 입력 구성
4. **[모방 학습 튜토리얼](./02_tutorials/01_imitation_learning_ko.md)** - 첫 번째 프로젝트

## 💡 학습 경로

### 초급 → 중급
시작하기 문서를 모두 완료한 후, **모방 학습 튜토리얼**을 따라 첫 번째 정책을 학습해보세요.

### 중급 → 고급
- 더 복잡한 학습 방법을 원한다면: **[HIL-SERL 튜토리얼](./02_tutorials/02_hil_serl_workflow_ko.md)**
- 자신만의 로봇을 연결하려면: **[커스텀 하드웨어 가이드](./03_guides/02_custom_hardware_ko.md)**
- 새 정책을 개발하려면: **[커스텀 정책 가이드](./03_guides/01_custom_policies_ko.md)**

## 💬 지원

질문이나 도움이 필요하면 [LeRobot Discord 커뮤니티](https://discord.com/invite/s3KuuzsPFb)에 참여하세요.

## 📝 기여

문서 개선에 도움을 주고 싶으시다면 언제든지 Pull Request를 보내주세요!
