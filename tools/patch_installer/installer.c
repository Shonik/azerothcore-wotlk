/*
 * WoW Patch Installer
 *
 * This installer is extracted and executed by the WoW client
 * after downloading a patch via the XFER protocol.
 *
 * It performs the following tasks:
 * 1. Waits for WoW.exe to close (if still running)
 * 2. Patches the build number in WoW.exe to allow connection
 * 3. Cleans up wow-patch.mpq
 * 4. Restarts WoW.exe
 */

#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <tlhelp32.h>
#include <commctrl.h>

// Link with comctl32 for progress bar
#pragma comment(lib, "comctl32.lib")

#define WOW_PROCESS_NAME "Wow.exe"
#define PATCH_FILE "wow-patch.mpq"
#define LOG_FILE "patch_install.log"
#define CONTENT_PATCH_FILE "content-patch.mpq"

// Build number configuration
// The build number is stored as a 16-bit (uint16) little-endian integer at this offset
#define BUILD_NUMBER_OFFSET 0x4C99F0

// Config file extracted from the MPQ
#define CONFIG_FILE "patch.cfg"

// Default values (used if config file is missing)
#define DEFAULT_OLD_BUILD 12340
#define DEFAULT_NEW_BUILD 12341

// Display string offsets - ASCII "12340" shown in the UI
// These are the locations where the build number is displayed as text
static const DWORD DISPLAY_STRING_OFFSETS[] = {
    0x005F3A00,  // Login screen: "Jun 24 2010.12340"
    0x005E1231,  // "World of WarCraft (build 12340)"
    0x0062F3EC,  // "WoW [Release] Build 12340"
    0x00636F58,  // "WoW [Release] Build 12340"
};
#define DISPLAY_STRING_COUNT (sizeof(DISPLAY_STRING_OFFSETS) / sizeof(DISPLAY_STRING_OFFSETS[0]))

// MD5 hash file for content patch verification
#define CONTENT_PATCH_MD5_FILE "content-patch.md5"

// ============================================
// GLOBAL VARIABLES
// ============================================

FILE* g_logFile = NULL;
HWND g_hProgressDlg = NULL;
HWND g_hProgressBar = NULL;
HWND g_hStatusText = NULL;
BOOL g_patchSuccess = FALSE;

// Forward declarations
BOOL FileExists(const char* filename);

// ============================================
// LOGGING
// ============================================

void Log(const char* format, ...) {
    va_list args;
    va_start(args, format);

    if (g_logFile) {
        vfprintf(g_logFile, format, args);
        fprintf(g_logFile, "\n");
        fflush(g_logFile);
    }

    va_end(args);
}

// ============================================
// PROGRESS WINDOW
// ============================================

#define ID_PROGRESS_BAR 101
#define ID_STATUS_TEXT 102
#define PROGRESS_STEPS 7

LRESULT CALLBACK ProgressWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
        case WM_CREATE:
            return 0;
        case WM_CLOSE:
            // Prevent closing during installation
            return 0;
        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;
    }
    return DefWindowProcA(hwnd, msg, wParam, lParam);
}

HWND CreateProgressWindow(HINSTANCE hInstance) {
    // Initialize common controls
    INITCOMMONCONTROLSEX icex;
    icex.dwSize = sizeof(INITCOMMONCONTROLSEX);
    icex.dwICC = ICC_PROGRESS_CLASS;
    InitCommonControlsEx(&icex);

    // Register window class
    WNDCLASSEXA wc = {0};
    wc.cbSize = sizeof(WNDCLASSEXA);
    wc.lpfnWndProc = ProgressWndProc;
    wc.hInstance = hInstance;
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wc.lpszClassName = "WoWPatchProgress";
    RegisterClassExA(&wc);

    // Create main window
    int width = 400;
    int height = 130;
    int x = (GetSystemMetrics(SM_CXSCREEN) - width) / 2;
    int y = (GetSystemMetrics(SM_CYSCREEN) - height) / 2;

    HWND hwnd = CreateWindowExA(
        WS_EX_TOPMOST,
        "WoWPatchProgress",
        "Installing WoW Patch...",
        WS_POPUP | WS_CAPTION | WS_VISIBLE,
        x, y, width, height,
        NULL, NULL, hInstance, NULL
    );

    // Create status text
    g_hStatusText = CreateWindowExA(
        0, "STATIC", "Initializing...",
        WS_CHILD | WS_VISIBLE | SS_LEFT,
        20, 20, 360, 20,
        hwnd, (HMENU)ID_STATUS_TEXT, hInstance, NULL
    );

    // Create progress bar
    g_hProgressBar = CreateWindowExA(
        0, PROGRESS_CLASSA, NULL,
        WS_CHILD | WS_VISIBLE | PBS_SMOOTH,
        20, 50, 360, 25,
        hwnd, (HMENU)ID_PROGRESS_BAR, hInstance, NULL
    );

    // Set progress range (0-100)
    SendMessage(g_hProgressBar, PBM_SETRANGE, 0, MAKELPARAM(0, 100));
    SendMessage(g_hProgressBar, PBM_SETSTEP, 1, 0);

    return hwnd;
}

void UpdateProgress(int percent, const char* status) {
    if (g_hProgressBar) {
        SendMessage(g_hProgressBar, PBM_SETPOS, percent, 0);
    }
    if (g_hStatusText && status) {
        SetWindowTextA(g_hStatusText, status);
    }
    // Process messages to update UI
    MSG msg;
    while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
}

