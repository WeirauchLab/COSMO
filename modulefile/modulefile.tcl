#%Module1.0#####################################################################
##
##  cosmo modulefile
##
##  NOTE: This is a generated file! If you're not editing the '.m4' version,
##        your changes are likely to get clobbered by a later 'make module'.
##

set name "cosmo"
set version "1.1.3"
set proper "COSMO"
set descrip "Detects enriched composite motifs in genomic sequence data"
set homepage "https://github.com/weirauchlab/cosmo"
set helppage "https://github.com/weirauchlab/cosmo/#usage"
set installpage "https://github.com/weirauchlab/cosmo#detailed-installation"
set bugspage "https://github.com/weirauchlab/cosmo/issues"
set topdir  "/usr/local/modules/cosmo/$version"

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
module load python/2.7.18-wrl
prepend-path PYTHONPATH "$topdir/lib/python2.7/site-packages"

# COSMO 1.1.2 allows defining the path to the PWMs ('-p') option in the env.
setenv COSMO_PWMDIR "$topdir/lib/cosmo/jpwm"

# vim: ft=tcl ts=4 sw=4 expandtab
