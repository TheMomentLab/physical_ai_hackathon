# Bring Your Own Policies (커스텀 정책 연동)

이 튜토리얼은 LeRobot 생태계에 여러분의 커스텀 정책 구현을 통합하는 방법을 설명합니다. 이를 통해 자신의 알고리즘을 사용하면서도 LeRobot의 학습, 평가, 배포 도구를 모두 활용할 수 있습니다.

## Step 1: 정책 패키지 만들기

커스텀 정책은 LeRobot의 플러그인 규칙을 따르는 설치 가능한 Python 패키지 형태로 구성해야 합니다.

### 패키지 구조

패키지 이름은 `lerobot_policy_` 접두어로 시작해야 합니다(중요!). 그 뒤에 정책 이름을 붙입니다:

```bash
lerobot_policy_my_custom_policy/
├── pyproject.toml
└── src/
    └── lerobot_policy_my_custom_policy/
        ├── __init__.py
        ├── configuration_my_custom_policy.py
        ├── modeling_my_custom_policy.py
        └── processor_my_custom_policy.py
```

### 패키지 설정

`pyproject.toml`을 다음과 같이 설정합니다:

```toml
[project]
name = "lerobot_policy_my_custom_policy"
version = "0.1.0"
dependencies = [
    # 정책에 필요한 의존성
]
requires-python = ">= 3.11"

[build-system]
build-backend = # your-build-backend
requires = # your-build-system
```

## Step 2: 정책 설정 정의

`PreTrainedConfig`를 상속하고 정책 타입을 등록하는 설정 클래스를 만듭니다:

```python
# configuration_my_custom_policy.py
from dataclasses import dataclass, field
from lerobot.configs.policies import PreTrainedConfig
from lerobot.configs.types import NormalizationMode

@PreTrainedConfig.register_subclass("my_custom_policy")
@dataclass
class MyCustomPolicyConfig(PreTrainedConfig):
    """MyCustomPolicy용 설정 클래스.

    Args:
        n_obs_steps: 입력으로 사용할 관측 스텝 수
        horizon: 액션 예측 horizon
        n_action_steps: 실행할 액션 스텝 수
        hidden_dim: 정책 네트워크의 hidden dimension
        # 정책에 필요한 파라미터를 여기에 추가하세요
    """
    # ...PreTrainedConfig fields...
    pass

    def __post_init__(self):
        super().__post_init__()
        # 필요한 검증 로직을 여기에 추가하세요

    def validate_features(self) -> None:
        """입력/출력 feature 호환성 검증."""
        # 정책 요구사항에 맞는 검증 로직을 구현하세요
        pass
```

## Step 3: 정책 클래스 구현

LeRobot의 기본 `PreTrainedPolicy` 클래스를 상속해 정책을 구현합니다:

```python
# modeling_my_custom_policy.py
import torch
import torch.nn as nn
from typing import Dict, Any

from lerobot.policies.pretrained import PreTrainedPolicy
from .configuration_my_custom_policy import MyCustomPolicyConfig

class MyCustomPolicy(PreTrainedPolicy):
    config_class = MyCustomPolicyConfig
    name = "my_custom_policy"

    def __init__(self, config: MyCustomPolicyConfig, dataset_stats: Dict[str, Any] = None):
        super().__init__(config, dataset_stats)
        ...
```

## Step 4: 데이터 프로세서 추가

프로세서 함수를 만듭니다:

```python
# processor_my_custom_policy.py
from typing import Dict, Any
import torch

def make_my_custom_policy_pre_post_processors(
    config,
) -> tuple[
    PolicyProcessorPipeline[dict[str, Any], dict[str, Any]],
    PolicyProcessorPipeline[PolicyAction, PolicyAction],
]:
    """정책용 전처리/후처리 함수를 생성합니다."""
    pass  # 전처리/후처리 로직을 여기에 구현하세요

```

## Step 5: 패키지 초기화

패키지의 `__init__.py`에서 클래스들을 공개합니다:

```python
# __init__.py
"""LeRobot용 커스텀 정책 패키지."""

try:
    import lerobot  # noqa: F401
except ImportError:
    raise ImportError(
        "lerobot is not installed. Please install lerobot to use this policy package."
    )

from .configuration_my_custom_policy import MyCustomPolicyConfig
from .modeling_my_custom_policy import MyCustomPolicy
from .processor_my_custom_policy import make_my_custom_policy_pre_post_processors

__all__ = [
    "MyCustomPolicyConfig",
    "MyCustomPolicy",
    "make_my_custom_policy_pre_post_processors",
]
```

## Step 6: 설치 및 사용

### 정책 패키지 설치

```bash
cd lerobot_policy_my_custom_policy
pip install -e .

# 또는 PyPI에 배포했다면
pip install lerobot_policy_my_custom_policy
```

### 정책 사용

설치가 끝나면 LeRobot의 학습/평가 도구에서 자동으로 사용할 수 있습니다:

```bash
lerobot-train \
    --policy.type my_custom_policy \
    --env.type pusht \
    --steps 200000
```

## 예시 및 커뮤니티 기여

다음 예시 정책 구현을 참고하세요:

- [DiTFlow Policy](https://github.com/danielsanjosepro/lerobot_policy_ditflow) - flow-matching 목적을 사용하는 Diffusion Transformer 정책. 이 예시도 참고하세요: [DiTFlow Example](https://github.com/danielsanjosepro/test_lerobot_policy_ditflow)

커스텀 정책을 공유해서 커뮤니티에 기여해 주세요! 🤗