void CloseProgressWindow(void) {
    if (g_hProgressDlg) {
        DestroyWindow(g_hProgressDlg);
        g_hProgressDlg = NULL;
    }
}

// ============================================
// MD5 IMPLEMENTATION (Simple)
// ============================================

typedef struct {
    DWORD state[4];
    DWORD count[2];
    unsigned char buffer[64];
} MD5_CTX;

static void MD5Transform(DWORD state[4], const unsigned char block[64]);

static unsigned char PADDING[64] = {
    0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};

#define F(x, y, z) (((x) & (y)) | ((~x) & (z)))
#define G(x, y, z) (((x) & (z)) | ((y) & (~z)))
#define H(x, y, z) ((x) ^ (y) ^ (z))
#define I(x, y, z) ((y) ^ ((x) | (~z)))

#define ROTATE_LEFT(x, n) (((x) << (n)) | ((x) >> (32-(n))))

#define FF(a, b, c, d, x, s, ac) { \
    (a) += F((b), (c), (d)) + (x) + (DWORD)(ac); \
    (a) = ROTATE_LEFT((a), (s)); \
    (a) += (b); \
}
#define GG(a, b, c, d, x, s, ac) { \
    (a) += G((b), (c), (d)) + (x) + (DWORD)(ac); \
    (a) = ROTATE_LEFT((a), (s)); \
    (a) += (b); \
}
#define HH(a, b, c, d, x, s, ac) { \
    (a) += H((b), (c), (d)) + (x) + (DWORD)(ac); \
    (a) = ROTATE_LEFT((a), (s)); \
    (a) += (b); \
}
#define II(a, b, c, d, x, s, ac) { \
    (a) += I((b), (c), (d)) + (x) + (DWORD)(ac); \
    (a) = ROTATE_LEFT((a), (s)); \
    (a) += (b); \
}

static void MD5Init(MD5_CTX* context) {
    context->count[0] = context->count[1] = 0;
    context->state[0] = 0x67452301;
    context->state[1] = 0xefcdab89;
    context->state[2] = 0x98badcfe;
    context->state[3] = 0x10325476;
}

static void MD5Update(MD5_CTX* context, const unsigned char* input, unsigned int inputLen) {
    unsigned int i, index, partLen;
    index = (unsigned int)((context->count[0] >> 3) & 0x3F);
    if ((context->count[0] += ((DWORD)inputLen << 3)) < ((DWORD)inputLen << 3))
        context->count[1]++;
    context->count[1] += ((DWORD)inputLen >> 29);
    partLen = 64 - index;
    if (inputLen >= partLen) {
        memcpy(&context->buffer[index], input, partLen);
        MD5Transform(context->state, context->buffer);
        for (i = partLen; i + 63 < inputLen; i += 64)
            MD5Transform(context->state, &input[i]);
        index = 0;
    } else {
        i = 0;
    }
    memcpy(&context->buffer[index], &input[i], inputLen - i);
}

static void MD5Final(unsigned char digest[16], MD5_CTX* context) {
    unsigned char bits[8];
    unsigned int index, padLen;

    for (int i = 0; i < 4; i++) {
        bits[i] = (unsigned char)(context->count[0] >> (i * 8));
        bits[i + 4] = (unsigned char)(context->count[1] >> (i * 8));
    }

    index = (unsigned int)((context->count[0] >> 3) & 0x3f);
    padLen = (index < 56) ? (56 - index) : (120 - index);
    MD5Update(context, PADDING, padLen);
    MD5Update(context, bits, 8);

    for (int i = 0; i < 4; i++) {
        digest[i] = (unsigned char)(context->state[0] >> (i * 8));
        digest[i + 4] = (unsigned char)(context->state[1] >> (i * 8));
        digest[i + 8] = (unsigned char)(context->state[2] >> (i * 8));
        digest[i + 12] = (unsigned char)(context->state[3] >> (i * 8));
    }
}

