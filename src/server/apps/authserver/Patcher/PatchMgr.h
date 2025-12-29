/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef __PATCHMGR_H__
#define __PATCHMGR_H__

#include "Common.h"
#include "CryptoHash.h"
#include <mutex>
#include <vector>
#include <memory>
#include <fstream>

class AuthSession;

// Patch information structure
struct PatchInfo
{
    uint32 Build;                              // Client build this patch is for
    std::string Locale;                        // Locale (e.g., "enGB", "frFR")
    uint64 FileSize;                           // Size of the patch file
    Acore::Crypto::MD5::Digest MD5;            // MD5 hash of the patch
    std::string FilePath;                      // Full path to the patch file
    std::unique_ptr<uint8[]> Data;             // Cached patch data (optional)
    bool DataLoaded;                           // Whether data is loaded into memory

    PatchInfo() : Build(0), FileSize(0), DataLoaded(false) {}
};

// Active patch transfer job
struct PatchJob
{
    AuthSession* Session;                      // Session receiving the patch
    PatchInfo* Patch;                          // Patch being sent
    std::ifstream File;                        // File stream for reading
    uint64 Position;                           // Current position in file
    bool Active;                               // Whether job is active
    uint32 LastLoggedProgress;                 // Last progress % logged (for 10% increments)

    PatchJob() : Session(nullptr), Patch(nullptr), Position(0), Active(false), LastLoggedProgress(0) {}
};

// Transfer initiate packet structure
#pragma pack(push, 1)
struct TransferInitiatePacket
{
    uint8 Cmd;
    uint8 StrSize;
    char Name[5];                              // "Patch"
    uint64 FileSize;
    uint8 MD5[16];
};
#pragma pack(pop)

// Transfer data packet header
#pragma pack(push, 1)
struct TransferDataPacket
{
    uint8 Cmd;
    uint16 ChunkSize;
    // Followed by chunk data
};
#pragma pack(pop)

class PatchMgr
{
public:
    static PatchMgr* Instance();

    // Initialize the patch manager
    void Initialize();

    // Load patches from the ClientPatches directory
    void LoadPatches();

    // Find a patch for a specific client build and locale
    PatchInfo* FindPatchForClient(uint32 build, std::string const& locale);

    // Start a patch transfer to a client
    bool InitiatePatch(AuthSession* session, PatchInfo* patch);

    // Handle client accepting the patch
    bool HandleXferAccept(AuthSession* session);

    // Handle client resuming a patch transfer
    bool HandleXferResume(AuthSession* session, uint64 position);

    // Handle client canceling the patch transfer
    bool HandleXferCancel(AuthSession* session);

    // Update all active patch jobs (called from main loop)
    void UpdateJobs();

    // Get the minimum required build
    uint32 GetMinBuild() const { return _minBuild; }

    // Set the minimum required build
    void SetMinBuild(uint32 build) { _minBuild = build; }

    // Check if patching is enabled
    bool IsEnabled() const { return _enabled; }

    // Enable/disable patching
    void SetEnabled(bool enabled) { _enabled = enabled; }

private:
    PatchMgr();
    ~PatchMgr();

    // Calculate MD5 hash of a file
    bool CalculateMD5(std::string const& filepath, Acore::Crypto::MD5::Digest& outMD5);

    // Send a chunk of patch data
    void SendPatchChunk(PatchJob& job);

    // Remove a job for a session
    void RemoveJob(AuthSession* session);

    std::vector<std::unique_ptr<PatchInfo>> _patches;
    std::vector<PatchJob> _jobs;
    std::mutex _jobsMutex;

    uint32 _minBuild;
    bool _enabled;
    std::string _patchDir;
    uint32 _chunkSize;                         // Size of each chunk to send (default 1500)
};

#define sPatchMgr PatchMgr::Instance()

#endif // __PATCHMGR_H__
