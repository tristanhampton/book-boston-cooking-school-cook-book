#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);

# Read the txt file
my $input_file = 'original/the-boston-cooking-school-cook-book.txt';
open(my $in, '<:utf8', $input_file) or die "Cannot open $input_file: $!";
my @lines = <$in>;
close($in);

# Read h3 headings (sections) from HTML
my %h3_headings;      # normalized => original heading
my %h3_max_count;     # normalized => how many times it appears in HTML
my %h3_used_count;    # normalized => how many times we've used it
open(my $h3, '<:utf8', 'h3-headings.txt') or die "Cannot open h3-headings.txt: $!";
while (my $heading = <$h3>) {
    chomp($heading);
    my $normalized = normalize_heading($heading);
    $h3_headings{$normalized} = $heading;
    $h3_max_count{$normalized}++;
    $h3_used_count{$normalized} = 0;
}
close($h3);

# Read h4 headings (subsections) from HTML
my %h4_headings;      # normalized => original heading
my %h4_max_count;     # normalized => how many times it appears in HTML
my %h4_used_count;    # normalized => how many times we've used it
open(my $h4, '<:utf8', 'h4-headings.txt') or die "Cannot open h4-headings.txt: $!";
while (my $heading = <$h4>) {
    chomp($heading);
    my $normalized = normalize_heading($heading);
    $h4_headings{$normalized} = $heading;
    $h4_max_count{$normalized}++;
    $h4_used_count{$normalized} = 0;
}
close($h4);

# Start building the LaTeX document
my @output;

# Document preamble
push @output, "\\documentclass[11pt,letterpaper]{book}";
push @output, "\\usepackage[utf8]{inputenc}";
push @output, "\\usepackage[T1]{fontenc}";
push @output, "\\usepackage{tgpagella}"; # TeX Gyre Pagella (Palatino-like)
push @output, "\\usepackage[margin=1in]{geometry}";
push @output, "\\usepackage{microtype}";
push @output, "\\usepackage{titlesec}";
push @output, "\\usepackage{titletoc}"; # For customizing table of contents
push @output, "\\usepackage{enumitem}";
push @output, "\\usepackage{array}";
push @output, "\\usepackage{tabularx}";
push @output, "\\usepackage[table]{xcolor}";
push @output, "\\usepackage{multicol}";
push @output, "\\usepackage{needspace}";
push @output, "\\usepackage{graphicx}";
push @output, "\\definecolor{tablerowgray}{gray}{0.75}";
push @output, "\\setlength{\\extrarowheight}{3pt}";
push @output, "";
push @output, "% Custom list formatting - reduce left padding";
push @output, "\\setlist[itemize]{leftmargin=1em}"; # Reduced from default (~2.5em)
push @output, "";
push @output, "% Prevent vertical justification (stretching)";
push @output, "\\raggedbottom";
push @output, "";
push @output, "% Custom chapter formatting";
push @output, "\\titleformat{\\chapter}[display]";
push @output, "  {\\normalfont\\huge\\bfseries\\centering}";
push @output, "  {}";
push @output, "  {0pt}";
push @output, "  {\\vspace*{-60pt}}";
push @output, "  [{\\vspace{2ex}\\centering\\includegraphics[width=5in]{divider-chapter.png}\\vspace{-2ex}}]";
push @output, "\\titlespacing*{\\chapter}";
push @output, "  {0pt}"; # Left margin
push @output, "  {20pt}"; # Space before (reduced from default ~50pt)
push @output, "  {40pt}"; # Space after
push @output, "";
push @output, "% Custom section formatting";
push @output, "\\setcounter{secnumdepth}{0}"; # Remove section numbering
push @output, "\\titleformat{\\section}";
push @output, "  {\\normalfont\\Large\\bfseries}"; # Font: Large, bold
push @output, "  {}"; # No label (no numbering)
push @output, "  {0pt}"; # No separation between label and title
push @output, "  {}"; # No transformation (keep original case)
push @output, "  [\\vspace{2pt}\\titlerule]"; # Add underline after title with 2pt space
push @output, "";
push @output, "% Custom subsection formatting";
push @output, "\\titleformat{\\subsection}";
push @output, "  {\\normalfont\\large\\bfseries}"; # Font: large, bold (smaller than section)
push @output, "  {}"; # No label (no numbering)
push @output, "  {0pt}"; # No separation between label and title
push @output, "  {\\underline}"; # Underline the text (not full-width)
push @output, "\\titlespacing*{\\subsection}";
push @output, "  {0pt}"; # Left margin
push @output, "  {1.5em}"; # Space before (breathing room between recipes)
push @output, "  {0.3em}"; # Space after (tight between title and ingredients)
push @output, "";
push @output, "% Customize table of contents - remove chapter numbers, add leader dots";
push @output, "\\titlecontents{chapter}";
push @output, "  [0pt]"; # Left indent
push @output, "  {\\bfseries}"; # Font formatting
push @output, "  {}"; # No chapter number
push @output, "  {}"; # No separator between number and title (not needed)
push @output, "  {\\titlerule*[0.5pc]{.}\\contentspage}"; # Leader dots and page number
push @output, "";
push @output, "% Customize chapter headers to show only chapter name (not \"Chapter X.\")";
push @output, "\\renewcommand{\\chaptermark}[1]{\\markboth{#1}{}}";
push @output, "";
push @output, "% Remove paragraph indentation and add space between paragraphs";
push @output, "\\setlength{\\parindent}{0pt}";
push @output, "\\setlength{\\parskip}{0.8em}";
push @output, "";
push @output, "% Custom title page";
push @output, "\\renewcommand{\\maketitle}{%";
push @output, "  \\begin{titlepage}";
push @output, "    \\centering";
push @output, "    \\vspace*{\\fill}";
push @output, "    {\\Huge\\bfseries The Boston Cooking-School Cook Book\\par}";
push @output, "    \\vspace{2em}";
push @output, "    \\includegraphics[width=5in]{divider-chapter.png}\\par";
push @output, "    \\vspace{2em}";
push @output, "    {\\Large Fannie Merritt Farmer\\par}";
push @output, "    \\vspace{1em}";
push @output, "    {\\large 1910\\par}";
push @output, "    \\vspace*{\\fill}";
push @output, "  \\end{titlepage}";
push @output, "}";
push @output, "";
push @output, "\\begin{document}";
push @output, "";
push @output, "\\maketitle";
push @output, "";

# State tracking
my $start_found = 0;
my $in_content = 0;
my $after_chapter = 0;  # Track if we just output a chapter
my $in_menu_chapter = 0;  # Track if we're in the "Suitable Combinations" chapter

