# 📱 Noise Mapper - Testing Guide for Non-Technical Users

**Welcome Tester!** Thank you for helping test the Noise Mapper app! This guide will help you test the app step-by-step.

---

## 📋 What You Need

- ✅ Android phone or tablet
- ✅ The Noise Mapper app installed
- ✅ 15-20 minutes of time
- ✅ Access to different locations (quiet room, street, etc.)

---

## 🎯 How to Report Issues

If you find any problems:
1. Take a screenshot (Press Power + Volume Down buttons together)
2. Fill out the **Bug Report Template** at the bottom of this guide
3. Send it to the developer

---

# 🧪 Test Instructions

Follow these tests in order. Check the box ✅ when completed.

---

## Test 1: Login & Registration (5 minutes)

### What to Test:
Opening the app and creating an account

### Steps:
1. **Open the app**
   - [ ] App opens without crashing

2. **Try to Sign Up**
   - [ ] Tap "Sign Up" button
   - [ ] Enter your name (any name)
   - [ ] Enter your email
   - [ ] Enter a password (minimum 6 characters)
   - [ ] Tap the blue "Sign Up" button
   - [ ] You should see a loading spinner
   - [ ] You should be taken to the home screen

3. **Check the Sign Up Button**
   - [ ] Button should be **SOLID BLUE** (not gradient)
   - [ ] App icon on the button should be visible but not too bright

**✅ What Should Work:**
- Sign up should take you to the home screen
- Button should be solid color, not gradient
- No error messages

**❌ Report If:**
- App crashes when tapping Sign Up
- Button shows gradient colors instead of solid
- You get error messages that don't make sense

---

## Test 2: Light Mode vs Dark Mode (3 minutes)

### What to Test:
All colors work correctly in both modes

### Steps:
1. **Check Current Mode**
   - [ ] Look at your app - is it dark background or light background?

2. **Go to Settings**
   - [ ] Tap the gear icon (⚙️) at the bottom right
   - [ ] Scroll down to "Dark Mode" toggle

