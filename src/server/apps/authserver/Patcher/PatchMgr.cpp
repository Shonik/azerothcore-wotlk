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

#include "PatchMgr.h"
#include "AuthSession.h"
#include "Config.h"
#include "Log.h"
#include <filesystem>
#include <regex>
#include <algorithm>
#include <cstring>

namespace fs = std::filesystem;

// XFER command opcodes
enum XferCmd
{
    XFER_INITIATE   = 0x30,
    XFER_DATA       = 0x31,
    XFER_ACCEPT     = 0x32,
    XFER_RESUME     = 0x33,
    XFER_CANCEL     = 0x34
};

PatchMgr* PatchMgr::Instance()
{
    static PatchMgr instance;
    return &instance;
}

PatchMgr::PatchMgr()
    : _minBuild(12340)      // Default to 3.3.5a build
    , _enabled(false)
    , _patchDir("ClientPatches")
    , _chunkSize(1500)      // Default chunk size
{
}

PatchMgr::~PatchMgr()
{
    std::lock_guard<std::mutex> lock(_jobsMutex);
    _jobs.clear();
    _patches.clear();
}

void PatchMgr::Initialize()
{
    _enabled = sConfigMgr->GetOption<bool>("Patching.Enabled", false);
    _minBuild = sConfigMgr->GetOption<uint32>("Patching.MinBuild", 12340);
    _patchDir = sConfigMgr->GetOption<std::string>("Patching.Directory", "ClientPatches");
    _chunkSize = sConfigMgr->GetOption<uint32>("Patching.ChunkSize", 1500);

    if (_chunkSize < 100)
        _chunkSize = 100;
    if (_chunkSize > 65535)
        _chunkSize = 65535;

    if (_enabled)
    {
        LOG_INFO("server.authserver", "");
        LOG_INFO("server.authserver", "========================================");
        LOG_INFO("server.authserver", "  Client Patching System Enabled");
        LOG_INFO("server.authserver", "  Min Build: {}", _minBuild);
        LOG_INFO("server.authserver", "  Patch Directory: {}", _patchDir);
        LOG_INFO("server.authserver", "  Chunk Size: {} bytes", _chunkSize);
        LOG_INFO("server.authserver", "========================================");
        LOG_INFO("server.authserver", "");

        LoadPatches();
    }
    else
    {
        LOG_INFO("server.authserver", "Client Patching System is disabled");
    }
}

void PatchMgr::LoadPatches()
{
    _patches.clear();

    if (!fs::exists(_patchDir))
    {
        LOG_WARN("server.authserver", "Patch directory '{}' does not exist, creating it...", _patchDir);
        fs::create_directories(_patchDir);
        return;
    }

    // Regex pattern: LocaleBuild.mpq (e.g., enGB12340.mpq, frFR12340.mpq)
    std::regex patchPattern("([a-zA-Z]{4})(\\d+)\\.mpq", std::regex::icase);

    LOG_INFO("server.authserver", "Loading patches from '{}'...", _patchDir);

    uint32 count = 0;
    for (const auto& entry : fs::directory_iterator(_patchDir))
    {
        if (!entry.is_regular_file())
            continue;

        std::string filename = entry.path().filename().string();
        std::smatch match;

        if (!std::regex_match(filename, match, patchPattern))
        {
            LOG_DEBUG("server.authserver", "Skipping non-patch file: {}", filename);
            continue;
        }

        auto patch = std::make_unique<PatchInfo>();
        patch->Locale = match[1].str();
        patch->Build = std::stoul(match[2].str());
        patch->FilePath = entry.path().string();
        patch->FileSize = fs::file_size(entry.path());
        patch->DataLoaded = false;

        // Convert locale to lowercase for comparison
        std::transform(patch->Locale.begin(), patch->Locale.end(), patch->Locale.begin(), ::tolower);

        // Calculate MD5
        if (!CalculateMD5(patch->FilePath, patch->MD5))
        {
            LOG_ERROR("server.authserver", "Failed to calculate MD5 for patch: {}", filename);
            continue;
        }

        LOG_INFO("server.authserver", "  Loaded patch: {} (Build: {}, Locale: {}, Size: {} bytes)",
            filename, patch->Build, patch->Locale, patch->FileSize);

        _patches.push_back(std::move(patch));
        count++;
    }

    LOG_INFO("server.authserver", "Loaded {} patch(es)", count);
}

