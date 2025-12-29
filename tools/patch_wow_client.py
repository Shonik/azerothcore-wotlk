#!/usr/bin/env python3
"""
WoW 3.3.5a Client Patcher

This script provides TWO separate patches for the WoW 3.3.5a client:

1. BUILD NUMBER PATCH (--build):
   Changes the client's build number so it reports a different version to the server.
   This is useful for triggering the patching system.
   Offset: 0x4C99F0

2. SIGNATURE BYPASS PATCH (--signature):
   Patches SFileAuthenticateArchiveEx to always return success.
   This allows the client to accept unsigned MPQ patches.
   NOTE: The offset for this function varies by client version and must be found
   using a disassembler (IDA Pro, Ghidra, x64dbg).

Usage:
    python patch_wow_client.py <path_to_wow.exe> --build <new_build_number>
    python patch_wow_client.py <path_to_wow.exe> --signature <hex_offset>
    python patch_wow_client.py <path_to_wow.exe> --info

WARNING: Always backup your WoW.exe before patching!

References:
- PDF: "Implementing in-client patching for World of Warcraft" by stoneharry & schlumpf
- https://github.com/stoneharry/Blizzard-Patching
- https://github.com/Xerrion/WoW_335a_Patcher
"""

import sys
import os
import shutil
import argparse

# Known offset for build number in WoW.exe 3.3.5a (12340)
BUILD_NUMBER_OFFSET = 0x4C99F0

# Signature bypass patterns for SFileAuthenticateArchiveEx
# Source: https://model-changing.net forum
# Pattern format: (search_pattern, replacement_pattern, mask)
# ?? in pattern means wildcard (any byte)
SIGNATURE_PATTERNS = {
    'windows_12340': {
        'description': 'Windows WoW 3.3.5a (12340)',
        # 55 8b ec 8b 45 1c 8b 4d 18 8b 55 14 53 68 ?? ?? ?? ??
        'search': bytes([0x55, 0x8B, 0xEC, 0x8B, 0x45, 0x1C, 0x8B, 0x4D, 0x18, 0x8B, 0x55, 0x14, 0x53, 0x68]),
        'search_mask': 'xxxxxxxxxxxxxx????',  # x = match, ? = wildcard
        # 55 8b ec b9 05 00 00 00 8b 45 0c 89 08 b8 01 00 00 00 5d c2 18 00
        'replace': bytes([0x55, 0x8B, 0xEC, 0xB9, 0x05, 0x00, 0x00, 0x00, 0x8B, 0x45, 0x0C, 0x89, 0x08, 0xB8, 0x01, 0x00, 0x00, 0x00, 0x5D, 0xC2, 0x18, 0x00]),
    },
    'osx_15689': {
        'description': 'OSX WoW (15689)',
        # C7 44 24 18 ?? ?? ?? ?? 8b 45 1c 89 44 24 14 8b 45 18
        'search': bytes([0xC7, 0x44, 0x24, 0x18]),
        'search_suffix': bytes([0x8B, 0x45, 0x1C, 0x89, 0x44, 0x24, 0x14, 0x8B, 0x45, 0x18]),
        'search_mask': 'xxxx????xxxxxxxxxx',
        # b9 05 00 00 00 8b 55 0c 89 0a b8 01 00 00 00 c9 c3
        'replace': bytes([0xB9, 0x05, 0x00, 0x00, 0x00, 0x8B, 0x55, 0x0C, 0x89, 0x0A, 0xB8, 0x01, 0x00, 0x00, 0x00, 0xC9, 0xC3]),
    }
}

def create_backup(exe_path):
    """Create a backup of the executable."""
    backup_path = exe_path + '.backup'
    if not os.path.exists(backup_path):
        print(f"Creating backup: {backup_path}")
        shutil.copy2(exe_path, backup_path)
    else:
        print(f"Backup already exists: {backup_path}")
    return backup_path

def read_file(exe_path):
    """Read the executable into a bytearray."""
    with open(exe_path, 'rb') as f:
        return bytearray(f.read())

def write_file(exe_path, data):
    """Write the modified data back to the executable."""
    with open(exe_path, 'wb') as f:
        f.write(data)

def get_current_build(data):
    """Read the current build number from the executable."""
    offset = BUILD_NUMBER_OFFSET
    # Build number is stored as uint16 (2 bytes, little-endian)
    return data[offset] | (data[offset + 1] << 8)