static void MD5Transform(DWORD state[4], const unsigned char block[64]) {
    DWORD a = state[0], b = state[1], c = state[2], d = state[3], x[16];

    for (int i = 0, j = 0; j < 64; i++, j += 4)
        x[i] = ((DWORD)block[j]) | (((DWORD)block[j+1]) << 8) |
               (((DWORD)block[j+2]) << 16) | (((DWORD)block[j+3]) << 24);

    FF(a, b, c, d, x[ 0],  7, 0xd76aa478); FF(d, a, b, c, x[ 1], 12, 0xe8c7b756);
    FF(c, d, a, b, x[ 2], 17, 0x242070db); FF(b, c, d, a, x[ 3], 22, 0xc1bdceee);
    FF(a, b, c, d, x[ 4],  7, 0xf57c0faf); FF(d, a, b, c, x[ 5], 12, 0x4787c62a);
    FF(c, d, a, b, x[ 6], 17, 0xa8304613); FF(b, c, d, a, x[ 7], 22, 0xfd469501);
    FF(a, b, c, d, x[ 8],  7, 0x698098d8); FF(d, a, b, c, x[ 9], 12, 0x8b44f7af);
    FF(c, d, a, b, x[10], 17, 0xffff5bb1); FF(b, c, d, a, x[11], 22, 0x895cd7be);
    FF(a, b, c, d, x[12],  7, 0x6b901122); FF(d, a, b, c, x[13], 12, 0xfd987193);
    FF(c, d, a, b, x[14], 17, 0xa679438e); FF(b, c, d, a, x[15], 22, 0x49b40821);

    GG(a, b, c, d, x[ 1],  5, 0xf61e2562); GG(d, a, b, c, x[ 6],  9, 0xc040b340);
    GG(c, d, a, b, x[11], 14, 0x265e5a51); GG(b, c, d, a, x[ 0], 20, 0xe9b6c7aa);
    GG(a, b, c, d, x[ 5],  5, 0xd62f105d); GG(d, a, b, c, x[10],  9, 0x02441453);
    GG(c, d, a, b, x[15], 14, 0xd8a1e681); GG(b, c, d, a, x[ 4], 20, 0xe7d3fbc8);
    GG(a, b, c, d, x[ 9],  5, 0x21e1cde6); GG(d, a, b, c, x[14],  9, 0xc33707d6);
    GG(c, d, a, b, x[ 3], 14, 0xf4d50d87); GG(b, c, d, a, x[ 8], 20, 0x455a14ed);
    GG(a, b, c, d, x[13],  5, 0xa9e3e905); GG(d, a, b, c, x[ 2],  9, 0xfcefa3f8);
    GG(c, d, a, b, x[ 7], 14, 0x676f02d9); GG(b, c, d, a, x[12], 20, 0x8d2a4c8a);

    HH(a, b, c, d, x[ 5],  4, 0xfffa3942); HH(d, a, b, c, x[ 8], 11, 0x8771f681);
    HH(c, d, a, b, x[11], 16, 0x6d9d6122); HH(b, c, d, a, x[14], 23, 0xfde5380c);
    HH(a, b, c, d, x[ 1],  4, 0xa4beea44); HH(d, a, b, c, x[ 4], 11, 0x4bdecfa9);
    HH(c, d, a, b, x[ 7], 16, 0xf6bb4b60); HH(b, c, d, a, x[10], 23, 0xbebfbc70);
    HH(a, b, c, d, x[13],  4, 0x289b7ec6); HH(d, a, b, c, x[ 0], 11, 0xeaa127fa);
    HH(c, d, a, b, x[ 3], 16, 0xd4ef3085); HH(b, c, d, a, x[ 6], 23, 0x04881d05);
    HH(a, b, c, d, x[ 9],  4, 0xd9d4d039); HH(d, a, b, c, x[12], 11, 0xe6db99e5);
    HH(c, d, a, b, x[15], 16, 0x1fa27cf8); HH(b, c, d, a, x[ 2], 23, 0xc4ac5665);

    II(a, b, c, d, x[ 0],  6, 0xf4292244); II(d, a, b, c, x[ 7], 10, 0x432aff97);
    II(c, d, a, b, x[14], 15, 0xab9423a7); II(b, c, d, a, x[ 5], 21, 0xfc93a039);
    II(a, b, c, d, x[12],  6, 0x655b59c3); II(d, a, b, c, x[ 3], 10, 0x8f0ccc92);
    II(c, d, a, b, x[10], 15, 0xffeff47d); II(b, c, d, a, x[ 1], 21, 0x85845dd1);
    II(a, b, c, d, x[ 8],  6, 0x6fa87e4f); II(d, a, b, c, x[15], 10, 0xfe2ce6e0);
    II(c, d, a, b, x[ 6], 15, 0xa3014314); II(b, c, d, a, x[13], 21, 0x4e0811a1);
    II(a, b, c, d, x[ 4],  6, 0xf7537e82); II(d, a, b, c, x[11], 10, 0xbd3af235);
    II(c, d, a, b, x[ 2], 15, 0x2ad7d2bb); II(b, c, d, a, x[ 9], 21, 0xeb86d391);

    state[0] += a; state[1] += b; state[2] += c; state[3] += d;
}

/*
 * Calculate MD5 hash of a file
 * Returns hash as hex string (32 chars + null)
 */
BOOL CalculateFileMD5(const char* filePath, char* hashOut) {
    FILE* file = fopen(filePath, "rb");
    if (!file) {
        return FALSE;
    }

    MD5_CTX ctx;
    MD5Init(&ctx);

    unsigned char buffer[4096];
    size_t bytesRead;
    while ((bytesRead = fread(buffer, 1, sizeof(buffer), file)) > 0) {
        MD5Update(&ctx, buffer, (unsigned int)bytesRead);
    }

    fclose(file);

    unsigned char digest[16];
    MD5Final(digest, &ctx);

    // Convert to hex string
    for (int i = 0; i < 16; i++) {
        sprintf(&hashOut[i * 2], "%02x", digest[i]);
    }
    hashOut[32] = '\0';

    return TRUE;
}

/*
 * Verify content patch MD5 hash
 */
BOOL VerifyContentPatchMD5(const char* patchPath, const char* md5FilePath) {
    Log("Verifying content patch integrity...");

    // Read expected MD5 from file
    FILE* md5File = fopen(md5FilePath, "r");
    if (!md5File) {
        Log("  No MD5 file found, skipping verification");
        return TRUE;  // No MD5 file = skip verification
    }

    char expectedMD5[64] = {0};
    if (fgets(expectedMD5, sizeof(expectedMD5), md5File) == NULL) {
        fclose(md5File);
        Log("  ERROR: Could not read MD5 file");
        return FALSE;
    }
    fclose(md5File);

    // Trim whitespace/newlines
    for (int i = strlen(expectedMD5) - 1; i >= 0 && (expectedMD5[i] == '\n' || expectedMD5[i] == '\r' || expectedMD5[i] == ' '); i--) {
        expectedMD5[i] = '\0';
    }

    // Calculate actual MD5
    char actualMD5[33];
    if (!CalculateFileMD5(patchPath, actualMD5)) {
        Log("  ERROR: Could not calculate MD5 of patch file");
        return FALSE;
    }

    Log("  Expected: %s", expectedMD5);
    Log("  Actual:   %s", actualMD5);

    // Compare (case insensitive)
    if (_stricmp(expectedMD5, actualMD5) == 0) {
        Log("  MD5 verification PASSED");
        return TRUE;
    } else {
        Log("  ERROR: MD5 verification FAILED!");
        return FALSE;
    }
}

