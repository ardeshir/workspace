# Dev VM — a Linux machine on your Mac

This repo sets up an Ubuntu Linux machine that runs *inside* your Mac, in a
window. It's a normal computer you can install anything on and break without
consequence — if it ever goes wrong, you delete it and start again. Your Mac is
never affected.

**You do not need to know Linux to follow this.** Every command is written out.
Copy it, paste it, press Return.

Total time: about 45 minutes, most of it waiting for downloads.

---

## Before you start

**1. Check your Mac is Apple Silicon.**

Click the  menu (top-left) → *About This Mac*. Look at the **Chip** line.

- Says **Apple M1 / M2 / M3 / M4** → you're good.
- Says **Intel** → stop here; these instructions won't work. Ask whoever
  shared this repo with you.

**2. Check you have about 30 GB of free disk space.**

Same *About This Mac* window → *More Info* → *Storage*.

**3. Install UTM.**

UTM is the app that runs the Linux machine. Download it free from
<https://mac.getutm.app> — click the big **Download** button (not the Mac App
Store one, which costs money and is identical). Open the downloaded file and
drag UTM into your Applications folder.

**4. Learn to open Terminal.**

Press `Cmd + Space`, type `terminal`, press Return. A window with text appears.
This is where you'll type commands. When these instructions say "run", they mean:
paste the command into Terminal and press Return.

> **A note about typing passwords.** When Terminal asks for a password, nothing
> appears as you type — no dots, no stars. That's normal and intentional. Type
> it and press Return.

---

## Pick your path

There are two ways to create the machine. They end up in the same place.

| | **Path A — Guided installer** | **Path B — Automatic** |
|---|---|---|
| **Best for** | First time doing this | You've done it before |
| **How it works** | You click through Ubuntu's setup screens | A settings file does it for you |
| **Download size** | ~2.5 GB | ~600 MB |
| **Your time** | ~20 min of clicking | ~5 min, then it's hands-off |
| **Needs Terminal skills?** | Barely | A little more |

**If you're unsure, use Path A.** It's more clicking but nothing is hidden from
you, and when something looks wrong you can see it on screen.

---

# Path A — Guided installer (recommended)

## A1. Download Ubuntu

Go to <https://cdimage.ubuntu.com/releases/24.04/release/>

Find and click the file named:

```
ubuntu-24.04.3-live-server-arm64.iso
```

The version numbers may be slightly different (`24.04.4`, and so on) — that's
fine, take whichever one is there. It **must** say `live-server` and `arm64`.

It's about 2.5 GB. Let it finish before continuing. It lands in your
**Downloads** folder.

## A2. Create the machine in UTM

Open UTM, then:

1. Click **Create a New Virtual Machine** (or the **+** at the top).
2. Click **Virtualize**.
3. Click **Linux**.
4. Click **Browse…** next to *Boot ISO Image*, and pick the `.iso` file you
   just downloaded from your Downloads folder.
5. Click **Continue**.
6. **Memory**: type `4096`. **CPU Cores**: type `4`. Click **Continue**.
   - *If your Mac has 8 GB of RAM total, use `3072` instead.*
