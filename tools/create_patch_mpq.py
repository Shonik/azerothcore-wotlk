#!/usr/bin/env python3
"""
WoW Patch MPQ Creator

Creates a properly structured MPQ patch file for the WoW 3.3.5a client.
The patch will be sent via the XFER protocol from the authserver.

Structure of the patch MPQ:
  - prepatch.lst       : Commands for the client to execute
  - patch.cfg          : Build configuration (OLD_BUILD, NEW_BUILD)
  - installer.exe      : Custom installer that handles the patch
  - content-patch.mpq  : (Optional) Content patch to install to Data/<locale>/
  - content-patch.md5  : (Optional) MD5 hash for content patch verification

Usage:
  python create_patch_mpq.py --output frFR12340.mpq --installer installer.exe
  python create_patch_mpq.py --installer patch_installer/installer.exe --locale frFR --build 12340
  python create_patch_mpq.py --installer installer.exe --content-patch my-patch.mpq --all-locales
"""

import argparse
import hashlib
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path


# All supported WoW locales
ALL_LOCALES = ["frFR", "enUS", "enGB", "deDE", "esES", "esMX", "ruRU", "zhCN", "zhTW", "koKR", "ptBR", "itIT"]

# Default MPQEditor paths to search
MPQEDITOR_PATHS = [
    "MPQEditor.exe",
    r"C:\Games\Tools\WOW\LadikMPQEditor\x64\MPQEditor.exe",
    r"C:\Tools\MPQEditor\MPQEditor.exe",
]


def find_mpqeditor() -> str | None:
    """Find MPQEditor executable."""
    import shutil

    # Check script directory first
    script_dir = Path(__file__).parent
    local_mpqeditor = script_dir / "MPQEditor.exe"
    if local_mpqeditor.exists():
        return str(local_mpqeditor)

    # Check known paths
    for path in MPQEDITOR_PATHS:
        if os.path.exists(path):
            return path
        if shutil.which(path):
            return path

    return None


def create_prepatch_lst(installer_name: str = "installer.exe",
                        config_name: str = "patch.cfg",
                        content_patch_name: str = None,
                        content_patch_md5_name: str = None) -> bytes:
    """
    Create prepatch.lst content with Windows line endings.

    Commands available:
    - delete <filename>     : Delete a file
    - extract <filename>    : Extract file from MPQ to game directory
    - execute <filename>    : Execute an extracted file

    Lines must be max 260 characters and use Windows line endings (\\r\\n).
    """
    lines = [
        f"extract {config_name}",
    ]

    # Add content patch extraction if present
    if content_patch_name:
        lines.append(f"extract {content_patch_name}")
        # Also extract MD5 file for verification
        if content_patch_md5_name:
            lines.append(f"extract {content_patch_md5_name}")

    lines.extend([
        f"extract {installer_name}",
        f"execute {installer_name}",
    ])

    # Join with Windows line endings
    content = "\r\n".join(lines) + "\r\n"
    return content.encode('ascii')


def calculate_file_md5(file_path: str) -> str:
    """
    Calculate MD5 hash of a file.

    Args:
        file_path: Path to the file

    Returns:
        MD5 hash as lowercase hex string (32 characters)
    """
    md5 = hashlib.md5()
    with open(file_path, 'rb') as f:
        # Read in chunks to handle large files
        for chunk in iter(lambda: f.read(8192), b''):
            md5.update(chunk)
    return md5.hexdigest().lower()


def create_patch_config(old_build: int, new_build: int) -> bytes:
    """
    Create patch.cfg content with the build configuration.

    Format:
        OLD_BUILD=12340
        NEW_BUILD=12341
    """
    lines = [
        f"# WoW Patch Configuration",
        f"OLD_BUILD={old_build}",
        f"NEW_BUILD={new_build}",
    ]
    content = "\r\n".join(lines) + "\r\n"
    return content.encode('ascii')


