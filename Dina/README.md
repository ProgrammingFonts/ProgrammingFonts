
Dina Programming Font
=====================

Copyright (c) 2005-2013 Joergen Ibsen

<http://www.donationcoder.com/Software/Jibz/Dina/>


About
-----

Dina is a monospace bitmap font, primarily aimed at programmers. It is
relatively compact to allow a lot of code on screen, while (hopefully) clear
enough to remain readable even at high resolutions.

I made this font after having tried all the free programming fonts I could
find. Somehow there was some detail in each of them that meant I could not
work with them in the long run.

The closest to perfect I found was the Proggy font, so I started building
Dina using Proggy as the base, and with inspiration from Tobi, Fixedsys and
some old DOS fonts I used to love.

Some of the design goals were:

  - Monospaced
  - Should be easy to distinguish between `j i l 1 I`
  - Should be easy to distinguish between `o O 0`
  - Operators should line up horizontally `- + * =`
  - Brackets should line up horizontally and vertically `< ( { [ ] } ) >`
  - Punctuation should be clear `., :; ' "`
  - Symbols used in programming languages should look right `& @ % $ #`
  - No other characters that look too similar `gqy z2Z s5S 8B CG6 DO uv`
  - Still has to be pleasant to read passages of text

Dina is the result of many hours of tweaking and testing, and I am quite
happy with it now.


Font Format
-----------

Dina is a monospace bitmap font in Windows FON file format (Windows-1252 /
ISO-8859-1 encoding). It is available as:

  - 6pt regular
  - 8pt regular, bold, italic, bold italic
  - 9pt regular, bold, italic, bold italic
  - 10pt regular, bold, italic, bold italic

`DinaR.fon` contains the regular fonts, `DinaB.fon` contains bold,
`DinaI.fon` italic, and `DinaZ.fon` bold italic.

All styles are the same width for proper alignment.

Depending on your monitor size and type, the 8pt or 9pt versions should be
preferable up to at least 1280x1024 resolution. The 10pt version may be an
option at higher resolutions.

BDF versions of the fonts are included for easier conversion to formats
usable on Linux and Mac. The point sizes may be slightly different on
other operating systems. Please check the [forum][] for updates on
conversions.

[forum]: http://www.donationcoder.com/forum/index.php?board=62.0


Installing on Windows
---------------------

If you have a previous version of Dina installed, it is a good idea to remove
that before installing a new version. Close all open programs that use the
Dina font before removing it.

On recent Windows versions, removing a font is usually done by going into
Control Panel, Appearance and Personalization, Fonts, finding the font in
question, right-clicking it and choosing Delete. On older Windows versions,
go to `C:\Windows\Fonts`, right-click the font and choose Delete.

Installing a font on recent Windows versions, can be done by right-clicking
the `.fon` files and choosing Install. On older versions, go into Control
Panel, Appearance and Personalization, Fonts, and choose Install New Font
from the File menu.

Microsoft has more detailed instructions on installing and removing fonts
for [Windows XP][winxp], [Windows Vista][winvista] and [Windows 7][win7].

There is an issue on some Windows versions, where the 10pt entry disappears
from the font selection dialog. If this is the case, you can enter a size of
10 manually in the editbox.

[winxp]: http://support.microsoft.com/kb/314960
[winvista]: http://windows.microsoft.com/en-us/windows-vista/install-or-uninstall-fonts
[win7]: http://windows.microsoft.com/en-us/windows7/install-or-delete-fonts


Acknowledgements
----------------

A big thanks to Tristan Grimmer for his excellent Proggy fonts.

Thanks to mouser for testing.

Thanks to Jamie Burns and bpcw001 for contributing conversions.


License
-------

Copyright (c) 2005-2013 Joergen Ibsen

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
