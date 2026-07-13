# One Pad - Product Specification (Working Draft)

Version: 0.1\
Status: Confirmed decisions only

## 1. Product Overview

### Product Summary

One Pad is an iOS application that teaches rhythm using a single
practice pad.

The application presents generated practice sessions using standard drum
notation. Users play on a practice pad while following a metronome.

Premium users may optionally record and analyze their performances after
a session.

The application is designed to expand over time into a complete rhythm
training platform covering multiple rhythmic concepts and time
signatures.

### Platform

-   iOS (Version 1)
-   Android (Future)

### Language

-   English (Version 1)
-   Built with localization support

### Required Equipment

Required: - iPhone - Practice pad - Drumsticks

Recommended: - Wired headphones

Bluetooth audio is not supported in Version 1.

## 2. Practice Model

### Skills

A Skill teaches one isolated rhythmic competency.

Each Skill defines its own exercise generation rules.

### Performance

Performance combines multiple Skills under a dedicated rule set.

Each Performance Area defines: - Allowed Skills - Difficulty limits -
BPM limits - Generation rules - Pedagogical goals

### Current Practice

Current Practice may be either: - Skill - Performance Area

Start Practice always generates a Session from the Current Practice.

## 3. Home Screen

Primary actions: - Start Practice - Skills - Performance

## 4. Session

Version 1: - 16 Exercises - Each Exercise = one measure

Flow:

Home → Session Preview → Count-in → Practice → Recording Stops →
Optional Analysis → Results

Changing BPM never regenerates the Session.

## 5. Preview Playback

Preview supports: - Metronome - Optional Reference Pad Hits

Reference Hits can be enabled or disabled.

Preview is never recorded or analyzed.

## 6. Count-in

Count-in always equals one complete measure.

Examples: - 4/4 = 4 clicks - 3/4 = 3 clicks - 5/4 = 5 clicks - 7/8 = 7
clicks

Count-in: - uses a different click sound - is not recorded - is not
analyzed - contains no notation - contains no reference hits

## 7. Practice Screen

Always displays four consecutive Exercises.

The window advances smoothly one Exercise at a time.

Current Exercise is indicated by: - highlighted frame - moving playhead

Only the following are displayed: - notation - playhead - BPM -
metronome - session progress

Beat numbers are never displayed.

## 8. Recording & Analysis

Recording is optional.

Modes: - Practice - Record - Analyze (Premium)

Recording and Analysis are separate.

## 9. Review Pool

Exercises that repeatedly cause difficulty are automatically stored.

Users cannot manually save Exercises.

Future Sessions may replay exact Review Exercises.

## 10. Session Length

Version 1: - Exactly 16 Exercises

Future versions may support different lengths.

## 11. Exercise

An Exercise is the smallest practice unit.

Version 1: - exactly one measure

## 12. Free Plan

One new Session may be generated per calendar day.

The generated Session may be replayed without limit.

Free users may: - Practice - Record - Replay recordings

Free users may not: - Generate another Session - Change BPM - Access
Performance - Analyze Sessions

## 13. Premium Plan

Premium users may: - Generate unlimited Sessions - Access all Skills -
Access Performance - Change BPM - Record - Analyze - Receive Review
recommendations

## 14. First Skill

Working title: Quarter-Note Pulse

Goals: - Read quarter notes - Synchronize with the metronome - Develop
steady pulse - Alternate sticking

Sticking is introduced immediately.

## 15. Master Timeline

All timing is controlled by one Master Timeline.

It synchronizes: - Preview playback - Count-in - Metronome - Reference
hits - Playhead - Recording - Analysis - Exercise transitions

## 16. Terminology

Practice = selected Skill or Performance Area.

Skill = one rhythmic competency.

Performance Area = curated combination of multiple Skills.

Session = one complete practice run.

Exercise = smallest practice unit (one measure in Version 1).

Review Pool = automatically maintained collection of difficult
Exercises.
