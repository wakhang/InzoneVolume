# InzoneVolume

Sony INZONE Buds를 USB-C 동글로 맥에 연결하면 macOS 볼륨 슬라이더와 볼륨 키가 동작하지 않습니다. 동글이 하드웨어 볼륨 조절 기능을 제공하지 않고 음소거만 지원하기 때문입니다. InzoneVolume은 INZONE 출력으로 가는 소리를 Core Audio 프로세스 탭으로 받아 소프트웨어로 볼륨을 조절하는 메뉴 막대 앱입니다.

> English: A menu bar app that adds software volume control (slider + volume keys) for Sony INZONE Buds connected via the USB-C dongle on macOS, where the dongle exposes no hardware volume.

## 기능

- 메뉴 막대 볼륨 슬라이더, 음소거
- INZONE Buds가 기본 출력일 때 키보드 볼륨 키 사용(Option+Shift를 누르면 1/64 단위로 세밀하게 조절)
- `INZONE Buds - Game`과 `INZONE Buds - Chat` 출력 모두 지원
- 로그인 시 자동 실행

## 요구 사항

- macOS 14.2 이상
- Apple Silicon(arm64)

## 설치

### 릴리스에서 받기

1. [Releases](../../releases)에서 `InzoneVolume.zip`을 받아 압축을 풀고 `InzoneVolume.app`을 응용 프로그램 폴더로 옮깁니다.
2. Apple 공증을 받지 않은 앱이라 처음에는 macOS가 실행을 막습니다. 터미널에서 아래 명령을 한 번 실행하세요.
   ```sh
   xattr -dr com.apple.quarantine /Applications/InzoneVolume.app
   ```

### 직접 빌드

Xcode Command Line Tools가 필요합니다.

```sh
./build.sh   # ~/Applications/InzoneVolume.app에 설치
```

## 권한

- **시스템 오디오 녹음**: 처음 실행할 때 허용해야 볼륨을 조절할 수 있습니다.
- **손쉬운 사용**: 볼륨 키를 쓰려면 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 InzoneVolume을 허용하세요.

권한을 바꾼 뒤에는 앱을 다시 실행하세요.

## 진단

```sh
INZONE_DEBUG=1 ~/Applications/InzoneVolume.app/Contents/MacOS/InzoneVolume
```

입력 RMS, 출력 RMS, 그 비율을 1초마다 로그로 남깁니다.

## 라이선스

[MIT](LICENSE)

Sony 및 INZONE은 Sony Group Corporation의 상표입니다. 이 프로젝트는 Sony와 관련이 없습니다.
