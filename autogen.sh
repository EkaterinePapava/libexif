#!/bin/sh
# autogen.sh - initialize and clean automake&co based build trees
#
# For more detailed info, run "autogen.sh --help" or scroll down to the
# print_help() function.


########################################################################
# Initial values

debug=false
self="$(basename "$0")"


########################################################################
# Print help message

print_help() {
    cat<<EOF
$self - initialize automake/autoconf/gettext/libtool based build system

Usage:
    $self [<command>...] [<directory>...]

Runs given command sequence on all given directories, in sequence.
If there is no command given, --init is assumed.
If there is no directory given, the location of $self is assumed.

Commands:
    --help
        Print this help text
    --verbose
        Verbose output

    --clean
        Clean all files and directories generated by "$self --init"
    --init
        Run on fresh CVS checkout to get a build tree you can treat with
        ./configure && make && make install

$self depends on automake, autoconf, libtool and gettext.

You may want to set AUTOCONF, AUTOHEADER, AUTOMAKE, ACLOCAL,
AUTOPOINT, LIBTOOLIZE to use specific version of these tools, and
AUTORECONF_OPTS to add options to the call to autoreconf.
EOF
}


########################################################################
# Initialize variables for configure.{in,ac} in $1

init_vars() {
    dir="$1"
    echo -n "Looking for \`${dir}/configure.{ac,in}'..."
    CONFIGURE_AC=""
    for tmp in "${dir}/configure".{ac,in}; do
	if test -s "$tmp"; then
	    CONFIGURE_AC="$tmp"
	    echo " $tmp"
	    break
	fi
    done
    if test "x$CONFIGURE_AC" = "x"; then
	echo " no."
	exit 1
    fi

    if "$debug"; then
	AUTORECONF_OPTS="$AUTORECONF_OPTS --verbose -Wall"
    fi

    echo -n "Initializing variables for \`${dir}'..."
    AG_CONFIG_H="$(sed -n 's/^AM_CONFIG_HEADER(\[\{0,1\}\([^])]*\).*/\1/p' < "$CONFIGURE_AC")"
    AG_CONFIG_DIR="$(dirname "${AG_CONFIG_H}")"
    AG_GEN_ACAM="aclocal.m4 configure config.guess config.sub compile"
    AG_GEN_RECONF="INSTALL install-sh missing depcomp"
    AG_GEN_GETTEXT="mkinstalldirs config.rpath ABOUT-NLS"
    while read file; do
	AG_GEN_GETTEXT="${AG_GEN_GETTEXT} ${file}"
    done <<EOF
m4/codeset.m4
m4/gettext.m4
m4/glibc21.m4
m4/iconv.m4
m4/intdiv0.m4
m4/intmax.m4
m4/inttypes-pri.m4
m4/inttypes.m4
m4/inttypes_h.m4
m4/isc-posix.m4
m4/lcmessage.m4
m4/lib-ld.m4
m4/lib-link.m4
m4/lib-prefix.m4
m4/longdouble.m4
m4/longlong.m4
m4/nls.m4
m4/po.m4
m4/printf-posix.m4
m4/progtest.m4
m4/signed.m4
m4/size_max.m4
m4/stdint_h.m4
m4/uintmax_t.m4
m4/ulonglong.m4
m4/wchar_t.m4
m4/wint_t.m4
m4/xsize.m4
po/Makefile.in.in
po/Makevars.template
po/Rules-quot
po/boldquot.sed
po/en@boldquot.header
po/en@quot.header
po/insert-header.sin
po/quot.sed
po/remove-potcdate.sin
po/stamp-po
EOF
    AG_GEN_CONFIG_H="${AG_CONFIG_H} ${AG_CONFIG_H}.in"
    AG_GEN_CONF="config.status config.log include/stamp-h1 include/stamp-h2"
    AG_GEN_LIBTOOL="ltmain.sh libtool"
    AG_GEN_FILES=""
    AG_GEN_FILES="$AG_GEN_ACAM $AG_GEN_RECONF $AG_GEN_GETTEXT $AG_GEN_CONFIG_H $AG_GEN_CONF $AG_GEN_LIBTOOL"
    AG_GEN_DIRS="autom4te.cache"
    echo " done."

    if "$debug"; then set | grep '^AG_'; fi
}


########################################################################
# Clean generated files from $1 directory

clean() {
    dir="$1"
    if test "x$AG_GEN_FILES" = "x"; then echo "Internal error"; exit 2; fi
    echo "$self clean: Entering \`${dir}'"
(
if cd "$dir"; then
    echo -n "Cleaning autogen generated files..."
    rm -rf ${AG_GEN_DIRS}
    rm -f ${AG_GEN_FILES}
    echo " done."
    echo -n "Cleaning generated Makefile, Makefile.in files..."
    if "$debug"; then echo; fi
    find . -type f -name 'Makefile.am' -print | \
	while read file; do
		echo "$file" | grep -q '/{arch}' && continue
		echo "$file" | grep -q '/\.svn'  && continue
		echo "$file" | grep -q '/CVS'    && continue
		base="$(dirname "$file")/$(basename "$file" .am)"
		if "$debug"; then
		    echo -e "  Removing files created from ${file}"
		fi
		rm -f "${base}" "${base}.in"
	done
    if "$debug"; then :; else echo " done."; fi
    echo -n "Removing *~ backup files..."
    find . -type f -name '*~' -exec rm -f {} \;
    echo " done."
    echo "$self clean: Leaving \`${dir}'"
fi
)
}


########################################################################
# Initialize build system in $1 directory

init() {
    dir="$1"
    if test "x$AG_GEN_FILES" = "x"; then echo "Internal error"; exit 2; fi
    echo "Running <<" autoreconf --install --symlink ${AUTORECONF_OPTS} "$CONFIGURE_AC" ">>"
    if autoreconf --install --symlink ${AUTORECONF_OPTS} "$CONFIGURE_AC"; then
	:; else
	status="$?"
	echo "autoreconf quit with exit code $status, aborting."
	exit "$status"
    fi    
    echo "You may run ./configure now in \`${dir}'."
    echo "Run as \"./configure --help\" to find out about config options."
}


########################################################################
# Parse command line.
# This still accepts more than the help text says it does, but that
# isn't supported.

commands="init" # default command in case none is given
pcommands=""
dirs="$(dirname "$0")"
pdirs=""
while :; do
    param="$1"
    if shift; then
	case "$param" in
	    --clean)
		pcommands="$pcommands clean"
		;;
	    --init)
		pcommands="$pcommands init"
		;;
	    --verbose)
		debug="true"
		;;
	    -h|--help)
		print_help
		exit 0
		;;
	    -*)
		echo "Unhandled $self option: $param"
		exit 1
		;;
	    *)
		pdirs="${pdirs} ${param}"
		;;
	esac
    else
	break
    fi
done
if test "x$pcommands" != "x"; then
    # commands given on command line? use them!
    commands="$pcommands"
fi
if test "x$pdirs" != "x"; then
    # dirs given on command line? use them!
    dirs="$pdirs"
fi


########################################################################
# Actually run the commands

for dir in ${dirs}; do
    echo "Running commands on directory \`${dir}'"
    if test ! -d "$dir"; then
	echo "Could not find directory \`${dir}'"	
    fi
    init_vars "$dir"
    for command in ${commands}; do
	"$command" "$dir"
    done
done

exit 0
