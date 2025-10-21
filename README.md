# 🧭 QuestCompleteSound (QCS)

**QuestCompleteSound** makes your questing more immersive.  
It plays a sound when a quest is ready to turn in — and can optionally color quest progress messages (like “7/8 Wolves Slain”) in **red → yellow → green** based on how close you are to completion.

Compatible only with **Retail**.

---

## 🎵 Features

- 🔔 **Quest Completion Sound**  
  Plays a sound when all objectives for a quest are complete.

- 🧩 **Quest Progress Colors (UIErrorsFrame)**  
  Colors *quest-related UI messages* (e.g., “Boars slain: 4/8”) from red to green as you progress.  
  Toggle with `/qcs color`.

- 📋 **Automatic Quest Tracking**  
  Automatically tracks newly accepted quests in your quest tracker.

- 🪄 **Splash Screen & Help**  
  Shows version, AutoTrack, and colorization state at login or via `/qcs splash`.

- 🧪 **Debug & Reset Tools**  
  - `/qcs debugtrack` – shows detailed tracking debug messages  
  - `/qcs reset` – resets all settings to default

---

## ⚙️ Chat Commands

| Command | Description |
|----------|--------------|
| `/qcs autotrack` | Toggle current autotrack state |
| `/qcs color` | Toggle or disable progress colorization |
| `/qcs splash` | Toggle or disable splash screen on login |
| `/qcs debugtrack` | Toggle detailed tracking debug output |
| `/qcs reset` | Reset all settings to defaults |
| `/qcs help` | Display command overview |

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
- Only compatible with **Retail**.