// ============================================
// ROLLBACK FUNCTIONALITY
// ============================================

static char g_backupPath[MAX_PATH] = {0};
static BOOL g_backupCreatedByUs = FALSE;

/*
 * Perform rollback - restore WoW.exe from backup
 */
BOOL PerformRollback(void) {
    Log("Performing rollback...");

    if (g_backupPath[0] == '\0') {
        Log("  No backup path recorded, cannot rollback");
        return FALSE;
    }

    if (!FileExists(g_backupPath)) {
        Log("  Backup file not found: %s", g_backupPath);
        return FALSE;
    }

    // Restore the backup
    if (CopyFileA(g_backupPath, WOW_PROCESS_NAME, FALSE)) {
        Log("  Restored WoW.exe from backup");

        // If we created the backup, delete it
        if (g_backupCreatedByUs) {
            DeleteFileA(g_backupPath);
            Log("  Removed temporary backup");
        }
        return TRUE;
    } else {
        Log("  ERROR: Failed to restore backup, error: %lu", GetLastError());
        return FALSE;
    }
}

BOOL IsProcessRunning(const char* processName) {
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        return FALSE;
    }

    PROCESSENTRY32 pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32);

    if (!Process32First(hSnapshot, &pe32)) {
        CloseHandle(hSnapshot);
        return FALSE;
    }

    BOOL found = FALSE;
    do {
        if (_stricmp(pe32.szExeFile, processName) == 0) {
            found = TRUE;
            break;
        }
    } while (Process32Next(hSnapshot, &pe32));

    CloseHandle(hSnapshot);
    return found;
}

void WaitForProcessToClose(const char* processName, int timeoutSeconds) {
    Log("Waiting for %s to close...", processName);

    int waited = 0;
    while (IsProcessRunning(processName) && waited < timeoutSeconds) {
        Sleep(1000);
        waited++;
    }

    if (waited >= timeoutSeconds) {
        Log("Timeout waiting for %s to close", processName);
    } else {
        Log("%s closed after %d seconds", processName, waited);
    }
}

BOOL DeletePatchFile(const char* filename) {
    Log("Deleting patch file: %s", filename);

    // Try multiple times in case file is still locked
    for (int i = 0; i < 5; i++) {
        if (DeleteFileA(filename)) {
            Log("Successfully deleted %s", filename);
            return TRUE;
        }
        Sleep(500);
    }

    Log("Failed to delete %s, error: %lu", filename, GetLastError());
    return FALSE;
}

/*
 * Configuration structure for patch parameters
 */
typedef struct {
    WORD oldBuild;
    WORD newBuild;
} PatchConfig;

/*
 * Read configuration from patch.cfg
 *
 * File format (simple key=value):
 *   OLD_BUILD=12340
 *   NEW_BUILD=12341
 *
 * Returns: TRUE if config was loaded, FALSE otherwise (defaults will be used)
 */
BOOL ReadConfig(const char* configPath, PatchConfig* config) {
    // Set defaults first
    config->oldBuild = DEFAULT_OLD_BUILD;
    config->newBuild = DEFAULT_NEW_BUILD;

    FILE* file = fopen(configPath, "r");
    if (!file) {
        Log("Config file %s not found, using defaults", configPath);
        return FALSE;
    }

    Log("Reading config from %s", configPath);

    char line[256];
    while (fgets(line, sizeof(line), file)) {
        // Remove newline
        char* newline = strchr(line, '\n');
        if (newline) *newline = '\0';
        char* cr = strchr(line, '\r');
        if (cr) *cr = '\0';

        // Skip empty lines and comments
        if (line[0] == '\0' || line[0] == '#' || line[0] == ';')
            continue;

        // Parse key=value
        char* equals = strchr(line, '=');
        if (!equals) continue;

        *equals = '\0';
        char* key = line;
        char* value = equals + 1;

        // Trim whitespace from key
        while (*key == ' ' || *key == '\t') key++;
        char* keyEnd = key + strlen(key) - 1;
        while (keyEnd > key && (*keyEnd == ' ' || *keyEnd == '\t')) *keyEnd-- = '\0';

        // Trim whitespace from value
        while (*value == ' ' || *value == '\t') value++;

        if (_stricmp(key, "OLD_BUILD") == 0) {
            config->oldBuild = (WORD)atoi(value);
            Log("  OLD_BUILD = %u", config->oldBuild);
        } else if (_stricmp(key, "NEW_BUILD") == 0) {
            config->newBuild = (WORD)atoi(value);
            Log("  NEW_BUILD = %u", config->newBuild);
        }
    }

    fclose(file);
    return TRUE;
}

BOOL FileExists(const char* filename) {
    DWORD attrib = GetFileAttributesA(filename);
    return (attrib != INVALID_FILE_ATTRIBUTES && !(attrib & FILE_ATTRIBUTE_DIRECTORY));
}

