#!/usr/bin/env python2.6
# -*- coding: utf-8 -*-

# Thanks to Jonas Kjellström and Cody Boisclair for their help in finding bugs in this script!

import re
import os
import sys
import tempfile
from fontTools.ttLib import TTFont, newTable
from fontTools.ttLib.xmlImport import importXML

doc = """USAGE: python /path/to/inputCustomize.py [INPUT] [--dest=OUTPUT] [OPTIONS]
Use this script to customize one or more Input font files.
Requires TTX/FontTools: <http://sourceforge.net/projects/fonttools/>

If INPUT is missing, it will customize all fonts in the Current Working Directory.
If OUTPUT is missing, it will overwrite the INPUT files.

Options:
    -h, --help              Print this help text, and exit.
    --lineHeight=<float>    A multiplier for the font's built-in line-height.
    --fourStyleFamily       Only works when four INPUT files are provided. 
                            Assigns Regular, Italic, Bold, and Bold Italic names to the 
                            INPUT fonts in the order provided.
    --suffix=<string>       Append a suffix to the font names. Takes a string with no spaces.
    --a=ss                  Swaps alternate single-story 'a' for the default double-story 'a'
    --g=ss                  Swaps alternate single-story 'g' for the default double-story 'a'
    --i=serif               Swaps one of the alternate 'i' for the default in Sans/Mono
        serifs
        serifs_round
        topserif
    --l=serif               Swaps one of the alternate 'l' for the default in Sans/Mono
        serifs
        serifs_round
        topserif
    --zero=slash            Swaps the slashed zero for the default dotted zero
           nodot            Swaps a dotless zero for the default dotted zero
    --asterisk=height       Swaps the mid-height asterisk for the default superscripted asterisk
    --braces=straight       Swaps tamer straight-sided braces for the default super-curly braces

    Example 1:
    $ cd /path/to/the/top/level/of/the/fonts/you/want/to/edit
    $ python /path/to/InputCustomize.py --dest=/path/to/output  --lineHeight=1.5 --suffix=Hack --fourStyleFamily --a=ss --g=ss --i=topserif --l=serifs_round --zero=slash --asterisk=height
    
    Example 2:
    $ cd /path/to/the/top/level/of/the/fonts/you/want/to/edit
    $ python /path/to/InputCustomize.py InputSans-Regular.ttf InputSans-Italic.ttf InputSans-Bold.ttf InputSerif-Regular.ttf --suffix=Hack --fourStyleFamily
"""

class InputModifier(object):
    """
    An object for manipulating Input, takes a TTFont. Sorry this is a little hacky.
    """
    
    def __init__(self, f):
        self.f = f

    def changeLineHeight(self, lineHeight):
        """
        Takes a line height multiplier and changes the line height.
        """
        f = self.f
        baseAsc = f['OS/2'].sTypoAscender
        baseDesc = f['OS/2'].sTypoDescender
        multiplier = float(lineHeight)
        f['hhea'].ascent = round(baseAsc * multiplier)
        f['hhea'].descent = round(baseDesc * multiplier)
        f['OS/2'].usWinAscent = round(baseAsc * multiplier)
        f['OS/2'].usWinDescent = round(baseDesc * multiplier)*-1

    def swap(self, swap):
        """
        Takes a dictionary of glyphs to swap and swaps 'em.
        """
        f = self.f
        glyphNames = f.getGlyphNames()
        maps = {
        'a': {'a': 97, 'aring': 229, 'adieresis': 228, 'acyrillic': 1072, 'aacute': 225, 'amacron': 257, 'agrave': 224, 'atilde': 227, 'acircumflex': 226, 'aogonek': 261, 'abreve': 259},
        'g':  {'gdotaccent': 289, 'gbreve': 287, 'gcircumflex': 285, 'gcommaaccent': 291, 'g': 103},
        'i':  {'i': 105, 'iacute': 237, 'iogonek': 303, 'igrave': 236, 'itilde': 297, 'icircumflex': 238, 'imacron': 299, 'ij': 307, 'ibreve': 301, 'yicyrillic': 1111, 'idieresis': 239, 'icyrillic': 1110, 'dotlessi': 305,},
        'l':  {'l': 108, 'lcaron': 318, 'lcommaaccent': 316, 'lacute': 314, 'lslash': 322, 'ldot': 320},
        'zero': {'zero': 48},
        'asterisk':  {'asterisk': 42},
        'braces': {'braceleft': 123, 'braceright': 125}
        }
        swapMap = {}
        for k, v in swap.items():
            for gname, u in maps[k].items():
                newGname = gname + '.salt_' + v
                if newGname in glyphNames:
                    swapMap[gname] = newGname
        for table in f['cmap'].tables:
            cmap = table.cmap
            for u, gname in cmap.items():
                if swapMap.has_key(gname):
                    cmap[u] = swapMap[gname]

    def fourStyleFamily(self, position, suffix=None):
        """
        Replaces the name table and certain OS/2 values with those that will make a four-style family.
        """
        f = self.f
        source = TTFont(fourStyleFamilySources[position])

        tf = tempfile.mkstemp()
        pathToXML = tf[1]
        source.saveXML(pathToXML, tables=['name'])
        os.close(tf[0])
        
        with open(pathToXML, "r") as temp:
            xml = temp.read()

        # make the changes
        if suffix:
            xml = xml.replace("Input", "Input" + suffix)

        # save the table
        with open(pathToXML, 'w') as temp:
            temp.write(xml)
            temp.write('\r')

        f['OS/2'].usWeightClass = source['OS/2'].usWeightClass
        f['OS/2'].fsType = source['OS/2'].fsType

        # write the table
        f['name'] = newTable('name')
        importXML(f, pathToXML)
    
    def changeNames(self, suffix=None):
        # this is a similar process to fourStyleFamily()
        
        tf = tempfile.mkstemp()
        pathToXML = tf[1]
        f.saveXML(pathToXML, tables=['name'])
        os.close(tf[0])
        
        with open(pathToXML, "r") as temp:
            xml = temp.read()

        # make the changes
        if suffix:
            xml = xml.replace("Input", "Input" + suffix)

        # save the table
        with open(pathToXML, 'w') as temp:
            temp.write(xml)
            temp.write('\r')
        
        # write the table
        f['name'] = newTable('name')
        importXML(f, pathToXML)




            
