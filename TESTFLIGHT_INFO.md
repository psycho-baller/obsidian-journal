# TestFlight Information for Ignite

## App Information

**App Name:** Ignite
**Subtitle:** Voice to Daily Note

## Description

**Ignite is the zero-friction bridge between your thoughts and your Obsidian Vault.**

Capturing a thought on mobile shouldn't feel like work. Ignite solves the "friction of mechanics" by allowing you to instantly capture ideas using your voice, without waiting for apps to load or pecking at a glass screen.

**Why Ignite?**
*   **Instant Capture:** One tap using the "Magic Button" to record. State-of-the-art on-device transcription via WhisperKit ensures privacy and speed.
*   **Intelligent Hydration:** Ignite doesn't just dump text. It reads your *existing* Daily Note template and surgically places your thoughts where they belong.
    *   Say "I slept 7 hours," and it finds your `Sleep:` field.
    *   Say "Remind me to buy milk," and it adds a task under `## Tasks`.
*   **Private by Default:** No cloud databases. No sync servers. Ignite works directly with your local Markdown files.
*   **Zero Lock-In:** Your data remains standard Markdown in your Obsidian vault.

Ignite is for the "Architects of Thought"—those who value structured notes but need a faster, more fluid way to capture life as it happens.

---

## What to Test (Beta Notes)

**Welcome to the Ignite Beta!**

We are testing the core "Capture to Daily Note" workflow. Please focus your testing on the following areas:

1.  **The "Magic Button" Flow:**
    *   Does the recording start instantly?
    *   Is the transcription accurate (we use on-device WhisperKit)?

2.  **Template Intelligence:**
    *   Try speaking different types of data (Tasks, Mood, Sleep, General Reflections).
    *   Check your Daily Note in Obsidian. Did Ignite correctly identify where to put the information?
    *   *Note: Ensure you have a Daily Note template set up in your Obsidian configuration for best results.*

3.  **Permissions & Setup:**
    *   verify that microphone and folder access permissions work smoothly.

4.  **Overall Stability:**
    *   Please report any crashes or "hanging" states during processing.

**Feedback:**
Please take screenshots of any "misplaced" text in your daily notes so we can improve the template engine!

*Built with obsession in Swift. Open Source. Private First.*