BOOL DirectoryExists(const char* path) {
    DWORD attrib = GetFileAttributesA(path);
    return (attrib != INVALID_FILE_ATTRIBUTES && (attrib & FILE_ATTRIBUTE_DIRECTORY));
}

/*
 * Recursively delete a directory and all its contents
 *
 * Returns: TRUE if successful, FALSE otherwise
 */
BOOL DeleteDirectoryRecursive(const char* dirPath) {
    char searchPath[MAX_PATH];
    char filePath[MAX_PATH];
    WIN32_FIND_DATAA findData;

    snprintf(searchPath, MAX_PATH, "%s\\*", dirPath);

    HANDLE hFind = FindFirstFileA(searchPath, &findData);
    if (hFind == INVALID_HANDLE_VALUE) {
        return FALSE;
    }

    do {
        // Skip . and ..
        if (strcmp(findData.cFileName, ".") == 0 || strcmp(findData.cFileName, "..") == 0) {
            continue;
        }

        snprintf(filePath, MAX_PATH, "%s\\%s", dirPath, findData.cFileName);

        if (findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            // Recursively delete subdirectory
            DeleteDirectoryRecursive(filePath);
        } else {
            // Delete file
            DeleteFileA(filePath);
        }
    } while (FindNextFileA(hFind, &findData));

    FindClose(hFind);

    // Remove the now-empty directory
    return RemoveDirectoryA(dirPath);
}

/*
 * Clear the WoW cache directory
 *
 * Returns: TRUE if cache was cleared, FALSE otherwise
 */
BOOL ClearWoWCache(void) {
    const char* cacheDir = "Cache";

    Log("Clearing WoW cache...");

    if (!DirectoryExists(cacheDir)) {
        Log("  Cache directory not found, skipping");
        return FALSE;
    }

    if (DeleteDirectoryRecursive(cacheDir)) {
        Log("  Cache cleared successfully");
        return TRUE;
    } else {
        Log("  WARNING: Failed to fully clear cache, error: %lu", GetLastError());
        return FALSE;
    }
}

/*
 * Known WoW locale codes
 */
static const char* KNOWN_LOCALES[] = {
    "frFR", "enUS", "enGB", "deDE", "esES", "esMX",
    "ruRU", "zhCN", "zhTW", "koKR", "ptBR", "itIT", NULL
};

/*
 * Detect the client locale by checking which Data/<locale> folder exists
 *
 * Returns: Pointer to static string with locale code, or NULL if not found
 */
const char* DetectClientLocale(void) {
    static char detectedLocale[8] = {0};
    char path[MAX_PATH];

    Log("Detecting client locale...");

    for (int i = 0; KNOWN_LOCALES[i] != NULL; i++) {
        snprintf(path, MAX_PATH, "Data\\%s", KNOWN_LOCALES[i]);
        if (DirectoryExists(path)) {
            strncpy(detectedLocale, KNOWN_LOCALES[i], sizeof(detectedLocale) - 1);
            Log("  Found locale: %s", detectedLocale);
            return detectedLocale;
        }
    }

    Log("  ERROR: No locale folder found!");
    return NULL;
}

/*
 * Find the next available patch-<locale>-X.MPQ filename
 *
 * WoW loads locale patches in order: patch-frFR.mpq, patch-frFR-2.MPQ, patch-frFR-3.MPQ, etc.
 * We need to find the next available number.
 *
 * Returns: The patch number to use, or -1 on error
 */
int FindNextPatchNumber(const char* localeDir, const char* locale) {
    char path[MAX_PATH];
    int patchNum = 2;  // Start at patch-<locale>-2.MPQ

    // Check up to patch-<locale>-9.MPQ
    for (; patchNum <= 9; patchNum++) {
        snprintf(path, MAX_PATH, "%s\\patch-%s-%d.MPQ", localeDir, locale, patchNum);
        if (!FileExists(path)) {
            Log("  Next available patch slot: patch-%s-%d.MPQ", locale, patchNum);
            return patchNum;
        }
        Log("  patch-%s-%d.MPQ exists, checking next...", locale, patchNum);
    }

    Log("  ERROR: All patch slots (2-9) are full!");
    return -1;
}

/*
 * Install the content patch MPQ to the appropriate Data/<locale>/ folder
 *
 * Returns: TRUE if successful, FALSE otherwise
 */
BOOL InstallContentPatch(const char* contentPatchPath) {
    Log("Installing content patch: %s", contentPatchPath);

    if (!FileExists(contentPatchPath)) {
        Log("  Content patch file not found, skipping");
        return FALSE;
    }

    // Detect locale
    const char* locale = DetectClientLocale();
    if (!locale) {
        Log("  ERROR: Could not detect client locale");
        return FALSE;
    }

    // Build destination directory path
    char localeDir[MAX_PATH];
    snprintf(localeDir, MAX_PATH, "Data\\%s", locale);

    // Find next available patch number
    int patchNum = FindNextPatchNumber(localeDir, locale);
    if (patchNum < 0) {
        Log("  ERROR: No available patch slots");
        return FALSE;
    }

    // Build destination path: patch-<locale>-<num>.MPQ
    char destPath[MAX_PATH];
    snprintf(destPath, MAX_PATH, "%s\\patch-%s-%d.MPQ", localeDir, locale, patchNum);

    Log("  Copying to: %s", destPath);

    // Copy the file
    if (!CopyFileA(contentPatchPath, destPath, FALSE)) {
        Log("  ERROR: Failed to copy file, error: %lu", GetLastError());
        return FALSE;
    }

    Log("  Content patch installed successfully!");

    // Delete the source file (cleanup)
    DeleteFileA(contentPatchPath);
    Log("  Cleaned up temporary file");

    return TRUE;
}