baseTemplatePath = os.path.split(__file__)[0]
fourStyleFamilySources = [
    os.path.join(baseTemplatePath, '_template_Regular.txt'),
    os.path.join(baseTemplatePath, '_template_Italic.txt'),
    os.path.join(baseTemplatePath, '_template_Bold.txt'),
    os.path.join(baseTemplatePath, '_template_BoldItalic.txt'),
]

fourStyleFileNameAppend = [ 'Regular', 'Italic', 'Bold', 'BoldItalic' ]

if __name__ == "__main__":
    
    # Get command-line arguments
    go = True
    arguments = sys.argv[1:]
    paths = []
    swap = {}
    lineHeight = None
    fourStyleFamily = None
    suffix = None
    destBase = None


    # parse arguments
    for argument in arguments:
        key = None
        value = None
        if len(argument.split('=')) == 2:
            key, value = argument.split('=')
            key = key[2:]
        elif argument[0:2] == '--':
            key = argument[2:]
            value = True
        elif argument == '-h':
            print doc
            go = False
        else:
            key = argument
            value = None
        # assign preference variables
        if value is None:
            paths.append(key)
        elif key == 'lineHeight':
            lineHeight = value
        elif key == 'fourStyleFamily':
            fourStyleFamily = True
        elif key == 'suffix':
            suffix = value
        elif key == 'dest':
            destBase = value
        elif key == 'help':
            print doc
            go = False
        else:
            swap[key] = value
    
    # account for arguments where no value is given (for example, '--a' instead of '--a=ss')
    if swap.get('a') is True:
            swap['a'] = 'ss'
    if swap.get('g') is True:
            swap['g'] = 'ss'
    if swap.get('i') is True:
            swap['i'] = 'serifs'
    if swap.get('l') is True:
            swap['l'] = 'serifs'
    if swap.get('zero') is True:
            swap['zero'] = 'slash'
    if swap.get('asterisk') is True:
            swap['asterisk'] = 'height'
    if swap.get('braces') is True:
            swap['braces'] = 'straight'

    
    # if specific paths were not supplied, collect them from the current directory
    if not paths:
        for root, dirs, files in os.walk(os.getcwd()):
            for filename in files:
                basePath, ext = os.path.splitext(filename)
                if ext in ['.otf', '.ttf']:
                    paths.append(os.path.join(root, filename))

    # if four paths were not supplied, do not process as a four-style family
    if len(paths) != 4:
        fourStyleFamily = None

    if go:
        for i, path in enumerate(paths):
            print os.path.split(path)[1]
            f = TTFont(path)
            c = InputModifier(f)
            if lineHeight:
                c.changeLineHeight(lineHeight)
            if swap:
                c.swap(swap)
            if fourStyleFamily:
                c.fourStyleFamily(i, suffix)
                base, ext = os.path.splitext(path)
                path = base + '_as_' + fourStyleFileNameAppend[i] + ext
            elif suffix:
                c.changeNames(suffix)
            if destBase:
                baseScrap, fileAndExt = os.path.split(path)
                destPath = os.path.join(destBase, fileAndExt)
            else:
                destPath = path
            try:
                os.remove(destPath)
            except:
                pass
                
            # Take care of that weird "post" table issue, just in case. Delta#1
            try:
                del f['post'].mapping['Delta#1']
            except:
                pass
                
            f.save(destPath)
        print 'done'
