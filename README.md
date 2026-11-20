# Bench Crow™ RWR Display: DCS World setup

Your Bench Crow RWR display works on its own as an animated desk display. **You only need this page if you
want it to show your live radar warning picture from DCS World.**

It takes about five minutes, once. Nothing is installed on the display itself: one small file goes into
your DCS folder on the PC, and the display picks up the data over your home WiFi.

## What you need

- A Windows PC with DCS World
- The display and the PC on the **same home network** (the display uses 2.4 GHz WiFi)
- The display already connected to your WiFi (see step 1)

## 1. Connect the display to your WiFi

Skip this if you've already done it: the bottom of the display then shows a network address (like `192.168.1.57`).

1. Plug the display into USB-C power. The first time, it opens its own WiFi network called **RWR-Setup**
   for 5 minutes (the screen shows `SETUP: RWR-Setup`).
2. On your phone, join **RWR-Setup**. A setup page opens by itself. If it doesn't, open a browser and go to `192.168.4.1`.
3. Tap **Configure WiFi**, choose your home network, enter its password, and tap **Save**.
4. The display connects and shows its network address at the bottom of the screen.

To change networks later: unplug the display, then **hold the MUTE button while plugging it back in**
and keep holding for 3 seconds. The saved WiFi is cleared and **RWR-Setup** opens again.

## 2. Add the file to DCS

1. Download **[BenchCrow_RWR_Export.lua](BenchCrow_RWR_Export.lua)**: click it, then the download button
   (the arrow at the top right of the file view).
2. Open your DCS **Saved Games** folder. Paste this into the File Explorer address bar and press Enter:
   ```
   %USERPROFILE%\Saved Games\DCS
   ```
   (Older installs may use `DCS.openbeta` instead of `DCS`.)
3. Open the **Scripts** folder. If there isn't one, create a folder named `Scripts`.
4. Copy **BenchCrow_RWR_Export.lua** into the Scripts folder.

## 3. Tell DCS to load it

1. In the same Scripts folder, look for a file called **Export.lua**.
   - **If it's there:** open it with Notepad (right-click → Open with → Notepad).
   - **If it isn't:** in Notepad, start a new file and save it in the Scripts folder as `Export.lua`
     (choose "All files" as the type, so Notepad doesn't add `.txt`).
2. Add this line **at the very end** of Export.lua, on its own line:
   ```lua
   dofile(lfs.writedir()..[[Scripts\BenchCrow_RWR_Export.lua]])
   ```
3. Save and close. Leave any other lines in the file alone: other add-ons (SRS, Tacview, DCS-BIOS...) use it too,
   and they all keep working side by side.

## 4. Fly

Start DCS and a mission. As soon as you're in the cockpit, the display switches from **DEMO** to **LINK**
and shows the same threats as your aircraft's own radar warning receiver. When you leave the mission,
it goes back to the demo after a few seconds.

A quick test: in the Mission Editor, put yourself in a helicopter or jet with a hostile SA-8 or ZSU-23-4
a few miles away, set to **Weapon Hold** so it searches but doesn't fire.

## If it doesn't work

| What you see | What to do |
|---|---|
| Display stays on **DEMO** in a mission | Check the line at the end of Export.lua is spelled exactly as above, then restart DCS. Check the display shows a network address (step 1). |
| Works in single player, not on a server | The server has to allow sensor data export. Many do; some don't. Single player always works. |
| Still nothing | Some routers and mesh/guest networks block the "send to everyone" message the script uses. Open BenchCrow_RWR_Export.lua in Notepad, find `local ESP_IP = ""`, and put the address your display shows between the quotes, e.g. `local ESP_IP = "192.168.1.57"`. |
| Threats appear mirrored left/right | In the script, change `local AZ_SIGN = 1` to `local AZ_SIGN = -1`. |
| A threat shows as **U** | DCS reported a radar type the script doesn't know yet, often after a DCS update. Send us the line from `Saved Games\DCS\Logs\APR39_types.txt` and we'll add it to the next version. |

## Updates

New versions of the script are posted here (see [CHANGELOG.md](CHANGELOG.md)). To update, download the new
file and replace the old one. You don't need to change Export.lua again.

## Questions

Message us through Etsy. We're glad to help.

---

The Bench Crow RWR display is a hobby replica for display and simulation use. It is not real military
equipment and does not detect real radar signals. Not affiliated with or endorsed by Eagle Dynamics
(DCS World), the U.S. Government, or any aircraft manufacturer.

This script is provided for use with Bench Crow displays. © Bench Crow. All rights reserved.