/*
 * Patch the build number in WoW.exe
 *
 * The build number is stored as a 16-bit (uint16) little-endian integer.
 * For WoW 3.3.5a (12340), it's at offset 0x4C99F0.
 *
 * Returns: TRUE if successful, FALSE otherwise
 */
BOOL PatchBuildNumber(const char* wowExePath, DWORD offset, WORD oldBuild, WORD newBuild) {
    Log("Patching build number in %s", wowExePath);
    Log("  Offset: 0x%08X", offset);
    Log("  Old build: %u", oldBuild);
    Log("  New build: %u", newBuild);

    // Open the file for reading and writing
    HANDLE hFile = CreateFileA(
        wowExePath,
        GENERIC_READ | GENERIC_WRITE,
        0,                      // No sharing
        NULL,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        NULL
    );

    if (hFile == INVALID_HANDLE_VALUE) {
        Log("ERROR: Failed to open %s, error: %lu", wowExePath, GetLastError());
        return FALSE;
    }

    // Seek to the build number offset
    DWORD newPos = SetFilePointer(hFile, offset, NULL, FILE_BEGIN);
    if (newPos == INVALID_SET_FILE_POINTER) {
        Log("ERROR: Failed to seek to offset 0x%08X, error: %lu", offset, GetLastError());
        CloseHandle(hFile);
        return FALSE;
    }

    // Read the current build number (uint16 = 2 bytes)
    WORD currentBuild = 0;
    DWORD bytesRead = 0;
    if (!ReadFile(hFile, &currentBuild, sizeof(WORD), &bytesRead, NULL) || bytesRead != sizeof(WORD)) {
        Log("ERROR: Failed to read build number, error: %lu", GetLastError());
        CloseHandle(hFile);
        return FALSE;
    }

    Log("  Current build at offset: %u", currentBuild);

    // Verify we're patching the right value
    if (currentBuild != oldBuild) {
        if (currentBuild == newBuild) {
            Log("  Build number already patched to %u, skipping", newBuild);
            CloseHandle(hFile);
            return TRUE;
        }
        Log("WARNING: Expected build %u but found %u", oldBuild, currentBuild);
        Log("  Proceeding anyway...");
    }

    // Seek back to write position
    SetFilePointer(hFile, offset, NULL, FILE_BEGIN);

    // Write the new build number (uint16 = 2 bytes only!)
    DWORD bytesWritten = 0;
    if (!WriteFile(hFile, &newBuild, sizeof(WORD), &bytesWritten, NULL) || bytesWritten != sizeof(WORD)) {
        Log("ERROR: Failed to write new build number, error: %lu", GetLastError());
        CloseHandle(hFile);
        return FALSE;
    }

    // Verify the write
    SetFilePointer(hFile, offset, NULL, FILE_BEGIN);
    WORD verifyBuild = 0;
    ReadFile(hFile, &verifyBuild, sizeof(WORD), &bytesRead, NULL);

    CloseHandle(hFile);

    if (verifyBuild == newBuild) {
        Log("  Successfully patched build number to %u", newBuild);
        return TRUE;
    } else {
        Log("ERROR: Verification failed! Expected %u but got %u", newBuild, verifyBuild);
        return FALSE;
    }
}

/*
 * Patch the display string (ASCII) in WoW.exe
 *
 * The build number is displayed as "12340" (5 ASCII characters) in the UI.
 * We replace it with "12341" (same length).
 *
 * Returns: TRUE if successful, FALSE otherwise
 */
BOOL PatchDisplayString(const char* wowExePath, DWORD offset, const char* oldStr, const char* newStr) {
    size_t len = strlen(oldStr);

    if (strlen(newStr) != len) {
        Log("ERROR: Old and new strings must have the same length");
        return FALSE;
    }

    Log("Patching display string at 0x%08X: \"%s\" -> \"%s\"", offset, oldStr, newStr);

    HANDLE hFile = CreateFileA(
        wowExePath,
        GENERIC_READ | GENERIC_WRITE,
        0,
        NULL,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        NULL
    );

    if (hFile == INVALID_HANDLE_VALUE) {
        Log("  ERROR: Failed to open file, error: %lu", GetLastError());
        return FALSE;
    }

    // Seek to offset
    if (SetFilePointer(hFile, offset, NULL, FILE_BEGIN) == INVALID_SET_FILE_POINTER) {
        Log("  ERROR: Failed to seek, error: %lu", GetLastError());
        CloseHandle(hFile);
        return FALSE;
    }

    // Read current string
    char currentStr[16] = {0};
    DWORD bytesRead = 0;
    if (!ReadFile(hFile, currentStr, (DWORD)len, &bytesRead, NULL) || bytesRead != len) {
        Log("  ERROR: Failed to read, error: %lu", GetLastError());
        CloseHandle(hFile);
        return FALSE;
    }

    // Check if already patched
    if (memcmp(currentStr, newStr, len) == 0) {
        Log("  Already patched, skipping");
        CloseHandle(hFile);
        return TRUE;
    }

    // Verify we're patching the right string
    if (memcmp(currentStr, oldStr, len) != 0) {
        Log("  WARNING: Expected \"%s\" but found \"%.*s\"", oldStr, (int)len, currentStr);
    }

    // Seek back and write new string
    SetFilePointer(hFile, offset, NULL, FILE_BEGIN);
    DWORD bytesWritten = 0;
    if (!WriteFile(hFile, newStr, (DWORD)len, &bytesWritten, NULL) || bytesWritten != len) {
        Log("  ERROR: Failed to write, error: %lu", GetLastError());
        CloseHandle(hFile);
        return FALSE;
    }

    CloseHandle(hFile);
    Log("  Successfully patched display string");
    return TRUE;
}

