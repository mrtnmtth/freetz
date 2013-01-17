#!/bin/bash
# Generates a Config.in(.busybox) of Busybox for Freetz
BBDIR="$(dirname $(readlink -f $0))"
BBVER="$(sed -n 's/$(call PKG_INIT_BIN, \(.*\))/\1/p' $BBDIR/busybox.mk)"
BBOUT="$BBDIR/Config.in.busybox"
BBDEP="$BBDIR/busybox.rebuild-subopts.mk.in"

default_int() {
	sed -r -i "/^config FREETZ_BUSYBOX_$1$/{N;N;N;N;N;s/(\tdefault )[^\n]*/\1$2/}" "$BBOUT"
}

default_string() {
	sed -r -i "/^config FREETZ_BUSYBOX_$1$/{N;N;N;N;N;s#(\tdefault )[^\n]*#\1\"$2\"#}" "$BBOUT"
}

default_choice() {
	sed -r -i "/^[ \t]*prompt \"$1\"/{N;N;N;N;N;s/(\tdefault )[^\n]*/\1$2/}" "$BBOUT"
}
depends_on() {
	sed -r -i "/^config FREETZ_BUSYBOX_$1/{N;N;N;N;N;s/(\thelp\n)/\tdepends on $2\n\1/}" "$BBOUT"
}

echo -n "unpacking ..."
rm -rf "$BBDIR/busybox-$BBVER"
tar xf "$BBDIR/../../dl/busybox-$BBVER.tar.bz2" -C "$BBDIR"

echo -n " patching ..."
cd "$BBDIR/busybox-$BBVER/"
for p in $BBDIR/patches/*.patch; do
	patch -p0 < $p >/dev/null
done

echo -n " building ..."
yes "" | make oldconfig >/dev/null

echo -n " parsing ..."
echo -e "\n### Do not edit this file! Run generate.sh to create it. ###\n\n" > "$BBOUT"
$BBDIR/../../tools/parse-config Config.in >> "$BBOUT" 2>/dev/null
rm -rf "$BBDIR/busybox-$BBVER"

echo -n " searching ..."
des=""
for c in $(sed -n 's/^config //p' "$BBOUT"); do
	[ -n "$des" ] && des="${des};"
	des="${des}s!\([ (!]\)\($c$\)!\1FREETZ_BUSYBOX_\2!g;s!\([ (!]\)\($c[) ]\)!\1FREETZ_BUSYBOX_\2!g"
done

echo -n " replacing ..."
sed -i "$des" "$BBOUT"
sed -i '/^mainmenu /d' "$BBOUT"
sed -i 's!\(^#*[\t ]*default \)y\(.*\)$!\1n\2!g;' "$BBOUT"

echo -n " finalizing ..."
echo -e "\n### Do not edit this file! Run generate.sh to create it. ###\n\n" > "$BBDEP"
sed -n 's/^config /$(PKG)_REBUILD_SUBOPTS += /p' "$BBOUT" | sort -u >> "$BBDEP"

default_int FEATURE_COPYBUF_KB 64
default_int FEATURE_VI_MAX_LEN 1024
default_int SUBST_WCHAR 0
default_int LAST_SUPPORTED_WCHAR 0
default_string BUSYBOX_EXEC_PATH "/bin/busybox"
default_choice "Buffer allocation policy" FREETZ_BUSYBOX_FEATURE_BUFFERS_GO_ON_STACK
depends_on LOCALE_SUPPORT "!FREETZ_TARGET_UCLIBC_VERSION_0_9_28"

echo " done."