class MPQCreator:
    """
    Creates MPQ archives using MPQEditor command line.

    MPQEditor MoPaq 2000 commands (without slash = no GUI):
      new <mpq> <maxfiles> [sectorsize]  - Create new MPQ
      add <mpq> <file> <name>            - Add file to MPQ
      flush <mpq>                        - Flush changes
      close <mpq>                        - Close MPQ
    """

    def __init__(self, mpqeditor_path: str = None):
        self.mpqeditor = mpqeditor_path or find_mpqeditor()
        if not self.mpqeditor:
            raise RuntimeError(
                "MPQEditor not found!\n"
                "Please download from: http://www.zezula.net/en/mpq/download.html\n"
                "And place it in one of these locations:\n"
                f"  - {Path(__file__).parent / 'MPQEditor.exe'}\n"
                "  - " + "\n  - ".join(MPQEDITOR_PATHS)
            )
        self.files = {}  # filename -> (data or filepath, is_path)
        self.temp_files = []  # Track temp files for cleanup

    def add_file(self, mpq_filename: str, data: bytes = None, source_path: str = None):
        """
        Add a file to the archive.

        Args:
            mpq_filename: Name of the file inside the MPQ
            data: Raw bytes to add (mutually exclusive with source_path)
            source_path: Path to file on disk (mutually exclusive with data)
        """
        mpq_filename = mpq_filename.replace('/', '\\')

        if data is not None:
            self.files[mpq_filename] = (data, False)
            print(f"  Queued: {mpq_filename} ({len(data)} bytes)")
        elif source_path is not None:
            if not os.path.exists(source_path):
                raise FileNotFoundError(f"Source file not found: {source_path}")
            self.files[mpq_filename] = (source_path, True)
            size = os.path.getsize(source_path)
            print(f"  Queued: {mpq_filename} <- {source_path} ({size} bytes)")
        else:
            raise ValueError("Either data or source_path must be provided")

    def _run_mpqeditor(self, *args, wait_time: float = 0.5) -> bool:
        """
        Run MPQEditor command (without slash = no GUI window).

        Args:
            *args: Command arguments
            wait_time: Time to wait after command for file operations

        Returns:
            True if command was executed successfully
        """
        cmd = [self.mpqeditor] + list(args)
        print(f"  > {' '.join(cmd)}")

        try:
            # Run and wait for completion
            result = subprocess.run(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == 'win32' else 0,
                timeout=600  # 10 minute timeout for large files
            )
            # Give filesystem time to sync
            time.sleep(wait_time)
            return True
        except subprocess.TimeoutExpired:
            print(f"  ERROR: MPQEditor timed out")
            return False
        except Exception as e:
            print(f"  ERROR: {e}")
            return False

    def save(self, output_path: str) -> bool:
        """
        Create the MPQ archive with all queued files.

        Args:
            output_path: Path for the output MPQ file

        Returns:
            True if successful
        """
        output_path = os.path.abspath(output_path)
        print(f"\nCreating MPQ: {output_path}")
        print(f"Using MPQEditor: {self.mpqeditor}")

        # Remove existing file
        if os.path.exists(output_path):
            os.remove(output_path)
            print(f"  Removed existing: {output_path}")

        try:
            # Step 1: Create new MPQ
            print("\n[1/4] Creating new MPQ archive...")
            if not self._run_mpqeditor("new", output_path, "16"):
                raise RuntimeError("Failed to create MPQ")

            # Verify MPQ was created
            time.sleep(0.5)
            if not os.path.exists(output_path):
                raise RuntimeError(f"MPQ file was not created: {output_path}")
            print(f"  Created: {output_path} ({os.path.getsize(output_path)} bytes)")

            # Step 2: Prepare temp files for data that needs to be written
            print("\n[2/4] Preparing files...")
            file_mappings = []  # (temp_or_source_path, mpq_filename)

            for mpq_filename, (content, is_path) in self.files.items():
                if is_path:
                    # Content is already a file path
                    file_mappings.append((content, mpq_filename))
                else:
                    # Content is bytes, write to temp file
                    temp_fd, temp_path = tempfile.mkstemp(suffix=f"_{mpq_filename.replace(chr(92), '_')}")
                    os.write(temp_fd, content)
                    os.close(temp_fd)
                    self.temp_files.append(temp_path)
                    file_mappings.append((temp_path, mpq_filename))
                    print(f"  Temp file: {temp_path}")

            # Step 3: Add files to MPQ
            print("\n[3/4] Adding files to MPQ...")
            for source_path, mpq_filename in file_mappings:
                print(f"  Adding: {mpq_filename}")
                if not self._run_mpqeditor("add", output_path, source_path, mpq_filename):
                    raise RuntimeError(f"Failed to add {mpq_filename}")

            # Step 4: Verify
            print("\n[4/4] Verifying MPQ...")
            time.sleep(0.5)
            final_size = os.path.getsize(output_path)
            print(f"  Final size: {final_size} bytes")

            # Use mpyq to verify contents if available (optional)
            try:
                import mpyq
                mpq = mpyq.MPQArchive(output_path)
                if mpq.files is None:
                    print("  (mpyq could not read file list)")
                else:
                    files_in_mpq = [f.decode() if isinstance(f, bytes) else f for f in mpq.files]
                    print(f"  Files in MPQ: {files_in_mpq}")

                    expected_files = set(self.files.keys())
                    actual_files = set(files_in_mpq)

                    if not expected_files.issubset(actual_files):
                        missing = expected_files - actual_files
                        print(f"  WARNING: Missing files: {missing}")
                    else:
                        print("  All files verified!")

            except ImportError:
                print("  (mpyq not available for verification)")
            except Exception as verify_error:
                print(f"  (mpyq verification failed: {verify_error})")

            print(f"\n SUCCESS: MPQ created at {output_path}")
            return True

        except Exception as e:
            print(f"\n FAILED: {e}")
            return False

        finally:
            # Cleanup temp files
            for temp_path in self.temp_files:
                try:
                    os.remove(temp_path)
                except:
                    pass
            self.temp_files.clear()


