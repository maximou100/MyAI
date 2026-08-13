# App Store Connect — submission pack for MyAI

Everything below is paste-ready. Character limits are noted; counts were
verified against these exact strings.

---

## 1. App information

| Field | Value |
|---|---|
| **Bundle ID** | `Max-Leclercq.MyAI` |
| **SKU** | `MYAI-001` |
| **Primary language** | English (U.S.) |
| **Primary category** | Productivity |
| **Secondary category** | Utilities |
| **Content rights** | Does **not** contain, show, or access third-party content |
| **Copyright** | `2026 Maxime Leclercq` |
| **Version** | `1.0` |
| **Build** | `1` |

> ⚠️ **App Name must be unique across the App Store.** "MyAI" alone is very
> likely taken. Use the differentiated name below, and have a fallback ready.

---

## 2. Name, subtitle, promotional text

**App Name** (max 30)
```
MyAI — On-Device AI Chat
```
Fallbacks if unavailable: `MyAI: Private On-Device AI` · `MyAI — Offline AI Chat`

**Subtitle** (max 30)
```
Private AI. No account.
```

**Promotional Text** (max 170 — editable without a new build)
```
Chat with an AI that runs entirely on your iPhone. No account, no API key, no data leaving your device. Add your own knowledge, agents, and skills.
```

---

## 3. Description (max 4000)

```
MyAI is a private AI chat app that runs entirely on your device.

There is no account to create, no API key to paste, and no subscription. Your conversations never leave your iPhone or iPad. MyAI is powered by Apple Intelligence and the on-device Apple Foundation Model, so it works without a network connection and costs nothing to use.

CHAT THAT STAYS PRIVATE
• Answers stream in as they are generated
• Full conversation history, saved on device
• Markdown formatting for clear, readable replies
• Works offline — no server, ever

SEE WHAT YOU SHOW IT
• Attach a photo and ask about it directly
• Attach text, JSON, or CSV files for context
• Optional on-device tools read text and scan codes inside your images

YOUR OWN KNOWLEDGE
• Add notes, facts, and reference material the model can draw on
• Turn individual entries on or off at any time
• The model can search your knowledge when a question calls for it

AGENTS
• Create named assistants with their own instructions and creativity
• Switch between them from the chat screen or Settings
• Import and export agents as Markdown files

SKILLS
• Reusable instructions that shape every reply
• Toggle them on and off individually
• Import and export skills as Markdown files

REAL CONTROL OVER THE MODEL
• Temperature, sampling strategy (greedy, top-K, nucleus), and seed
• Maximum response length and default instructions
• One-tap presets: Balanced, Precise, and Creative
• See exactly where the model runs and how large its context window is

SYNCED WITH ICLOUD
• Chats, agents, skills, knowledge, and settings follow you across devices
• Stored in your own private iCloud database
• Works local-only if you prefer to stay signed out

PRIVACY BY DESIGN
No analytics. No advertising. No tracking. No third-party SDKs. Nothing is collected, because there is no server to collect it.

REQUIREMENTS
MyAI requires a device that supports Apple Intelligence, with Apple Intelligence turned on in Settings. Without it, the app will tell you the model is unavailable and chat will not function.
```

---

## 4. Keywords (max 100, comma-separated, no spaces after commas)

```
ai,chat,offline,private,assistant,on-device,local,chatbot,apple intelligence,agents,skills,notes
```

---

## 5. What's New in This Version (max 4000)

```
First release.

• Private AI chat powered by the on-device Apple Foundation Model
• Attach photos and files and ask about them
• Knowledge files the model can reason over
• Custom agents and skills, with Markdown import and export
• Full generation controls: temperature, sampling, seed, response length
• iCloud sync for chats, agents, skills, knowledge, and settings
```

---

## 6. URLs

| Field | Value |
|---|---|
| **Support URL** *(required)* | `https://github.com/maximou100/MyAI/issues` |
| **Marketing URL** *(optional)* | `https://github.com/maximou100/MyAI` |
| **Privacy Policy URL** *(required)* | `https://github.com/maximou100/MyAI/blob/main/PRIVACY.md` |

> The privacy policy lives in `PRIVACY.md` at the repo root. For a tidier URL,
> enable GitHub Pages (Settings → Pages → deploy from `main`) and use
> `https://maximou100.github.io/MyAI/PRIVACY`.

