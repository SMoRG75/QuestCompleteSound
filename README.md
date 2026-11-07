# 🧭 QuestCompleteSound (QCS)

**QuestCompleteSound** lets you hear your quest progress: a worker voice line when you complete a quest objective, and another when the whole quest is done. That's all it does.

Works in **Retail** and **WoW Forever**.

---

## 📦 Moved to SMoRG's QoL

All the other settings have moved to my addon [**SMoRG's QoL**](https://www.curseforge.com/wow/addons/smorgsqol):

- Quest progress colors
- Automatic quest tracking
- Hide completed achievements
- Splash screen
- Debug output
- Chat messages when a quest is done

SMoRG's QoL plays the same sounds, so you only need one of the addons. If both are loaded, QCS stays silent so you don't hear every sound twice.

---

## 🎵 Sounds

| Profile | Objective complete | Quest complete |
|----------|--------------|--------------|
| **Horde (Peon)** (default) | "Work, work." | "Work complete." |
| **Alliance (Human worker)** | "More work?" | "Job's done!" |

When the last objective of a quest is completed, you only hear the quest complete sound.

---

## 🪟 Options Window

Turn the sounds on or off and choose the sound profile in the options window. Open it from the addon compartment menu at the minimap, the button under **Options → AddOns**, or with `/qcs config`.

---

## ⚙️ Chat Commands

| Command | Description |
|----------|--------------|
| `/qcs questsound` | Toggle the quest completion sound |
| `/qcs qs` | Shorthand for questsound |
| `/qcs objectivesound` | Toggle the objective completion sound |
| `/qcs os` | Shorthand for objectivesound |
| `/qcs soundprofile` | Switch between the Horde and Alliance sounds |
| `/qcs config` | Open the options window |
| `/qcs reset` | Reset all settings to defaults |
| `/qcs help` | Display command overview |

---

## 💾 Saved Variables

Your settings persist between sessions in `QCS_DB`:

| Variable | Purpose |
|-----------|----------|
| `QuestCompleteSound` | Play a sound when a whole quest is done |
| `QuestObjectiveSound` | Play a sound when a quest objective is completed |
| `QuestSoundProfile` | `Horde` or `Alliance` |
| `PopupPosition` | Where you moved the options window |
