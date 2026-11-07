🧾 QuestCompleteSound

New Features & Improvements:

v2.0.0 - 🔊 QuestCompleteSound now only plays sounds, the same ones as SMoRG's QoL
Added a sound when a quest objective is completed, toggle with /qcs objectivesound or /qcs os
Added Horde (Peon) and Alliance (Human worker) sounds, switch with /qcs soundprofile
Toggle the quest completion sound with /qcs questsound or /qcs qs
Added an options window, like the one in SMoRG's QoL. Open it from the addon compartment, the button under Options > AddOns, or with /qcs config

Now also works in WoW Forever

Removed progress colors, auto-tracking, hiding completed achievements, the splash screen, debug output and the chat messages. All of these are available in SMoRG's QoL
QCS stays silent when SMoRG's QoL is loaded, so you don't hear every sound twice

Fixed: quests that were already done played the sound after login or /reload
Fixed: a repeatable quest played no sound when you did it again in the same session

v1.4.2 - 🧩 I have made an Addon called SMoRGs QoL. This will be my new primary Addon.

v1.4.1 - 🧩 Addon now starts with only Quest Complete Sound turned on.
No QCS messages are show, they have to be turned on manually

v1.4.0 - 🧩 Achievement panel can now automatically hide or show completed achievements
Controlled via /qcs hideach or /qcs ha
New Features & Improvements:

🧩 Achievement panel can now automatically hide or show completed achievements
Controlled via /qcs hideach or /qcs ha

Setting is saved and correctly restored after reload

⚙️ The reset command now also updates the achievement filter

🎨 Code refactored and organized under the QCS namespace with persistent QCS_DB SavedVariables
✨ Feature Highlights
v1.3.1 - Made addon more stable

v1.3.0 - Added colors to Quest objective progress

v1.2.1 - Fixed handling of all quest types

v1.2.0 — Auto-Tracking & UI Improvements

🔊 Quest Complete Sound
Plays a satisfying sound when all quest objectives are done — you’ll know instantly when it’s time to turn in!

🧭 Optional Auto-Tracking
Automatically track any quest you accept. Toggle with:
/qcs autotrack, at

🎨 Optional coloring of progress
Automatically show the progress in a color from red to green. Toggle with:
/qcs color, col

💬 Customizable Splash Screen
Choose whether QCS greets you on login with a version summary.
/qcs splash

🧰 Easy Reset
Reset settings anytime:
/qcs reset