/*
 * Patch all display strings in WoW.exe
 */
BOOL PatchAllDisplayStrings(const char* wowExePath, WORD oldBuild, WORD newBuild) {
    char oldStr[16], newStr[16];
    snprintf(oldStr, sizeof(oldStr), "%d", oldBuild);
    snprintf(newStr, sizeof(newStr), "%d", newBuild);

    Log("Patching %d display string locations...", DISPLAY_STRING_COUNT);

    int successCount = 0;
    for (int i = 0; i < DISPLAY_STRING_COUNT; i++) {
        if (PatchDisplayString(wowExePath, DISPLAY_STRING_OFFSETS[i], oldStr, newStr)) {
            successCount++;
        }
    }

    Log("Patched %d/%d display strings", successCount, DISPLAY_STRING_COUNT);
    return successCount > 0;
}

/*
 * Create a backup of WoW.exe before patching
 */
BOOL CreateBackup(const char* wowExePath) {
    char backupPath[MAX_PATH];
    snprintf(backupPath, MAX_PATH, "%s.backup", wowExePath);

    // Check if backup already exists
    if (FileExists(backupPath)) {
        Log("Backup already exists: %s", backupPath);
        return TRUE;
    }

    Log("Creating backup: %s", backupPath);

    if (CopyFileA(wowExePath, backupPath, FALSE)) {
        Log("Backup created successfully");
        return TRUE;
    } else {
        Log("WARNING: Failed to create backup, error: %lu", GetLastError());
        return FALSE;
    }
}

void LaunchWow() {
    Log("Launching WoW.exe...");

    STARTUPINFOA si;
    PROCESS_INFORMATION pi;

    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));

    if (CreateProcessA(
        WOW_PROCESS_NAME,   // Application name
        NULL,               // Command line
        NULL,               // Process security attributes
        NULL,               // Thread security attributes
        FALSE,              // Inherit handles
        0,                  // Creation flags
        NULL,               // Environment
        NULL,               // Current directory
        &si,                // Startup info
        &pi                 // Process information
    )) {
        Log("WoW.exe launched successfully");
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
    } else {
        Log("Failed to launch WoW.exe, error: %lu", GetLastError());
    }
}