7. **Storage**: type `40` (that's 40 GB). Click **Continue**.
   - *This is a maximum, not a reservation. It only uses what it actually needs.*
8. **Shared Directory**: skip it, just click **Continue**.
9. **Name**: type `devvm`. Click **Save**.

## A3. Install Ubuntu

Select `devvm` in the left sidebar and click the big **▶ Play** button.

A window opens with scrolling white text on black. That's normal. Wait for the
first blue screen.

Then work through the screens:

| Screen | What to do |
|---|---|
| Language | Press **Return** for English |
| Installer update available | Choose **Continue without updating** |
| Keyboard | Press **Return** unless yours differs |
| Type of install | **Ubuntu Server** (already selected) → **Done** |
| Network | Leave it — it configures itself → **Done** |
| Proxy | Leave blank → **Done** |
| Mirror | Leave it → **Done** |
| Storage — guided | **Use an entire disk** → **Done** |
| Storage — summary | **Done**, then **Continue** on the warning popup |
| **Profile setup** | See just below ⬇ |
| Ubuntu Pro | **Skip for now** → **Continue** |
| **SSH Setup** | See just below ⬇ |
| Featured snaps | Select nothing → **Done** |

**Moving around:** arrow keys move, `Tab` jumps between areas, `Return` selects.
The mouse mostly won't work here. To click into the window, click once; to get
your mouse back out, press `Ctrl + Option`.

### The Profile setup screen — fill it in exactly like this

```
Your name:            dev
Your server's name:   devvm
Pick a username:      dev
Choose a password:    (anything you'll remember — you WILL need it)
Confirm password:     (the same again)
```

Write that password down. You need it every time you type `sudo`.

### The SSH Setup screen — this one matters

Move to **Install OpenSSH server** and press **Space** so it shows `[X]`.

If you skip this you won't be able to connect from your Mac, and fixing it
afterwards is fiddly. Check it says `[X]` before continuing.

### Then wait

Installation takes 10–20 minutes. When it finally says **Reboot Now**, press
Return.

You may see `Please remove the installation medium, then press ENTER`. Just
press Return. If it loops back into the installer instead of booting, do this:

- Click the **⏻ power icon** in the UTM toolbar to stop the machine.
- In the left sidebar, right-click `devvm` → **Edit**.
- Find the **CD/DVD** drive in the list on the left, click it, click **Clear**.
- Click **Save**, then press ▶ Play again.

When you see `devvm login:`, Ubuntu is installed. **Now skip ahead to
[Step 6](#step-6-connect-from-your-mac).**

---

# Path B — Automatic setup

This path writes your settings into a small file that Ubuntu reads on its first
boot, so there are no installer screens at all.

## B1. Get this repo onto your Mac

In Terminal:

```bash
git clone https://github.com/ardeshir/workspace.git ~/vm
cd ~/vm
```

That downloads this repo into a folder called `vm` in your home directory and
moves you into it.

## B2. Make an SSH key

An SSH key is a pair of files: a private one that stays on your Mac, and a
public one you can hand out freely. It replaces typing a password.

Check whether you already have one:

```bash
cat ~/.ssh/id_ed25519.pub
```

- Prints a line starting with `ssh-ed25519` → you already have one, move on.
- Says *No such file or directory* → make one:

```bash
ssh-keygen -t ed25519 -C "dev vm"
```

Press **Return three times** to accept every default (an empty passphrase is
fine here). Then run the `cat` command again.

## B3. Put your key in the settings file

Open the settings file:

```bash
open -e cloud-init/user-data
```

Find this line:

```
      - ssh-ed25519 REPLACE_WITH_YOUR_PUBLIC_KEY
```

Replace `REPLACE_WITH_YOUR_PUBLIC_KEY` with the **whole line** that
`cat ~/.ssh/id_ed25519.pub` printed. Keep the `      - ` at the start.

While you're in there, find the line `dev:changeme` further down and change
`changeme` to a password you'll remember — keep it as `dev:yourpassword`, one
word, no spaces.

Save with `Cmd + S` and close the window.

> **Never press the Tab key in this file.** Use spaces. A single tab makes
> Ubuntu ignore the entire file, and it does so silently.

## B4. Build the two files

```bash
./cloud-init/download-image.sh
./cloud-init/make-seed.sh
```

The first downloads Ubuntu (~600 MB) and checks it arrived intact. The second
packages your settings into `seed.iso`. Both will tell you plainly if something
is wrong.

## B5. Create the machine in UTM

1. Open UTM → **Create a New Virtual Machine** → **Virtualize** → **Linux**.
2. Tick **Boot from kernel image**? **No** — leave it unticked. Skip the ISO
   field entirely (leave it empty) and click **Continue**.
3. **Memory** `4096`, **CPU Cores** `4` → **Continue**.
4. **Storage** `1` (we're about to replace this disk anyway) → **Continue**.
5. Skip **Shared Directory** → **Continue**.
6. **Name** it `devvm` → **Save**.

Now swap in the real disk:

7. Right-click `devvm` → **Edit**.
8. In the left list, click the **1 GB drive** under *Drives*, then **Delete**.
9. Click **New…** → **Import** → choose `~/vm/cloud-init/ubuntu.img` → **Save**.
10. Click **New…** again → tick **Removable (CD/DVD)** → **Import** → choose
    `~/vm/cloud-init/seed.iso` → **Save**.
11. Click the Ubuntu drive again and set **Size** to `40 GB` → **Resize**.
12. **Save**.

Order matters: the Ubuntu disk must sit above the seed disc in the list. Drag
it up if it doesn't.

## B6. Start it

Press **▶ Play**. Text scrolls for a minute or two while it applies your
settings, then you'll see `devvm login:`.

Continue below.

---

# Step 6. Connect from your Mac

The VM window works, but it's cramped — no copy-paste, no scrolling. From here
on you'll drive the VM from a normal Terminal window instead.

## 6a. Find the VM's address

Click into the VM window and log in at the `devvm login:` prompt:

- username: `dev`
- password: the one you chose

Then type:

```bash
ip -4 addr show | grep inet
```

You'll get two or three lines. Ignore `127.0.0.1`. Take the other one — it
looks like `192.168.64.5`. That's your VM's address. Write it down.

## 6b. Connect

Open a **new** Terminal window on your Mac (`Cmd + N`) and run, substituting
your own address:

```bash
ssh dev@192.168.64.5
```

The first time it asks `Are you sure you want to continue connecting?` — type
`yes` and press Return.

- **Path A** users: it asks for the password you set during installation.
- **Path B** users: it lets you straight in using your key.

You're in when the prompt changes to `dev@devvm:~$`.

## 6c. Make it a one-word command

Typing that IP every time gets old. On your **Mac** (open another Terminal tab
with `Cmd + T`):

```bash
open -e ~/.ssh/config
```

If TextEdit complains the file doesn't exist, run `touch ~/.ssh/config` first,
then the `open` command again.

Add this at the bottom, using your own address:

```
Host devvm
    HostName 192.168.64.5
    User dev
```

Save and close. Now you can just type:

```bash
ssh devvm
```

> The VM's address can change after your Mac reboots. If `ssh devvm` suddenly
> fails, redo step 6a and update the `HostName` line.

---

# Step 7. Install the development tools

Inside the VM (i.e. after `ssh devvm`), run:

```bash
git clone https://github.com/ardeshir/workspace.git ~/vm
cd ~/vm
./provision.sh
```

This installs the compilers, Git, Node.js, Docker and the rest. It takes
10–15 minutes and prints what it's doing. It will ask for your password once.

**It's safe to run again.** If it fails partway — a dropped connection, a
mirror hiccup — just run `./provision.sh` again. It skips whatever is already
installed.

When it finishes:

```bash
exec bash -l     # loads the new settings into your shell
./verify.sh      # checks everything works
```

`verify.sh` prints a ✓ for each working tool. If everything is green, you're
done.

If Docker shows ✗ with "not usable yet", that's expected on the first run —
type `exit`, `ssh devvm` back in, and run `./verify.sh` again.

---

# Using it day to day

| What you want | What to do |
|---|---|
| Start the VM | Open UTM, select `devvm`, press ▶ |
| Get a terminal in it | `ssh devvm` from your Mac |
| Leave the terminal | `exit` (the VM keeps running) |
| Shut it down properly | `sudo poweroff` inside the VM |
| Copy a file Mac → VM | `scp thefile.txt devvm:~/` |
| Copy a file VM → Mac | `scp devvm:~/thefile.txt .` |
| Edit VM files in VS Code | Install the *Remote — SSH* extension, connect to `devvm` |
| Add more tools | Edit `provision.sh`, run it again |
| Start completely over | Delete `devvm` in UTM, follow this README again |

You can close the UTM window and leave the machine running in the background.
Just remember to `sudo poweroff` when you're done for the day — it uses memory
and battery otherwise.

---

# When something goes wrong

| What you see | What it means | Fix |
|---|---|---|
| `ssh: connect to host ... Connection refused` | VM is off, or SSH isn't running | Start it in UTM. Path A users: you probably missed the SSH Setup tick — see below |
| `ssh: Could not resolve hostname devvm` | The `~/.ssh/config` entry is missing or misspelled | Redo step 6c |
| `Operation timed out` when connecting | Wrong IP address | Redo step 6a — it likely changed |
| `Permission denied (publickey)` | Your key isn't on the VM | Path B: your key wasn't pasted correctly. Rebuild the seed, bump `instance-id`, reboot |
| VM boots back into the installer | The install ISO is still attached | Edit the VM → CD/DVD drive → **Clear** |
| Path B: settings seem ignored | Usually a tab character in `user-data`, or an unchanged `instance-id` | Fix, run `make-seed.sh`, bump `instance-id`, reboot |
| `No space left on device` | The 40 GB filled up | `docker system prune -a` clears the usual culprit |
| `docker: permission denied` | Group change hasn't applied to this session | `exit`, then `ssh devvm` again |
| Really slow | Not enough memory | Shut down, Edit → raise Memory, restart |
| Everything is broken | — | Delete `devvm` in UTM and redo this README. It's 45 minutes, and that's the point of a VM |

**Missed the SSH tick during a Path A install?** Log into the VM window
directly and run:

```bash
sudo apt update && sudo apt install -y openssh-server
sudo systemctl enable --now ssh
```

Then go back to step 6a.

---

# What's in this folder

```
README.md                    this file
provision.sh                 installs the dev tools (run inside the VM)
verify.sh                    checks everything works (run inside the VM)
probe.sh                     lists what's on an existing machine (only for whoever
                             maintains this repo)
cloud-init/
  user-data                  Path B: your account settings — the file you edit
  meta-data                  Path B: the machine's name and identity
  download-image.sh          Path B: downloads and verifies Ubuntu (run on your Mac)
  make-seed.sh               Path B: builds seed.iso from the two files above
```

---

# Customising it

`provision.sh` starts with a block marked `EDIT ME`. That's the only part you
need to touch:

```bash
APT_PACKAGES=( build-essential git curl ... )   # add or remove names
NODE_VERSION="lts/*"                            # or "20", "22"
INSTALL_DOCKER=yes
INSTALL_RUST=no                                 # flip to yes
INSTALL_GO=no
```

Change it, run `./provision.sh` again, then `./verify.sh`. Existing tools are
left alone.

---

# A word on safety

Nothing here contains passwords or keys, and nothing should. If you ever share
your own version of this repo:

- Never commit your private SSH key (`~/.ssh/id_ed25519` — the file *without*
  `.pub`). Only the `.pub` one is safe to share.
- Never commit real passwords, API tokens or `.env` files.
- The `.gitignore` here already blocks the downloaded disk images and ISOs.

If you'd rather not put your public key in a file that gets committed, keep the
placeholder in the repo and edit your local copy only — `make-seed.sh` reads
your local copy, so it just works.
