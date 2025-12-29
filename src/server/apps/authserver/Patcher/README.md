# In-Client Patching System for AzerothCore 3.3.5a

A complete implementation of the WoW client patching system using the XFER protocol.
This allows the authserver to automatically send patch files (MPQ) to clients with outdated builds.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Server-Side Components](#server-side-components)
4. [Client-Side Components](#client-side-components)
5. [Tools](#tools)
6. [Installation](#installation)
7. [Configuration](#configuration)
8. [Usage](#usage)
9. [Troubleshooting](#troubleshooting)
10. [Technical Details](#technical-details)

---

## Overview

### How It Works

```
┌─────────────┐     1. Login (build 12340)      ┌─────────────┐
│  WoW Client │ ────────────────────────────────▶│  AuthServer │
│  (outdated) │                                  │             │
│             │◀──────────────────────────────── │  MinBuild:  │
│             │     2. XFER_INITIATE             │   12341     │
│             │        (patch available)         │             │
│             │                                  │             │
│             │     3. XFER_ACCEPT               │             │
│             │ ────────────────────────────────▶│             │
│             │                                  │             │
│             │◀──────────────────────────────── │             │
│             │     4. XFER_DATA (chunks)        │             │
│             │        [65KB per chunk]          │             │
│             │                                  │             │
│             │     5. Transfer complete         │             │
│             │        Client restarts           │             │
└─────────────┘                                  └─────────────┘
       │
       │  6. Client executes prepatch.lst
       │     - Extracts installer.exe
       │     - Runs installer.exe
       ▼
┌─────────────┐
│  Installer  │  7. installer.exe:
│             │     - Creates backup of WoW.exe
│             │     - Patches WoW.exe (build 12340 → 12341)
│             │     - Installs content patch to Data/<locale>/
│             │     - Clears cache
│             │     - Shows progress bar
│             │     - Rollback on failure
└─────────────┘
       │
       ▼
┌─────────────┐
│  WoW Client │  8. Client reconnects with build 12341
│  (patched)  │     → Accepted by server
└─────────────┘
```

### Features

- **Automatic patch delivery** via XFER protocol
- **Multi-locale support** (frFR, enUS, enGB, deDE, esES, esMX, ruRU, zhCN, zhTW, koKR, ptBR, itIT)
- **High-speed transfer** (up to 65KB chunks, configurable interval)
- **Content patch installation** to Data/<locale>/ folder
- **Progress bar** with visual feedback
- **Automatic rollback** on failure
- **MD5 verification** of content patches
- **Cache clearing** to avoid stale data
- **Concurrent downloads** for multiple players

---

## Architecture

### File Structure

```
azerothcore/
├── src/server/apps/authserver/
│   ├── Patcher/
│   │   ├── PatchMgr.h          # Patch manager header
│   │   ├── PatchMgr.cpp        # Patch manager implementation
│   │   ├── AuthSession_patch.cpp  # Code snippets for AuthSession
│   │   └── README.md           # This documentation
│   ├── Server/
│   │   ├── AuthSession.h       # Modified: added patch members
│   │   └── AuthSession.cpp     # Modified: XFER handlers
│   └── Main.cpp                # Modified: PatchMgr initialization
│
├── tools/
│   ├── deploy_patch.py         # One-command deployment script
│   ├── create_patch_mpq.py     # MPQ generation script
│   └── patch_installer/
│       ├── installer.c         # Native Windows installer
│       ├── build.bat           # Compilation script
│       └── installer.exe       # Compiled installer
│
├── ClientPatches/              # Patch files directory
│   ├── frFR12340.mpq          # French patch
│   ├── enUS12340.mpq          # US English patch
│   ├── enGB12340.mpq          # GB English patch
│   └── ...                     # Other locales
│
└── env/dist/etc/
    └── authserver.conf         # Server configuration
```

### MPQ Patch Structure

Each patch MPQ (`{locale}{build}.mpq`) contains:

| File | Description |
|------|-------------|
| `prepatch.lst` | Commands for the client to execute |
| `patch.cfg` | Build configuration (OLD_BUILD, NEW_BUILD) |
| `installer.exe` | Native Windows installer (~39KB) |
| `content-patch.mpq` | (Optional) Content patch to install |
| `content-patch.md5` | (Optional) MD5 hash for verification |

### prepatch.lst Format

```
extract patch.cfg
extract content-patch.mpq
extract content-patch.md5
extract installer.exe
execute installer.exe
```

Commands available:
- `extract <filename>` - Extract file from MPQ to game directory
- `execute <filename>` - Execute an extracted file
- `delete <filename>` - Delete a file

---

## Server-Side Components

### PatchMgr (Singleton)

Manages all patch operations:

```cpp
class PatchMgr
{
public:
    void Initialize();                    // Load patches from directory
    void UpdateJobs();                    // Process pending transfers

    PatchInfo* GetPatchForClient(uint16 build, const std::string& locale);
    void HandleXferAccept(AuthSession* session);
    void HandleXferResume(AuthSession* session, uint64 offset);
    void HandleXferCancel(AuthSession* session);
};

#define sPatchMgr PatchMgr::Instance()
```

### PatchInfo Structure

```cpp
struct PatchInfo
{
    std::string FilePath;       // Full path to MPQ file
    std::string FileName;       // Filename only
    std::string Locale;         // Client locale (frFR, enUS, etc.)
    uint16 Build;               // Target build number
    uint64 FileSize;            // Size in bytes
    std::array<uint8, 16> MD5;  // MD5 hash
};
```

### PatchJob Structure

```cpp
struct PatchJob
{
    AuthSession* Session;       // Client session
    PatchInfo* Patch;           // Patch being sent
    std::ifstream FileStream;   // Open file handle
    uint64 BytesSent;           // Progress tracking
    int LastLoggedProgress;     // For logging (avoid spam)
};
```

---

## Client-Side Components

### installer.exe

A lightweight Windows executable (~39KB) compiled with MinGW-w64:

**Features:**
- Patches WoW.exe build number (12340 → 12341)
- Creates automatic backup (WoW.exe.backup)
- Installs content patch to `Data/<locale>/patch-<locale>-X.MPQ`
- Verifies content patch integrity via MD5
- Clears WoW cache folder
- Shows progress bar during installation
- Automatic rollback on failure
- Cleans up temporary files

**Build Requirements:**
- MinGW-w64 (x86_64-w64-mingw32-gcc)
- Windows target

### Client Patch (Required)

The WoW client must be patched to accept unsigned MPQs. This involves patching `SFileAuthenticateArchiveEx()` in Storm.dll to always return success.

**Patch locations for WoW 3.3.5a (12340):**

| File | Offset | Original | Patched |
|------|--------|----------|---------|
| Storm.dll | 0x1B4E6 | 74 | EB |

This changes a conditional jump (JE) to unconditional jump (JMP), bypassing signature verification.

---

## Tools

### deploy_patch.py

One-command deployment script:

```bash
# Full deployment (compile + generate all locales)
python tools/deploy_patch.py --content-patch ClientPatches/my-patch.mpq

# Skip compilation (use existing installer)
python tools/deploy_patch.py --skip-compile --content-patch my-patch.mpq

# Custom build numbers
python tools/deploy_patch.py --content-patch my-patch.mpq --build 12341 --new-build 12342
```

**Options:**
| Option | Description | Default |
|--------|-------------|---------|
| `--content-patch, -p` | Content patch MPQ to include | None |
| `--output-dir, -o` | Output directory for MPQs | ClientPatches |
| `--build, -b` | Build to patch FROM | 12340 |
| `--new-build, -n` | Build to patch TO | build+1 |
| `--skip-compile, -s` | Skip installer compilation | False |

### create_patch_mpq.py

Lower-level MPQ creation script:

```bash
# Single locale
python tools/create_patch_mpq.py -i installer.exe -l frFR

# All locales
python tools/create_patch_mpq.py -i installer.exe --all-locales

# With content patch
python tools/create_patch_mpq.py -i installer.exe -p content.mpq --all-locales
```

**Requirements:**
- Python 3.8+
- MPQEditor.exe (from http://www.zezula.net/en/mpq/download.html)

---

## Installation

### Step 1: Apply Code Changes to AuthSession

**AuthSession.h** - Add member variables:

```cpp
// After existing members:
PatchInfo* _pendingPatch = nullptr;

// Add destructor declaration if not present:
~AuthSession();
```

**AuthSession.cpp** - Add XFER handlers in `InitHandlers()`:

```cpp
// After REALM_LIST handler:
handlers[XFER_ACCEPT] = { STATUS_XFER, 1, &AuthSession::HandleXferAccept };
handlers[XFER_RESUME] = { STATUS_XFER, 9, &AuthSession::HandleXferResume };
handlers[XFER_CANCEL] = { STATUS_XFER, 1, &AuthSession::HandleXferCancel };
```

**AuthSession.cpp** - Add destructor:

```cpp
AuthSession::~AuthSession()
{
    if (_pendingPatch)
    {
        sPatchMgr->HandleXferCancel(this);
        _pendingPatch = nullptr;
    }
}
```

**AuthSession.cpp** - Modify `HandleLogonProof()`:

Replace:
```cpp
if (_expversion == NO_VALID_EXP_FLAG)
{
    LOG_DEBUG("network", "Client with invalid version, patching is not implemented");
    return false;
}
```

With:
```cpp
if (_expversion == NO_VALID_EXP_FLAG)
{
    if (CheckAndInitiatePatch())
    {
        return true;
    }
    LOG_DEBUG("network", "Client with invalid version, patching not available");
    return false;
}
```

See `AuthSession_patch.cpp` for complete handler implementations.

### Step 2: Initialize PatchMgr in Main.cpp

```cpp
#include "PatchMgr.h"

// In main(), after config loading:
if (sConfigMgr->GetOption<bool>("Patching.Enabled", false))
{
    sPatchMgr->Initialize();
}

// In the main loop, add update timer:
int32 patchJobsInterval = sConfigMgr->GetOption<int32>("Patching.UpdateInterval", 10);
Acore::Asio::DeadlineTimer patchJobsTimer(*ioContext);
patchJobsTimer.expires_from_now(boost::posix_time::milliseconds(patchJobsInterval));
patchJobsTimer.async_wait([&](const boost::system::error_code&) {
    if (sConfigMgr->GetOption<bool>("Patching.Enabled", false))
    {
        sPatchMgr->UpdateJobs();
    }
    // Reschedule...
});
```

### Step 3: Compile Installer

```bash
cd tools/patch_installer
build.bat
```

Requires MinGW-w64. Output: `installer.exe` (~39KB)

### Step 4: Generate Patch MPQs

```bash
python tools/deploy_patch.py --content-patch your-content-patch.mpq
```

### Step 5: Configure AuthServer

Add to `authserver.conf`:

```ini
###################################################################################################
# CLIENT PATCHING
###################################################################################################

#    Patching.Enabled
#        Enable the client patching system.
#        Default: 0
Patching.Enabled = 1

#    Patching.MinBuild
#        Minimum build required. Clients below this will be patched.
#        Default: 12340
Patching.MinBuild = 12341

#    Patching.Directory
#        Directory containing patch MPQ files.
#        Default: "ClientPatches"
Patching.Directory = "ClientPatches"

#    Patching.ChunkSize
#        Bytes per XFER_DATA packet (max 65535).
#        Default: 65535
Patching.ChunkSize = 65535

#    Patching.UpdateInterval
#        Milliseconds between chunk sends (1-1000).
#        Lower = faster transfer, more CPU.
#        Default: 10
Patching.UpdateInterval = 10
```

---

## Configuration

### Transfer Speed Optimization

| ChunkSize | UpdateInterval | Speed | Use Case |
|-----------|----------------|-------|----------|
| 1500 | 50ms | ~30 KB/s | Slow connections |
| 65535 | 50ms | ~1.3 MB/s | Default |
| 65535 | 10ms | ~6.4 MB/s | Fast LAN |
| 65535 | 1ms | ~64 MB/s | Maximum (CPU intensive) |

**Transfer time for 100MB patch:**

| Settings | Time |
|----------|------|
| 1500/50ms | ~55 minutes |
| 65535/50ms | ~1.3 minutes |
| 65535/10ms | ~16 seconds |

### Build Number Strategy

The build number acts as a version:
- **12340** = Vanilla WotLK 3.3.5a
- **12341** = Your content patch v1
- **12342** = Your content patch v2
- etc.

When updating content:
1. Create new patch MPQ for the new version
2. Update `Patching.MinBuild` to the new build
3. Players with old build will be patched automatically

---

## Usage

### Deploying a New Patch

```bash
# 1. Build everything and generate MPQs for all locales
python tools/deploy_patch.py --content-patch my-new-content.mpq --build 12341 --new-build 12342

# 2. Copy MPQs to server
cp ClientPatches/*.mpq /path/to/server/ClientPatches/

# 3. Update authserver.conf
# Patching.MinBuild = 12342

# 4. Restart authserver
```

### Testing

1. Ensure `Patching.Enabled = 1`
2. Set `Patching.MinBuild` higher than client build
3. Connect with WoW client
4. Watch authserver logs for transfer progress
5. Client should download patch, restart, and reconnect

---

## Troubleshooting

### Patch Not Offered

| Symptom | Cause | Solution |
|---------|-------|----------|
| No XFER_INITIATE | Patching disabled | Set `Patching.Enabled = 1` |
| No XFER_INITIATE | Client build >= MinBuild | Lower MinBuild or use older client |
| No XFER_INITIATE | No matching patch file | Check locale/build in filename |
| No XFER_INITIATE | Patch directory wrong | Check `Patching.Directory` path |

### Transfer Fails

| Symptom | Cause | Solution |
|---------|-------|----------|
| Transfer stops | Client disconnected | Check network, increase timeout |
| Transfer slow | Low chunk size | Increase `Patching.ChunkSize` |
| File not found | Permissions issue | Check file permissions |

### Client Doesn't Apply Patch

| Symptom | Cause | Solution |
|---------|-------|----------|
| Error on restart | Client not patched | Apply Storm.dll patch |
| prepatch.lst error | Wrong line endings | Use CRLF (Windows) |
| installer.exe fails | Missing MinGW runtime | Compile with `-static` flag |

### Installer Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| "WoW.exe not found" | Wrong working directory | Run from WoW folder |
| "Build pattern not found" | Wrong WoW version | Use 3.3.5a 12340 |
| MD5 mismatch | Corrupted download | Re-download patch |

---

## Technical Details

### XFER Protocol

| Opcode | Direction | Description |
|--------|-----------|-------------|
| XFER_INITIATE (0x30) | S→C | Start transfer (filename, size, MD5) |
| XFER_DATA (0x31) | S→C | Data chunk |
| XFER_ACCEPT (0x32) | C→S | Client accepts transfer |
| XFER_RESUME (0x33) | C→S | Resume from offset |
| XFER_CANCEL (0x34) | C→S | Cancel transfer |

### XFER_INITIATE Packet

```cpp
struct XFER_INITIATE
{
    uint8 opcode;           // 0x30
    uint8 fileType;         // 'P' for patch
    uint64 fileSize;        // Total size in bytes
    uint8 md5[16];          // MD5 hash
    char filename[];        // Null-terminated filename
};
```

### WoW.exe Build Patch

The installer patches the build number in WoW.exe:

```
Offset: Variable (searched by pattern)
Pattern: 34 30 33 32 31 (ASCII "12340" reversed as "04321")

Original: 34 30 33 32 31  (12340)
Patched:  31 34 33 32 31  (12341)
```

### Content Patch Naming

Content patches are installed to `Data/<locale>/` with the naming format:

```
patch-<locale>-<number>.MPQ
```

Example: `patch-frFR-4.MPQ`

The installer finds the next available number automatically.

---

## Security Considerations

1. **Client Patch Required**: Disabling signature verification is required
2. **Trust**: Only distribute patches from trusted sources
3. **Network**: XFER protocol is not encrypted
4. **Backup**: Installer creates backup before patching
5. **Rollback**: Automatic rollback on failure

---

## References

- [Blizzard Patching Documentation (stoneharry)](https://github.com/stoneharry/Blizzard-Patching)
- [MPQEditor (Ladik)](http://www.zezula.net/en/mpq/download.html)
- [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk)
- [WoW Modding Wiki](https://wowdev.wiki/)

---

## License

This implementation is provided for educational purposes and private server use.
WoW and related content are trademarks of Blizzard Entertainment.