def patch_build_number(exe_path, new_build):
    """Patch the build number in the executable."""
    if not os.path.exists(exe_path):
        print(f"Error: File not found: {exe_path}")
        return False

    create_backup(exe_path)
    data = read_file(exe_path)

    current_build = get_current_build(data)
    print(f"Current build number: {current_build}")
    print(f"New build number: {new_build}")

    if current_build == new_build:
        print("Build number is already set to the requested value.")
        return True

    # Write new build number (uint16, little-endian)
    data[BUILD_NUMBER_OFFSET] = new_build & 0xFF
    data[BUILD_NUMBER_OFFSET + 1] = (new_build >> 8) & 0xFF

    write_file(exe_path, data)
    print(f"Build number patched successfully: {current_build} -> {new_build}")
    return True

def patch_signature_verification(exe_path, hex_offset):
    """
    Patch SFileAuthenticateArchiveEx to always return success.

    The patch replaces the function prologue with:
        mov dword ptr [edx], 5    ; *authresult = 5 (success)
        mov eax, 1                ; return true
        ret                       ; return

    According to the PDF, authresult > 4 means success.
    """
    if not os.path.exists(exe_path):
        print(f"Error: File not found: {exe_path}")
        return False

    # Parse hex offset
    try:
        if hex_offset.startswith('0x'):
            offset = int(hex_offset, 16)
        else:
            offset = int(hex_offset, 16)
    except ValueError:
        print(f"Error: Invalid hex offset: {hex_offset}")
        return False

    create_backup(exe_path)
    data = read_file(exe_path)

    if offset >= len(data) - 20:
        print(f"Error: Offset 0x{offset:X} is out of bounds")
        return False

    print(f"Patching SFileAuthenticateArchiveEx at offset 0x{offset:X}")
    print(f"Current bytes: {data[offset:offset+20].hex()}")

    # The patch based on the PDF (Listing 6):
    # This makes SFileAuthenticateArchiveEx always return true with authresult = 5
    #
    # Original function typically starts with:
    #   55              push ebp
    #   8B EC           mov ebp, esp
    #   ...
    #
    # We patch it to:
    #   8B 55 0C        mov edx, [ebp+0Ch]    ; edx = authresult pointer (2nd param)
    #   C7 02 05 00 00 00  mov dword ptr [edx], 5  ; *authresult = 5
    #   B8 01 00 00 00  mov eax, 1            ; return true
    #   C3              ret
    #
    # But since we're replacing from the start, we need a simpler approach:
    # Just make it return true immediately after setting authresult
    #
    # Simpler patch (assuming stdcall/cdecl, authresult is at [esp+8]):
    #   8B 54 24 08     mov edx, [esp+8]      ; edx = authresult pointer
    #   C7 02 05 00 00 00  mov dword ptr [edx], 5  ; *authresult = 5
    #   B8 01 00 00 00  mov eax, 1            ; return true
    #   C2 18 00        ret 0x18              ; return (clean up 24 bytes for 6 params)

    # Patch bytes
    patch = bytes([
        0x8B, 0x54, 0x24, 0x08,              # mov edx, [esp+8] - get authresult pointer
        0xC7, 0x02, 0x05, 0x00, 0x00, 0x00,  # mov dword ptr [edx], 5
        0xB8, 0x01, 0x00, 0x00, 0x00,        # mov eax, 1
        0xC2, 0x18, 0x00,                    # ret 0x18 (24 bytes = 6 params * 4)
        0x90, 0x90                           # nop padding
    ])

    # Apply patch
    for i, byte in enumerate(patch):
        data[offset + i] = byte

    write_file(exe_path, data)
    print(f"Patched bytes: {patch.hex()}")
    print("Signature verification bypass applied successfully!")
    print("The client will now accept unsigned MPQ patches.")
    return True

def find_string_offset(data, string):
    """Find the offset of a string in the data."""
    encoded = string.encode('ascii') + b'\x00'
    offset = data.find(encoded)
    return offset

def find_pattern(data, pattern, mask=None):
    """Find a byte pattern in data. Returns list of offsets."""
    results = []
    pattern_len = len(pattern)

    for i in range(len(data) - pattern_len):
        match = True
        for j in range(pattern_len):
            if mask and mask[j] == '?':
                continue
            if data[i + j] != pattern[j]:
                match = False
                break
        if match:
            results.append(i)
    return results