bool PatchMgr::CalculateMD5(std::string const& filepath, Acore::Crypto::MD5::Digest& outMD5)
{
    std::ifstream file(filepath, std::ios::binary);
    if (!file)
        return false;

    Acore::Crypto::MD5 md5;

    char buffer[8192];
    while (file.read(buffer, sizeof(buffer)) || file.gcount() > 0)
    {
        md5.UpdateData(reinterpret_cast<uint8*>(buffer), file.gcount());
    }

    md5.Finalize();
    outMD5 = md5.GetDigest();

    return true;
}

PatchInfo* PatchMgr::FindPatchForClient(uint32 build, std::string const& locale)
{
    if (!_enabled || _patches.empty())
        return nullptr;

    // Convert locale to lowercase for comparison
    std::string localeLower = locale;
    std::transform(localeLower.begin(), localeLower.end(), localeLower.begin(), ::tolower);

    PatchInfo* fallback = nullptr;

    for (auto& patch : _patches)
    {
        if (patch->Locale == localeLower)
        {
            // Exact build match
            if (patch->Build == build)
            {
                LOG_DEBUG("server.authserver", "Found exact patch match for build {} locale {}", build, locale);
                return patch.get();
            }

            // Fallback patch (build 0 means any build for this locale)
            if (patch->Build == 0 && !fallback)
            {
                fallback = patch.get();
            }
        }
    }

    if (fallback)
    {
        LOG_DEBUG("server.authserver", "Using fallback patch for locale {}", locale);
    }

    return fallback;
}

bool PatchMgr::InitiatePatch(AuthSession* session, PatchInfo* patch)
{
    if (!session || !patch)
        return false;

    LOG_INFO("server.authserver", "Initiating patch transfer to client (Size: {} bytes)", patch->FileSize);

    // Build the XFER_INITIATE packet
    TransferInitiatePacket pkt;
    pkt.Cmd = XFER_INITIATE;
    pkt.StrSize = 5;
    pkt.Name[0] = 'P';
    pkt.Name[1] = 'a';
    pkt.Name[2] = 't';
    pkt.Name[3] = 'c';
    pkt.Name[4] = 'h';
    pkt.FileSize = patch->FileSize;
    std::memcpy(pkt.MD5, patch->MD5.data(), 16);

    ByteBuffer buffer;
    buffer.resize(sizeof(pkt));
    std::memcpy(buffer.contents(), &pkt, sizeof(pkt));

    session->SendPacket(buffer);

    // Create a pending job (will be activated when client sends XFER_ACCEPT)
    std::lock_guard<std::mutex> lock(_jobsMutex);

    // Remove any existing job for this session
    RemoveJob(session);

    PatchJob job;
    job.Session = session;
    job.Patch = patch;
    job.Position = 0;
    job.Active = false;  // Will be activated on XFER_ACCEPT

    _jobs.push_back(std::move(job));

    return true;
}

bool PatchMgr::HandleXferAccept(AuthSession* session)
{
    std::lock_guard<std::mutex> lock(_jobsMutex);

    for (auto& job : _jobs)
    {
        if (job.Session == session)
        {
            LOG_DEBUG("server.authserver", "Client accepted patch transfer");

            // Open the file
            job.File.open(job.Patch->FilePath, std::ios::binary);
            if (!job.File)
            {
                LOG_ERROR("server.authserver", "Failed to open patch file: {}", job.Patch->FilePath);
                return false;
            }

            job.Position = 0;
            job.Active = true;
            return true;
        }
    }

    LOG_WARN("server.authserver", "XFER_ACCEPT received but no pending job found");
    return false;
}

