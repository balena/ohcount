#!/usr/bin/env python

from distutils.core import setup, Extension
from distutils.command.build import build
from distutils.command.build_ext import build_ext
import distutils.command.install_data
import os.path, sys

if not hasattr(sys, 'version_info') or sys.version_info < (2,6,0,'final'):
    raise SystemExit("Ohcount requires Python 2.6 or later.")

class build_ohcount(build):
    def initialize_options(self):
        build.initialize_options(self)
        self.build_base = 'build-python'

class build_ohcount_ext(build_ext):
    def run(self):
        os.system('cd src/parsers/ && bash ./compile')
        os.system('cd src/hash/ && bash ./generate_headers')
        return build_ext.run(self)

ext_modules=[
    Extension(
        name='ohcount._ohcount',
        sources= [
            'ruby/ohcount.i',
            'src/sourcefile.c',
            'src/detector.c',
            'src/licenses.c',
            'src/parser.c',
            'src/loc.c',
            'src/log.c',
            'src/diff.c',
            'src/parsed_language.c',
            'src/hash/language_hash.c',
        ],
        libraries=['pcre'],
        swig_opts=['-modern']
    )
]

setup(
    name='ohcount',
    version = '3.0.0',
    description = 'Ohcount is the source code line counter that powers Ohloh.',
    long_description =
        'Ohcount supports over 70 popular programming languages, and has been '
        'used to count over 6 billion lines of code by 300,000 developers! '
        'Ohcount does more more than just count lines of code. It can also '
        'detect popular open source licenses such as GPL within a large '
        'directory of source code. It can also detect code that targets a '
        'particular programming API, such as Win32 or KDE.',
    author = 'Mitchell Foral',
    author_email = 'mitchell@caladbolg.net',
    license = 'GNU GPL',
    platforms = ['Linux','Mac OSX'],
    keywords = ['ohcount','ohloh','loc','source','code','line','counter'],
    url = 'http://www.ohloh.net/p/ohcount',
    download_url = 'http://sourceforge.net/projects/ohcount/files/',
    packages = ['ohcount'],
    package_dir = {'ohcount': 'python'},
    classifiers = [
        'Development Status :: 5 - Production/Stable',
        'License :: OSI Approved :: GNU General Public License (GPL)'
        'Intended Audience :: Developers',
        'Natural Language :: English',
        'Programming Language :: C',
        'Programming Language :: Python',
        'Topic :: Software Development :: Libraries :: Python Modules',
    ],
    ext_modules=ext_modules,
    cmdclass={'build': build_ohcount, 'build_ext': build_ohcount_ext},
)