for (my $i = 0; $i < @lines; $i++) {
    my $line = $lines[$i];
    chomp($line);
    $line =~ s/\r$//;  # Remove trailing carriage return (Windows line endings)

    # Skip until we find the start marker
    if (!$start_found && $line =~ /\*\*\* START OF .*PROJECT GUTENBERG/) {
        $start_found = 1;
        next;
    }
    next unless $start_found;

    # Stop at the end marker
    if ($line =~ /\*\*\* END OF .*PROJECT GUTENBERG/) {
        last;
    }

    # Skip Project Gutenberg boilerplate at the beginning
    if (!$in_content) {
        # Look for the start of actual content (PREFACE or first CHAPTER)
        if ($line =~ /^\s+PREFACE/i || $line =~ /^\s+CHAPTER [IVXLCDM]+\s*$/) {
            $in_content = 1;
        } else {
            next;
        }
    }

    # Skip illustration placeholders (BEFORE escaping)
    if ($line =~ /^\[Illustration/) {
        # Skip lines until we find the closing bracket
        my $j = $i + 1;
        while ($j < @lines) {
            my $nextline = $lines[$j];
            chomp($nextline);
            $nextline =~ s/\r$//;  # Remove trailing carriage return (Windows line endings)

            # Check if this line is the closing bracket
            if ($nextline =~ /^\]$/) {
                $i = $j; # Move main loop index past the closing bracket
                last;
            }
            $j++;
        }
        next;
    }

    # Check for section headings (h3) and subsection headings (h4) BEFORE escaping
    # This must happen before escape_latex so we can match against unescaped text
    my $normalized_line = normalize_heading($line);

    # Check if this line matches an h3 heading (section)
    if (exists $h3_headings{$normalized_line} &&
        $h3_used_count{$normalized_line} < $h3_max_count{$normalized_line}) {
        my $heading = $h3_headings{$normalized_line};
        my $escaped_heading = escape_latex($heading);

        # Convert to title case
        my $section_title = lc($escaped_heading);
        $section_title =~ s/\b(\w)/\U$1/g;

        # Fix possessives (convert 'S back to 's)
        $section_title =~ s/'S\b/'s/g;

        # Fix Roman numerals (should be all uppercase)
        # Match common patterns: I, II, III, IV, V, VI, VII, VIII, IX, X, XI, XII, etc.
        $section_title =~ s/\b(I|Ii|Iii|Iv|V|Vi|Vii|Viii|Ix|X|Xi|Xii|Xiii|Xiv|Xv|Xvi|Xvii|Xviii|Xix|Xx)\b/\U$1/g;

        # Add clearpage before large table sections to prevent stretching
        if ($section_title =~ /Division And Ways Of Cooking A Side Of Beef/i) {
            push @output, "";
            push @output, "\\clearpage";
        }
        if ($section_title =~ /Table Showing Composition Of Meats/i) {
            push @output, "";
            push @output, "\\clearpage";
        }

        # Check if this is the "Table Of Measures And Weights" - handle specially
        if ($section_title =~ /Table Of Measures And Weights/i) {
            # This should be a table header, not a section
            # Skip the section output and let the table handler below process it
            $h3_used_count{$normalized_line}++;
            $i++;  # Skip past the heading line

            # Skip blank lines after the heading
            while ($i < @lines && $lines[$i] =~ /^\s*$/) {
                $i++;
            }

            # Start the table with the title as header (2 columns)
            push @output, "";
            push @output, "\\vfill";
            push @output, "\\begin{center}";
            push @output, "\\arrayrulecolor{tablerowgray}";
            push @output, "\\begin{tabularx}{\\textwidth}{Xr}";
            push @output, "\\hline";
            push @output, "\\multicolumn{2}{c}{\\textbf{Table Of Measures And Weights}} \\\\";
            push @output, "\\hline";

            # Process table rows until we hit blank lines or different section
            my $blank_count = 0;
            while ($i < @lines) {
                my $tableline = $lines[$i];
                chomp($tableline);
                $tableline =~ s/\r$//;

                # Count consecutive blank lines - stop after 2
                if ($tableline =~ /^\s*$/) {
                    $blank_count++;
                    if ($blank_count >= 2) {
                        last;
                    }
                    $i++;
                    next;
                } else {
                    $blank_count = 0;
                }

                # Stop if we hit another section heading
                last if $tableline =~ /^\s+[A-Z\s]+$/;

                # Process table row: " 2  cups butter (packed solidly)                          = 1 pound"
                # Parse: left side (quantity + description) and right side (measurement)
                if ($tableline =~ /^\s+(.+?)\s+=\s+(.+)$/) {
                    my $left_side = $1;
                    my $right_side = $2;

                    # Combine quantity and description into one column
                    my $escaped_left = escape_latex($left_side);
                    my $escaped_right = escape_latex($right_side);

                    # Remove extra whitespace
                    $escaped_left =~ s/\s+/ /g;
                    $escaped_left =~ s/^\s+|\s+$//g;

                    push @output, "$escaped_left & $escaped_right \\\\";
                    push @output, "\\hline";
                } else {
                    # Not a table row, might be end of table
                    last;
                }

                $i++;
            }

            push @output, "\\end{tabularx}";
            push @output, "\\arrayrulecolor{black}";
            push @output, "\\end{center}";
            push @output, "\\vfill";
            push @output, "\\pagebreak";
            push @output, "";

            $i--;  # Back up one line so the main loop processes the next line correctly
            next;
        }

        # Don't output section heading for Time Tables For Cooking (handled specially below)
        unless ($section_title =~ /Time Tables For Cooking/i) {
            push @output, "";
            push @output, "\\needspace{15\\baselineskip}"; # Prevent recipe from splitting across pages
            push @output, "\\section*{$section_title}";
            push @output, "";
        }
        $after_chapter = 0;  # Reset flag - section breaks the "after chapter" sequence

        $h3_used_count{$normalized_line}++;

        # Check if this is a composition table - if so, format as LaTeX table
        if ($section_title =~ /Table Showing Composition/i) {
            # Look ahead to collect table data
            my $j = $i + 1;
            my $header_line = "";
            my @table_rows;

            # Skip blank lines and find the header
            while ($j < @lines && $lines[$j] =~ /^\s*$/) {
                $j++;
            }

            # Get header line (may span multiple lines)
            if ($j < @lines) {
                $header_line = $lines[$j];
                chomp($header_line);
                $header_line =~ s/\r$//;
                $j++;

                # Check if header continues on next line (not a data row)
                # If next line has minimal indentation and no numbers, it's part of the header
                while ($j < @lines) {
                    my $next = $lines[$j];
                    chomp($next);
                    $next =~ s/\r$//;

                    # If it's blank, we're done with header
                    last if $next =~ /^\s*$/;
                    # If it starts with lots of spaces (data row), we're done with header
                    last if $next =~ /^\s{5,}\S/;
                    # If it has numeric data that looks like a value, it's a data row
                    last if $next =~ /^\s+\S+\s+[\d\.]+/;

                    # Otherwise, append to header
                    $header_line .= " " . $next;
                    $j++;
                }
            }

            # Collect data rows
            while ($j < @lines) {
                my $row = $lines[$j];
                chomp($row);
                $row =~ s/\r$//;

                # Stop if starts with italic markup (citation)
                last if $row =~ /^\s*_/;

                # Skip blank lines but continue collecting
                if ($row =~ /^\s*$/) {
                    $j++;
                    next;
                }

                # Skip category labels (all caps, no numeric data, short)
                # Category labels like "BEEF", "MUTTON", "POULTRY"
                if ($row =~ /^\s+[A-Z]+\s*$/ && $row !~ /[\d\.]/) {
                    $j++;
                    next;
                }

                # Skip intermediate labels like "Carbohydrates", "Refuse"
                if ($row =~ /^\s+[A-Z][a-z]+s?\s*$/ && $row !~ /[\d\.]/) {
                    $j++;
                    next;
                }

                # Data rows start with spaces followed by a name and numbers
                if ($row =~ /^\s+\S/) {
                    # Check if this line has numeric data or is a continuation of previous line
                    if ($row =~ /[\d\.]/ && $row =~ /\s+[\d\.]+/) {
                        # This row has numeric data, add it as a new row
                        push @table_rows, $row;
                    } elsif (@table_rows > 0) {
                        # This is a continuation line (no numeric data), append to previous row
                        $row =~ s/^\s+//;  # Remove leading spaces
                        $table_rows[-1] .= " " . $row;
                    }
                    $j++;
                } else {
                    last;
                }
            }

            # Generate LaTeX table if we have data
            if (@table_rows > 0) {
                push @output, "";

                # Determine table column count - fish table needs 7 columns for shellfish
                # Use p{width} for first column to allow text wrapping
                my $col_spec;
                my $header_row;
                if ($section_title =~ /Fish/i) {
                    $col_spec = "p{1.8in}cccccc";  # 7 columns for fish (includes Carbohydrates for shellfish)
                    $header_row = "Item & Refuse & Proteid & Fat & Mineral matter & Carbohydrates & Water";
                } elsif ($section_title =~ /Meat/i) {
                    $col_spec = "p{2in}ccccc";   # 6 columns
                    $header_row = "Item & Refuse & Proteid & Fat & Mineral matter & Water";
                } elsif ($section_title =~ /Vegetable/i) {
                    $col_spec = "p{2in}ccccc";   # 6 columns
                    $header_row = "Item & Proteid & Fat & Carbohydrates & Mineral matter & Water";
                } else {
                    # Default for cereals composition table
                    $col_spec = "p{2in}ccccc";   # 6 columns
                    $header_row = "Item & Proteid & Fat & Starch & Mineral matter & Water";
                }

                push @output, "\\begin{tabular}{$col_spec}";
                push @output, "\\hline";

                push @output, "$header_row \\\\";
                push @output, "\\hline";

                # Output data rows
                my $row_num = 0;
                foreach my $row (@table_rows) {
                    # Parse row: name (may contain spaces) followed by numeric values
                    # Split on whitespace, then separate numeric values from name parts
                    $row =~ s/^\s+//;  # Remove leading spaces
                    my @parts = split /\s+/, $row;

                    # Separate numeric values from name parts
                    my @name_parts;
                    my @values;
                    for my $part (@parts) {
                        # Match numbers including decimals like ".8" or "1.0" or "68.0"
                        if ($part =~ /^\.?\d+\.?\d*$/) {
                            push @values, $part;
                        } else {
                            push @name_parts, $part;
                        }
                    }

                    my $name = join(" ", @name_parts);

                    # Handle column alignment for fish table
                    # Fish table has: Item, Refuse, Proteid, Fat, Mineral matter, Carbohydrates, Water
                    # Regular fish have 5 values: Refuse, Proteid, Fat, Mineral matter, Water (no Carbohydrates)
                    # Shellfish have 6 values: Refuse, Proteid, Fat, Mineral matter, Carbohydrates, Water
                    if ($section_title =~ /Fish/i && @values == 5) {
                        # Insert empty Carbohydrates column before Water
                        splice(@values, 4, 0, "");  # Insert empty string at position 4
                    }

                    # Determine expected number of value columns based on table type
                    my $expected_cols;
                    if ($section_title =~ /Fish/i) {
                        $expected_cols = 6;  # Fish table has 6 value columns
                    } else {
                        $expected_cols = 5;  # Other tables have 5 value columns
                    }

                    # Pad with empty values at end if still needed
                    while (@values < $expected_cols) {
                        push @values, "";
                    }

                    my $data_row = escape_latex($name) . " & " . join(" & ", map { escape_latex($_) } @values[0..$expected_cols-1]);
                    push @output, "$data_row \\\\";

                    # Add light grey line between rows (but not after last row)
                    $row_num++;
                    if ($row_num < scalar(@table_rows)) {
                        push @output, "\\arrayrulecolor{tablerowgray}\\hline";
                    }
                }
                push @output, "\\arrayrulecolor{black}";

                push @output, "\\hline";
                push @output, "\\end{tabular}";
                push @output, "";
            }

            # Skip the lines we processed
            $i = $j - 1;
        }
        # Check if this is a time table section - create 4 separate tables, one per page
        elsif ($section_title =~ /Time Tables For Cooking/i) {
            # This section contains multiple subsections: Boiling, Broiling, Baking, Frying
            # We'll create separate tables for each subsection with page breaks between them
            my $j = $i + 1;

            # Skip blank lines
            while ($j < @lines && $lines[$j] =~ /^\s*$/) {
                $j++;
            }

            my $first_table = 1;

            # Process each subsection
            while ($j < @lines) {
                my $line = $lines[$j];
                chomp($line);
                $line =~ s/\r$//;

                # Handle blank lines - check if we're at end of section
                if ($line =~ /^\s*$/) {
                    my $blank_count = 0;
                    my $k = $j;
                    while ($k < @lines && $lines[$k] =~ /^\s*$/) {
                        $blank_count++;
                        $k++;
                    }

                    # Check what comes after the blank lines
                    if ($k < @lines) {
                        my $next = $lines[$k];
                        $next =~ s/\r$//;
                        # If it's another subsection header, continue (don't exit)
                        if ($next =~ /^\s+(Boiling|Broiling|Baking|Frying)\s*$/i) {
                            $j++;
                            next;
                        }
                        # If it's NOTE or new content, we're done with this section
                        last if $next =~ /^NOTE/i;
                        last if $next =~ /^\s+CHAPTER/i;
                    } else {
                        # End of file
                        last;
                    }
                    $j++;
                    next;
                }

                # Check if this is a subsection header (Boiling, Broiling, Baking, Frying)
                if ($line =~ /^\s+(Boiling|Broiling|Baking|Frying)\s*$/i) {
                    my $subsection = $1;

                    $first_table = 0;

                    # Start a new table for this subsection with vertical and horizontal centering
                    push @output, "";
                    push @output, "\\vfill";
                    push @output, "\\begin{center}";
                    push @output, "\\arrayrulecolor{tablerowgray}";
                    push @output, "\\begin{tabularx}{\\textwidth}{Xrr}";  # ARTICLES, Hours, Minutes (no vertical lines)
                    push @output, "\\hline";
                    push @output, "\\multicolumn{3}{c}{\\textbf{Time Tables For Cooking — $subsection}} \\\\";
                    push @output, "\\hline";
                    push @output, "ARTICLES & Hours & Minutes \\\\";
                    push @output, "\\hline";

                    $j++;

                    # Skip blank lines
                    while ($j < @lines && $lines[$j] =~ /^\s*$/) {
                        $j++;
                    }

                    # Skip header lines (ARTICLES, TIME, Hours, Minutes)
                    while ($j < @lines) {
                        my $hdr = $lines[$j];
                        chomp($hdr);
                        $hdr =~ s/\r$//;
                        $hdr =~ s/^\s+//;
                        $hdr =~ s/\s+$//;
                        last unless $hdr =~ /^(ARTICLES?|TIME|Hours?|Minutes?|[:\s])+$/i;
                        $j++;
                    }

                    # Collect data rows for this subsection
                    my @table_data;
                    while ($j < @lines) {
                        my $row = $lines[$j];
                        chomp($row);
                        $row =~ s/\r$//;

                        # Stop at blank line followed by another subsection or end
                        if ($row =~ /^\s*$/) {
                            my $k = $j + 1;
                            while ($k < @lines && $lines[$k] =~ /^\s*$/) {
                                $k++;
                            }
                            if ($k < @lines) {
                                my $next = $lines[$k];
                                $next =~ s/\r$//;
                                # If next line is subsection header, NOTE, or new CHAPTER, we're done with this subsection
                                last if $next =~ /^\s+(Boiling|Broiling|Baking|Frying)\s*$/i;
                                last if $next =~ /^NOTE/i;
                                last if $next =~ /^\s*CHAPTER\s+/i;
                            } else {
                                last;
                            }
                            $j++;
                            next;
                        }

                        # Skip special notes like "or steam 2 hours and bake 1½"
                        if ($row =~ /^\s+(or |and )/i) {
                            $j++;
                            next;
                        }

                        # Data rows start with spaces followed by text
                        if ($row =~ /^\s{2,}\S/) {
                            # Keep original row to determine column positions
                            my $original_row = $row;
                            $row =~ s/^\s+//;  # Remove leading spaces for parsing

                            # Try to parse: name followed by time values
                            # Format could be: "name    time" or "name    hours    minutes"
                            my $formatted_row = "";

                            # First, try patterns with two time ranges (hours and minutes both present)
                            if ($row =~ /^(.+?)\s{2,}(\d+)\s+to\s+(\d+)\s+(\d+)\s+to\s+(\d+)$/) {
                                # Format: "name    H1 to H2    M1 to M2"
                                my ($name, $h1, $h2, $m1, $m2) = ($1, $2, $3, $4, $5);
                                $name =~ s/\s+$//;
                                $formatted_row = escape_latex($name) . " & $h1 to $h2 & $m1 to $m2 \\\\";
                            } elsif ($row =~ /^(.+?)\s{2,}(\d+\s+to\s+\d+)\s+(\d+\s+to\s+\d+)$/) {
                                # Format: "name    H1 to H2    M1 to M2"
                                my ($name, $hours, $mins) = ($1, $2, $3);
                                $name =~ s/\s+$//;
                                $formatted_row = escape_latex($name) . " & $hours & $mins \\\\";
                            } elsif ($row =~ /^(.+?)\s{2,}(\d+)\s+(\d+\s+to\s+\d+)$/) {
                                # Format: "name    hours    M1 to M2"
                                my ($name, $hours, $mins) = ($1, $2, $3);
                                $name =~ s/\s+$//;
                                $formatted_row = escape_latex($name) . " & $hours & $mins \\\\";
                            } elsif ($row =~ /^(.+?)\s{2,}(\d+)\s+(\d+)$/) {
                                # Format: "name    hours    minutes" (two separate values)
                                my ($name, $hours, $mins) = ($1, $2, $3);
                                $name =~ s/\s+$//;
                                $formatted_row = escape_latex($name) . " & $hours & $mins \\\\";
                            } elsif ($row =~ /^(.+?)\s{2,}([\d¼½¾]+(?:\s+to\s+[\d¼½¾]+)?)\s*$/) {
                                # Format: "name    X to Y" or "name    X" (single time range/value)
                                # Use column position in original row to determine if it's hours or minutes
                                my ($name, $time) = ($1, $2);
                                $name =~ s/\s+$//;

                                # Find where the time value starts in the original row
                                my $time_pos = index($original_row, $time);

                                # If time starts before column 60, it's hours; otherwise it's minutes
                                if ($time_pos < 60) {
                                    $formatted_row = escape_latex($name) . " & $time & \\\\";
                                } else {
                                    $formatted_row = escape_latex($name) . " &  & $time \\\\";
                                }
                            } else {
                                # Fallback: just output the row as-is in first column
                                $formatted_row = escape_latex($row) . " &  &  \\\\";
                            }

                            push @table_data, $formatted_row;
                        }
                        $j++;
                    }

                    # Check if this is the Baking table - if so, split into two separate tables
                    if ($subsection =~ /Baking/i && @table_data > 20) {
                        # Split the data into two halves
                        my $mid = int((@table_data + 1) / 2);
                        my @first_half = @table_data[0..$mid-1];
                        my @second_half = @table_data[$mid..$#table_data];

                        # First table - output first half
                        foreach my $row (@first_half) {
                            push @output, $row;
                            push @output, "\\hline";
                        }
                        push @output, "\\arrayrulecolor{black}";
                        push @output, "\\end{tabularx}";
                        push @output, "";
                        push @output, "\\vspace{2em}";
                        push @output, "";

                        # Second table - start new table with same headers (still within center environment)
                        push @output, "\\arrayrulecolor{tablerowgray}";
                        push @output, "\\begin{tabularx}{\\textwidth}{Xrr}";
                        push @output, "\\hline";
                        push @output, "ARTICLES & Hours & Minutes \\\\";
                        push @output, "\\hline";
                        foreach my $row (@second_half) {
                            push @output, $row;
                            push @output, "\\hline";
                        }
                        push @output, "\\arrayrulecolor{black}";
                        push @output, "\\end{tabularx}";
                        push @output, "\\end{center}";
                        push @output, "\\vfill";
                        push @output, "\\pagebreak";
                        push @output, "";
                    } else {
                        # Regular single-column table - output all rows
                        foreach my $row (@table_data) {
                            push @output, $row;
                            push @output, "\\hline";
                        }

                        # Close this subsection's table
                        push @output, "\\arrayrulecolor{black}";
                        push @output, "\\end{tabularx}";
                        push @output, "\\end{center}";
                        push @output, "\\vfill";
                        push @output, "\\pagebreak";
                        push @output, "";
                    }
                } else {
                    # Not a subsection header, skip this line
                    $j++;
                }
            }

            # Skip the lines we processed
            $i = $j - 1;
        }
        # Check if this is the cereals cooking table
        elsif ($section_title =~ /Table For Cooking Cereals/i) {
            # This table has: Kind, Quantity, Water, Time columns
            # Multi-line entries where product names span multiple lines
            my $j = $i + 1;

            # Skip blank lines
            while ($j < @lines && $lines[$j] =~ /^\s*$/) {
                $j++;
            }

            # Skip header line (contains "Kind", "Quantity", "Water", "Time")
            if ($j < @lines && $lines[$j] =~ /(Kind|Quantity|Water|Time)/) {
                $j++;
            }

            # Skip another blank line
            while ($j < @lines && $lines[$j] =~ /^\s*$/) {
                $j++;
            }

            # Collect table rows - need to group multi-line entries
            my @table_rows;
            my $current_row = "";
            my $row_complete = 0;

            while ($j < @lines) {
                my $line = $lines[$j];
                chomp($line);
                $line =~ s/\r$//;

                # Stop at blank line followed by next section
                if ($line =~ /^\s*$/) {
                    # If we completed a row and hit blank line, save it and start fresh
                    if ($row_complete && $current_row) {
                        push @table_rows, $current_row;
                        $current_row = "";
                        $row_complete = 0;
                    }
                    # Check if we're at end of table - look for a section heading or non-indented text
                    my $k = $j + 1;
                    while ($k < @lines && $lines[$k] =~ /^\s*$/) {
                        $k++;
                    }
                    if ($k >= @lines) {
                        last;
                    }
                    # If next line doesn't start with spaces, we're done
                    my $nextline = $lines[$k];
                    $nextline =~ s/\r$//;
                    last if $nextline !~ /^\s+\S/;
                    $j++;
                    next;
                }

                # Add this line to current row
                $current_row .= " " if $current_row;
                $current_row .= $line;

                # Check if this line completes the row (has time units)
                if ($line =~ /\d+\s*(minutes?|hours?)/i) {
                    $row_complete = 1;
                }

                $j++;
            }

            # Save last row if any
            if ($current_row) {
                push @table_rows, $current_row;
            }

            # Generate LaTeX table
            if (@table_rows > 0) {
                push @output, "";
                push @output, "\\begin{tabular}{p{2in}p{0.8in}p{1.2in}p{1in}}";
                push @output, "\\hline";
                push @output, "Kind & Quantity & Water & Time \\\\";
                push @output, "\\hline";

                my $row_num = 0;
                foreach my $row (@table_rows) {
                    $row =~ s/^\s+//;  # Remove leading spaces
                    $row =~ s/\s+/ /g;  # Normalize all whitespace to single spaces

                    # Special case: if row starts with water amount (e.g., "2¾–3¼ cups Rice...")
                    # Extract the leading water amount first
                    my $leading_water = "";
                    if ($row =~ /^(\d+(?:\s*\d+\/\d+|[½¾¼⅓⅔])?(?:–|--|-)\d+(?:\s*\d+\/\d+|[½¾¼⅓⅔])?\s+cups?)\s+(.+)$/i) {
                        $leading_water = $1;
                        $row = $2;  # Continue with the rest
                    }

                    # Try to parse: kind (text), quantity (X cup), water (Y cups), time (Z minutes/hours)
                    # Look for pattern: text ... N cup ... M cups ... X minutes/hours
                    # Also capture any text after time
                    if ($row =~ /^(.+?)\s+(\d+(?:\s+\d+\/\d+|\.\d+|\/\d+|[½¾¼⅓⅔⅛⅜⅝⅞])?\s*cups?)\s+(.+?)\s+(\d+(?:–\d+)?\s*(?:minutes?|hours?))\s*(.*)$/i) {
                        my ($kind, $qty, $water, $time, $trailing) = ($1, $2, $3, $4, $5);
                        $kind =~ s/\s+$//;

                        # If we found a leading water amount, use it; otherwise use parsed water
                        if ($leading_water) {
                            # Combine leading water with any additional water description
                            $water = $leading_water . " " . $water;
                        }

                        # Decide where to put trailing text based on its content
                        if ($trailing && $trailing =~ /\S/) {
                            $trailing =~ s/^\s+|\s+$//g;  # Trim whitespace
                            # If trailing starts with lowercase or "(", it's a water description
                            # Otherwise it's product names for the kind column
                            if ($trailing =~ /^[a-z(]/) {
                                $water .= " " . $trailing;
                            } else {
                                # Product names - add to kind
                                $kind .= " " . $trailing;
                            }
                        }

                        $water =~ s/\s+$//;
                        push @output, escape_latex($kind) . " & " . escape_latex($qty) . " & " . escape_latex($water) . " & " . escape_latex($time) . " \\\\";
                    } else {
                        # Fallback: try simpler pattern or output as-is
                        push @output, escape_latex($row) . " &  &  &  \\\\";
                    }

                    # Add light grey line between rows (but not after last row)
                    $row_num++;
                    if ($row_num < scalar(@table_rows)) {
                        push @output, "\\arrayrulecolor{tablerowgray}\\hline";
                    }
                }
                push @output, "\\arrayrulecolor{black}";

                push @output, "\\hline";
                push @output, "\\end{tabular}";
                push @output, "";
            }

            # Skip the lines we processed
            $i = $j - 1;
        }
        # Check if this is the beef cuts table
        elsif ($section_title =~ /Division And Ways Of Cooking A Side Of Beef/i) {
            # This table has two columns: DIVISIONS and WAYS OF COOKING
            # Some entries have sub-divisions with extra indentation
            my $j = $i + 1;

            # Start the table
            push @output, "";
            push @output, "\\begin{tabular}{|p{2.5in}|p{2.5in}|}";
            push @output, "\\hline";

            # We'll process sections: HIND-QUARTER and FORE-QUARTER
            while ($j < @lines) {
                my $line = $lines[$j];
                chomp($line);
                $line =~ s/\r$//;

                # Check if we've hit the next section (looks like a heading with 4-10 spaces)
                if ($line =~ /^\s{4,10}[A-Z]/ && $line !~ /(HIND-QUARTER|FORE-QUARTER|DIVISIONS|WAYS OF COOKING|Other Parts)/i) {
                    # This looks like the next section heading, stop here
                    last;
                }

                # Check if we've hit a blank line
                if ($line =~ /^\s*$/) {
                    $j++;
                    next;
                }

                # Check for subsection headers (HIND-QUARTER, FORE-QUARTER, Other Parts)
                if ($line =~ /^\s+(HIND-QUARTER|FORE-QUARTER)\s*$/i) {
                    push @output, "\\multicolumn{2}{|c|}{\\textbf{" . escape_latex($1) . "}} \\\\";
                    push @output, "\\hline";
                    $j++;
                    next;
                }

                # Check for "Other Parts of Beef Creature used for Food" subsection
                if ($line =~ /^\s+Other Parts of Beef/i) {
                    push @output, "\\multicolumn{2}{|c|}{\\textbf{Other Parts of Beef Creature used for Food}} \\\\";
                    push @output, "\\hline";
                    $j++;
                    next;
                }

                # Skip column headers (DIVISIONS, WAYS OF COOKING)
                if ($line =~ /(DIVISIONS|WAYS OF COOKING)/i) {
                    $j++;
                    next;
                }

                # Parse table rows
                # Three formats:
                # 1. " Main-Division    Cooking" (e.g., "Flank (thick and boneless)    Stuffed...")
                # 2. " Main-Division    Sub-Division    Cooking" (e.g., "Round    Aitchbone    Cheap roast...")
                # 3. "                  Sub-Division    Cooking" (very indented sub-divisions)

                # Format 1 & 2: Line starts with 1 space and division name
                if ($line =~ /^\s{1}(\S.+?)\s{2,}(.+)$/) {
                    my ($col1, $rest) = ($1, $2);
                    $col1 =~ s/\s+$//;
                    $rest =~ s/^\s+//;

                    # Check if rest has two columns (sub-division + cooking)
                    if ($rest =~ /^(\S.+?)\s{2,}(.+)$/) {
                        # Format 2: Main + Sub + Cooking
                        my ($sub, $cooking) = ($1, $2);
                        $sub =~ s/\s+$//;
                        $cooking =~ s/\s+$//;

                        # Collect continuation lines
                        my $k = $j + 1;
                        while ($k < @lines) {
                            my $next = $lines[$k];
                            chomp($next);
                            $next =~ s/\r$//;
                            # Sub-division continuation: 15-25 spaces
                            if ($next =~ /^\s{15,25}(\S.+)$/) {
                                $sub .= " " . $1;
                                $k++;
                            }
                            # Cooking continuation: 35+ spaces
                            elsif ($next =~ /^\s{35,}(.+)$/) {
                                $cooking .= " " . $1;
                                $k++;
                            } else {
                                last;
                            }
                        }

                        push @output, escape_latex("$col1 — $sub") . " & " . escape_latex($cooking) . " \\\\";
                        push @output, "\\arrayrulecolor{tablerowgray}\\hline";
                        $j = $k;
                    } else {
                        # Format 1: Main + Cooking (no sub-division)
                        my $cooking = $rest;

                        # Collect continuation lines
                        my $k = $j + 1;
                        while ($k < @lines) {
                            my $next = $lines[$k];
                            chomp($next);
                            $next =~ s/\r$//;
                            if ($next =~ /^\s{30,}(.+)$/) {
                                $cooking .= " " . $1;
                                $k++;
                            } else {
                                last;
                            }
                        }

                        push @output, escape_latex($col1) . " & " . escape_latex($cooking) . " \\\\";
                        push @output, "\\arrayrulecolor{tablerowgray}\\hline";
                        $j = $k;
                    }
                }
                # Format 3: Very indented sub-division
                elsif ($line =~ /^\s{15,}(\S.+?)\s{2,}(.+)$/) {
                    my ($sub, $cooking) = ($1, $2);
                    $sub =~ s/\s+$//;
                    $cooking =~ s/\s+$//;

                    # Collect continuation lines
                    my $k = $j + 1;
                    while ($k < @lines) {
                        my $next = $lines[$k];
                        chomp($next);
                        $next =~ s/\r$//;
                        if ($next =~ /^\s{30,}(.+)$/) {
                            $cooking .= " " . $1;
                            $k++;
                        } else {
                            last;
                        }
                    }

                    push @output, "\\hspace{0.3in}" . escape_latex($sub) . " & " . escape_latex($cooking) . " \\\\";
                    push @output, "\\arrayrulecolor{tablerowgray}\\hline";
                    $j = $k;
                } else {
                    $j++;
                }
            }

            push @output, "\\arrayrulecolor{black}";
            push @output, "\\end{tabular}";
            push @output, "";

            # Skip the lines we processed
            $i = $j - 1;
        }

        # Skip any blank lines immediately following the section
        while ($i + 1 < @lines && $lines[$i + 1] =~ /^\s*$/) {
            $i++;
        }

        next;
    }

    # Check if this line matches an h4 heading (subsection)
    if (exists $h4_headings{$normalized_line} &&
        $h4_used_count{$normalized_line} < $h4_max_count{$normalized_line}) {
        my $heading = $h4_headings{$normalized_line};
        my $escaped_heading = escape_latex($heading);

        push @output, "";
        push @output, "\\needspace{15\\baselineskip}"; # Prevent recipe from splitting across pages
        push @output, "\\subsection*{$escaped_heading}";
        push @output, "";

        $h4_used_count{$normalized_line}++;

        # Skip any blank lines immediately following the subsection
        while ($i + 1 < @lines && $lines[$i + 1] =~ /^\s*$/) {
            $i++;
        }

        next;
    }

    # Check for composition blocks (BEFORE escaping, so we can see original text)
    if ($line =~ /^\s+COMPOSITION\s*$/) {
        # Look ahead to collect composition data lines
        my @comp_lines;
        my $j = $i + 1;

        while ($j < @lines) {
            my $compline = $lines[$j];
            chomp($compline);

            # Skip blank lines
            if ($compline =~ /^\s*$/) {
                $j++;
                next;
            }

            # Check if this line is part of the composition data
            if ($compline =~ /^\s+(.+)\s*$/) {
                my $content = $1;

                # Stop if we hit a long paragraph (>50 chars starting with capital and lowercase)
                last if $content =~ /^[A-Z][a-z].{50,}/;

                push @comp_lines, $content;
                $j++;

                # Stop after we get the citation (ends with period)
                last if $content =~ /\.$/;
                # Safety: stop after 10 lines
                last if scalar(@comp_lines) > 10;
            } else {
                last;
            }
        }

        if (@comp_lines >= 2) {
            # Generate formatted composition block as a table
            push @output, "";

            # Center the table if it comes right after a chapter
            if ($after_chapter) {
                push @output, "\\begin{center}";
            }

            push @output, "\\begin{tabular}{|l|r|}";
            push @output, "\\hline";
            push @output, "\\multicolumn{2}{|l|}{\\textbf{Composition}} \\\\";
            push @output, "\\hline";

            foreach my $comp (@comp_lines) {
                # Check if this is an attribution line (italic text like "_Boston Chemist._")
                if ($comp =~ /^_(.+)_$/) {
                    # Attribution line - right-aligned, italic, spanning both columns
                    my $attribution = $1;
                    my $escaped = escape_latex($attribution);
                    push @output, "\\multicolumn{2}{|r|}{\\textit{$escaped}} \\\\";
                    push @output, "\\hline";
                } elsif ($comp =~ /^(.+?),\s+(.+?)%?\s*$/) {
                    # Data line with item and percentage (e.g., "Protein, 14.9%")
                    my $item = $1;
                    my $value = $2;
                    my $escaped_item = escape_latex($item);
                    my $escaped_value = escape_latex($value);
                    # Add % if not already there
                    $escaped_value .= "\\%" unless $escaped_value =~ /%/;
                    push @output, "$escaped_item & $escaped_value \\\\";
                    push @output, "\\hline";
                } else {
                    # Fallback: output as-is in a single spanning cell
                    my $escaped = escape_latex($comp);
                    push @output, "\\multicolumn{2}{|l|}{$escaped} \\\\";
                    push @output, "\\hline";
                }
            }

            push @output, "\\end{tabular}";

            # Close center if we opened it
            if ($after_chapter) {
                push @output, "\\end{center}";
                $after_chapter = 0;  # Reset flag
            }

            # Add bottom margin and prevent indentation of next paragraph
            push @output, "";
            push @output, "\\vspace{10pt}";
            push @output, "";
            push @output, "\\noindent";

            # Skip the COMPOSITION line and all the data lines we've processed
            $i = $j - 1;
            next;
        }
    }

    # Check for standalone shared-quantity tables (not within an ingredient list)
    # These tables appear before any ingredients, so they won't be caught by ingredient collection
    # Must be BEFORE escape_latex so we can detect the Unicode box-drawing characters
    if ($line =~ /^\s+[─┬]+/ && $line =~ /[─┬]/) {
        # This is the opening line of a shared quantity table
        my $j = $i + 1;
        my @table_ingredients;
        my $quantity = "";

        # Look for the ingredient lines with │ and extract the quantity
        while ($j < @lines) {
            my $tableline = $lines[$j];
            chomp($tableline);
            $tableline =~ s/\r$//;

            # Check if this is the closing line
            if ($tableline =~ /^\s+[─┴]+/ && $tableline =~ /[─┴]/) {
                $i = $j; # Move past the closing line
                last;
            }

            # Check if this is an ingredient line with │
            if ($tableline =~ /^\s+(.+?)│(.*)$/) {
                my $ingredient = $1;
                my $qty_part = $2;

                # Remove trailing/leading whitespace
                $ingredient =~ s/\s+$//;
                $qty_part =~ s/^\s+|\s+$//g;

                # If this line has the quantity (contains "each"), extract it
                if ($qty_part && $qty_part =~ /(.+?)\s+each/i) {
                    $quantity = $1;
                    # Convert Unicode fractions
                    $quantity =~ s/½/1\/2/g;
                    $quantity =~ s/¼/1\/4/g;
                    $quantity =~ s/⅓/1\/3/g;
                    $quantity =~ s/⅔/2\/3/g;
                    $quantity =~ s/¾/3\/4/g;
                    # Add this ingredient
                    push @table_ingredients, lc($ingredient);
                } elsif ($qty_part eq "" && $ingredient) {
                    # Just an ingredient name, no quantity on this line
                    push @table_ingredients, lc($ingredient);
                }
            }

            $j++;
        }

        # If we found ingredients and a quantity, insert expanded lines
        # so they can be picked up by the next ingredient list detection
        if (@table_ingredients > 0 && $quantity) {
            my @expanded;
            foreach my $ing (@table_ingredients) {
                # Create a properly formatted ingredient line with enough indentation
                my $expanded_line = " " x 25 . "$quantity $ing";
                push @expanded, $expanded_line;
            }

            # Insert the expanded lines into @lines array after current position
            splice(@lines, $i + 1, 0, @expanded);
        }

        next;
    }

    # Escape LaTeX special characters
    $line = escape_latex($line);

    # Check for chapter headings
    if ($line =~ /^\s+CHAPTER ([IVXLCDM]+)\s*$/) {
        my $next_line = $i + 1 < @lines ? $lines[$i + 1] : '';
        chomp($next_line);
        $next_line =~ s/^\s+|\s+$//g;

        if ($next_line =~ /^[A-ZÀ-ÿ\s\-',:]+$/i && length($next_line) < 60) {
            my $title = escape_latex($next_line);
            $title = lc($title);
            $title =~ s/\b(\w)/\U$1/g;  # Title case

            push @output, "";
            push @output, "\\chapter{$title}";
            push @output, "";
            $after_chapter = 1;  # Flag that we just output a chapter

            # Check if this is the "Suitable Combinations For Serving" chapter
            if ($next_line =~ /SUITABLE COMBINATIONS FOR SERVING/i) {
                $in_menu_chapter = 1;

                # Process the rest of the chapter as menus
                $i += 2;  # Skip the chapter title line and next blank line
                my @current_menu = ();

                while ($i < @lines) {
                    my $menu_line = $lines[$i];
                    chomp($menu_line);
                    $menu_line =~ s/\r$//;

                    # Check for ☸ separator
                    if ($menu_line =~ /^\s*☸+\s*$/) {
                        # Output the collected menu as a table
                        if (@current_menu > 0) {
                            # First, split each item by multiple spaces to detect columns
                            my @rows;
                            my $max_cols = 1;

                            foreach my $item (@current_menu) {
                                # Split on 2 or more spaces
                                my @cols = split(/\s{2,}/, $item);
                                push @rows, \@cols;
                                $max_cols = @cols if @cols > $max_cols;
                            }

                            # Create table with appropriate number of columns
                            push @output, "";
                            push @output, "\\vspace{1em}";
                            push @output, "\\begin{center}";
                            push @output, "{\\renewcommand{\\arraystretch}{1.5}";  # Increase row height
                            my $col_spec = "|" . (">{\\hspace{0.5em}}c<{\\hspace{0.5em}}|" x $max_cols);
                            push @output, "\\begin{tabular}{$col_spec}";
                            push @output, "\\hline";

                            foreach my $row (@rows) {
                                my @escaped_cols;
                                foreach my $col (@$row) {
                                    my $escaped_col = escape_latex($col);
                                    $escaped_col =~ s/^\s+|\s+$//g;  # Trim whitespace
                                    push @escaped_cols, $escaped_col;
                                }

                                # If only one column, use multicolumn to span all columns
                                if (@escaped_cols == 1) {
                                    push @output, "\\multicolumn{$max_cols}{|c|}{$escaped_cols[0]} \\\\ \\hline";
                                } else {
                                    # Pad with empty cells if needed
                                    while (@escaped_cols < $max_cols) {
                                        push @escaped_cols, "";
                                    }
                                    push @output, join(" & ", @escaped_cols) . " \\\\ \\hline";
                                }
                            }

                            push @output, "\\end{tabular}}";  # Close arraystretch group
                            push @output, "\\end{center}";
                            push @output, "\\vspace{0.5em}";
                            push @output, "";

                            @current_menu = ();
                        }
                        $i++;
                        next;
                    }

                    # Check for section headers like "Breakfast Menus"
                    if ($menu_line =~ /^\s+([A-Z][a-z]+\s+Menus?)\s*$/i) {
                        my $section = $1;
                        my $escaped_section = escape_latex($section);
                        $escaped_section =~ s/\b(\w)/\U$1/g;  # Title case
                        push @output, "";
                        push @output, "\\section*{\\centering $escaped_section}";
                        push @output, "";
                        $i++;
                        next;
                    }

                    # Check for blank lines - skip them
                    if ($menu_line =~ /^\s*$/) {
                        # Just skip blank lines
                    }
                    # Check for illustrations
                    elsif ($menu_line =~ /^\[Illustration/) {
                        # Skip until closing bracket
                        while ($i < @lines) {
                            $i++;
                            last if $i >= @lines;
                            $menu_line = $lines[$i];
                            chomp($menu_line);
                            last if $menu_line =~ /^\]$/;
                        }
                    }
                    # Check if this is the end of the book content (INDEX, etc.)
                    elsif ($menu_line =~ /^\s*(INDEX|GLOSSARY|THE END)\s*$/i) {
                        last;
                    }
                    # Otherwise, treat any line with content as a menu item
                    elsif ($menu_line =~ /\S/) {  # Has non-whitespace content
                        my $item = $menu_line;
                        $item =~ s/^\s+|\s+$//g;  # Trim leading/trailing whitespace
                        push @current_menu, $item if $item;  # Only add if not empty after trimming
                    }

                    $i++;
                }

                # Output any remaining menu
                if (@current_menu > 0) {
                    # First, split each item by multiple spaces to detect columns
                    my @rows;
                    my $max_cols = 1;

                    foreach my $item (@current_menu) {
                        # Split on 2 or more spaces
                        my @cols = split(/\s{2,}/, $item);
                        push @rows, \@cols;
                        $max_cols = @cols if @cols > $max_cols;
                    }

                    # Create table with appropriate number of columns
                    push @output, "";
                    push @output, "\\vspace{1em}";
                    push @output, "\\begin{center}";
                    push @output, "{\\renewcommand{\\arraystretch}{1.5}";  # Increase row height
                    my $col_spec = "|" . (">{\\hspace{0.5em}}c<{\\hspace{0.5em}}|" x $max_cols);
                    push @output, "\\begin{tabular}{$col_spec}";
                    push @output, "\\hline";

                    foreach my $row (@rows) {
                        my @escaped_cols;
                        foreach my $col (@$row) {
                            my $escaped_col = escape_latex($col);
                            $escaped_col =~ s/^\s+|\s+$//g;  # Trim whitespace
                            push @escaped_cols, $escaped_col;
                        }

                        # If only one column, use multicolumn to span all columns
                        if (@escaped_cols == 1) {
                            push @output, "\\multicolumn{$max_cols}{|c|}{$escaped_cols[0]} \\\\ \\hline";
                        } else {
                            # Pad with empty cells if needed
                            while (@escaped_cols < $max_cols) {
                                push @escaped_cols, "";
                            }
                            push @output, join(" & ", @escaped_cols) . " \\\\ \\hline";
                        }
                    }

                    push @output, "\\end{tabular}}";  # Close arraystretch group
                    push @output, "\\end{center}";
                    push @output, "";
                }

                # We've processed the entire chapter, so we can break out of the main loop
                last;
            }

            $i++;  # Skip the next line
            next;
        }
    }

    # Check for TABLE OF CONTENTS - replace with automatic TOC
    if ($line =~ /^\s+TABLE OF CONTENTS\s*$/) {
        push @output, "";
        push @output, "\\tableofcontents";
        push @output, "";

        # Skip all lines until we find the next section (LIST OF ILLUSTRATIONS or first CHAPTER)
        my $skip_toc = 1;
        while ($skip_toc && $i + 1 < @lines) {
            $i++;
            my $next = $lines[$i];
            chomp($next);

            # Stop skipping when we hit the next major section
            if ($next =~ /^\s+(LIST OF ILLUSTRATIONS|CHAPTER [IVXLCDM]+)\s*$/) {
                $i--;  # Back up one line so we process this line normally
                $skip_toc = 0;
            }
        }
        next;
    }

    # Check for LIST OF ILLUSTRATIONS - skip entire section
    if ($line =~ /^\s+LIST OF ILLUSTRATIONS\s*$/) {
        # Skip all lines until we find the next major section (first CHAPTER or book title)
        my $skip_loi = 1;
        while ($skip_loi && $i + 1 < @lines) {
            $i++;
            my $next = $lines[$i];
            chomp($next);

            # Stop skipping when we hit the book title or first chapter
            if ($next =~ /^\s+(THE BOSTON COOKING-SCHOOL COOK BOOK|CHAPTER [IVXLCDM]+)\s*$/) {
                $i--;  # Back up one line so we process this line normally
                $skip_loi = 0;
            }
        }
        next;
    }

    # Check for other major headings (PREFACE, GLOSSARY, INDEX)
    if ($line =~ /^\s+(PREFACE.*|GLOSSARY|INDEX)\s*$/i) {
        my $heading = $1;
        $heading =~ s/^\s+|\s+$//g;  # Trim whitespace
        $heading = lc($heading);
        $heading =~ s/\b(\w)/\U$1/g;  # Title case

        push @output, "";
        push @output, "\\chapter*{$heading}";
        push @output, "";
        $after_chapter = 1;  # Flag that we just output a chapter
        next;
    }

    # Check for the line before the food classification table
    if ($line =~ /^\s+1\.\s+Protein\s+\(nitrogenous or albuminous\)/) {
        # Check if next line is "I. ORGANIC"
        if ($i + 1 < @lines && $lines[$i + 1] =~ /^\s+I\.\s+ORGANIC\s+/) {
            # This is the food classification table - create it
            push @output, "";
            push @output, "\\begin{tabular}{clp{3.5in}}";

            # Row 1: I. ORGANIC
            push @output, "I. & ORGANIC & 1. Protein (nitrogenous or albuminous) \\\\";
            push @output, " & & 2. Carbohydrates (sugar and starch) \\\\";
            push @output, " & & 3. Fats and oils \\\\[0.5em]";

            # Row 2: II. INORGANIC
            push @output, "II. & INORGANIC & 1. Mineral matter \\\\";
            push @output, " & & 2. Water \\\\";

            push @output, "\\end{tabular}";
            push @output, "";

            # Skip the next 6 lines (the rest of the table structure)
            for (my $skip = 0; $skip < 6 && $i + 1 < @lines; $skip++) {
                $i++;
            }
            next;
        }
    }

    # Check for measurement/conversion tables (pattern: number + description + = + value)
    if ($line =~ /^\s+\d+/ && $line =~ /=\s*1\s+pound/) {
        # Start of a measurement table - look ahead to collect all rows
        my @table_rows;
        my $j = $i;

        while ($j < @lines) {
            my $tline = $lines[$j];
            chomp($tline);
            $tline = escape_latex($tline);

            # Check if this line is part of the table
            if ($tline =~ /^\s+(\d+\/?\d*)\s+(.+?)\s+(=\s*.+)$/) {
                push @table_rows, [$1, $2, $3];
                $j++;
            } else {
                last;
            }
        }

        if (@table_rows > 0) {
            # Generate LaTeX table
            push @output, "";
            push @output, "\\begin{tabular}{rll}";

            foreach my $row (@table_rows) {
                my $formatted = sprintf("%s & %s & %s \\\\", $row->[0], $row->[1], $row->[2]);
                push @output, $formatted;
            }

            push @output, "\\end{tabular}";
            push @output, "";

            # Skip the lines we've processed
            $i = $j - 1;
            next;
        }
    }

    # Check for vegetables parts table (introduced by "For the various vegetables different parts")
    if ($line =~ /For the various vegetables different parts of the plant are used/i) {
        # Output the introduction paragraph
        push @output, escape_latex($line);
        my $j = $i + 1;

        # Get the next line "are eaten in the natural state, others are cooked."
        if ($j < @lines && $lines[$j] =~ /\S/) {
            push @output, escape_latex($lines[$j]);
            $j++;
        }

        # Skip blank lines
        while ($j < @lines && $lines[$j] =~ /^\s*$/) {
            $j++;
        }

        # Start the table
        push @output, "";
        push @output, "\\arrayrulecolor{tablerowgray}";
        push @output, "\\begin{tabular}{|p{1in}|p{3.5in}|}";
        push @output, "\\hline";

        # Process table rows
        while ($j < @lines) {
            my $tline = $lines[$j];
            chomp($tline);
            $tline =~ s/\r$//;

            # Stop at next paragraph (line that doesn't start with space or is blank followed by non-table content)
            if ($tline =~ /^\s*$/) {
                $j++;
                # Check if we've reached the end of the table
                if ($j < @lines && $lines[$j] =~ /^[A-Z]/ && $lines[$j] !~ /^\s+[A-Z]/) {
                    last;
                }
                next;
            }

            # Parse table row: " Category  Examples"
            if ($tline =~ /^\s+([A-Z][a-z]+)\s{2,}(.+)$/) {
                my ($category, $examples) = ($1, $2);
                $examples =~ s/\s+$//;

                # Collect continuation lines (heavily indented)
                my $k = $j + 1;
                while ($k < @lines) {
                    my $cont = $lines[$k];
                    chomp($cont);
                    $cont =~ s/\r$//;

                    # Check if it's a continuation (10+ spaces, no category name at start)
                    if ($cont =~ /^\s{10,}(.+)$/) {
                        $examples .= " " . $1;
                        $k++;
                    } else {
                        last;
                    }
                }

                push @output, escape_latex($category) . " & " . escape_latex($examples) . " \\\\";
                push @output, "\\hline";
                $j = $k;
            } else {
                $j++;
            }
        }

        push @output, "\\arrayrulecolor{black}";
        push @output, "\\end{tabular}";
        push @output, "";

        # Skip the lines we processed
        $i = $j - 1;
        next;
    }

    # Check for recipe ingredient lists (indented lines with measurements)
    # Match patterns like: 1 cup, 1/2 cup, 1 1/2 cup, 2 3/4 to 3 1/4 cups, 4 eggs, 3 "hard-boiled" eggs, 6 lbs, 3 large cucumbers (after escape_latex converts Unicode fractions)
    # Also match standalone ingredients like Salt, Pepper, Butter
    # Require at least 7 spaces of indentation to distinguish from regular text
    if ($line =~ /^\s{7,}(\d+(?:\s+\d+\/\d+)?|\d+\/\d+)(?:\s+(?:to|-|--)\s+\d+(?:\s+\d+\/\d+)?|\d+\/\d+)?\s+(?:.*?\s+)?(cup|tablespoon|teaspoon|pound|lb|quart|pint|gallon|peck|slice|sprig|stalk|can|square|ounce|egg|cucumber|crab|clove|head|artichoke|potato|potatoe|turnip|leek|breast|terrapin|oyster|knuckle|veal|beet|pepper|onion|tomatoe|chicken|fish|shrimp|lobster|salmon|lamb|pork|beef|mutton|duck|turkey|sardine|anchovy|scallop|sweetbread|carrot|almond|celery|mushroom|squash|radish|parsnip|bean|pea|apple|orange|lemon|lime|banana|peach|pear|plum|cherry|chocolate|grape|roll|biscuit|cracker|cookie|truffle|crumb|quail|loaf|box|gelatine|clam|pineapple)s?\.?(?:\s+|$)/i || $line =~ /^\s{7,}(Salt|Pepper|Butter)(\s+and\s+\w+)?\s*$/i) {
        # Start of ingredient list - look ahead to collect all ingredients
        my @ingredients;
        my $j = $i;

        while ($j < @lines) {
            my $ingline = $lines[$j];
            chomp($ingline);
            $ingline =~ s/\r$//;  # Remove carriage return

            # Check if we hit a shared-quantity table (check BEFORE escaping)
            if ($ingline =~ /^\s+[─┬]+/ && $ingline =~ /[─┬]/) {
                # This is a shared-quantity table - expand it inline
                my $table_start = $j;
                my @table_ingredients;
                my $quantity = "";
                $j++;  # Move past the opening line

                # Collect ingredients from the table
                while ($j < @lines) {
                    my $tableline = $lines[$j];
                    chomp($tableline);
                    $tableline =~ s/\r$//;

                    # Check if this is the closing line
                    if ($tableline =~ /^\s+[─┴]+/ && $tableline =~ /[─┴]/) {
                        $j++;  # Move past the closing line
                        last;
                    }

                    # Check if this is an ingredient line with │
                    if ($tableline =~ /^\s+(.+?)│(.*)$/) {
                        my $ingredient = $1;
                        my $qty_part = $2;

                        # Remove trailing/leading whitespace
                        $ingredient =~ s/\s+$//;
                        $qty_part =~ s/^\s+|\s+$//g;

                        # If this line has the quantity (contains "each"), extract it
                        if ($qty_part && $qty_part =~ /(.+?)\s+each/i) {
                            $quantity = $1;
                            # Convert Unicode fractions in quantity
                            $quantity =~ s/½/1\/2/g;
                            $quantity =~ s/⅓/1\/3/g;
                            $quantity =~ s/¼/1\/4/g;
                            $quantity =~ s/⅔/2\/3/g;
                            $quantity =~ s/¾/3\/4/g;
                            # Add this ingredient
                            push @table_ingredients, lc($ingredient);
                        } elsif ($qty_part eq "" && $ingredient) {
                            # Just an ingredient name, no quantity on this line
                            push @table_ingredients, lc($ingredient);
                        }
                    }

                    $j++;
                }

                # Add expanded ingredients to the main ingredient list
                if (@table_ingredients > 0 && $quantity) {
                    foreach my $ing (@table_ingredients) {
                        push @ingredients, "$quantity $ing";
                    }
                }

                # Continue collecting more ingredients after the table
                next;
            }

            # Now escape for LaTeX
            $ingline = escape_latex($ingline);

            # Check if this line is an ingredient (starts with measurement)
            if ($ingline =~ /^\s{7,}(.+)$/) {
                my $ing = $1;
                # Stop if we hit a blank line or non-ingredient text
                if ($ing =~ /^\s*$/ || $ing =~ /^[A-Z][a-z].*\.$/) {
                    last;
                }
                push @ingredients, $ing;
                $j++;
            } else {
                last;
            }
        }

        if (@ingredients >= 2) {  # At least 2 ingredients to be considered a list
            # Generate formatted ingredient list
            push @output, "";

            # Use two columns if more than 5 items
            if (@ingredients > 5) {
                push @output, "\\begin{minipage}{0.7\\textwidth}";
                push @output, "{\\setlength{\\multicolsep}{0pt}\\setlength{\\columnsep}{2em}\\raggedcolumns%";
                push @output, "\\begin{multicols}{2}";
            }

            push @output, "\\begin{itemize}";
            push @output, "\\setlength{\\itemsep}{0pt}";
            push @output, "\\setlength{\\parsep}{0pt}";

            foreach my $ing (@ingredients) {
                push @output, "\\item $ing";
            }

            push @output, "\\end{itemize}";

            if (@ingredients > 5) {
                push @output, "\\end{multicols}}";
                push @output, "\\end{minipage}";
                push @output, "";
                push @output, "\\vspace{0.3em}";
            } else {
                # Reduce spacing for single-column lists to match two-column
                push @output, "";
                push @output, "\\vspace{-0.5em}"; # Compensates for parskip (0.8em - 0.5em = 0.3em)
            }

            # Get the next non-blank line and output it with noindent
            while ($j < @lines && $lines[$j] =~ /^\s*$/) {
                $j++;
            }

            if ($j < @lines) {
                my $nextline = $lines[$j];
                chomp($nextline);
                $nextline =~ s/\r$//;
                $nextline = escape_latex($nextline);
                push @output, "\\noindent%";
                push @output, $nextline;
                $i = $j;
            } else {
                push @output, "\\noindent%";
                $i = $j - 1;
            }

            next;
        }
    }

    # Check for bulleted list (lines starting with "- ")
    if ($line =~ /^- (.+)$/) {
        my @bullet_items;
        my $first_item = $1;
        push @bullet_items, $first_item;

        # Look ahead for more bullet items
        my $j = $i + 1;
        while ($j < @lines) {
            my $nextline = $lines[$j];
            chomp($nextline);
            $nextline =~ s/\r$//;

            if ($nextline =~ /^- (.+)$/) {
                push @bullet_items, $1;
                $j++;
            } else {
                last;
            }
        }

        # Create bulleted list
        push @output, "";
        push @output, "\\begin{itemize}";
        push @output, "\\setlength{\\itemsep}{0pt}";

        foreach my $item (@bullet_items) {
            my $escaped_item = escape_latex($item);
            push @output, "\\item $escaped_item";
        }

        push @output, "\\end{itemize}";
        push @output, "";

        # Skip the lines we've processed
        $i = $j - 1;
        next;
    }

    # Add the line
    push @output, $line;
}

push @output, "";
push @output, "\\end{document}";

# Write output
my $output_file = 'the-boston-cooking-school-cook-book.tex';
open(my $out, '>:utf8', $output_file) or die "Cannot open $output_file: $!";
print $out join("\n", @output);
close($out);

print "Conversion complete! Created $output_file\n";

# Subroutine to normalize headings for comparison
sub normalize_heading {
    my ($text) = @_;
    # Remove leading/trailing whitespace
    $text =~ s/^\s+|\s+$//g;
    # Normalize internal whitespace to single spaces
    $text =~ s/\s+/ /g;
    # Remove subscript notation _{digits} to match HTML headings (which don't have subscripts)
    $text =~ s/\_\{\d+\}//g;
    # Remove all remaining digits (chemical formulas in HTML have digits, but we want to ignore them for matching)
    $text =~ s/\d+//g;
    # Convert to uppercase for case-insensitive comparison
    $text = uc($text);
    return $text;
}

# Subroutine to escape LaTeX special characters
sub escape_latex {
    my ($text) = @_;

    # Replace Unicode box-drawing characters with simple ASCII
    $text =~ s/[─━]/--/g;    # horizontal lines
    $text =~ s/[┌┬┐┼├┤└┴┘]/+/g;  # corners and intersections
    $text =~ s/[│┃]/|/g;     # vertical lines

    # Replace common Unicode fraction and special characters
    # Add space before fraction if preceded by a digit
    $text =~ s/(\d)½/$1 1\/2/g;
    $text =~ s/(\d)⅓/$1 1\/3/g;
    $text =~ s/(\d)¼/$1 1\/4/g;
    $text =~ s/(\d)⅔/$1 2\/3/g;
    $text =~ s/(\d)¾/$1 3\/4/g;
    $text =~ s/(\d)⅛/$1 1\/8/g;
    $text =~ s/(\d)⅜/$1 3\/8/g;
    $text =~ s/(\d)⅝/$1 5\/8/g;
    $text =~ s/(\d)⅞/$1 7\/8/g;
    # Handle fractions not preceded by a digit
    $text =~ s/½/1\/2/g;
    $text =~ s/⅓/1\/3/g;
    $text =~ s/¼/1\/4/g;
    $text =~ s/⅔/2\/3/g;
    $text =~ s/¾/3\/4/g;
    $text =~ s/⅛/1\/8/g;
    $text =~ s/⅜/3\/8/g;
    $text =~ s/⅝/5\/8/g;
    $text =~ s/⅞/7\/8/g;

    # Replace other common Unicode characters
    $text =~ s/[""]/"/g;     # smart quotes
    $text =~ s/['']/'/g;     # smart apostrophes
    $text =~ s/\x{2019}/'/g; # right single quotation mark (another curly apostrophe)
    $text =~ s/[–—]/--/g;    # en/em dashes
    $text =~ s/[…]/.../g;    # ellipsis
    $text =~ s/[◆◇]/*/g;     # diamond symbols
    $text =~ s/[°]/deg/g;    # degree symbol
    $text =~ s/[×]/x/g;      # multiplication sign
    $text =~ s/[☸]/*/g;      # wheel of dharma (decorative)

    # Convert chemical formula subscripts _{digits} using a placeholder
    # Do this BEFORE other conversions to avoid conflicts with underscore escaping
    my @subscripts;
    while ($text =~ s/\_\{(\d+)\}/\x00SUB\x00/) {
        push @subscripts, $1;
    }

    # Convert =text= to bold using a placeholder (BEFORE escaping special characters)
    my @bold_texts;
    while ($text =~ s/=([^=]+)=/\x00BOLD\x00/) {
        my $bold_content = $1;
        # Escape special LaTeX characters in bold text
        $bold_content =~ s/\\/\\textbackslash{}/g;
        $bold_content =~ s/([%\$#_&{}])/\\$1/g;
        $bold_content =~ s/~/\\textasciitilde{}/g;
        $bold_content =~ s/\^/\\textasciicircum{}/g;
        push @bold_texts, $bold_content;
    }

    # Convert _text_ to italic using a placeholder (BEFORE escaping special characters)
    my @italic_texts;
    while ($text =~ s/_([^_]+)_/\x00ITALIC\x00/) {
        my $italic_content = $1;
        # Escape special LaTeX characters in italic text
        $italic_content =~ s/\\/\\textbackslash{}/g;
        $italic_content =~ s/([%\$#_&{}])/\\$1/g;
        $italic_content =~ s/~/\\textasciitilde{}/g;
        $italic_content =~ s/\^/\\textasciicircum{}/g;
        push @italic_texts, $italic_content;
    }

    # Escape special LaTeX characters
    $text =~ s/\\/\\textbackslash{}/g;
    $text =~ s/([%\$#_&{}])/\\$1/g;
    $text =~ s/~/\\textasciitilde{}/g;
    $text =~ s/\^/\\textasciicircum{}/g;

    # Now replace placeholders with actual bold commands
    foreach my $bold_text (@bold_texts) {
        $text =~ s/\x00BOLD\x00/\\textbf{$bold_text}/;
    }

    # Now replace placeholders with actual italic commands
    foreach my $italic_text (@italic_texts) {
        $text =~ s/\x00ITALIC\x00/\\textit{$italic_text}/;
    }

    # Now replace placeholders with actual subscript commands
    foreach my $subscript (@subscripts) {
        $text =~ s/\x00SUB\x00/\\textsubscript{$subscript}/;
    }

    return $text;
}