bool PatchMgr::HandleXferResume(AuthSession* session, uint64 position)
{
    std::lock_guard<std::mutex> lock(_jobsMutex);

    for (auto& job : _jobs)
    {
        if (job.Session == session)
        {
            LOG_DEBUG("server.authserver", "Client resuming patch transfer from position {}", position);

            // Open the file if not already open
            if (!job.File.is_open())
            {
                job.File.open(job.Patch->FilePath, std::ios::binary);
                if (!job.File)
                {
                    LOG_ERROR("server.authserver", "Failed to open patch file: {}", job.Patch->FilePath);
                    return false;
                }
            }

            // Seek to the requested position
            job.File.seekg(position);
            if (job.File.fail())
            {
                LOG_ERROR("server.authserver", "Failed to seek in patch file to position {}", position);
                return false;
            }

            job.Position = position;
            job.Active = true;
            return true;
        }
    }

    LOG_WARN("server.authserver", "XFER_RESUME received but no pending job found");
    return false;
}

bool PatchMgr::HandleXferCancel(AuthSession* session)
{
    std::lock_guard<std::mutex> lock(_jobsMutex);

    LOG_DEBUG("server.authserver", "Client canceled patch transfer");
    RemoveJob(session);
    return true;
}

void PatchMgr::RemoveJob(AuthSession* session)
{
    // Note: Assumes _jobsMutex is already locked
    _jobs.erase(
        std::remove_if(_jobs.begin(), _jobs.end(),
            [session](PatchJob& job) {
                if (job.Session == session)
                {
                    if (job.File.is_open())
                        job.File.close();
                    return true;
                }
                return false;
            }),
        _jobs.end());
}

void PatchMgr::UpdateJobs()
{
    if (!_enabled)
        return;

    std::lock_guard<std::mutex> lock(_jobsMutex);

    for (auto& job : _jobs)
    {
        if (!job.Active || !job.File.is_open())
            continue;

        // Send one chunk per update
        SendPatchChunk(job);
    }

    // Remove completed jobs
    _jobs.erase(
        std::remove_if(_jobs.begin(), _jobs.end(),
            [](PatchJob& job) {
                if (job.Position >= job.Patch->FileSize)
                {
                    LOG_INFO("server.authserver", "Patch transfer completed");
                    if (job.File.is_open())
                        job.File.close();
                    return true;
                }
                return false;
            }),
        _jobs.end());
}

void PatchMgr::SendPatchChunk(PatchJob& job)
{
    if (!job.Session || !job.Patch)
        return;

    uint64 remaining = job.Patch->FileSize - job.Position;
    uint16 chunkSize = static_cast<uint16>(std::min(static_cast<uint64>(_chunkSize), remaining));

    if (chunkSize == 0)
        return;

    // Read the chunk
    std::vector<uint8> chunkData(chunkSize);
    job.File.read(reinterpret_cast<char*>(chunkData.data()), chunkSize);

    if (job.File.fail() && !job.File.eof())
    {
        LOG_ERROR("server.authserver", "Failed to read patch chunk at position {}", job.Position);
        job.Active = false;
        return;
    }

    // Build the XFER_DATA packet
    ByteBuffer packet;
    packet << uint8(XFER_DATA);
    packet << uint16(chunkSize);
    packet.append(chunkData.data(), chunkSize);

    job.Session->SendPacket(packet);
    job.Position += chunkSize;

    // Log progress every 10%
    uint32 progress = static_cast<uint32>((job.Position * 100) / job.Patch->FileSize);
    
    if (progress / 10 > job.LastLoggedProgress / 10)
    {
        LOG_INFO("server.authserver", "[Patch] {} - {}% ({}/{} bytes)", job.Patch->FilePath, progress, job.Position, job.Patch->FileSize);
        job.LastLoggedProgress = progress;
    }
}
