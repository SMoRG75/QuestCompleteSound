# 🧭 QuestCompleteSound (QCS)

**QuestCompleteSound** makes your questing more immersive.  
It plays a sound when a quest is ready to turn in — and can optionally color quest progress messages (like “7/8 Wolves Slain”) in **red → yellow → green** based on how close you are to completion.

Compatible only with **Retail**.

---

## 🎵 Features

🔔 **Quest Completion Sound**  
Plays a sound when all objectives for a quest are complete.
Toggle with `/qcs soundonly`, `/qcs so`.

🧩 **Quest Progress Colors**  
Colors *quest-related UI messages* (e.g., “Boars slain: 4/8”) from red to green as you progress.  
Toggle with `/qcs color`, `/qcs col`.

📋 **Automatic Quest Tracking**  
Automatically tracks newly accepted quests in your quest tracker.
Toggle with `/qcs autotrack`, `/qcs at`.  

📋 **Hide completed Achievements**  
Always hide your completed Achievements in the Achievements Frame.
Toggle with `/qcs hideach`, `/qcs ha`.  

🪄 **Splash Screen & Help**  
Shows version, AutoTrack, and colorization state at login or via  
`/qcs splash`.

🧪 **Debug & Reset Tools**  
`/qcs debugtrack` – shows detailed tracking debug messages  
`/qcs reset` – resets all settings to default

---

## ⚙️ Chat Commands

| Command | Description |
|----------|--------------|
| `/qcs soundonly` | Toggle sound-only mode |
| `/qcs so` | Shorthand for soundonly |
| `/qcs autotrack` | Toggle current autotrack state |
| `/qcs at` | Shorthand for autotrack |
| `/qcs color` | Toggle progress colorization |
| `/qcs col` | Shorthand for color |
| `/qcs hideach` | Toggle hiding completed achievements |
| `/qcs ha` | Shorthand for hideach |
| `/qcs splash` | Toggle or disable splash screen on login |
| `/qcs debugtrack` | Toggle detailed tracking debug output |
| `/qcs dbg` | Shorthand for debugtrack |
| `/qcs reset` | Reset all settings to defaults |
| `/qcs help` | Display command overview |

---

## 💾 Saved Variables

Your settings persist between sessions via these variables:

| Variable | Purpose |
|-----------|----------|
| `QCS_DB` | Now contains the following variables |
| `AutoTrack` | Automatically track newly accepted quests |
| `DebugTrack` | Enable detailed debug logging |
| `ShowSplash` | Show splash screen at login |
| `ColorProgress` | Color quest progress messages (red → green) |
| `HideDoneAchievements` | Show or Hide completed achievements |
| `SoundOnly` | Turn on or off Sound Only |

---

## 🧠 Notes

- The Blizzard tracker limit of **25 quests** still applies — new quests can’t be added automatically beyond that.  
- You can safely toggle features on/off at any time.  
- Sound and colorization features work independently — use one or both.  
- Only compatible with **Retail**.