3. **Turn Dark Mode ON** (if it's off)
   - [ ] Toggle ON the "Dark Mode" switch
   - [ ] Go back to home screen (tap home icon in center)
   - [ ] Check if background is dark

4. **Turn Dark Mode OFF**
   - [ ] Go back to Settings
   - [ ] Toggle OFF the "Dark Mode" switch
   - [ ] Go back to home screen
   - [ ] Check if background is light

5. **Test Edit Profile in Light Mode**
   - [ ] Go to Settings → tap "Edit Profile"
   - [ ] Check if you can READ all text clearly
   - [ ] Name field should be visible
   - [ ] Email field should be visible
   - [ ] "Save Changes" button should be **SOLID COLOR** (not gradient)
   - [ ] Profile icon (person icon) should be **SOLID COLOR** (not gradient)

**✅ What Should Work:**
- Text is readable in both light and dark modes
- Profile icon is solid color (not gradient)
- Save button is solid color (not gradient)

**❌ Report If:**
- Text is white on white background (invisible)
- Profile icon has gradient colors
- Save button has gradient colors
- Any text is hard to read

---

## Test 3: Recording Noise (8 minutes)

### What to Test:
Recording sounds and getting accurate readings

### Steps:

#### 3A: Test in a Quiet Room
1. **Start Recording**
   - [ ] Go to home screen (tap center home button)
   - [ ] Make sure you're in a quiet room
   - [ ] Tap the big red "START RECORDING" button

2. **Check the dB Level**
   - [ ] Wait 5 seconds
   - [ ] Look at the big number in the center
   - [ ] Write down the dB level: _____ dB
   - [ ] **Expected: 30-40 dB** in a quiet room

3. **Check What Sound It Detected**
   - [ ] Wait 10 seconds (let it classify the sound)
   - [ ] Look below the gauge - you should see a colored card
   - [ ] What sound type did it show? (e.g., "Speech", "Music", "Other")
   - [ ] Write it down: _____________

4. **Stop Recording**
   - [ ] Tap the red "STOP RECORDING" button

#### 3B: Test With Your Voice
1. **Start Recording**
   - [ ] Tap "START RECORDING"

2. **Talk Normally**
   - [ ] Talk or have a conversation for 10 seconds
   - [ ] Check the dB level: _____ dB
   - [ ] **Expected: 60-70 dB** for normal speech

3. **Check Sound Classification**
   - [ ] Wait for the colored card to appear
   - [ ] It should say **"Speech"** (not "Other")
   - [ ] Write what it shows: _____________

4. **Stop Recording**

#### 3C: Test With Music
1. **Start Recording**
   - [ ] Tap "START RECORDING"

2. **Play Music**
   - [ ] Play any music on your phone or nearby
   - [ ] Let it play for 10-15 seconds
   - [ ] Check the dB level: _____ dB

3. **Check Sound Classification**
   - [ ] It should say **"Music"** (not "Other")
   - [ ] Write what it shows: _____________

4. **Stop Recording**

**✅ What Should Work:**
- Quiet room: 30-40 dB
- Normal speech: 60-70 dB
- Music should be detected as "Music"
- Speech should be detected as "Speech"

**❌ Report If:**
- Quiet room shows 10-20 dB (too low)
- Speech shows 30-50 dB (too low)
- Music always shows "Other" instead of "Music"
- Speech always shows "Other" instead of "Speech"

---

## Test 4: Navigation Bar (2 minutes)

### What to Test:
Bottom navigation bar doesn't get hidden by phone buttons

### Steps:
1. **Check All Screens**
   - [ ] Go to Map screen (tap map icon 🗺️)
   - [ ] Look at the bottom - can you see all 5 icons?
   - [ ] Go to Analytics (tap chart icon 📊)
   - [ ] Check bottom again - all 5 icons visible?
   - [ ] Go to History (tap clock icon 🕒)
   - [ ] Check bottom again
   - [ ] Go to Settings (tap gear icon ⚙️)
   - [ ] Check bottom again

2. **Test on Different Pages**
   - [ ] Open "Manual Report" (tap + icon from home)
   - [ ] Check if bottom buttons are visible
   - [ ] Check if phone's gesture bar (if you have one) overlaps with app buttons

**✅ What Should Work:**
- All 5 bottom icons always visible
- No overlap with phone's gesture bar or buttons

**❌ Report If:**
- Bottom navigation is hidden behind phone's navigation
- Icons get cut off at the bottom
- You can't tap some icons because they're too low

---

## Test 5: Map Screen (3 minutes)

### What to Test:
Map shows correctly with different colors

### Steps:
1. **Open Map**
   - [ ] Tap the map icon (🗺️) at bottom

2. **Check Map Colors**
   - [ ] Can you see the map?
   - [ ] Are there any markers (colored pins)?
   - [ ] What color is the top bar? _____________
   - [ ] In **Dark Mode**: top bar should be dark purple
   - [ ] In **Light Mode**: top bar should be your theme color (blue/green/etc.)

3. **Check Bottom Navigation**
   - [ ] What color is the bottom navigation bar? _____________
   - [ ] In **Dark Mode**: should be dark purple
   - [ ] In **Light Mode**: should be your theme color
   - [ ] Active icon (map icon) should be highlighted
   - [ ] Other icons should be slightly faded

**✅ What Should Work:**
- Map loads and shows
- Bottom bar changes color based on light/dark mode
- Active icon is clearly visible

**❌ Report If:**
- Bottom bar is always dark purple (even in light mode)
- Can't tell which icon is active
- Map doesn't load

---

## Test 6: Manual Report (2 minutes)

### What to Test:
Reporting noise manually looks correct

### Steps:
1. **Open Manual Report**
   - [ ] From home, tap the History icon (🕒)
   - [ ] Tap the blue "+" button (floating button on right)

2. **Check Colors**
   - [ ] Check the card showing dB slider
   - [ ] In **Light Mode**: card should be light colored
   - [ ] In **Dark Mode**: card should be dark colored
   - [ ] Text should be readable

3. **Test the Slider**
   - [ ] Move the dB slider left and right
   - [ ] Numbers should update
   - [ ] Should go from 0 to 120 dB

**✅ What Should Work:**
- Card colors change with light/dark mode
- All text is readable
- Slider works smoothly

**❌ Report If:**
- Card is always dark (even in light mode)
- Text is hard to read
- Slider doesn't move or is invisible

---

# 📝 Bug Report Template

Copy this template and fill it out when you find a problem:

```
==========================================
🐛 BUG REPORT
==========================================

📅 Date: __________________

👤 Your Name: __________________

📱 Phone Model: __________________ (e.g., Samsung Galaxy S21)

🎨 Theme Mode: Dark ☐  Light ☐

---

🔍 WHAT TEST WERE YOU DOING?
Test #: _____ (e.g., Test 3 - Recording Noise)

---

❌ WHAT WENT WRONG?
Describe the problem in simple words:
_________________________________________
_________________________________________
_________________________________________

---

✅ WHAT SHOULD HAVE HAPPENED?
What did you expect to see?
_________________________________________
_________________________________________

---

📸 SCREENSHOT
Did you take a screenshot? Yes ☐  No ☐

---

🔢 STEPS TO REPRODUCE
How to make the problem happen again:
1. _____________________________________
2. _____________________________________
3. _____________________________________

---

💬 ADDITIONAL NOTES
Anything else we should know?
_________________________________________
_________________________________________

==========================================
```

---

# 📊 Testing Summary Sheet

After completing all tests, fill this out:

| Test # | Test Name | Status | Notes |
|--------|-----------|--------|-------|
| 1 | Login & Registration | ✅ Pass / ❌ Fail | ____________ |
| 2 | Light/Dark Mode | ✅ Pass / ❌ Fail | ____________ |
| 3 | Recording Noise | ✅ Pass / ❌ Fail | ____________ |
| 4 | Navigation Bar | ✅ Pass / ❌ Fail | ____________ |
| 5 | Map Screen | ✅ Pass / ❌ Fail | ____________ |
| 6 | Manual Report | ✅ Pass / ❌ Fail | ____________ |

**Total Tests Passed:** _____ / 6

**Overall App Rating:** ⭐⭐⭐⭐⭐ (circle stars)

**Would you use this app?** Yes ☐  No ☐

**General Comments:**
_________________________________________
_________________________________________
_________________________________________

---

# ✅ Done!

Thank you for testing! Please send:
1. ✉️ Your filled **Bug Report Template** (if you found issues)
2. 📊 Your **Testing Summary Sheet**
3. 📸 Any **screenshots** of problems

Send to: [Developer's Email/Contact]

**Questions?** Contact the developer if you need help understanding any test.

---

**Last Updated:** February 18, 2026
**Version:** 1.0
