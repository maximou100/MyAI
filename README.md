# MyAI

A private, fully on-device AI chat app for iOS — built entirely on Apple's **Foundation Models** framework.

No API keys. No accounts. No server. Every conversation, knowledge file, agent, and skill stays on your device.

![Platform](https://img.shields.io/badge/platform-iOS%2027.0%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![UI](https://img.shields.io/badge/UI-SwiftUI-blue)
![Persistence](https://img.shields.io/badge/data-SwiftData-green)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## What makes it different

Most "AI chat" apps are thin clients wrapped around a cloud API — they need your key, your account, and your data leaves the device. MyAI inverts that:

| | Typical AI chat app | **MyAI** |
|---|---|---|
| Inference | Remote server | **On-device** (Apple Neural Engine) |
| API key / account | Required | **None** |
| Data leaves device | Yes | **No** |
| Works offline | No | **Yes** |
| Cost per message | Metered | **Free** |
| Image understanding | Cloud vision model | **On-device multimodal** |

Beyond privacy, MyAI exposes the parts of the on-device model that are usually hidden: sampling strategy, seeds, context-window size, and the fact that **you cannot pick the compute unit** — the OS schedules it on the Neural Engine. It's as much a window into Apple's on-device stack as it is a chat client.

---

## Features

### 💬 Chat
- ChatGPT-style threaded conversation with **streamed token-by-token responses**
- Markdown rendering with selectable text
- Multi-turn context preserved across a conversation
- Auto-generated chat titles derived from your first message
- Full **conversation history**, persisted with SwiftData and searchable by recency
- Empty chats are never persisted to history

### 🖼️ Multimodal input (`+` button)
- Attach a **photo** (PhotosPicker) or a **file** (Files)
- Images are sent as real `Attachment` objects — the model *looks at* the picture, it isn't given a text description of it
- Correct EXIF orientation handling so rotated photos aren't analyzed sideways
- Text/JSON/CSV files are folded into the prompt
- Attached images render inline in the transcript

### 🧠 Foundation model controls
Everything Apple's framework actually exposes, surfaced in the UI:
- **Temperature** (0–1)
- **Sampling strategy** — Automatic, Greedy, Top-K, Nucleus (Top-P)
- **Random seed** pinning for repeatable output
- **Max response tokens**
- **Default instructions** (system prompt)
- **Three one-tap presets** — Balanced Assistant, Precise Analyst, Creative Writer
- Live **availability status** and **supported-language list**
- Read-only **Hardware & Memory** panel showing where the model runs and the live context-window size

### 📚 Knowledge files
Give the model your own facts to reason over:
- Create, edit, and import text/JSON/CSV entries
- Toggle entries **active/inactive**
- Two delivery modes, both configurable:
  - **Inline injection** into instructions (character-budgeted to protect the context window)
  - **`searchKnowledge` tool** — a custom `Tool` the model can call on demand, scoring entries by keyword overlap

### 🤖 Agents
Named personas with their own configuration:
- Open configuration: name, summary, instructions, per-agent temperature
- **Import & export as Markdown (`.md`)** with a lenient parser
- Activate from **Settings** *or* the chat toolbar — both stay in sync
- Ships with two examples: *Code Helper*, *Brainstorm Buddy*

### 🪄 Skills
Reusable behavior modules composed into the model's instructions:
- Manual editing, plus **`.md` import/export**
- Toggle individually; enabled skills apply to every message
- Ships with two examples: *Cite Sources*, *Step-by-Step*

### 🔍 Vision tools (device only)
Register Apple's Vision tools with the session so the model can act on images:
- **`OCRTool`** — extract text from attached images
- **`BarcodeReaderTool`** — decode barcodes and QR codes

### ☁️ Private Cloud Compute (optional)
- One-toggle switch to route requests to Apple's server-side model (**32K context** vs 4,096 on-device)
- Full error handling for network failure, quota limits, and service outages
- Gated behind a build flag; safely disabled and clearly explained when unavailable

---

## Architecture

```
MyAI/
├── MyAIApp.swift              # App entry, SwiftData container, environment wiring
├── ContentView.swift          # Root TabView (Chat | Settings)
│
├── AI/
│   └── LLMEngine.swift        # Foundation Models wrapper: availability, sessions,
│                              # GenerationOptions, multimodal prompts, PCC, knowledge tool
├── Chat/
│   ├── ChatHomeView.swift     # Chat screen, attachments, toolbar, transcript
│   ├── ChatViewModel.swift    # Send pipeline, streaming, session reuse, error mapping
│   ├── ChatComponents.swift   # Message bubbles + composer bar
│   └── ConversationListView.swift  # History sheet
├── Models/
│   ├── DataModels.swift       # SwiftData: Conversation, Message, KnowledgeFile, Agent, Skill
│   ├── SettingsStore.swift    # @Observable, UserDefaults-backed settings + presets
│   └── SampleData.swift       # First-launch seed content
├── Settings/
│   ├── SettingsView.swift     # Settings root
│   ├── FoundationModelSettingsView.swift
│   ├── KnowledgeFilesView.swift
│   ├── AgentsView.swift
│   ├── SkillsView.swift
│   └── AboutView.swift
└── Support/
    └── MarkdownDocument.swift # FileDocument + Markdown ⇄ model conversion
```

~2,700 lines of Swift. No third-party dependencies.

### How a prompt is assembled

`PromptComposer` merges four layers into the session instructions, in order:

1. **Persona** — the active agent's instructions, or the global default
2. **Skills** — every enabled skill, appended as labeled sections
3. **Knowledge** — active entries, inline and character-budgeted
4. **Locale** — an explicit language directive when "Prefer device language" is on

The session is cached and only rebuilt when the conversation or the composed instructions change, so multi-turn context survives while settings changes take effect immediately.

---

## Requirements

- **iOS 27.0+**
- Xcode 27+
- A device that supports **Apple Intelligence**, with it enabled in Settings
- Swift 5.0

> **Simulator note:** the UI runs fine in the Simulator, but text generation typically fails there with a missing `com.apple.modelcatalog` asset, and Vision's `OCRTool`/`BarcodeReaderTool` are device-only. Use a real device for actual responses.

---

## Getting started

```bash
git clone https://github.com/maximou100/MyAI.git
cd MyAI
open MyAI.xcodeproj
```

**1. Set your signing team.** No Team ID is stored in this repo. Supply your own via a gitignored config file:

```bash
cp Config/Local.xcconfig.template Config/Local.xcconfig
# then edit it and set your own Team ID
```

`Config/Signing.xcconfig` is the project's base configuration and pulls your file in with an optional `#include?`, so a clone without it still builds cleanly.

**2. Enable the safety hook** (recommended — Xcode silently rewrites `DEVELOPMENT_TEAM` into `project.pbxproj` whenever it repairs automatic signing):

```bash
git config core.hooksPath .githooks
```

This blocks any commit that would leak a Team ID.

**3. Choose an Apple Intelligence–capable device and run** (⌘R).

On first launch the app seeds two agents, two skills, and two knowledge files so every feature is immediately explorable.

### Enabling Private Cloud Compute

PCC needs a **managed entitlement** that Apple must grant:

1. Request access at [developer.apple.com/private-cloud-compute](https://developer.apple.com/private-cloud-compute/).
2. Once granted, add the **Private Cloud Compute** capability in Signing & Capabilities.
3. Add `HAS_PCC_ENTITLEMENT` to **Active Compilation Conditions** (`SWIFT_ACTIVE_COMPILATION_CONDITIONS`).

Until then the toggle stays disabled and the app transparently falls back to the on-device model — it never silently fails.

---

## Under the hood: what the on-device model can and can't do

Findings worth knowing if you're building on Foundation Models:

- **It runs on the Apple Neural Engine**, orchestrated by the OS. Unlike Core ML's `MLComputeUnits`, the framework exposes **no** CPU/GPU/ANE selector — placement is not yours to choose.
- **Context window is 4,096 tokens** per session (read at runtime via `contextSize`) covering instructions + prompts + responses. PCC raises this to 32K.
- **Memory is system-managed.** The only real lever is the context window, so MyAI budgets injected knowledge and reuses sessions deliberately.
- **The tuning surface is deliberately small** — temperature, sampling mode, seed, and max response tokens. There is no frequency/presence-penalty grab-bag.
- **Multimodal is image-in, text-out.** There is no audio input and no image generation.

---

## Roadmap

- [ ] Quota status UI for PCC (approaching / reached, with iCloud+ upgrade path)
- [ ] Live token-usage meter against the context window
- [ ] Cancel an in-flight response
- [ ] PDF text extraction for attachments
- [ ] iCloud sync for conversations, agents, and skills

---

## License

Released under the [MIT License](LICENSE) — © 2026 Maxime Leclercq.

The MIT license covers **this repository's own source code**. It does not redistribute any Apple code: the app links against frameworks that ship with iOS and the SDK, used under the Apple Developer Program License Agreement.

Two things MIT does **not** waive:

- **Apple's [Acceptable Use Requirements for the Foundation Models framework](https://developer.apple.com/apple-intelligence/acceptable-use-requirements-for-the-foundation-models-framework)** apply to anyone who builds or ships an app using this code.
- **App icon artwork** in `Assets.xcassets` is not covered by the MIT grant unless you own it — replace it with your own before redistributing.

---

## Author

**Maxime Leclercq**

---

## Acknowledgements

Built on Apple's [Foundation Models](https://developer.apple.com/documentation/foundationmodels), SwiftUI, SwiftData, and Vision.
