# Install WSL2 on Windows (Step-by-Step Guide for Beginners)

This guide will help you install **Windows Subsystem for Linux 2 (WSL2)** on your Windows computer — even if you’ve never used a terminal before.

---

## What is WSL2?

**WSL2 (Windows Subsystem for Linux)** lets you run a real Linux system directly inside Windows — no virtual machines, no dual boot.

You’ll be able to:

* Use Linux commands
* Run development tools
* Install software like Python, Node.js, Docker, etc.

---

## Requirements

Before starting, make sure you have:

* Windows 10 (version 2004+) OR Windows 11
* Administrator access to your computer
* Internet connection

---

## Step 1 — Open PowerShell as Administrator

1. Click the **Start Menu**
2. Type: `PowerShell`
3. Right-click **Windows PowerShell**
4. Click **Run as administrator**

---

## Step 2 — Install WSL (One Command)

Copy and paste this command into PowerShell:

```bash
wsl --install
```

Press **Enter**

### What this does:

* Enables WSL
* Installs WSL2
* Downloads Ubuntu (Linux)

---

## Step 3 — Restart Your Computer

After installation finishes:

Restart your PC

---

## Step 4 — Set Up Linux (Ubuntu)

After restarting:

1. A window will open automatically (Ubuntu setup)
2. Create:

   * A **username**
   * A **password**

?? Important:

* Password will NOT show while typing (this is normal)

---

## Step 5 — You're Done!

You now have Linux running on your Windows machine 

---

## How to Open Linux Again

You can open Linux anytime by:

* Pressing **Start**
* Typing: `Ubuntu`
* Clicking the app

OR using PowerShell:

```bash
wsl
```

---

## Check WSL Version

To confirm everything is working:

```bash
wsl --status
```

You should see something like:

* Default Version: 2

---

## Optional — Set WSL2 as Default

```bash
wsl --set-default-version 2
```

---

## Useful Basic Commands

Inside Linux, try these:

```bash
ls        # List files
cd        # Change folder
pwd       # Show current folder
clear     # Clean screen
```

---

## Tips for Beginners

* Linux is **case-sensitive** (`Documents` is not the same as `documents`)
* Use `Ctrl + Shift + V` to paste in terminal
* Don’t worry if it feels unfamiliar — you’ll learn quickly!

---

## Troubleshooting

### If `wsl --install` doesn’t work:

Try manually enabling WSL:

```bash
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
```

Then:

```bash
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

Restart your computer and try again.

---

## Learn More

* Official Microsoft Docs:
  [https://learn.microsoft.com/windows/wsl/](https://learn.microsoft.com/windows/wsl/)

---

## Support

If this guide helped you, consider giving the repo a ?!