def find_xrefs_to_address(data, target_va, code_start=0x1000, code_end=0x600000):
    """
    Find cross-references to a virtual address in x86 code.
    Searches for:
    - push imm32 (68 XX XX XX XX)
    - mov reg, imm32 (B8-BF XX XX XX XX, C7 XX XX XX XX XX)
    - lea reg, [mem] patterns

    Returns list of (file_offset, instruction_type) tuples.
    """
    results = []

    # Convert VA to bytes for searching
    target_bytes = target_va.to_bytes(4, 'little')

    # Search in code section
    search_start = code_start
    search_end = min(code_end, len(data) - 5)

    for i in range(search_start, search_end):
        # Check for push imm32 (68 XX XX XX XX)
        if data[i] == 0x68 and data[i+1:i+5] == target_bytes:
            results.append((i, 'push'))

        # Check for mov reg, imm32 (B8+reg for eax-edi)
        elif 0xB8 <= data[i] <= 0xBF and data[i+1:i+5] == target_bytes:
            regs = ['eax', 'ecx', 'edx', 'ebx', 'esp', 'ebp', 'esi', 'edi']
            reg = regs[data[i] - 0xB8]
            results.append((i, f'mov {reg}, imm32'))

        # Check for mov [esp+XX], imm32 (C7 44 24 XX imm32)
        elif data[i] == 0xC7 and i + 7 < len(data):
            if data[i+1] == 0x44 and data[i+2] == 0x24:  # [esp+disp8]
                if data[i+4:i+8] == target_bytes:
                    results.append((i, f'mov [esp+0x{data[i+3]:02X}], imm32'))
            elif data[i+1] == 0x45:  # [ebp+disp8]
                if data[i+3:i+7] == target_bytes:
                    results.append((i, f'mov [ebp+0x{data[i+2]:02X}], imm32'))
            elif data[i+1] == 0x05:  # mov dword ptr [addr], imm32
                if data[i+6:i+10] == target_bytes:
                    results.append((i, 'mov [mem], imm32'))

    return results

def find_function_start(data, offset, max_search=0x200):
    """
    Search backwards from an offset to find the function prologue.
    Common prologues:
    - 55 8B EC        push ebp; mov ebp, esp
    - 55 89 E5        push ebp; mov ebp, esp (alternate)
    - 83 EC XX        sub esp, XX (sometimes without push ebp)
    """
    # Search backwards for function prologue
    for i in range(offset, max(0, offset - max_search), -1):
        # Standard prologue: push ebp; mov ebp, esp
        if data[i] == 0x55 and i + 2 < len(data):
            if data[i+1] == 0x8B and data[i+2] == 0xEC:
                return i
            if data[i+1] == 0x89 and data[i+2] == 0xE5:
                return i

        # Check for int 3 padding (CC) which often precedes functions
        if data[i] == 0xCC and i + 1 < len(data) and data[i+1] == 0x55:
            return i + 1

        # Check for ret followed by function start
        if data[i] in (0xC3, 0xC2) and i + 1 < len(data) and data[i+1] == 0x55:
            return i + 1

    return None

def disassemble_bytes(data, offset, count=20):
    """Simple hex dump with basic x86 disassembly hints."""
    result = []
    i = offset
    end = min(offset + count, len(data))

    while i < end:
        byte = data[i]

        if byte == 0x55:
            result.append(f"  0x{i:06X}: 55              push ebp")
            i += 1
        elif byte == 0x8B and i + 1 < end and data[i+1] == 0xEC:
            result.append(f"  0x{i:06X}: 8B EC           mov ebp, esp")
            i += 2
        elif byte == 0x83 and i + 2 < end and data[i+1] == 0xEC:
            result.append(f"  0x{i:06X}: 83 EC {data[i+2]:02X}        sub esp, 0x{data[i+2]:02X}")
            i += 3
        elif byte == 0x68 and i + 4 < end:
            imm = int.from_bytes(data[i+1:i+5], 'little')
            result.append(f"  0x{i:06X}: 68 {data[i+1:i+5].hex()}    push 0x{imm:08X}")
            i += 5
        elif byte == 0xC7 and i + 7 < end and data[i+1] == 0x44 and data[i+2] == 0x24:
            disp = data[i+3]
            imm = int.from_bytes(data[i+4:i+8], 'little')
            result.append(f"  0x{i:06X}: C7 44 24 {disp:02X} ...  mov [esp+0x{disp:02X}], 0x{imm:08X}")
            i += 8
        elif byte == 0xE8 and i + 4 < end:
            rel = int.from_bytes(data[i+1:i+5], 'little', signed=True)
            target = i + 5 + rel
            result.append(f"  0x{i:06X}: E8 {data[i+1:i+5].hex()}    call 0x{target:06X}")
            i += 5
        elif byte == 0xC3:
            result.append(f"  0x{i:06X}: C3              ret")
            i += 1
        elif byte == 0xC2 and i + 2 < end:
            imm = int.from_bytes(data[i+1:i+3], 'little')
            result.append(f"  0x{i:06X}: C2 {data[i+1]:02X} {data[i+2]:02X}         ret 0x{imm:04X}")
            i += 3
        else:
            result.append(f"  0x{i:06X}: {byte:02X}              db 0x{byte:02X}")
            i += 1

    return result