def main():
    parser = argparse.ArgumentParser(
        description="Create WoW patch MPQ for XFER protocol",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --installer installer.exe
  %(prog)s --installer installer.exe --locale enUS --build 12340
  %(prog)s --installer installer.exe --output ClientPatches/frFR12340.mpq
  %(prog)s --mpqeditor "C:/Path/To/MPQEditor.exe" --installer installer.exe
        """
    )
    parser.add_argument('--output', '-o',
                        help='Output MPQ path (default: {locale}{build}.mpq)')
    parser.add_argument('--installer', '-i', required=True,
                        help='Path to installer.exe to include')
    parser.add_argument('--content-patch', '-p',
                        help='Path to content patch MPQ to include (installed to Data/<locale>/)')
    parser.add_argument('--locale', '-l', default='frFR',
                        help='Client locale (default: frFR)')
    parser.add_argument('--all-locales', '-a', action='store_true',
                        help='Generate MPQ for all supported locales')
    parser.add_argument('--build', '-b', type=int, default=12340,
                        help='Client build number to patch FROM (default: 12340)')
    parser.add_argument('--new-build', '-n', type=int, default=None,
                        help='Client build number to patch TO (default: build+1)')
    parser.add_argument('--mpqeditor', '-m',
                        help='Path to MPQEditor.exe (auto-detected if not specified)')
    parser.add_argument('--prepatch-commands', '-c', nargs='*',
                        help='Additional prepatch.lst commands (e.g., "delete old.dll")')

    args = parser.parse_args()

    # Determine new build if not specified
    if args.new_build is None:
        args.new_build = args.build + 1

    # Validate installer exists
    if not os.path.exists(args.installer):
        print(f"ERROR: Installer not found: {args.installer}")
        print("\nTo create the installer:")
        print("  1. Install MinGW-w64 from https://winlibs.com/")
        print("  2. Run: cd tools/patch_installer && build.bat")
        sys.exit(1)

    # Validate content patch if specified
    content_patch_name = None
    if args.content_patch:
        if not os.path.exists(args.content_patch):
            print(f"ERROR: Content patch not found: {args.content_patch}")
            sys.exit(1)
        content_patch_name = "content-patch.mpq"

    # Determine which locales to process
    if args.all_locales:
        locales = ALL_LOCALES
    else:
        locales = [args.locale]

    print("=" * 60)
    print("WoW Patch MPQ Creator")
    print("=" * 60)
    print(f"Build: {args.build} -> {args.new_build}")
    print(f"Locales: {', '.join(locales)}")
    if args.content_patch:
        print(f"Content patch: {args.content_patch}")
    print()

    success_count = 0
    failed_locales = []

    for locale in locales:
        # Determine output filename
        if args.output and not args.all_locales:
            output_path = args.output
        else:
            output_dir = os.path.dirname(args.output) if args.output else "."
            output_path = os.path.join(output_dir, f"{locale}{args.build}.mpq")

        print(f"[{locale}] Creating {output_path}...")

        try:
            # Create MPQ creator
            mpq = MPQCreator(mpqeditor_path=args.mpqeditor)

            # Add patch.cfg with build configuration
            config_content = create_patch_config(args.build, args.new_build)
            mpq.add_file("patch.cfg", data=config_content)

            # Add content patch if specified
            content_patch_md5_name = None
            if content_patch_name:
                mpq.add_file(content_patch_name, source_path=args.content_patch)

                # Calculate and add MD5 hash file for verification
                content_patch_md5_name = "content-patch.md5"
                md5_hash = calculate_file_md5(args.content_patch)
                md5_content = f"{md5_hash}\r\n".encode('ascii')
                mpq.add_file(content_patch_md5_name, data=md5_content)
                print(f"  Content patch MD5: {md5_hash}")

            # Add prepatch.lst
            prepatch_content = create_prepatch_lst("installer.exe", "patch.cfg", content_patch_name, content_patch_md5_name)

            # Add custom commands if specified
            if args.prepatch_commands:
                extra_commands = "\r\n".join(args.prepatch_commands) + "\r\n"
                prepatch_content = extra_commands.encode('ascii') + prepatch_content

            mpq.add_file("prepatch.lst", data=prepatch_content)

            # Add installer
            mpq.add_file("installer.exe", source_path=args.installer)

            # Save MPQ
            if mpq.save(output_path):
                print(f"[{locale}] OK")
                success_count += 1
            else:
                print(f"[{locale}] FAILED")
                failed_locales.append(locale)

        except RuntimeError as e:
            print(f"[{locale}] ERROR: {e}")
            failed_locales.append(locale)

    # Summary
    print()
    print("=" * 60)
    print(f"Created {success_count}/{len(locales)} MPQ files")
    if failed_locales:
        print(f"Failed: {', '.join(failed_locales)}")
    print()
    print("Next steps:")
    print(f"  1. Copy MPQ files to ClientPatches directory")
    print(f"  2. Ensure authserver has Patching.Enabled = 1")
    print(f"  3. Connect with WoW client build {args.build}")
    print(f"  4. Client will be patched to build {args.new_build}")
    if content_patch_name:
        print(f"  5. Content patch will be installed to Data/<locale>/")
    print("=" * 60)

    sys.exit(0 if success_count == len(locales) else 1)


if __name__ == '__main__':
    main()
