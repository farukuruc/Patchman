# Patchman 1.1-stable

**Small, useful features for the Sony NW-A55 with Walkman One 3.02.**

Patchman adds album information, Parametric EQ, an optional cassette screen,
Audio Path information, quick links to the current album and album artist,
newest-first album years, and optional artist photos.
It keeps Sony's familiar interface.

**Walkman One 3.02 must already be installed. Patchman does not install Walkman One.**

**Go to requires Playback Settings > Artist List Display > Album Artist.**
The Artist setting is not supported by this feature.

## Contents

- [Requirements](#requirements)
- [Features](#features)
- [Installation](#installation)
- [Check your installation](#check-your-installation)
- [Album Play and total time](#album-play-and-total-time)
- [Album years and scrolling](#album-years-and-scrolling)
- [Artist photos](#artist-photos)
- [Queue Remaining time](#queue-remaining-time)
- [Parametric EQ](#parametric-eq)
- [Cassette Screen](#cassette-screen)
- [Audio Path](#audio-path)
- [Go to Album and Album Artist](#go-to-album-and-album-artist)
- [Update or remove Patchman](#update-or-remove-patchman)
- [Problems and solutions](#problems-and-solutions)
- [Testing and limits](#testing-and-limits)
- [Questions](#questions)
- [Credits](#credits)

## Requirements

| Item | Requirement |
| --- | --- |
| Player | Sony NW-A55 |
| Firmware | Compatible Walkman One 3.02, already installed |
| Computer | Windows, to run the included installer |
| Connection | A USB cable that supports data transfer |
| Storage | Free space on the player's internal storage |
| Go to setting | Artist List Display set to Album Artist |
| First PEQ test | Wired headphones and a normal PCM/FLAC music file |

Charge the player before installation. Keep a copy of your music and your
current working firmware package before changing the system.

You do not need to choose the WM1Z sound signature. Patchman keeps your existing
Walkman One sound signature and Plus mode choices.

Other models and firmware versions have not been verified. Do not assume the
package works on another Walkman because it looks similar.

Patchman changes the player software. It is not an official Sony update.

## Features

| Feature | What it does |
| --- | --- |
| Album total time | Shows the total length of the album on its track page |
| Play button | Starts the album from its first track |
| Album years | Shows tagged years and lists newest albums first inside an album artist |
| Artist photos | Uses optional JPG/PNG files from internal ARTIST-PHOTOS |
| Queue Remaining | Shows the time left in the current playback list |
| Parametric EQ | Loads headphone EQ profiles from `.txt` files |
| Cassette Screen | Shows a purple Sony UCX cassette while HOLD is active |
| Audio Path | Shows format, Direct Source, PEQ and connection information |
| Go to | Opens the current album or album artist from Now Playing |
| Help label | Shows Audio Path instead of Bookmark List in View Help |
| Version label | Shows Patchman v1.1 in Unit Information |

Bookmark List is replaced by Audio Path. Bookmark actions are removed from the
affected menus. **Add to Playlist** remains available.

On Standard Now Playing, **Change Playback Screen** is replaced by **Go to**.
That menu no longer offers the spectrum analyzer or level meters.

## Installation

### Before you start

1. Confirm that the player is an **NW-A55**.
2. Confirm that compatible **Walkman One 3.02** is already installed.
3. Download `Patchman_NW-A55.zip`.
4. Extract the **whole ZIP** to a new folder on your computer.

Keep every file and folder together. Do not run the installer from inside the
ZIP. Do not copy only the `.exe` file to another location.

The extracted package contains:

```text
Patchman_NW-A55/
  Install/
    FirmwareUpdateTool.exe
    Data/
  Remove/
    FirmwareUpdateTool.exe
    Data/
  README.md
  SHA256SUMS.txt
  manifest.json
```

Use **Install** to add Patchman. Use **Remove** only when you want to remove it.
The Data folders contain files needed by the installers.

### Install the patch

1. Connect the Walkman to the computer by USB.
2. Open the extracted **Install** folder.
3. Run `FirmwareUpdateTool.exe`.
4. Read the message and follow the installer instructions.
5. Wait for installation to finish. Do not disconnect the cable while the
   installer is still working.
6. Optional: copy artist photos into **ARTIST-PHOTOS on internal storage**,
   as explained below, while USB is still connected.
7. When installation is complete, disconnect USB.
8. Fully turn the Walkman off, then turn it on **without USB connected**.

Turning the screen off and on is not a full restart.

When the player starts with USB connected, the original Sony interface may
appear. This is expected. Check Patchman after a start without USB.

### First PEQ installation

If this is the first time the Patchman PEQ system is installed on the player:

1. Start the player without USB.
2. Connect wired headphones.
3. Play a normal PCM/FLAC track and confirm that sound plays.
4. Do this **before the next full restart**. It completes the first playback
   check.

An update keeps an existing successful PEQ playback check when the audio
components match. You do not need to repeat this first-install process for
every profile change.

On a first installation, PEQ and Cassette Screen start **off**. Enable them in
Settings if you want to use them. Supported updates keep existing preferences.

## Check your installation

After starting without USB, check these items:

- Open an album: total time and a **Play** button should appear.
- Open Play Queue: **Remaining** should appear when the required information
  is ready.
- Open Sound settings: **Parametric EQ** should be available.
- Open Basic Settings: **Cassette Screen** should be below Device Settings.
- Open the old Bookmark List page: it should now show **Audio Path**.
- Open View Help from Now Playing: its right-hand label should say **Audio Path**.
- Open Unit Information: it should show **Patchman v1.1**.
- Open an album artist: albums should be newest first, with years below their
  names. The All row is hidden in this list.
- If you added an artist photo, check it in the Artist list. An artist without
  a photo should keep the original Sony album artwork.

Then select **Playback Settings > Artist List Display > Album Artist** and test
both Go to choices, as described below.

## Album Play and total time

Open an album's track list to see its total time and the **Play** button.
For example, open Artist, choose an album artist, then choose an album.

Tap **Play** to start the album from its first track. You can still tap an
individual track to start from that track.

The total time is calculated from track information. It may take a short time
to appear, especially when the player has not loaded the information yet.
It is not always available at the exact moment you open the page.

This release keeps the original single-line album and artist rows. It does not
add disc groups or a large album cover above the track list.

## Album years and scrolling

In an album artist's album list, the year appears under each album name. Albums
are ordered from newest to oldest. The All row is hidden in this list. Other
library views, such as Recently Added, keep their original behavior.

The year comes from the release-year metadata in Sony's database. It is not an
online lookup of the original release date. A remaster can therefore show the
year written in its tags. Albums with unknown or conflicting valid years show
no year and go last. Albums with the same year keep their original Sony order.
Albums with the same title under different album artists are matched separately.

The result is ordered in the native media client before the album screen model
is created. There is no added Loading page or visible A–Z list followed by a
reorder. If the metadata snapshot or native layout check fails, Sony's original
order is kept instead of guessing a new order.

The year snapshot is prepared once before the modified player starts. After
adding music or changing tags, let Sony finish updating the music library, then
fully turn the player off and on without USB. This refreshes the years and
artist-photo matches together. The snapshot supports up to 8,192 album-artist /
album pairs and has a bounded size.

Long album lists use a consistently thin position indicator. Swipe the list to
scroll; the indicator itself is not a draggable handle. It stays visible while
this page is open and the list is long enough to scroll. This page also stops
at its top and bottom boundaries to avoid a large blank overscroll area. Other
pages keep Sony's original scrollbar and scrolling settings.

## Artist photos

Artist photos are optional. Put them in **ARTIST-PHOTOS on the Walkman's internal
storage**, not on the SD card. The installer creates the folder if needed.

```text
WALKMAN internal storage/
  ARTIST-PHOTOS/
    Queen.jpg
    Pink Floyd.png
```

On Windows this may be `D:\ARTIST-PHOTOS\Queen.jpg`. The drive letter can be
different on another computer. The folder is directly at the top of the internal
drive. Do not put it inside MUSIC, and do not create a subfolder per artist.

The photo filename must match the **Album Artist** metadata. For Album Artist
`Pink Floyd`, use `Pink Floyd.jpg` or `Pink Floyd.png`. The extension can be JPG
or PNG. If both exist, JPG has priority. `Pink Floyd Live.jpg` does not match
`Pink Floyd`. Use the same spelling, spaces and accents as the tag.

Use a square image, for example 500×500, 600×600 or 640×640. The image is requested
at the existing 84×84 display size and cropped to fit the square. Keep a face near
the center. Empty files and files larger than 8 MiB are ignored.

For a name with a Windows-forbidden character, use its percent code in the
filename. For example, Album Artist `AC/DC` uses `AC%2FDC.jpg`. A literal `%`
becomes `%25`. Ordinary spaces and letters do not need escaping.

After adding, changing or deleting photos, disconnect USB and fully turn the
player off and on. Photo matches are prepared at startup; this release does not
have a photo Refresh button. You can add many photos and restart once.

For a new artist, add the music to your usual music storage and put the photo
in internal ARTIST-PHOTOS. Wait for Sony's music-library update to finish, then
fully restart without USB. The music can be on SD; the artist photo stays in
internal storage.

When a matching artist photo is loading, its square stays empty until the photo
is ready. The representative album cover is not shown first.

If no photo matches, the original Sony album artwork stays. If a selected photo
is broken or cannot load, that artwork also stays. No setup is required for
artists without photos. Year sorting does not change which representative album
cover Sony uses for this fallback. This feature never edits your photo files.

## Queue Remaining time

The Play Queue page shows **Remaining** beside its title.

It uses the current playback position and available track lengths to calculate
the time left. It includes the part of the current track that has not played yet.

The queue fix covers long lists, including the 50-track and 58-track cases used
during testing. The value may need a short time to appear while information loads.

If the player cannot provide enough information for a correct value, the display
may be blank or show a placeholder. A repeat setting can also mean that playback
has no final end. Do not treat the number as a promise that the player will stop
at that time.

## Parametric EQ

Parametric EQ, or **PEQ**, changes the sound using a profile with frequency,
gain and filter settings. You can use different profiles for different headphones.
It is not limited to the included Truthear Gate profile.

Open **Settings > Sound > Parametric EQ**.

### Add a new profile

1. Get a profile in the supported **Equalizer APO `.txt` format**.
2. Connect the Walkman to your computer by USB.
3. Open the player's **internal storage**.
4. Copy the profile into the **PEQ** folder. Create this folder if it is missing.
5. Put profile files directly in that folder, not in subfolders.
6. Disconnect USB and return to the patched interface. If you started with USB
   connected, fully restart without USB.
7. Open **Sound > Parametric EQ**.
8. Tap **Refresh**.
9. Tap the profile name to load it. Selecting a profile also enables PEQ.

Example folder:

```text
Internal storage/
  PEQ/
    Truthear Gate PEQ.txt
    My Other Headphones.txt
    active.txt
```

`active.txt` is the selection file used by Patchman. **Do not use that name for a
headphone profile.** You normally do not need to edit it yourself. The PEQ screen
manages the selection.

Use clear file names so that you can recognise your headphones in the list.
Check that Windows has not saved a file as `profile.txt.txt`.

### Turn PEQ on or off

- Tap **PEQ On** to switch processing off.
- Tap **PEQ Off** to enable the selected profile again.
- If no profile is selected, choose one from the list first.
- To change headphones, tap the other headphone's profile.

Manage profile files on your computer over USB. The player UI does not include
a profile Delete button.

The selected profile and PEQ on/off choice are saved across normal restarts.
If you edit a profile file on the computer, refresh the list and select that
profile again to load the changed settings.

### Supported filters

| Profile name | Filter type |
| --- | --- |
| PK | Peak filter |
| LS / LSC | Low shelf |
| HS / HSC | High shelf |

The profile can also include a **Preamp** value.

The included `Truthear Gate PEQ.txt` uses this format:

```text
Preamp: -2.0 dB
Filter 1: ON PK Fc 33 Hz Gain -4 dB Q 0.35
Filter 2: ON PK Fc 410 Hz Gain 1 dB Q 0.4
Filter 3: ON PK Fc 2000 Hz Gain 1.5 dB Q 1.5
Filter 4: ON PK Fc 4700 Hz Gain -3.5 dB Q 1.5
```

This is an example for a specific headphone profile, not a setting for every
headphone. A `.txt` file must still contain a supported profile. Changing another
file's extension does not convert it.

The included Gate file is not written over an existing file with the same name.

### Direct Source and PEQ

**Direct Source and Patchman PEQ can be used together.** This combination was
tested with wired headphones on the author's NW-A55.

Direct Source being on does not mean Patchman PEQ is off. Check the PEQ screen
for your selected profile and on/off setting.

Bluetooth audio and Bluetooth PEQ have **not** been tested. The author uses wired
headphones. The wired test does not prove that Bluetooth, USB audio, or every
playback mode works in the same way.

## Cassette Screen

Open **Basic Settings > Cassette Screen**, just below **Device Settings**.

Turn it on to use the purple Sony UCX cassette view. Turn it off to keep the
normal Sony view during HOLD.

When enabled:

- HOLD activates the cassette view when the normal player view is available.
- Track and artist names appear in capital letters.
- The reels turn while music plays and stop when playback is paused.
- Animation stops while the display is off.
- The cassette view returns when you wake the display while HOLD is active.

The on/off choice is saved across restarts. This feature uses one selected purple
cassette design. It does not include Wampy's full interface or a skin menu.

Sony's HOLD warning may briefly appear when you press a locked button. The reels
may also have a short delay when the display wakes. These behaviours do not mean
that music has stopped.

## Audio Path

Audio Path replaces Bookmark List. You can still move between Play Queue,
Now Playing and Audio Path with the normal horizontal swipe.

It shows:

- Format information reported by Sony.
- Direct Source on/off state.
- PEQ configuration state.
- Selected PEQ profile.
- The preamp value written in that profile.
- Output connection information, when available.

**This is an information page.** It does not change your sound settings.
Use the Parametric EQ screen to load a profile or turn PEQ on/off.

Some values may show **Unknown** when the player does not provide the information.
The format text is not an independent check of the final audio output.
Likewise, **ON (configured)** shows the PEQ configuration. It is not a live
measurement proving that every audio sample is being processed.

## Go to Album and Album Artist

### Required setting

First open:

**Playback Settings > Artist List Display > Album Artist**

This is the setting under Playback Settings. It is **not** the old Change
Playback Screen option in the Now Playing menu.

The home icon may still be called **Artist**. That is fine if Artist List Display
is set to **Album Artist**. Keep the Artist library icon enabled.

### Use Go to

1. Play a track and open **Standard Now Playing**.
2. Tap the bottom-right options icon, which looks like a small bag.
3. Tap **Go to**.
4. Choose **Album** or **Album Artist**.

**Album** opens the current track's album track list.

**Album Artist** opens the albums belonging to that album artist.

A short **Opening library...** message can appear while the player opens the
correct page. It hides intermediate browsing screens. **Cancel** lets you stop
the move.

Go to does not select a new track or start the album. Your music and current
queue stay in place while you browse.

### Tags matter

The feature uses Sony's library information. Music files need correct track,
album and album-artist tags, and the player library must be up to date.

The track artist and album artist can be different. For example, a compilation
may use **Various Artists** as its album artist. In that case, Album Artist
opens **Various Artists**, not the individual performer.

The **Artist** display mode is not supported in v1.1. Do not switch to that mode
and expect the Album Artist shortcut to change its behaviour.

Go to is implemented for the **English Standard Now Playing menu**. Other
languages and playback screens are not verified. If track or library information
does not match, the feature stops instead of guessing a destination.

## Update or remove Patchman

### Update an existing installation

For a supported existing Patchman installation, run the new package's
`Install/FirmwareUpdateTool.exe` directly. You do not need to remove the old
version first.

Upgrade checks cover v1.0-stable and the known development versions used during
this project. Unknown modified players or launchers can be rejected.

Supported updates keep music, PEQ profiles and selection, PEQ on/off preference,
Cassette Screen preference, and Walkman One sound signature and Plus mode choices.

**Patchman 1.0 is not required before 1.1.** The 1.1 installer includes the full
Patchman feature set. See the testing section for first-install hardware status.

### Remove Patchman

1. Connect the player by USB.
2. Open the **Remove** folder from this v1.1 package.
3. Run `FirmwareUpdateTool.exe` and follow its instructions.
4. When finished, disconnect USB and fully turn the player off/on.

This removes active Patchman features and returns to the original **Walkman One
player interface**. It does **not** return to stock Sony firmware.

Music, PEQ profile files and the saved cassette preference are kept.
Use the combined package's remover, not an old remover for only one feature.
Removing Patchman is also different from returning to Patchman v1.0.

## Problems and solutions

| Problem | What to check |
| --- | --- |
| The installer says the program is damaged | Extract the full ZIP again. Keep the `.exe` and Data folder together. Download again if files are missing. |
| Installation finishes but the old interface appears | Disconnect USB and fully turn the player off/on. A USB-connected start uses the original interface. |
| Go to cannot find the album artist | Select Album Artist in Artist List Display. Check file tags, library information and the Artist home icon. |
| Go to opens a compilation artist | Check the Album Artist tag. Various Artists may be the correct album artist. |
| A PEQ profile is missing | Put the `.txt` directly in internal storage's PEQ folder, then tap Refresh. |
| A PEQ profile cannot load | Check the file format and supported filters. A text file is not always an Equalizer APO profile. |
| PEQ gives no response | Start without USB, reopen the PEQ page and tap Refresh. Keep the error message if it continues. |
| Cassette Screen does not appear | Enable it in Basic Settings, activate HOLD, and check the normal player view. |
| Album or Remaining time is not immediate | Allow time for track lengths to load. Check again after normal playback starts. |
| The installer reports low space | Keep the exact error and install log. Free internal music storage if needed. Do not delete unknown system files. |
| The installer reports unknown firmware or files | Confirm the model and Walkman One version. Another modification may be present. Do not bypass the check. |

### Clicks or distortion with PEQ

A small click was reported around some track changes and PEQ/profile changes.
This is a known observation, not a promise of perfectly silent changes.

If you hear distortion during a track, compare it with PEQ off. Check the profile
gains and preamp. A negative preamp, such as -2 dB, does not by itself guarantee
that every profile avoids clipping. Lower the preamp and reload the profile when
more headroom is needed.

Repeated clicks during normal playback or clear distortion should be reported.
Do not treat every sound problem as normal.

### Information for a bug report

Include the model, Walkman One version, Patchman version, connection type,
steps that cause the problem, and the exact error message.

If available, attach these files from the player's internal storage:

- `Patchman-install.log` for installation errors.
- `sony_peq_status.log` for PEQ problems.
- `sony_album_launch.log` for startup problems.
- `sony_album-year-cache.log` for album years and artist-photo indexing.
- `sony_album-native-years.log` for native album order checks.
- `sony_goto-navigation-b6.json` and `sony_goto-target.json` for Go to problems.

The Go to log still uses an internal filename from development. This does not
mean the release menu should show a beta label. Some logs appear only after
another startup exports information from the previous run.
Logs can include track titles and profile names. Check them before sharing.

### Artist photo does not appear

Check the internal ARTIST-PHOTOS folder, exact Album Artist spelling, JPG/PNG
extension and file size. Check that Windows did not save a double extension such
as `Queen.jpg.jpg`. Fully restart after copying. Do not use the SD MUSIC folder.

After a cable-free startup and a later USB connection, `sony_album-year-cache.log`
can show `internal-flat-v1`, `available=1`, and the number of indexed artist photos.
The same log reports the year snapshot. A zero photo count means that no matching
photo files were indexed at that startup.

## Testing and limits

The main features were tested on the author's **Sony NW-A55 with Walkman One**,
using a local lossless library and wired headphones.

| Area | Status |
| --- | --- |
| Album Play and total time | Tested on the author's device |
| Long-list queue Remaining fix | Tested, including 50-track and 58-track cases |
| PEQ selection, on/off and saved preference | Tested on the author's device |
| Wired Direct Source + PEQ | Tested on the author's device |
| Cassette Screen and saved preference | Tested on the author's device |
| Audio Path and horizontal swipes | Tested on the author's device |
| Go to with Album Artist display | Tested using the route kept in v1.1 |
| Package checks | Host/ARM metadata and photo tests, layout tests, upgrade/removal/return and UPG round trips passed for the confirmed payload; final ZIP integrity and payload equality checked |
| Newest-first album years and hidden All | Confirmed on the author's device |
| Thin indicator and album scroll boundaries | Confirmed on the author's device |
| Internal artist photos, loading without album-cover flash and error fallback | Confirmed on the author's device |
| First installation on clean Walkman One | Not yet verified on hardware |
| Bluetooth playback and PEQ | Not tested; the author listens by wired headphones |
| MP3, AAC, DSD and every other playback mode | Not fully tested by this project |
| Other players and firmware versions | Not verified |

An untested format is not automatically unsupported. It means this project does
not yet have enough testing to promise correct behaviour for it.

The package does not promise longer battery life, faster performance, or support
for every NW-A55 setup. The installer checks known firmware files, available
space and package contents before activating the patch.

## Questions

**Is this a new operating system?**

No. Patchman adds features to the existing Sony/Walkman One system.

**Do I need Patchman 1.0 first?**

No. Compatible Walkman One 3.02 is the required base.

**Does it install Walkman One or change my sound signature?**

No. Install Walkman One first. Your sound signature and Plus mode choices are kept.

**Can I use a profile for another headphone?**

Yes. Add a supported Equalizer APO `.txt` profile to the PEQ folder and select it
on the player. You do not need to build a new firmware package for each headphone.

**Can I use Go to with Artist instead of Album Artist?**

No. Keep Artist List Display set to Album Artist in this release.

**Does Audio Path prove the output is bit-perfect?**

No. It displays information from Sony and the saved PEQ configuration.
It does not measure the final output.

**Will Remove restore stock Sony firmware?**

No. It removes Patchman and keeps Walkman One.

## Credits

- Sony, for the original Walkman hardware and software.
- MrWalkman, for Walkman One, which is required before this patch.
- Wampy, for the cassette artwork used by the optional cassette view.
- Cinder and its tools/research, including the PEQ foundation and firmware work.
- Rockbox nwztools, used in the firmware unpacking and packing workflow.
- Qt and SQLite, used by the interface and metadata components.

Patchman is a separate community project. It is not an official Sony or
MrWalkman firmware release.

## Release package

This v1.1-stable package contains the same Install and Remove firmware payloads
as the device-confirmed internal-photo build with the loading-flash fix. The final release updates the
package name, installer information and this README. It does not add new runtime
code. Users already running that confirmed build do not need to reinstall only
to receive the stable label.

The public ZIP contains Install and Remove. Older working packages remain in the
maintainer's backups. Remove returns to Walkman One, not to an older Patchman.
`SHA256SUMS.txt` checks the packaged files; the ZIP also has a separate SHA-256
file beside it. `manifest.json` records the version and component hashes.
