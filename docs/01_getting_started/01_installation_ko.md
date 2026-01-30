# Installation

## [`miniforge`](https://conda-forge.org/download/) 설치

```bash
wget "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
bash Miniforge3-$(uname)-$(uname -m).sh
```

## 환경 설정

conda로 Python 3.10 가상환경을 생성하세요:

```bash
conda create -y -n lerobot python=3.10
```

그 다음 conda 환경을 활성화합니다. lerobot을 사용하려면 셸을 열 때마다 이 작업을 해야 합니다:

```bash
conda activate lerobot
```

`conda`를 사용할 때는 환경 안에 `ffmpeg`를 설치하세요:

```bash
conda install ffmpeg -c conda-forge
```

> [!TIP]
> 보통 `libsvtav1` 인코더로 컴파일된 `ffmpeg 7.X`가 플랫폼에 맞게 설치됩니다. `libsvtav1`이 지원되지 않는 경우(지원 인코더는 `ffmpeg -encoders`로 확인), 다음을 수행할 수 있습니다:
>
> - _[모든 플랫폼]_ 다음을 사용해 `ffmpeg 7.X`를 명시적으로 설치:
>
> ```bash
> conda install ffmpeg=7.1.1 -c conda-forge
> ```
>
> - _[Linux 전용]_ 자체 ffmpeg를 사용하려면: [ffmpeg 빌드 의존성 설치](https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu#GettheDependencies) 및 [libsvtav1로 ffmpeg를 소스에서 컴파일](https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu#libsvtav1)하고, `which ffmpeg`로 설치에 대응하는 ffmpeg 바이너리를 사용하고 있는지 확인하세요.

## LeRobot 🤗 설치

### 소스에서 설치

먼저 저장소를 클론하고 디렉터리로 이동하세요:

```bash
git clone https://github.com/huggingface/lerobot.git
cd lerobot
```

그 다음 라이브러리를 editable 모드로 설치합니다. 이는 코드에 기여하려는 경우 유용합니다.

```bash
pip install -e .
```

### PyPI에서 설치

**핵심 라이브러리:**
기본 패키지는 다음과 같이 설치합니다:

```bash
pip install lerobot
```

_이는 기본 의존성만 설치합니다._

**추가 기능:**
추가 기능을 설치하려면 다음 중 하나를 사용하세요:

```bash
pip install 'lerobot[all]'          # 사용 가능한 모든 기능
pip install 'lerobot[aloha,pusht]'  # 특정 기능 (Aloha & Pusht)
pip install 'lerobot[feetech]'      # Feetech 모터 지원
```

_[...]는 원하는 기능으로 대체하세요._

**사용 가능한 태그:**
선택적 의존성의 전체 목록은 다음을 참고하세요:
https://pypi.org/project/lerobot/

> [!NOTE]
> lerobot 0.4.0에서 pi를 설치하려면 다음을 해야 합니다: `pip install "lerobot[pi]@git+https://github.com/huggingface/lerobot.git"`

### 문제 해결

빌드 오류가 발생하면 추가 의존성(`cmake`, `build-essential`, `ffmpeg libs`)을 설치해야 할 수 있습니다.
Linux에서 설치하려면 다음을 실행하세요:

```bash
sudo apt-get install cmake build-essential python3-dev pkg-config libavformat-dev libavcodec-dev libavdevice-dev libavutil-dev libswscale-dev libswresample-dev libavfilter-dev
```

다른 시스템의 경우 다음을 참고하세요: [Compiling PyAV](https://pyav.org/docs/develop/overview/installation.html#bring-your-own-ffmpeg)

## 선택적 의존성

LeRobot은 특정 기능을 위한 선택적 extras를 제공합니다. 여러 extras를 결합할 수 있습니다(예: `.[aloha,feetech]`). 사용 가능한 모든 extras는 `pyproject.toml`을 참고하세요.

### 시뮬레이션

환경 패키지 설치: `aloha` ([gym-aloha](https://github.com/huggingface/gym-aloha)) 또는 `pusht` ([gym-pusht](https://github.com/huggingface/gym-pusht))
예시:

```bash
pip install -e ".[aloha]" # 또는 예를 들어 "[pusht]"
```

### 모터 제어

Koch v1.1의 경우 Dynamixel SDK를 설치하고, SO100/SO101/Moss의 경우 Feetech SDK를 설치하세요.

```bash
pip install -e ".[feetech]" # 또는 예를 들어 "[dynamixel]"
```

### 실험 추적

실험 추적을 위해 [Weights and Biases](https://docs.wandb.ai/quickstart)를 사용하려면 다음으로 로그인하세요:

```bash
wandb login
```

이제 로봇이 아직 준비되지 않았다면 조립할 수 있습니다. 왼쪽에서 로봇 타입을 찾은 다음, 아래 링크를 따라 Lerobot을 사용하세요.
