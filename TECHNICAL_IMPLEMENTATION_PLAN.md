# txtin — Technical Implementation Plan (MVP)

## 1) Цель MVP
- Отделить текущий `Option+Q` voice-to-text флоу из Linza в отдельное menu bar приложение.
- Минимальный UI: одно окно из menu bar.
- В этом окне:
- ввод/сохранение `Deepgram API Key`;
- статус и выдача обязательных разрешений.
- Основной runtime флоу: `Option+Q -> запись микрофона -> Deepgram -> вставка текста в активный input`.

## 2) Scope MVP
- Входит:
- menu bar app (без Dock icon, `LSUIElement=true`);
- global hotkey только `Option+Q`;
- микрофонная запись и транскрибация Deepgram;
- вставка текста в активное приложение;
- permissions: `Microphone`, `Accessibility`;
- хранение Deepgram ключа в Keychain.
- Не входит:
- screen recording;
- overlay/presentation mode/meeting mode;
- Option+C/Option+P/Option+O;
- авторизация/подписки/backend UI.

## 3) Техническая архитектура

### 3.1 App Shell
- `txtin` (`@main`, SwiftUI App)
- `AppDelegate` (инициализация менеджеров)
- `MenuBarManager` (`NSStatusItem`, меню: Open Settings, Quit)
- `SettingsWindowController` (одно окно с SwiftUI view)

### 3.2 Core Modules
- `HotkeyManager` (только transcription hotkey)
- `VoiceRecordingManager` (упрощённый профиль для mic-only)
- `DeepgramTranscriptionService`
- `TextInsertionService`
- `PermissionsManager` (только mic + accessibility)
- `ConfigManager` + `KeychainHelper` (только deepgram key)

### 3.3 UI Modules
- `SettingsView`
- `DeepgramKeySection`
- `PermissionsSection`
- `RuntimeStatusSection` (idle/recording/transcribing/error)

## 4) План миграции кода из Linza

### 4.1 Копируем с минимальными правками
- `Sources/HotkeyManager.swift` -> оставить только `Option+Q`.
- `Sources/VoiceRecordingManager.swift` и `Sources/Services/AudioRecording/*` -> убрать meeting mode ветки.
- `Sources/DeepgramTranscriptionService.swift`.
- `Sources/TextInsertionService.swift`.
- `Sources/Utils/KeychainHelper.swift` -> ключи только для Deepgram.
- `Sources/Config/ConfigManager.swift` -> оставить deepgram API key.
- `Sources/PermissionsManager.swift` + `Sources/PermissionsUI.swift` -> упростить до 2 permission rows.

### 4.2 Удаляем/не переносим зависимости
- `Overlay*`, `Presentation*`, `Meeting*`, `HRInterview*`.
- `AIProvider` мульти-провайдерная логика.
- сложную навигацию и большой `ContentView`.

## 5) Этапы реализации

### Phase 0 — Bootstrap проекта
- Создать отдельный Swift Package / app structure внутри `VoicePasteMenuBarApp`.
- Добавить `Info.plist` с:
- `LSUIElement=true`;
- `NSMicrophoneUsageDescription`;
- `NSAccessibilityUsageDescription`.
- Добавить entitlements: `audio-input`, `network.client`, `automation.apple-events`.

### Phase 1 — Menu Bar + Settings Window
- Поднять `NSStatusItem` и меню.
- Реализовать открытие/фокус окна настроек.
- Сделать стартовый `SettingsView` (placeholder секции).

### Phase 2 — Permissions + Deepgram key
- Реализовать `PermissionsManager` (polling + actions).
- Реализовать save/load/delete Deepgram key в Keychain через `ConfigManager`.
- В UI: статус бейджи + кнопки “Open Settings”.

### Phase 3 — Runtime Pipeline
- Подключить `Option+Q` hotkey.
- `startRecording/stopRecording`.
- после stop: `DeepgramTranscriptionService.transcribe`.
- после транскрибации: `TextInsertionService.insertText`.

### Phase 4 — Stability + Edge Cases
- защита от rapid hotkey toggles.
- восстановление target app перед вставкой.
- корректная обработка: нет ключа, нет разрешений, пустая транскрибация, сетевые ошибки.

### Phase 5 — Packaging
- build script для `.app` bundle.
- smoke-check на чистой машине (permissions flow + Option+Q).

## 6) Acceptance Criteria (MVP Done)
- Приложение запускается как menu bar only.
- В Settings можно сохранить/удалить Deepgram key.
- Статусы разрешений отражаются корректно.
- При нажатии `Option+Q`:
- начинается запись;
- по остановке выполняется транскрибация;
- результат вставляется в активное текстовое поле.
- Ошибки показываются пользователю без крэша.

## 7) Риски и контроль
- TCC/permissions могут вести себя по-разному на разных macOS версиях.
- Accessibility может быть выдано, но вставка нестабильна в некоторых приложениях.
- Фокус окна может “убегать” перед paste.
- Deepgram timeout/429: нужен понятный retry policy (MVP: без сложного backoff, только ясная ошибка).

## 8) Следующий шаг
- Phase 0/1: создать каркас приложения и базовую структуру файлов в `VoicePasteMenuBarApp`.
