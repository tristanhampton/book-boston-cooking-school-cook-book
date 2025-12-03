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
push @output, "\\usepackage[margin=1in]{geometry}";
push @output, "\\usepackage{microtype}";
push @output, "\\usepackage{titlesec}";
push @output, "\\usepackage{enumitem}";
push @output, "\\usepackage{array}";
push @output, "\\usepackage[table]{xcolor}";
push @output, "\\definecolor{tablerowgray}{gray}{0.9}";
push @output, "";
push @output, "\\title{The Boston Cooking-School Cook Book}";
push @output, "\\author{Fannie Merritt Farmer}";
push @output, "\\date{1910}";
push @output, "";
push @output, "\\begin{document}";
push @output, "";

# State tracking
my $start_found = 0;
my $in_content = 0;

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
        if ($line =~ /^\s+PREFACE\s*$/ || $line =~ /^\s+CHAPTER [IVXLCDM]+\s*$/) {
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

        # Fix Roman numerals (should be all uppercase)
        # Match common patterns: I, II, III, IV, V, VI, VII, VIII, IX, X, XI, XII, etc.
        $section_title =~ s/\b(I|Ii|Iii|Iv|V|Vi|Vii|Viii|Ix|X|Xi|Xii|Xiii|Xiv|Xv|Xvi|Xvii|Xviii|Xix|Xx)\b/\U$1/g;

        push @output, "";
        push @output, "\\section{$section_title}";
        push @output, "";

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
                push @output, "\\begin{center}";

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
                push @output, "\\end{center}";
                push @output, "";
            }

            # Skip the lines we processed
            $i = $j - 1;
        }
        # Check if this is a time table section
        elsif ($section_title =~ /Time Tables For Cooking/i) {
            # This section contains multiple subsection tables: Boiling, Broiling, Baking, Frying
            my $j = $i + 1;

            # Skip blank lines
            while ($j < @lines && $lines[$j] =~ /^\s*$/) {
                $j++;
            }

            # Process each subsection table
            while ($j < @lines) {
                my $line = $lines[$j];
                chomp($line);
                $line =~ s/\r$//;

                # Stop if we hit multiple blank lines (end of section)
                if ($line =~ /^\s*$/) {
                    # Check if we have more blank lines (section end)
                    my $blank_count = 0;
                    my $k = $j;
                    while ($k < @lines && $lines[$k] =~ /^\s*$/) {
                        $blank_count++;
                        $k++;
                    }
                    # If we have 2+ blank lines, we're done with this section
                    last if $blank_count >= 2;
                }

                # Check if this is a subsection header (Boiling, Broiling, Baking, Frying)
                if ($line =~ /^\s+(Boiling|Broiling|Baking|Frying)\s*$/i) {
                    my $subsection = $1;
                    push @output, "";
                    push @output, "\\subsection*{$subsection}";
                    push @output, "";
                    $j++;

                    # Skip blank lines and collect table
                    while ($j < @lines && $lines[$j] =~ /^\s*$/) {
                        $j++;
                    }

                    # Skip header lines (ARTICLES, TIME, Hours, Minutes, or lines with only these words)
                    while ($j < @lines) {
                        my $hdr = $lines[$j];
                        chomp($hdr);
                        $hdr =~ s/\r$//;
                        $hdr =~ s/^\s+//;
                        $hdr =~ s/\s+$//;
                        # Skip if line contains only header keywords
                        last unless $hdr =~ /^(ARTICLES?|TIME|Hours?|Minutes?|[:\s])+$/i;
                        $j++;
                    }

                    # Collect data rows until we hit blank lines or next subsection
                    my @table_rows;
                    while ($j < @lines) {
                        my $row = $lines[$j];
                        chomp($row);
                        $row =~ s/\r$//;

                        # Stop at blank line followed by another subsection or end
                        if ($row =~ /^\s*$/) {
                            # Check if next non-blank line is a subsection or note
                            my $k = $j + 1;
                            while ($k < @lines && $lines[$k] =~ /^\s*$/) {
                                $k++;
                            }
                            if ($k < @lines) {
                                my $next = $lines[$k];
                                $next =~ s/\r$//;
                                # If next line is subsection header or NOTE, we're done with this table
                                last if $next =~ /^\s+(Boiling|Broiling|Baking|Frying)\s*$/i;
                                last if $next =~ /^NOTE/i;
                            } else {
                                last;  # End of section
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
                            push @table_rows, $row;
                        }
                        $j++;
                    }

                    # Generate LaTeX table for this subsection
                    if (@table_rows > 0) {
                        push @output, "\\begin{center}";
                        push @output, "\\begin{tabular}{p{3.5in}cc}";  # Article (wrapped), Hours, Minutes
                        push @output, "\\hline";
                        push @output, "Article & Hours & Minutes \\\\";
                        push @output, "\\hline";

                        my $row_num = 0;
                        foreach my $row (@table_rows) {
                            $row =~ s/^\s+//;  # Remove leading spaces

                            # Try to parse: name followed by time values
                            # Format could be: "name    time" or "name    hours    minutes"
                            if ($row =~ /^(.+?)\s{2,}(\d+\S*)\s+to\s+(\d+\S*)$/) {
                                # Format: "name    X to Y" (single column time range)
                                my ($name, $time1, $time2) = ($1, $2, $3);
                                $name =~ s/\s+$//;
                                push @output, escape_latex($name) . " &  & $time1 to $time2 \\\\";
                            } elsif ($row =~ /^(.+?)\s{2,}(\d+\S*\s+to\s+\d+\S*)\s*$/) {
                                # Format: "name    X to Y" (already formatted time range)
                                my ($name, $time) = ($1, $2);
                                $name =~ s/\s+$//;
                                push @output, escape_latex($name) . " &  & $time \\\\";
                            } elsif ($row =~ /^(.+?)\s{2,}(\d+\S*)\s*$/) {
                                # Format: "name    X" (single time value)
                                my ($name, $time) = ($1, $2);
                                $name =~ s/\s+$//;
                                push @output, escape_latex($name) . " &  & $time \\\\";
                            } elsif ($row =~ /^(.+?)\s{2,}(\d+)\s+(\d+)$/) {
                                # Format: "name    hours    minutes" (two separate columns)
                                my ($name, $hours, $mins) = ($1, $2, $3);
                                $name =~ s/\s+$//;
                                push @output, escape_latex($name) . " & $hours & $mins \\\\";
                            } else {
                                # Fallback: just output the row as-is in first column
                                push @output, escape_latex($row) . " &  &  \\\\";
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
                        push @output, "\\end{center}";
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
                push @output, "\\begin{center}";
                push @output, "\\begin{tabular}{p{2in}p{0.8in}p{1.2in}p{1in}}";
                push @output, "\\hline";
                push @output, "Kind & Quantity & Water & Time \\\\";
                push @output, "\\hline";

                my $row_num = 0;
                foreach my $row (@table_rows) {
                    $row =~ s/^\s+//;  # Remove leading spaces
                    $row =~ s/\s+/ /g;  # Normalize all whitespace to single spaces

                    # Try to parse: kind (text), quantity (X cup), water (Y cups), time (Z minutes/hours)
                    # Look for pattern: text ... N cup ... M cups ... X minutes/hours
                    if ($row =~ /^(.+?)\s+(\d+(?:\s+\d+\/\d+|\.\d+|\/\d+|[½¾¼⅓⅔⅛⅜⅝⅞])?\s*cups?)\s+(.+?)\s+(\d+(?:–\d+)?\s*(?:minutes?|hours?))/i) {
                        my ($kind, $qty, $water, $time) = ($1, $2, $3, $4);
                        $kind =~ s/\s+$//;
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
                push @output, "\\end{center}";
                push @output, "";
            }

            # Skip the lines we processed
            $i = $j - 1;
        }

        next;
    }

    # Check if this line matches an h4 heading (subsection)
    if (exists $h4_headings{$normalized_line} &&
        $h4_used_count{$normalized_line} < $h4_max_count{$normalized_line}) {
        my $heading = $h4_headings{$normalized_line};
        my $escaped_heading = escape_latex($heading);

        push @output, "";
        push @output, "\\subsection{$escaped_heading}";
        push @output, "";

        $h4_used_count{$normalized_line}++;
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
            # Generate formatted composition block
            push @output, "";
            push @output, "\\begin{center}";
            push @output, "\\textsc{Composition}";
            push @output, "";

            foreach my $comp (@comp_lines) {
                my $escaped = escape_latex($comp);
                push @output, $escaped . "\\\\";
            }

            push @output, "\\end{center}";
            push @output, "";

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

        if ($next_line =~ /^[A-Z\s\-',]+$/ && length($next_line) < 60) {
            my $title = escape_latex($next_line);
            $title = lc($title);
            $title =~ s/\b(\w)/\U$1/g;  # Title case

            push @output, "";
            push @output, "\\chapter{$title}";
            push @output, "";
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
    if ($line =~ /^\s+(PREFACE|GLOSSARY|INDEX)\s*$/) {
        my $heading = $1;
        $heading = lc($heading);
        $heading =~ s/\b(\w)/\U$1/g;

        push @output, "";
        push @output, "\\chapter*{$heading}";
        push @output, "";
        next;
    }

    # Check for the line before the food classification table
    if ($line =~ /^\s+1\.\s+Proteid\s+\(nitrogenous or albuminous\)/) {
        # Check if next line is "I. ORGANIC"
        if ($i + 1 < @lines && $lines[$i + 1] =~ /^\s+I\.\s+ORGANIC\s+/) {
            # This is the food classification table - create it
            push @output, "";
            push @output, "\\begin{center}";
            push @output, "\\begin{tabular}{clp{3.5in}}";

            # Row 1: I. ORGANIC
            push @output, "I. & ORGANIC & 1. Proteid (nitrogenous or albuminous) \\\\";
            push @output, " & & 2. Carbohydrates (sugar and starch) \\\\";
            push @output, " & & 3. Fats and oils \\\\[0.5em]";

            # Row 2: II. INORGANIC
            push @output, "II. & INORGANIC & 1. Mineral matter \\\\";
            push @output, " & & 2. Water \\\\";

            push @output, "\\end{tabular}";
            push @output, "\\end{center}";
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
            push @output, "\\begin{center}";
            push @output, "\\begin{tabular}{rll}";

            foreach my $row (@table_rows) {
                my $formatted = sprintf("%s & %s & %s \\\\", $row->[0], $row->[1], $row->[2]);
                push @output, $formatted;
            }

            push @output, "\\end{tabular}";
            push @output, "\\end{center}";
            push @output, "";

            # Skip the lines we've processed
            $i = $j - 1;
            next;
        }
    }

    # Check for recipe ingredient lists (indented lines with measurements)
    # Match patterns like: 1 cup, 1/2 cup, 1 1/2 cup (after escape_latex converts Unicode fractions)
    # Require at least 10 spaces of indentation to distinguish from regular text
    if ($line =~ /^\s{10,}(\d+(?:\s+\d+\/\d+)?|\d+\/\d+)\s+(cup|tablespoon|teaspoon|pound|quart|pint|slice|sprig|stalk|can|square|ounce)s?\s+/i) {
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
            if ($ingline =~ /^\s{10,}(.+)$/) {
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
            push @output, "\\begin{quote}";
            push @output, "\\begin{itemize}";
            push @output, "\\setlength{\\itemsep}{0pt}";

            foreach my $ing (@ingredients) {
                push @output, "\\item $ing";
            }

            push @output, "\\end{itemize}";
            push @output, "\\end{quote}";
            push @output, "";

            # Skip the lines we've processed
            $i = $j - 1;
            next;
        }
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
