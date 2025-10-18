# 🧭 QuestCompleteSound (QCS)

**QuestCompleteSound** makes your questing more immersive.  
It plays a sound when a quest is ready to turn in — and can optionally color quest progress messages (like “7/8 Wolves Slain”) in **red → yellow → green** based on how close you are to completion.

Compatible with both **Retail** and **Classic** clients.

---

## 🎵 Features

- 🔔 **Quest Completion Sound**  
  Plays a sound when all objectives for a quest are complete.

- 🧩 **Quest Progress Colors (UIErrorsFrame)**  
  Colors *quest-related UI messages* (e.g., “Boars slain: 4/8”) from red to green as you progress.  
  Toggle with `/qcs color on`.

- 📋 **Automatic Quest Tracking**  
  Automatically tracks newly accepted quests in your quest tracker.

- 🪄 **Splash Screen & Help**  
  Shows version, AutoTrack, and colorization state at login or via `/qcs splash`.

- 🧪 **Debug & Reset Tools**  
  - `/qcs debug` – lists all quests and tracking states  
  - `/qcs debugtrack` – shows detailed tracking debug messages  
  - `/qcs reset` – resets all settings to default

---

## ⚙️ Chat Commands

| Command | Description |
|----------|--------------|
| `/qcs autotrack on/off` | Enable or disable automatic quest tracking |
| `/qcs autotrack` | Show current autotrack state |
| `/qcs color on/off` | Enable or disable progress colorization |
| `/qcs splash on/off` | Enable or disable splash screen on login |
| `/qcs debug` | List all quests and watch state |
| `/qcs debugtrack` | Toggle detailed tracking debug output |
| `/qcs reset` | Reset all settings to defaults |
| `/qcs help` | Display command overview |
| `/qcs splash` | Show current configuration splash |

---

## 💾 Saved Variables

Your settings persist between sessions via these variables:

| Variable | Purpose |
|-----------|----------|
| `QCS_AutoTrack` | Automatically track newly accepted quests |
| `QCS_DebugTrack` | Enable detailed debug logging |
| `QCS_ShowSplash` | Show splash screen at login |
| `QCS_ColorProgress` | Color quest progress messages (red → green) |

---

## 🧠 Notes

- The Blizzard tracker limit of **25 quests** still applies — new quests can’t be added automatically beyond that.  
- You can safely toggle features on/off at any time.  
- Sound and colorization features work independently — use one or both.  
- Fully compatible with **Retail** and **Classic**.
