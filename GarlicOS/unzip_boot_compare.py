import os
import time
import filecmp
import difflib
from pathlib import Path
from datetime import datetime


def get_all_files(root_path):
    """Get all files in directory tree with relative paths"""
    files_dict = {}
    root_path = Path(root_path)

    for file_path in root_path.rglob('*'):
        if file_path.is_file():
            relative_path = file_path.relative_to(root_path)
            files_dict[str(relative_path)] = {
                'full_path': str(file_path),
                'size': file_path.stat().st_size
            }
    return files_dict


def is_text_file(filename):
    """Check if file should be compared line by line"""
    text_extensions = ['.txt', '.json', '.prop', '.rc']
    text_patterns = ['fstab']

    # Check extensions
    for ext in text_extensions:
        if filename.lower().endswith(ext):
            return True

    # Check patterns
    for pattern in text_patterns:
        if pattern in filename.lower():
            return True

    return False


def compare_text_files(file1_path, file2_path):
    """Compare two text files line by line and return differences"""
    differences = []

    try:
        with open(file1_path, 'r', encoding='utf-8', errors='ignore') as f1:
            lines1 = f1.readlines()
        with open(file2_path, 'r', encoding='utf-8', errors='ignore') as f2:
            lines2 = f2.readlines()

        # Line by line comparison with line numbers
        max_lines = max(len(lines1), len(lines2))
        line_diffs = []

        for line_num in range(max_lines):
            line1 = lines1[line_num].rstrip('\n\r') if line_num < len(lines1) else ''
            line2 = lines2[line_num].rstrip('\n\r') if line_num < len(lines2) else ''

            if line1 != line2:
                line_diffs.append(f"    ln {line_num + 1}: STOCK: '{line1}' | GARLIC: '{line2}'")

        return line_diffs

    except Exception as e:
        return [f"    Error comparing files: {str(e)}"]


