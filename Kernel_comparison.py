import re
from typing import Dict, Set, Tuple
from enum import Enum
from datetime import datetime


class ConfigState(Enum):
    ENABLED = "y"
    MODULE = "m"
    DISABLED = "disabled"
    NOT_SET = "not_set"


def parse_kernel_config(file_path: str) -> Dict[str, ConfigState]:
    """
    Parse a kernel config file and return a dictionary of config options and their states.
    """
    configs = {}

    with open(file_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()

            # Skip empty lines and regular comments
            if not line or (line.startswith('#') and 'is not set' not in line):
                continue

            # Handle disabled configs: # CONFIG_SOMETHING is not set
            if line.startswith('# ') and ' is not set' in line:
                match = re.match(r'# (CONFIG_\w+) is not set', line)
                if match:
                    config_name = match.group(1)
                    configs[config_name] = ConfigState.NOT_SET

            # Handle enabled configs: CONFIG_SOMETHING=y or CONFIG_SOMETHING=m
            elif line.startswith('CONFIG_'):
                if '=' in line:
                    config_name, value = line.split('=', 1)
                    if value == 'y':
                        configs[config_name] = ConfigState.ENABLED
                    elif value == 'm':
                        configs[config_name] = ConfigState.MODULE
                    else:
                        # For other values (strings, numbers, etc.)
                        configs[config_name] = ConfigState.DISABLED

    return configs


def read_raw_config_file(file_path: str) -> str:
    """
    Read the raw content of a config file for comment line extraction.
    """
    with open(file_path, 'r', encoding='utf-8') as f:
        return f.read()


def export_all_config_comparisons(config1: Dict[str, ConfigState], config2: Dict[str, ConfigState],
                                  config1_raw: str, config2_raw: str,
                                  file1_name: str, file2_name: str,
                                  diff_output_file: str = "enabled_configs_differences.txt",
                                  same_output_file: str = "enabled_configs_similarities.txt",
                                  comment_output_file: str = "configs_common_comments.txt"):
    """
    Export all three types of comparisons: enabled differences, enabled similarities, and common comments.
    """

    # Get all configs that are enabled (=y) in each file
    enabled_config1 = {k for k, v in config1.items() if v == ConfigState.ENABLED}
    enabled_config2 = {k for k, v in config2.items() if v == ConfigState.ENABLED}

    # Find configs enabled only in file1 (not in file2 or different state)
    only_in_file1 = []
    for config in enabled_config1:
        if config not in config2 or config2[config] != ConfigState.ENABLED:
            only_in_file1.append(config)

    # Find configs enabled only in file2 (not in file1 or different state)
    only_in_file2 = []
    for config in enabled_config2:
        if config not in config1 or config1[config] != ConfigState.ENABLED:
            only_in_file2.append(config)

    # Find configs that are enabled in both files (similarities)
    common_enabled = []
    for config in enabled_config1:
        if config in enabled_config2 and config2[config] == ConfigState.ENABLED:
            common_enabled.append(config)

    # Extract comment lines from raw configs (including "is not set" comments)
    comments1 = set()
    comments2 = set()

    for line in config1_raw.splitlines():
        line = line.strip()
        if line.startswith('#'):
            comments1.add(line)

    for line in config2_raw.splitlines():
        line = line.strip()
        if line.startswith('#'):
            comments2.add(line)

    # Find common comment lines (exact match)
    common_comments = sorted(comments1 & comments2)

    # 1. Export differences to diff_output_file
    with open(diff_output_file, 'w', encoding='utf-8') as f:
        f.write(f"=== ENABLED CONFIGURATIONS (=y) DIFFERENCES ===\n")
        f.write(f"Comparison between: {file1_name} and {file2_name}\n")
        f.write(f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Total differences: {len(only_in_file1) + len(only_in_file2)}\n\n")

        # Section for Config File 1
        f.write(f"{file1_name}: {len(only_in_file1)} unique enabled configs\n")
        for config in sorted(only_in_file1):
            f.write(f"{config}=y\n")

        f.write(f"\n{file2_name}: {len(only_in_file2)} unique enabled configs\n")
        for config in sorted(only_in_file2):
            f.write(f"{config}=y\n")

    # 2. Export similarities to same_output_file
    with open(same_output_file, 'w', encoding='utf-8') as f:
        f.write(f"=== ENABLED CONFIGURATIONS (=y) SIMILARITIES ===\n")
        f.write(f"Comparison between: {file1_name} and {file2_name}\n")
        f.write(f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Total common enabled configs: {len(common_enabled)}\n\n")

        for config in sorted(common_enabled):
            f.write(f"{config}=y\n")

    # 3. Export common comments to comment_output_file
    with open(comment_output_file, 'w', encoding='utf-8') as f:
        f.write(f"=== COMMON COMMENT LINES ===\n")
        f.write(f"Comparison between: {file1_name} and {file2_name}\n")
        f.write(f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Total common comment lines: {len(common_comments)}\n\n")

        for comment in common_comments:
            f.write(f"{comment}\n")

    print(f"✓ Exported {len(only_in_file1) + len(only_in_file2)} enabled config differences to: {diff_output_file}")
    print(f"  - {file1_name}: {len(only_in_file1)} unique enabled configs")
    print(f"  - {file2_name}: {len(only_in_file2)} unique enabled configs")
    print(f"✓ Exported {len(common_enabled)} enabled config similarities to: {same_output_file}")
    print(f"✓ Exported {len(common_comments)} common comment lines to: {comment_output_file}")

    return len(only_in_file1) + len(only_in_file2), len(common_enabled), len(common_comments)


def compare_configs_with_triple_export(config1: Dict[str, ConfigState], config2: Dict[str, ConfigState],
                                       config1_raw: str, config2_raw: str,
                                       file1_name: str, file2_name: str) -> None:
    """
    Compare two kernel configurations and export to three different files.
    """
    all_configs = set(config1.keys()) | set(config2.keys())

    print(f"=== Kernel Configuration Comparison ===")
    print(f"File 1: {file1_name}")
    print(f"File 2: {file2_name}")
    print(f"Total unique configs: {len(all_configs)}")

    # Get counts of enabled configs
    enabled1_count = sum(1 for state in config1.values() if state == ConfigState.ENABLED)
    enabled2_count = sum(1 for state in config2.values() if state == ConfigState.ENABLED)

    print(f"Enabled configs in {file1_name}: {enabled1_count}")
    print(f"Enabled configs in {file2_name}: {enabled2_count}")
    print()

    # Export all three comparison types
    diff_count, same_count, comment_count = export_all_config_comparisons(
        config1, config2, config1_raw, config2_raw, file1_name, file2_name
    )

    print(f"\n=== Export Summary ===")
    print(f"Enabled config differences exported: {diff_count}")
    print(f"Enabled config similarities exported: {same_count}")
    print(f"Common comment lines exported: {comment_count}")


# Main execution
if __name__ == "__main__":
    # Replace these with your actual file paths
    file1_path = "C:\\Users\\PC\\Desktop\\Email\\_LLM\\RP3+\\Linux\\Kernels\\4.14.193_kernel_configs.txt"
    file2_path = "C:\\Users\\PC\\Desktop\\Email\\_LLM\\RP3+\\Linux\\Kernels\\4.14.199_kernel_configs.txt"

    try:
        print("Parsing configuration files...")

        # Parse the config structures
        config1 = parse_kernel_config(file1_path)
        config2 = parse_kernel_config(file2_path)

        # Read raw file contents for comment extraction
        config1_raw = read_raw_config_file(file1_path)
        config2_raw = read_raw_config_file(file2_path)

        # Compare and export to all three files
        compare_configs_with_triple_export(
            config1, config2, config1_raw, config2_raw,
            "Config File 1", "Config File 2"
        )

        # Optional: Create custom export with specific filenames
        print("\n=== Creating Custom Export Files ===")
        export_all_config_comparisons(
            config1, config2, config1_raw, config2_raw,
            "Config File 1", "Config File 2",
            diff_output_file="C:\\Users\\PC\\Desktop\\Email\\_LLM\\RP3+\\Linux\\Kernels\\193vs199_differences.txt",
            same_output_file="C:\\Users\\PC\\Desktop\\Email\\_LLM\\RP3+\\Linux\\Kernels\\193vs199_similarities.txt",
            comment_output_file="C:\\Users\\PC\\Desktop\\Email\\_LLM\\RP3+\\Linux\\Kernels\\193vs199_comments.txt"
        )

        print("\nTriple export completed successfully!")

    except FileNotFoundError as e:
        print(f"Error: Could not find configuration file - {e}")
        print("Make sure your kernel config files are in the correct path.")
    except Exception as e:
        print(f"Error processing files: {e}")
