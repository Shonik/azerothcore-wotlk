#!/usr/bin/env python3
"""
WoW Patch Deployment Script

Compiles the installer and generates patch MPQs for all locales in one command.

Usage:
  python deploy_patch.py --content-patch path/to/patch.mpq
  python deploy_patch.py --content-patch patch.mpq --build 12340 --new-build 12341
  python deploy_patch.py --content-patch patch.mpq --output-dir ClientPatches/
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path


# Script locations
SCRIPT_DIR = Path(__file__).parent
INSTALLER_DIR = SCRIPT_DIR / "patch_installer"
CREATE_MPQ_SCRIPT = SCRIPT_DIR / "create_patch_mpq.py"

# Default paths
DEFAULT_OUTPUT_DIR = Path("Y:/ClientPatches")
DEFAULT_INSTALLER = INSTALLER_DIR / "installer.exe"


def run_command(cmd: list, cwd: str = None, description: str = None) -> bool:
    """Run a command and return success status."""
    if description:
        print(f"\n{'='*60}")
        print(f"  {description}")
        print(f"{'='*60}")

    print(f"> {' '.join(str(c) for c in cmd)}")

    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            capture_output=False,
            text=True
        )
        return result.returncode == 0
    except Exception as e:
        print(f"ERROR: {e}")
        return False


def compile_installer() -> bool:
    """Compile the installer using build.bat."""
    print("\n" + "="*60)
    print("  STEP 1: Compiling installer")
    print("="*60)

    build_script = INSTALLER_DIR / "build.bat"

    if not build_script.exists():
        print(f"ERROR: Build script not found: {build_script}")
        return False

    # Run build.bat with full path
    result = subprocess.run(
        ["cmd", "/c", str(build_script)],
        cwd=str(INSTALLER_DIR),
        capture_output=True,
        text=True
    )

    print(result.stdout)
    if result.stderr:
        print(result.stderr)

    # Check if installer was created
    if not DEFAULT_INSTALLER.exists():
        print(f"ERROR: Installer not created: {DEFAULT_INSTALLER}")
        return False

    size = DEFAULT_INSTALLER.stat().st_size
    print(f"Installer compiled: {DEFAULT_INSTALLER} ({size} bytes)")
    return True


def generate_mpqs(content_patch: str, output_dir: str, build: int, new_build: int) -> bool:
    """Generate MPQ files for all locales."""
    print("\n" + "="*60)
    print("  STEP 2: Generating MPQ files for all locales")
    print("="*60)

    cmd = [
        sys.executable,
        str(CREATE_MPQ_SCRIPT),
        "--installer", str(DEFAULT_INSTALLER),
        "--all-locales",
        "--build", str(build),
        "--new-build", str(new_build),
        "--output", str(Path(output_dir) / "placeholder.mpq"),  # Directory hint
    ]

    if content_patch:
        cmd.extend(["--content-patch", content_patch])

    result = subprocess.run(cmd, capture_output=False, text=True)
    return result.returncode == 0


def show_summary(output_dir: str, build: int, new_build: int, content_patch: str):
    """Show deployment summary."""
    print("\n" + "="*60)
    print("  DEPLOYMENT COMPLETE")
    print("="*60)

    # List generated files
    output_path = Path(output_dir)
    if output_path.exists():
        mpq_files = list(output_path.glob(f"*{build}.mpq"))
        print(f"\nGenerated {len(mpq_files)} MPQ files in {output_dir}:")
        total_size = 0
        for f in sorted(mpq_files):
            size = f.stat().st_size
            total_size += size
            print(f"  - {f.name} ({size:,} bytes)")
        print(f"\nTotal size: {total_size:,} bytes ({total_size/1024/1024:.2f} MB)")

    print(f"\nPatch configuration:")
    print(f"  - From build: {build}")
    print(f"  - To build:   {new_build}")
    if content_patch:
        print(f"  - Content:    {content_patch}")

    print(f"\nServer configuration (authserver.conf):")
    print(f"  Patching.Enabled = 1")
    print(f"  Patching.MinBuild = {new_build}")
    print(f"  Patching.MaxBuild = {new_build}")
    print(f"  Patching.PatchesDir = \"{output_dir}\"")

    print("\n" + "="*60)


def main():
    parser = argparse.ArgumentParser(
        description="Deploy WoW patch - compile installer and generate MPQs",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --content-patch my-patch.mpq
  %(prog)s --content-patch my-patch.mpq --build 12341 --new-build 12342
  %(prog)s --content-patch my-patch.mpq --output-dir /path/to/patches/
  %(prog)s --skip-compile --content-patch my-patch.mpq
        """
    )

    parser.add_argument('--content-patch', '-p',
                        help='Path to content patch MPQ to include')
    parser.add_argument('--output-dir', '-o', default=str(DEFAULT_OUTPUT_DIR),
                        help=f'Output directory for MPQ files (default: {DEFAULT_OUTPUT_DIR})')
    parser.add_argument('--build', '-b', type=int, default=12340,
                        help='Client build to patch FROM (default: 12340)')
    parser.add_argument('--new-build', '-n', type=int, default=None,
                        help='Client build to patch TO (default: build+1)')
    parser.add_argument('--skip-compile', '-s', action='store_true',
                        help='Skip installer compilation (use existing)')

    args = parser.parse_args()

    # Determine new build
    if args.new_build is None:
        args.new_build = args.build + 1

    # Validate content patch if specified
    if args.content_patch and not os.path.exists(args.content_patch):
        print(f"ERROR: Content patch not found: {args.content_patch}")
        sys.exit(1)

    # Create output directory
    os.makedirs(args.output_dir, exist_ok=True)

    print("="*60)
    print("  WoW Patch Deployment")
    print("="*60)
    print(f"Build: {args.build} -> {args.new_build}")
    print(f"Output: {args.output_dir}")
    if args.content_patch:
        print(f"Content patch: {args.content_patch}")

    # Step 1: Compile installer
    if not args.skip_compile:
        if not compile_installer():
            print("\nFAILED: Could not compile installer")
            sys.exit(1)
    else:
        if not DEFAULT_INSTALLER.exists():
            print(f"ERROR: Installer not found: {DEFAULT_INSTALLER}")
            print("Run without --skip-compile to build it")
            sys.exit(1)
        print(f"\nSkipping compilation, using existing: {DEFAULT_INSTALLER}")

    # Step 2: Generate MPQs
    if not generate_mpqs(args.content_patch, args.output_dir, args.build, args.new_build):
        print("\nFAILED: Could not generate MPQ files")
        sys.exit(1)

    # Summary
    show_summary(args.output_dir, args.build, args.new_build, args.content_patch)

    sys.exit(0)


if __name__ == '__main__':
    main()