def compare_directories(folder_pathstock, folder_pathgarlic, output_file):
    """Main function to compare directories"""

    print("Starting directory comparison...")
    print(f"Stock folder: {folder_pathstock}")
    print(f"Garlic folder: {folder_pathgarlic}")

    # Get all files from both directories
    print("Scanning stock directory...")
    stock_files = get_all_files(folder_pathstock)
    print("Scanning garlic directory...")
    garlic_files = get_all_files(folder_pathgarlic)

    # Get unique subdirectories for progress tracking
    all_subdirs = set()
    for filepath in list(stock_files.keys()) + list(garlic_files.keys()):
        subdir = str(Path(filepath).parent)
        if subdir != '.':
            all_subdirs.add(subdir)

    all_subdirs = sorted(list(all_subdirs))

    # Find common files and analyze differences
    common_files = set(stock_files.keys()) & set(garlic_files.keys())
    size_different_files = []
    content_different_files = []

    # Collect all files with different sizes
    print("Analyzing file differences...")
    for file in common_files:
        stock_info = stock_files[file]
        garlic_info = garlic_files[file]

        if stock_info['size'] != garlic_info['size']:
            size_different_files.append({
                'file': file,
                'stock_size': stock_info['size'],
                'garlic_size': garlic_info['size'],
                'stock_path': stock_info['full_path'],
                'garlic_path': garlic_info['full_path']
            })

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(f"Directory Comparison Report\n")
        f.write(f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Stock folder: {folder_pathstock}\n")
        f.write(f"Garlic folder: {folder_pathgarlic}\n")
        f.write("=" * 80 + "\n\n")

        # Files missing in garlic (present in stock)
        f.write("FILES MISSING IN GARLIC FOLDER:\n")
        f.write("-" * 40 + "\n")
        missing_in_garlic = set(stock_files.keys()) - set(garlic_files.keys())
        if missing_in_garlic:
            for file in sorted(missing_in_garlic):
                f.write(f"  {file}\n")
        else:
            f.write("  No missing files found.\n")
        f.write("\n")

        # Files missing in stock (present in garlic)
        f.write("FILES MISSING IN STOCK FOLDER:\n")
        f.write("-" * 40 + "\n")
        missing_in_stock = set(garlic_files.keys()) - set(stock_files.keys())
        if missing_in_stock:
            for file in sorted(missing_in_stock):
                f.write(f"  {file}\n")
        else:
            f.write("  No missing files found.\n")
        f.write("\n")

        # Files with different sizes - DEDICATED SECTION
        f.write("FILES WITH DIFFERENT SIZES:\n")
        f.write("-" * 40 + "\n")
        if size_different_files:
            for file_info in sorted(size_different_files, key=lambda x: x['file']):
                f.write(f"  {file_info['file']}\n")
                f.write(f"    Stock size: {file_info['stock_size']} bytes\n")
                f.write(f"    Garlic size: {file_info['garlic_size']} bytes\n")
                f.write(f"    Size difference: {file_info['garlic_size'] - file_info['stock_size']:+} bytes\n")
                f.write("\n")
        else:
            f.write("  No files with different sizes found.\n")
        f.write("\n")

        # Detailed content comparison by subdirectory
        f.write("DETAILED CONTENT COMPARISON BY DIRECTORY:\n")
        f.write("=" * 50 + "\n")

        for subdir in [''] + all_subdirs:  # Start with root, then subdirectories
            if subdir:
                print(f"- Comparing files in /{subdir} path")
                f.write(f"\nComparing files in /{subdir} path:\n")
                f.write("-" * (30 + len(subdir)) + "\n")
            else:
                print("- Comparing files in root path")
                f.write(f"\nComparing files in root path:\n")
                f.write("-" * 30 + "\n")

            subdir_files = [file for file in common_files
                            if str(Path(file).parent) == subdir]

            if not subdir_files:
                print("  No files to compare in this directory")
                f.write("  No files to compare in this directory\n")
                continue

            files_compared_in_subdir = 0
            files_with_differences_in_subdir = 0

            for file in sorted(subdir_files):
                stock_info = stock_files[file]
                garlic_info = garlic_files[file]
                files_compared_in_subdir += 1

                # Check if file has size difference (we already know this from our earlier analysis)
                has_size_diff = any(f['file'] == file for f in size_different_files)

                # Check content for text files
                content_differences = []
                if is_text_file(file):
                    print(f"    Comparing content of text file: {file}")
                    content_differences = compare_text_files(stock_info['full_path'],
                                                             garlic_info['full_path'])

                # Report if there are any differences
                if has_size_diff or content_differences:
                    files_with_differences_in_subdir += 1
                    f.write(f"  {file}:\n")

                    if has_size_diff:
                        size_info = next(f for f in size_different_files if f['file'] == file)
                        f.write(f"    SIZE DIFFERENCE: Stock={size_info['stock_size']} bytes, "
                                f"Garlic={size_info['garlic_size']} bytes "
                                f"(diff: {size_info['garlic_size'] - size_info['stock_size']:+} bytes)\n")

                    if content_differences:
                        f.write(f"    CONTENT DIFFERENCES:\n")
                        for diff in content_differences[:10]:  # Limit to first 10 differences
                            f.write(f"{diff}\n")
                        if len(content_differences) > 10:
                            f.write(f"    ... and {len(content_differences) - 10} more content differences\n")

                    f.write("\n")

            f.write(f"  Summary for this directory: {files_compared_in_subdir} files compared, "
                    f"{files_with_differences_in_subdir} files with differences\n")

            # Sleep between subdirectories
            if subdir_files and subdir != (all_subdirs[-1] if all_subdirs else ''):
                print("  Pausing before next directory...")
                time.sleep(2)  # 2 second break

        # Summary
        f.write("\n" + "=" * 80 + "\n")
        f.write("SUMMARY:\n")
        f.write(f"Total files in stock: {len(stock_files)}\n")
        f.write(f"Total files in garlic: {len(garlic_files)}\n")
        f.write(f"Files missing in garlic: {len(missing_in_garlic)}\n")
        f.write(f"Files missing in stock: {len(missing_in_stock)}\n")
        f.write(f"Common files: {len(common_files)}\n")
        f.write(f"Files with different sizes: {len(size_different_files)}\n")


# Main execution
if __name__ == "__main__":
    # Set your folder paths here
    folder_pathstock = "C:\\Users\\PC\\Desktop\\Email\\_LLM\\RP3+\\Linux\\GarlicOS\\2Plus\\boot\\unzip_bootstock"
    folder_pathgarlic = "C:\\Users\\PC\\Desktop\\Email\\_LLM\\RP3+\\Linux\\GarlicOS\\3.5\\unzip_bootstock3plus"

    # Output file
    output_file = "rp3+_vs_rp2+_comparison_report.txt"

    # Verify paths exist
    if not os.path.exists(folder_pathstock):
        print(f"Error: Stock folder path does not exist: {folder_pathstock}")
        exit(1)

    if not os.path.exists(folder_pathgarlic):
        print(f"Error: Garlic folder path does not exist: {folder_pathgarlic}")
        exit(1)

    # Run comparison
    start_time = time.time()
    compare_directories(folder_pathstock, folder_pathgarlic, output_file)
    end_time = time.time()

    print(f"\nComparison completed in {end_time - start_time:.2f} seconds")
    print(f"Report saved to: {output_file}")
