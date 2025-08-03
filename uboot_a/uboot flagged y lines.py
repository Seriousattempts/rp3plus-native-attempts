def filter_comments_and_empty_lines(input_file, output_file):
    """
    Read a text file and create a new file with lines that don't start with #
    and are not empty or whitespace-only

    Args:
        input_file (str): Path to the input .txt file
        output_file (str): Path to the output .txt file
    """
    try:
        with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
            for line in infile:
                stripped_line = line.strip()
                # Keep lines that don't start with # AND are not empty
                if stripped_line and not stripped_line.startswith('#'):
                    outfile.write(line)

        print(f"Filtered file created: {output_file}")

    except FileNotFoundError:
        print(f"Error: File '{input_file}' not found.")
    except Exception as e:
        print(f"Error: {e}")


def export_commented_not_set_flags(input_file, output_file):
    """
    Read a text file and create a new file with lines that are comments indicating flags
    that are not set. These lines start with '#' and end with 'is not set'.

    Args:
        input_file (str): Path to the input .txt file
        output_file (str): Path to the output .txt file
    """
    try:
        with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
            count = 0
            for line in infile:
                stripped_line = line.strip()
                # Lines that start with '#' and end with 'is not set'
                if (stripped_line.startswith('#') and stripped_line.endswith('is not set')):
                    outfile.write(line)
                    count += 1

        print(f"Exported {count} commented 'not set' flags to: {output_file}")

    except FileNotFoundError:
        print(f"Error: File '{input_file}' not found.")
    except Exception as e:
        print(f"Error: {e}")


# Usage example
input_filename = "C:\\Users\\PC\\Desktop\\Email\\- LLM\\RP3+\\Linux\\.config uboot addons 1.txt"  # Replace with your input file name
filtered_output_filename = "C:\\Users\\PC\\Desktop\\Email\\- LLM\\RP3+\\Linux\\filtered_output.txt"  # Replace with desired output file name
commented_flags_output = "C:\\Users\\PC\\Desktop\\Email\\- LLM\\RP3+\\Linux\\commented_not_set_flags.txt"

# Filter out comments and empty lines (original function)
filter_comments_and_empty_lines(input_filename, filtered_output_filename)

# Export only the commented-out flags that are not set (new function)
export_commented_not_set_flags(input_filename, commented_flags_output)