def find_signature_pattern(data, pattern_info):
    """
    Find a signature pattern with mask support.
    Returns the offset if found, -1 otherwise.
    """
    search = pattern_info['search']
    mask = pattern_info.get('search_mask', 'x' * len(search))

    # Build full pattern if there's a suffix (for patterns with wildcards in the middle)
    if 'search_suffix' in pattern_info:
        # Pattern has wildcards in the middle
        prefix_len = len(search)
        suffix = pattern_info['search_suffix']
        wildcard_count = len(mask) - prefix_len - len(suffix)

        for i in range(len(data) - len(mask)):
            # Check prefix
            prefix_match = True
            for j in range(prefix_len):
                if data[i + j] != search[j]:
                    prefix_match = False
                    break

            if not prefix_match:
                continue

            # Check suffix (after wildcard bytes)
            suffix_start = prefix_len + wildcard_count
            suffix_match = True
            for j in range(len(suffix)):
                if data[i + suffix_start + j] != suffix[j]:
                    suffix_match = False
                    break

            if suffix_match:
                return i

    else:
        # Simple pattern with wildcards only at the end
        for i in range(len(data) - len(mask)):
            match = True
            for j in range(len(mask)):
                if mask[j] == 'x':
                    if j < len(search) and data[i + j] != search[j]:
                        match = False
                        break
            if match:
                return i

    return -1

def patch_signature_auto(exe_path):
    """
    Automatically find and patch SFileAuthenticateArchiveEx using known patterns.
    """
    if not os.path.exists(exe_path):
        print(f"Error: File not found: {exe_path}")
        return False

    data = read_file(exe_path)
    current_build = get_current_build(data)

    print(f"File: {exe_path}")
    print(f"Current build: {current_build}")
    print()

    # Try to find a matching pattern
    found_pattern = None
    found_offset = -1

    for pattern_info in SIGNATURE_PATTERNS.values():
        print(f"Trying pattern: {pattern_info['description']}...")
        offset = find_signature_pattern(data, pattern_info)
        if offset != -1:
            found_pattern = pattern_info
            found_offset = offset
            print(f"  FOUND at offset 0x{offset:X}!")
            break
        else:
            print(f"  Not found.")

    if found_offset == -1:
        print()
        print("ERROR: Could not find SFileAuthenticateArchiveEx pattern.")
        print("Your WoW.exe might be a different version or already patched.")
        print()
        print("Try using --info to get more details, or --signature with a manual offset.")
        return False

    # Check if already patched
    replace_bytes = found_pattern['replace']
    if data[found_offset:found_offset + len(replace_bytes)] == replace_bytes:
        print()
        print("Client is already patched!")
        return True

    # Create backup and apply patch
    create_backup(exe_path)

    print()
    print(f"Patching at offset 0x{found_offset:X}")
    print(f"Original bytes: {data[found_offset:found_offset + len(replace_bytes)].hex()}")
    print(f"Patch bytes:    {replace_bytes.hex()}")

    # Apply the patch
    for i, byte in enumerate(replace_bytes):
        data[found_offset + i] = byte

    write_file(exe_path, data)

    print()
    print("=" * 60)
    print("SUCCESS! Signature verification bypass applied.")
    print("The client will now accept unsigned MPQ patches.")
    print("=" * 60)

    return True

