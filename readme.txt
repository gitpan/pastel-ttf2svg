pastel-ttf2svg.pl
-----------------
Truetype v1.0 to SVG converter - v0.04, April 2, 2002.

Copyright (c) 2002 Malay <curiouser@gene.ccmbindia.org>
You can do whatever you want to do with this program with the same condition as
Perl itself. Just don't blame me for anything!

Usage
-----
Pastel-ttf2svg.pl -f <ttffile> [-l NNN] [-h NNN] [-i CCC] [-t] [-s]
      -f <ttffile>    - The full path name of the TTF file
      -l NNN          - The low index number of the character. Default 32.
      -h NNN          - The high index number of the character. Default 255.
      -i CCC          - Font id.
      -t              - Print a SVG file with the glyphs displayed
      -s              - This is Symbol font file.
                        Default characters parsed is from 61472 to 61695.
                        When using your own high and low character values
                        use character numbers between 61472 to 61695.

This program only parses Microsoft table of the font.

The POD documentation is in the code.