---

## 7. App Privacy questionnaire

**"Do you or your third-party partners collect data from this app?"** → **No**

That is the whole section. It is accurate and matches `PrivacyInfo.xcprivacy`,
which declares no tracking and no collected data types. The app has no analytics,
no ad SDK, and no third-party SDKs, and inference happens on device.

> iCloud sync does **not** count as collection: the data goes to the user's own
> private iCloud database, which the developer cannot access.

---

## 8. Age rating

Answer the questionnaire honestly. The one that matters here:

- **Does your app include AI-generated content or a chatbot?** → **Yes.**
  MyAI is a general-purpose chat interface over a language model, so users can
  receive model-generated text on arbitrary topics.

Do **not** understate this. Apple's rating questionnaire covers AI chat
explicitly, and misdeclaring is a rejection risk. Answer yes, then accept
whatever rating the questionnaire produces — for an unrestricted AI chat app
this typically lands above 4+.

All other categories (violence, sexual content, gambling, contests, drugs,
horror, profanity) → **None**, since the app ships no such content itself.

---

## 9. Export compliance

- **Does your app use encryption?** → **No**
- If asked to select encryption algorithms → **select neither option**

Verified in code: no `CryptoKit`, no `CommonCrypto`, no `Security` framework, no
custom networking. The only encryption involved is Apple's own, used
automatically by iCloud. `ITSAppUsesNonExemptEncryption = false` is already in
Info.plist, so uploads should stop prompting.

---

## 10. App Review notes ⚠️ important

Paste this into **App Review Information → Notes**:

```
IMPORTANT — HOW TO TEST THIS APP

MyAI runs entirely on device using Apple Intelligence and the on-device Apple Foundation Model. It requires:

1. A device that supports Apple Intelligence
2. Apple Intelligence turned ON in Settings > Apple Intelligence & Siri
3. The model assets finished downloading

If Apple Intelligence is unavailable or still downloading, the app deliberately shows a clear notice and chat will not produce answers. This is intended behaviour, not a defect. Settings > Foundation Model shows the live availability status.

No account, login, or demo credentials are required. There is no server component and no network API.

On first launch the app seeds example content (two agents, two skills, two knowledge files) so every feature can be tried immediately.

TO TEST THE CORE FEATURE
Open the MyAI tab, type a question, and send it. The reply streams in from the on-device model.

TO TEST IMAGE UNDERSTANDING
Tap "+" > Photo Library, choose any photo, and ask "What is in this photo?".

PRIVACY
No data is collected. Conversations, agents, skills, and knowledge stay on device and sync only to the user's own private iCloud database via CloudKit. The developer has no access to any of it.

NOTE ON PRIVATE CLOUD COMPUTE
The binary contains a disabled code path for Apple's Private Cloud Compute. It is gated behind a build flag (HAS_PCC_ENTITLEMENT) that is OFF in this build, and the app is not signed with the PCC entitlement, so no request ever leaves the device.
```

**Sign-in required?** → No
**Contact:** Maxime Leclercq · leclercq.maxime@me.com

---

## 11. Screenshots

Required sizes:

| Device | Pixels (portrait) | Min |
|---|---|---|
| iPhone 6.9" | 1320 × 2868 or 1290 × 2796 | 1 (up to 10) |
| iPad 13" | 2064 × 2752 or 2048 × 2732 | 1 (up to 10) — required only if the app supports iPad |

MyAI's `TARGETED_DEVICE_FAMILY` is `1,2`, so **iPad screenshots are required**.

Suggested order and captions:

1. Chat — "Private AI chat that runs on your iPhone"
2. Foundation Model settings — "Real control: temperature, sampling, seed"
3. Knowledge — "Teach it with your own knowledge"
4. Agents — "Build agents with their own personality"
5. Skills — "Reusable skills shape every reply"

---

## 12. Pre-submission checklist

- [ ] App name confirmed available on the App Store
- [ ] CloudKit schema **deployed to Production** (App Store builds cannot use the Development environment)
- [ ] Screenshots captured at full native resolution for iPhone 6.9" and iPad 13"
- [ ] `PRIVACY.md` reachable at a public URL
- [ ] Archive validated in Xcode Organizer before uploading
- [ ] Tested on a real device with Apple Intelligence enabled