void SelfDelete() {
    // Create a batch file to delete ourselves after we exit
    char selfPath[MAX_PATH];
    GetModuleFileNameA(NULL, selfPath, MAX_PATH);

    char batPath[MAX_PATH];
    GetTempPathA(MAX_PATH, batPath);
    strcat(batPath, "cleanup.bat");

    FILE* bat = fopen(batPath, "w");
    if (bat) {
        fprintf(bat, "@echo off\n");
        fprintf(bat, ":retry\n");
        fprintf(bat, "del \"%s\"\n", selfPath);
        fprintf(bat, "if exist \"%s\" goto retry\n", selfPath);
        fprintf(bat, "del \"%%~f0\"\n");  // Delete the batch file itself
        fclose(bat);

        // Run the batch file hidden
        STARTUPINFOA si;
        PROCESS_INFORMATION pi;
        ZeroMemory(&si, sizeof(si));
        si.cb = sizeof(si);
        si.dwFlags = STARTF_USESHOWWINDOW;
        si.wShowWindow = SW_HIDE;
        ZeroMemory(&pi, sizeof(pi));

        char cmd[MAX_PATH + 20];
        sprintf(cmd, "cmd.exe /c \"%s\"", batPath);

        CreateProcessA(NULL, cmd, NULL, NULL, FALSE, CREATE_NO_WINDOW, NULL, NULL, &si, &pi);
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
    }
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    // Open log file
    g_logFile = fopen(LOG_FILE, "w");
    Log("=== WoW Patch Installer Started ===");
    Log("Command line: %s", lpCmdLine);

    // Get current directory
    char currentDir[MAX_PATH];
    GetCurrentDirectoryA(MAX_PATH, currentDir);
    Log("Working directory: %s", currentDir);

    // ============================================
    // CREATE PROGRESS WINDOW
    // ============================================

    g_hProgressDlg = CreateProgressWindow(hInstance);
    UpdateProgress(0, "Initializing...");

    // ============================================
    // LOAD CONFIGURATION
    // ============================================

    UpdateProgress(5, "Loading configuration...");
    PatchConfig config;
    ReadConfig(CONFIG_FILE, &config);
    Log("Using builds: %u -> %u", config.oldBuild, config.newBuild);

    // ============================================
    // WAIT FOR WOW TO CLOSE
    // ============================================

    UpdateProgress(10, "Waiting for WoW to close...");
    Sleep(2000);

    if (IsProcessRunning(WOW_PROCESS_NAME)) {
        WaitForProcessToClose(WOW_PROCESS_NAME, 30);
    }

    // ============================================
    // CREATE BACKUP (for rollback)
    // ============================================

    UpdateProgress(15, "Creating backup...");
    Log("Creating backup for rollback...");

    // Record backup path for potential rollback
    snprintf(g_backupPath, MAX_PATH, "%s.patch_backup", WOW_PROCESS_NAME);

    // Check if a backup already exists from previous run
    if (!FileExists(g_backupPath)) {
        if (CopyFileA(WOW_PROCESS_NAME, g_backupPath, FALSE)) {
            g_backupCreatedByUs = TRUE;
            Log("Created backup: %s", g_backupPath);
        } else {
            Log("WARNING: Could not create backup");
        }
    } else {
        Log("Backup already exists: %s", g_backupPath);
    }

    // Also maintain the permanent backup
    CreateBackup(WOW_PROCESS_NAME);

    // ============================================
    // VERIFY CONTENT PATCH (MD5)
    // ============================================

    if (FileExists(CONTENT_PATCH_FILE)) {
        UpdateProgress(20, "Verifying content patch...");
        if (!VerifyContentPatchMD5(CONTENT_PATCH_FILE, CONTENT_PATCH_MD5_FILE)) {
            Log("ERROR: Content patch verification failed!");
            UpdateProgress(100, "Error: Patch verification failed!");

            MessageBoxA(NULL,
                "Content patch verification failed!\n\n"
                "The downloaded patch may be corrupted.\n"
                "Please try again.",
                "Patch Error",
                MB_OK | MB_ICONERROR);

            CloseProgressWindow();
            if (g_logFile) { fclose(g_logFile); g_logFile = NULL; }
            return 1;
        }
    }

    // ============================================
    // PATCH BUILD NUMBER
    // ============================================

    UpdateProgress(30, "Patching build number...");
    BOOL patchSuccess = FALSE;

    Log("Starting build number patch...");

    patchSuccess = PatchBuildNumber(
        WOW_PROCESS_NAME,
        BUILD_NUMBER_OFFSET,
        config.oldBuild,
        config.newBuild
    );

    if (!patchSuccess) {
        Log("ERROR: Failed to patch build number!");
        UpdateProgress(100, "Error: Patch failed! Rolling back...");

        // Perform rollback
        PerformRollback();

        MessageBoxA(NULL,
            "Failed to patch WoW.exe!\n\n"
            "Your original WoW.exe has been restored.\n"
            "Please check patch_install.log for details.",
            "Patch Error",
            MB_OK | MB_ICONERROR);

        CloseProgressWindow();
        if (g_logFile) { fclose(g_logFile); g_logFile = NULL; }
        return 1;
    }

    Log("Build number patch completed successfully");

    // ============================================
    // PATCH DISPLAY STRINGS (UI)
    // ============================================

    UpdateProgress(50, "Updating version display...");
    Log("Patching display strings for UI...");
    PatchAllDisplayStrings(WOW_PROCESS_NAME, config.oldBuild, config.newBuild);

    // ============================================
    // INSTALL CONTENT PATCH
    // ============================================

    BOOL contentInstalled = FALSE;
    if (FileExists(CONTENT_PATCH_FILE)) {
        UpdateProgress(60, "Installing content patch...");
        Log("Content patch found, installing...");
        contentInstalled = InstallContentPatch(CONTENT_PATCH_FILE);

        if (!contentInstalled) {
            Log("WARNING: Content patch installation failed");
            // Don't rollback for content patch failure, build number is still patched
        }
    } else {
        Log("No content patch to install");
    }

    // ============================================
    // CLEANUP
    // ============================================

    UpdateProgress(70, "Clearing cache...");
    // Clear WoW cache to avoid stale data
    ClearWoWCache();

    UpdateProgress(80, "Cleaning up...");
    // Delete the patch MPQ file
    if (FileExists(PATCH_FILE)) {
        DeletePatchFile(PATCH_FILE);
    } else {
        Log("Patch file %s not found (already deleted?)", PATCH_FILE);
    }

    // Delete config file
    if (FileExists(CONFIG_FILE)) {
        DeleteFileA(CONFIG_FILE);
        Log("Deleted config file: %s", CONFIG_FILE);
    }

    // Delete MD5 file if present
    if (FileExists(CONTENT_PATCH_MD5_FILE)) {
        DeleteFileA(CONTENT_PATCH_MD5_FILE);
        Log("Deleted MD5 file: %s", CONTENT_PATCH_MD5_FILE);
    }

    // Delete rollback backup (patch successful, no longer needed)
    if (g_backupCreatedByUs && FileExists(g_backupPath)) {
        DeleteFileA(g_backupPath);
        Log("Deleted rollback backup: %s", g_backupPath);
    }

    UpdateProgress(90, "Patch complete!");
    g_patchSuccess = TRUE;

    // Close progress window
    CloseProgressWindow();

    // Show success message
    char successMsg[512];
    if (contentInstalled) {
        snprintf(successMsg, sizeof(successMsg),
            "Patch installed successfully!\n\n"
            "- Build number updated: %u -> %u\n"
            "- Content patch installed\n\n"
            "Click OK to restart World of Warcraft.",
            config.oldBuild, config.newBuild);
    } else {
        snprintf(successMsg, sizeof(successMsg),
            "Patch installed successfully!\n\n"
            "Build number updated: %u -> %u\n\n"
            "Click OK to restart World of Warcraft.",
            config.oldBuild, config.newBuild);
    }

    MessageBoxA(NULL, successMsg, "Patch Complete", MB_OK | MB_ICONINFORMATION);

    // Restart WoW
    LaunchWow();

    Log("=== Installer Complete ===");

    if (g_logFile) {
        fclose(g_logFile);
        g_logFile = NULL;
    }

    // Clean up ourselves
    SelfDelete();

    return 0;
}
