#%Module1.0#####################################################################
##
##  cosmo modulefile
##

set name "cosmo"
set version "MODULEVERSION"
set proper "COSMO"
set descrip "Detects enriched composite motifs in genomic sequence data"
set homepage "MODULEHOMEPAGE"
set helppage "https://tfwiki.cchmc.org/wiki/COSMO"
set installpage "https://tfwiki.cchmc.org/wiki/COSMO/Creating_a_%27cosmo%27_module"
set bugspage "MODULEHOMEPAGE/issues"
set topdir  "/data/weirauchlab/modules/local/cosmo/$version"

proc ModulesHelp { } {
    global proper
    global descrip
    global version
    global homepage
    global helppage
    global installpage
    global bugspage
    puts stderr "\t$proper\n\t  - $descrip\n"
    puts stderr "\tVersion:       $version"
    puts stderr "\tHomepage:      $homepage"
    puts stderr "\tHelp:          $helppage"
    puts stderr "\tInstallation:  $installpage"
    puts stderr "\tBug reports:   $bugspage"
    puts stderr ""
}

module-whatis "$proper $version - $descrip"

prepend-path PATH "$topdir/bin"
prepend-path MANPATH "$topdir/share/man"

# so that `setup.py --install --prefix` doesn't gripe
module load MODULEPYTHON27MOD
prepend-path PYTHONPATH "$topdir/lib/python2.7/site-packages"

# COSMO 1.1.2 allows defining the path to the PWMs ('-p') option in the env.
setenv COSMO_PWMDIR "$topdir/lib/cosmo/jpwm"

# vim: ft=tcl ts=4 sw=4 expandtab