def show_info(exe_path):
    """Show information about the executable."""
    if not os.path.exists(exe_path):
        print(f"Error: File not found: {exe_path}")
        return False

    data = read_file(exe_path)
    current_build = get_current_build(data)

    print(f"File: {exe_path}")
    print(f"Size: {len(data)} bytes")
    print(f"Build number at 0x{BUILD_NUMBER_OFFSET:X}: {current_build}")
    print()

    # Search for "ARCHIVE" string (used as parameter to SFileAuthenticateArchiveEx)
    archive_offset = find_string_offset(data, "ARCHIVE")
    if archive_offset != -1:
        print(f"Found 'ARCHIVE' string at offset: 0x{archive_offset:X}")
        print("  This string is passed to SFileAuthenticateArchiveEx")

        # Calculate VA (Virtual Address) for WoW.exe
        # WoW.exe typically has image base 0x400000 and .rdata around 0x5E0000
        image_base = 0x400000
        archive_va = image_base + archive_offset
        print(f"  Virtual Address: 0x{archive_va:08X}")

        print()
        print("Searching for cross-references to 'ARCHIVE' string...")
        print("(This may take a moment...)")

        xrefs = find_xrefs_to_address(data, archive_va)

        if xrefs:
            print(f"\nFound {len(xrefs)} cross-reference(s) to 'ARCHIVE':")
            for xref_offset, xref_type in xrefs:
                xref_va = image_base + xref_offset
                print(f"\n  [{xref_type}] at file offset 0x{xref_offset:X} (VA: 0x{xref_va:08X})")

                # Try to find function start
                func_start = find_function_start(data, xref_offset)
                if func_start:
                    func_va = image_base + func_start
                    print(f"  -> Function starts at: 0x{func_start:X} (VA: 0x{func_va:08X})")
                    print(f"  -> USE THIS OFFSET: --signature 0x{func_start:X}")
                    print()
                    print("  Function prologue:")
                    for line in disassemble_bytes(data, func_start, 30):
                        print(line)
                else:
                    print("  -> Could not find function start")
        else:
            print("\nNo cross-references found automatically.")
            print("The string might be referenced indirectly or through a register.")

    else:
        print("'ARCHIVE' string not found")

    # Search for "wow-patch.mpq" string
    print()
    patch_offset = find_string_offset(data, "wow-patch.mpq")
    if patch_offset != -1:
        print(f"Found 'wow-patch.mpq' string at offset: 0x{patch_offset:X}")

    print()
    print("=" * 60)
    print("MANUAL INSTRUCTIONS (if automatic search didn't work):")
    print("=" * 60)
    print("1. Open WoW.exe in Ghidra or x64dbg")
    print("2. Go to the 'ARCHIVE' string offset shown above")
    print("3. Find cross-references (xrefs) to this string")
    print("4. The function that uses it is SFileAuthenticateArchiveEx wrapper")
    print()
    print("The function typically has this pattern:")
    print("  55              push ebp")
    print("  8B EC           mov ebp, esp")
    print("  83 EC 38        sub esp, 38h")
    print("  C7 44 24 18 XX  mov [esp+18h], offset 'ARCHIVE'")

    return True

def main():
    parser = argparse.ArgumentParser(
        description='WoW 3.3.5a Client Patcher',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # Show client info
  python patch_wow_client.py "C:\\WoW\\WoW.exe" --info

  # Automatically patch signature verification (RECOMMENDED)
  python patch_wow_client.py "C:\\WoW\\WoW.exe" --patch-signature

  # Change build number to 12339 (to trigger patching)
  python patch_wow_client.py "C:\\WoW\\WoW.exe" --build 12339

  # Patch signature verification with manual offset
  python patch_wow_client.py "C:\\WoW\\WoW.exe" --signature 0x123456
'''
    )

    parser.add_argument('exe_path', help='Path to WoW.exe')
    parser.add_argument('--build', type=int, help='New build number to set')
    parser.add_argument('--signature', help='Hex offset of SFileAuthenticateArchiveEx to patch (manual)')
    parser.add_argument('--patch-signature', action='store_true', help='Auto-find and patch signature verification (RECOMMENDED)')
    parser.add_argument('--info', action='store_true', help='Show client information')

    args = parser.parse_args()

    if args.info:
        success = show_info(args.exe_path)
    elif args.patch_signature:
        success = patch_signature_auto(args.exe_path)
    elif args.build:
        success = patch_build_number(args.exe_path, args.build)
    elif args.signature:
        success = patch_signature_verification(args.exe_path, args.signature)
    else:
        parser.print_help()
        print("\nError: You must specify --build, --signature, --patch-signature, or --info")
        sys.exit(1)

    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
