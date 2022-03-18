# auto-installer

그렙인들의 공통 개발환경 구축을 위한 스크립트입니다.

## 실행 방법

터미널을 엽니다. (OS X 기본 터미널, [iTerm](https://iterm2.com/), [warp](https://www.warp.dev/) 사용 가능)

### 기본값으로 설치하는 경우

```
zsh <(curl -fsSL https://raw.githubusercontent.com/grepp/auto-installer/main/install_dev.sh)
```

### 특정 버전을 설치하는 경우

- 파이썬 버전을 명시하고 싶은 경우에는 `--python-version=3.10.2` 처럼 원하는 버전을 추가하면 됩니다.
- 루비 버전을 명시하고 싶은 경우에는 `--ruby-version=2.7.5` 처럼 원하는 버전을 추가하면 됩니다.
- 노드 버전을 명시하고 싶은 경우에는 `--node-version=16.14.1` 처럼 원하는 버전을 추가하면 됩니다.

```
zsh <(curl -fsSL https://raw.githubusercontent.com/grepp/auto-installer/main/install_dev.sh) --python-version=3.10.2 --ruby-version=2.7.5 --node-version=16.14.1
```

## 기여자

- Peter
- Ian
- Oliver
- Gavin
- Ada
- Demi
- Koa
- Neo
- Marco
- Green

## Notes

다음 [스크립트](https://github.com/lablup/backend.ai/blob/main/scripts/install-dev.sh)를 참고하여 작성하였습니다.
