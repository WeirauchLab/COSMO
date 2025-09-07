#!/usr/bin/env python
##
##  COSMO's 'setup.py'
##
##  Author:     Kevin Ernst <kevin.ernst -at- cchmc.org>
##  Date:       6 September 2025
##  Reference:  https://setuptools.readthedocs.io/en/latest/setuptools.html#basic-use
##
import os
from setuptools import setup, find_packages

PROJECT_NAME = 'cosmo'
VERSION = '1.1.3'
PROJECTHOME = 'https://github.com/weirauchlab/cosmo'

# read and reformat a file suitable for 'long_description'
# source: https://pythonhosted.org/an_example_pypi_project/setuptools.html
def read(fname):
    return open(os.path.join(os.path.dirname(__file__), fname)).read()

if __name__ == '__main__':
    setup(
        name=PROJECT_NAME,
        version=VERSION,
        packages=find_packages(),
        scripts=["cosmo.py", "cosmostats.py"],

        # any required packages; see https://www.python.org/dev/peps/pep-0440
        # > For example, the following groups of version clauses are equivalent:
        # >    
        # >   ~= 2.2
        # >   >= 2.2, == 2.*
        # >   
        # >   ~= 1.4.5
        # >   >= 1.4.5, == 1.4.*

        # you can use, e.g., 'pip list | grep -i pandas' to see the current version
        # ref: https://setuptools.readthedocs.io/en/latest/setuptools.html#declaring-dependencies
        #install_requires=["pandas~=0.20"],
        install_requires=read('requirements.txt'),

        # use this option if, for example, your package requires non-Python code
        # files to function, and you want to keep those alongside the code
        #package_data={
        #    # If any package contains any support files, include them
        #    "": ["*.txt", "*.dat"],
        #    # And include any *.dat files found in the "lib" package, too:
        #    "lib": ["*.dat"],
        #},

        # metadata to display on PyPI (and in the output of 'pip show')
        author="Jeremy Riddell",
        author_email="riddeljr@mail.uc.edu",
        description="COSMO Composite Motif Scanner - detects enriched composite " \
                    "motifs in genomic sequence data",
        keywords="motif genomics sequence scanning jaspar cisbp",
        long_description=read('README.md'),

        # project home page, if any
        url=PROJECTHOME,

        # could also include download_url, etc
        # ref: https://setuptools.readthedocs.io/en/latest/setuptools.html#metadata

        # an arbitrary map of URL names to hyperlinks, beyond what's provided by
        # 'url' and 'download_url'
        project_urls={
            "Bug Tracker": PROJECTHOME + '/issues',
            "Documentation": PROJECTHOME + '#readme',
            "Source Code": PROJECTHOME,
        },

        # reference: https://choosealicense.com
        # should match the "License" classifier below
        #license = 'MIT / GPL / BSD', # choose one
        license = 'GPLv3',
        #license_file = 'LICENSE.txt',

        # reference: https://pypi.org/classifiers/
        classifiers=[
            #"Development Status :: 1 - Planning",
            #"Development Status :: 2 - Pre-Alpha",
            #"Development Status :: 3 - Alpha",
            #"Development Status :: 4 - Beta",
            "Development Status :: 5 - Production/Stable",
            #"Development Status :: 6 - Mature",
            #"Development Status :: 7 - Inactive",

            "Environment :: Console",

            "Programming Language :: Python",
            "Programming Language :: Python :: 2",
            "Programming Language :: Python :: 2 :: Only",
            "Programming Language :: Python :: 2.7",
            #"Programming Language :: Python :: 3",
            #"Programming Language :: Python :: 3 :: Only",
            #"Programming Language :: Python :: 3.6",
            #"Programming Language :: Python :: 3.7",
            #"Programming Language :: Python :: 3.8",

            # make sure this matches the 'license' parameter above
            "License :: OSI Approved",
            # choose one (see reference above for the full list)
            #"License :: OSI Approved :: MIT License",
            #"License :: OSI Approved :: BSD License",
            #"License :: OSI Approved :: Artistic License",
            #"License :: OSI Approved :: GNU General Public License (GPL)",
            #"License :: OSI Approved :: GNU General Public License v2 (GPLv2)",
            #"License :: OSI Approved :: GNU General Public License v2 or later (GPLv2+)",
            "License :: OSI Approved :: GNU General Public License v3 (GPLv3)",
            #"License :: OSI Approved :: Python Software Foundation License",

            # who will use this?
            #"Intended Audience :: Healthcare Industry",
            #"Intended Audience :: Science/Research",

            # add more classifiers later if it makese sense to; these are used to
            # categorize and search for packages on PyPI
            #"Topic :: Scientific/Engineering",
            #"Topic :: Scientific/Engineering :: Medical Science Apps.",
            #"Topic :: Scientific/Engineering :: Bio-Informatics",
            #"Topic :: Utilities",
            #"Topic :: Database",
        ],

        # create an executable in users' PATH for Windows or Unix; reference:
        # https://setuptools.pypa.io/en/latest/userguide/quickstart.html#entry-points-and-automatic-script-creation
        # TOOD: some day; this doesn't work with "plain" .py scripts, though
        #entry_points={
        #    "console_scripts": [
        #        "cosmo = cosmo:main",
        #        "cosmostats = cosmostats:main",
        #    ],
        #}
    )
