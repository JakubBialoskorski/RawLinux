#!/bin/bash
#
# Tests for pike. Every test runs in a fresh sandbox with its own ROOT,
# recipes and cache, so nothing outside the sandbox is touched and root
# is not needed. Usage: tests/run.sh

set -u -o pipefail
export LC_ALL=C

REPO=$(cd "$(dirname "$0")/.." && pwd)
PIKE=$REPO/pike/pike
BASE=$(mktemp -d)
trap 'rm -rf "$BASE"' EXIT

passed=0
failed=0

fresh() {
	T=$BASE/$1
	rm -rf "$T"
	mkdir -p "$T/root" "$T/recipes" "$T/src" "$T/cache" "$T/work"
	export ROOT=$T/root PIKE_RECIPES=$T/recipes PIKE_CACHE=$T/cache PIKE_WORK=$T/work
}

pike() { "$PIKE" "$@" >"$T/out" 2>&1; }

fails() {
	if "$@"; then
		printf '    unexpected success: %s\n' "$*"
		return 1
	fi
}

check() {
	if "$@"; then
		return 0
	fi
	printf '    failed: %s\n' "$*"
	sed 's/^/    | /' "$T/out" 2>/dev/null
	return 1
}

# errexit is ignored inside 'if' conditions, so the test runs as a
# plain command and its status is checked afterwards.
run() {
	local t=$1 rc
	fresh "$t"
	(
		set -e
		"$t"
	)
	rc=$?
	if [ "$rc" -eq 0 ]; then
		passed=$((passed + 1))
		printf 'ok   %s\n' "$t"
	else
		failed=$((failed + 1))
		printf 'FAIL %s\n' "$t"
	fi
}

# recipe <name> <version> <depends> <build body> [file=content ...]
# Creates a source tarball with the given files and a recipe that
# installs them into $PKG with 'cp -a'.
recipe() {
	local name=$1 version=$2 deps=$3 body=$4 kv dir tarball sum
	shift 4
	dir=$T/src/$name-$version
	rm -rf "$dir"
	mkdir -p "$dir"
	for kv in "$@"; do
		mkdir -p "$dir/$(dirname "${kv%%=*}")"
		printf '%s\n' "${kv#*=}" >"$dir/${kv%%=*}"
	done
	tarball=$T/src/$name-$version.tar.gz
	tar -C "$T/src" -czf "$tarball" "$name-$version"
	sum=$(sha256sum "$tarball")
	mkdir -p "$PIKE_RECIPES/$name"
	cat >"$PIKE_RECIPES/$name/recipe" <<EOF
name=$name
version=$version
release=1
depends=($deps)
source=(file://$tarball)
sha256=(${sum%% *})
backup=(${BACKUP:-})
build() {
	cd $name-$version
	${body:-cp -a . "\$PKG"}
}
EOF
}

has() { [ -e "$ROOT/$1" ]; }
hasnt() { [ ! -e "$ROOT/$1" ]; }
contains() { grep -qxF -- "$2" "$1"; }
out_has() { grep -qF -- "$1" "$T/out"; }

test_build_and_install() {
	BACKUP=etc/hello.conf recipe hello 1 "" "" usr/bin/hello=hi usr/share/hello/README=r etc/hello.conf=a
	check pike build hello
	check test -f "$PIKE_CACHE/packages/hello#1-1.tar.xz"
	check pike install hello
	check has usr/bin/hello
	check has etc/hello.conf
	check has var/lib/pike/db/hello/manifest
	pike list
	check contains "$T/out" "hello 1-1"
	pike owns /usr/bin/hello
	check contains "$T/out" hello
	pike files hello
	check contains "$T/out" /usr/share/hello/README
	fails pike owns /usr/bin/nothing
}

test_sha256_mismatch() {
	recipe hello 1 "" "" usr/bin/hello=hi
	cp "$PIKE_RECIPES/hello/recipe" "$T/good"
	sed -i 's/^sha256=(.*/sha256=(0000)/' "$PIKE_RECIPES/hello/recipe"
	fails pike build hello
	check out_has "sha256 mismatch"
	check test ! -e "$PIKE_CACHE/packages/hello#1-1.tar.xz"
	# The bad download is moved aside, so a fixed recipe builds.
	check test -f "$PIKE_CACHE/sources/hello/hello-1.tar.gz.bad"
	cp "$T/good" "$PIKE_RECIPES/hello/recipe"
	check pike build hello
}

test_sources_cached_per_package() {
	recipe a 1 "" "" usr/bin/a=a
	recipe b 1 "" "" usr/bin/b=b
	# Give both sources the same file name, like tag archives from GitHub.
	for n in a b; do
		mkdir -p "$T/src/$n"
		mv "$T/src/$n-1.tar.gz" "$T/src/$n/v1.tar.gz"
		sed -i "s|$T/src/$n-1.tar.gz|$T/src/$n/v1.tar.gz|" "$PIKE_RECIPES/$n/recipe"
	done
	check pike build a
	check pike build b
}

test_build_failure_stops() {
	recipe hello 1 "" "false; cp -a . \"\$PKG\"" usr/bin/hello=hi
	fails pike build hello
	check out_has "build() failed"
	check test ! -e "$PIKE_CACHE/packages/hello#1-1.tar.xz"
}

test_merged_usr_enforced() {
	recipe hello 1 "" "" bin/hello=hi
	fails pike build hello
	check out_has "use /usr/bin instead"
}

test_conflict_with_package() {
	recipe hello 1 "" "" usr/bin/hello=hi
	recipe clash 1 "" "" usr/bin/hello=other
	check pike build hello
	check pike build clash
	check pike install hello
	fails pike install clash
	check out_has "/usr/bin/hello is owned by hello"
	check contains "$ROOT/usr/bin/hello" hi
	check test ! -e "$ROOT/var/lib/pike/db/clash"
}

test_conflict_with_untracked_file() {
	recipe hello 1 "" "" usr/bin/hello=hi
	mkdir -p "$ROOT/usr/bin"
	echo mine >"$ROOT/usr/bin/hello"
	check pike build hello
	fails pike install hello
	check out_has "not owned by any package"
	check contains "$ROOT/usr/bin/hello" mine
}

test_upgrade_removes_stale_files() {
	recipe hello 1 "" "" usr/bin/hello=v1 usr/share/hello/README=r usr/share/old/file=o
	check pike build hello
	check pike install hello
	recipe hello 2 "" "" usr/bin/hello=v2 usr/share/hello/NEWS=n
	check pike build hello
	check pike install hello
	check contains "$ROOT/usr/bin/hello" v2
	check hasnt usr/share/hello/README
	check has usr/share/hello/NEWS
	check hasnt usr/share/old
	check contains "$ROOT/var/lib/pike/db/hello/version" 2-1
}

test_backup_unmodified_is_upgraded() {
	BACKUP=etc/hello.conf recipe hello 1 "" "" etc/hello.conf=default1
	check pike build hello
	check pike install hello
	BACKUP=etc/hello.conf recipe hello 2 "" "" etc/hello.conf=default2
	check pike build hello
	check pike install hello
	check contains "$ROOT/etc/hello.conf" default2
	check hasnt etc/hello.conf.new
}

test_backup_modified_is_kept() {
	BACKUP=etc/hello.conf recipe hello 1 "" "" etc/hello.conf=default1
	check pike build hello
	check pike install hello
	echo changed >"$ROOT/etc/hello.conf"
	BACKUP=etc/hello.conf recipe hello 2 "" "" etc/hello.conf=default2
	check pike build hello
	check pike install hello
	check contains "$ROOT/etc/hello.conf" changed
	check contains "$ROOT/etc/hello.conf.new" default2
	# A release that ships the same file again leaves the local one alone,
	# without another .new.
	rm "$ROOT/etc/hello.conf.new"
	BACKUP=etc/hello.conf recipe hello 3 "" "" etc/hello.conf=default2
	check pike build hello
	check pike install hello
	check contains "$ROOT/etc/hello.conf" changed
	check hasnt etc/hello.conf.new
	# One that ships a new default does.
	BACKUP=etc/hello.conf recipe hello 4 "" "" etc/hello.conf=default4
	check pike build hello
	check pike install hello
	check contains "$ROOT/etc/hello.conf" changed
	check contains "$ROOT/etc/hello.conf.new" default4
}

test_backup_matching_needs_no_new_file() {
	BACKUP=etc/hello.conf recipe hello 1 "" "" etc/hello.conf=default1
	check pike build hello
	check pike install hello
	echo changed >"$ROOT/etc/hello.conf"
	BACKUP=etc/hello.conf recipe hello 2 "" "" etc/hello.conf=changed
	check pike build hello
	check pike install hello
	check contains "$ROOT/etc/hello.conf" changed
	check hasnt etc/hello.conf.new
}

test_remove_saves_modified_backup() {
	BACKUP="etc/a.conf etc/b.conf" recipe hello 1 "" "" etc/a.conf=a etc/b.conf=b
	check pike build hello
	check pike install hello
	echo changed >"$ROOT/etc/a.conf"
	check pike remove hello
	check contains "$ROOT/etc/a.conf.pikesave" changed
	check hasnt etc/a.conf
	check hasnt etc/b.conf
	check hasnt etc/b.conf.pikesave
}

test_remove_respects_dependencies() {
	recipe lib 1 "" "" usr/lib/libx=x
	recipe app 1 "lib" "" usr/bin/app=a
	check pike build lib
	check pike build app
	fails pike install app
	check out_has "app needs: lib"
	check pike install lib
	check pike install app
	fails pike remove lib
	check out_has "lib is needed by: app"
	check pike remove app
	check hasnt usr/bin/app
	check pike remove lib
	check hasnt usr/lib/libx
	check hasnt usr
	pike list
	check test ! -s "$T/out"
}

test_remove_keeps_shared_directories() {
	recipe a 1 "" "" usr/share/common/a=a
	recipe b 1 "" "mkdir -p \"\$PKG/usr/share/common\"" x=unused
	check pike build a
	check pike build b
	check pike install a
	check pike install b
	check pike remove a
	check hasnt usr/share/common/a
	check test -d "$ROOT/usr/share/common"
}

test_dependency_cycle() {
	recipe a 1 "b" "" usr/bin/a=a
	recipe b 1 "a" "" usr/bin/b=b
	fails pike deps a
	check out_has "dependency cycle: a -> b -> a"
	fails pike add a
}

test_add_builds_dependencies_in_order() {
	recipe base 1 "" "" usr/lib/base=b
	recipe mid 1 "base" "" usr/lib/mid=m
	recipe top 1 "mid base" "" usr/bin/top=t
	pike deps top
	check test "$(cat "$T/out")" = "$(printf 'base\nmid\ntop')"
	check pike add top
	check has usr/bin/top
	pike list
	check test "$(cat "$T/out")" = "$(printf 'base 1-1\nmid 1-1\ntop 1-1')"
	pike deps top
	check out_has "base (installed)"
}

test_unsafe_paths_rejected() {
	mkdir -p "$T/evil"
	printf 'name=evil\nversion=1\nrelease=1\ndepends=\nbackup=\n' >"$T/evil/.pikeinfo"
	echo x >"$T/evil/file"
	tar -C "$T/evil" --transform 's|^\./file$|./../../escaped|' -cJf "$T/evil#1-1.tar.xz" .
	fails pike install "$T/evil#1-1.tar.xz"
	check out_has "unsafe paths"
	check test ! -e "$T/escaped"
}

test_lock_blocks_second_writer() {
	recipe hello 1 "" "" usr/bin/hello=hi
	check pike build hello
	mkdir -p "$ROOT/var/lib/pike/lock"
	fails pike install hello
	check out_has "database is locked"
	rmdir "$ROOT/var/lib/pike/lock"
	check pike install hello
	check test ! -e "$ROOT/var/lib/pike/lock"
}

test_adopt_registers_base_system() {
	mkdir -p "$ROOT/usr/bin" "$ROOT/etc" "$ROOT/boot" "$ROOT/home/user" "$ROOT/tmp" "$ROOT/var/cache/x"
	echo sh >"$ROOT/usr/bin/sh"
	echo root >"$ROOT/etc/passwd"
	echo k >"$ROOT/boot/bzImage"
	echo mine >"$ROOT/home/user/notes"
	echo t >"$ROOT/tmp/x"
	ln -s usr/bin "$ROOT/bin"
	check pike adopt
	m=$ROOT/var/lib/pike/db/base-system/manifest
	check contains "$m" usr/bin/sh
	check contains "$m" usr/bin/
	check contains "$m" bin
	check contains "$m" etc/passwd
	check contains "$m" boot/bzImage
	fails grep -qE '^(home|root|tmp|var/cache|var/lib/pike)(/|$)' "$m"
	fails grep -qx '/*' "$m"
	pike owns /usr/bin/sh
	check test "$(cat "$T/out")" = base-system
	pike list
	check out_has "base-system "
}

test_install_takes_over_base_files() {
	recipe hello 1 "" "" usr/bin/hello=new usr/share/hello/README=r
	mkdir -p "$ROOT/usr/bin" "$ROOT/usr/share/hello"
	echo old >"$ROOT/usr/bin/hello"
	echo sh >"$ROOT/usr/bin/sh"
	check pike adopt
	check pike build hello
	# A file created after adopt is still untracked.
	echo mine >"$ROOT/usr/share/hello/README"
	fails pike install hello
	check out_has "/usr/share/hello/README exists and is not owned by any package"
	rm "$ROOT/usr/share/hello/README"
	check pike install hello
	check out_has "files taken over from base-system: 1"
	check contains "$ROOT/usr/bin/hello" new
	pike owns /usr/bin/hello
	check test "$(cat "$T/out")" = hello
	m=$ROOT/var/lib/pike/db/base-system/manifest
	fails contains "$m" usr/bin/hello
	check contains "$m" usr/bin/sh
	check contains "$ROOT/var/lib/pike/base/usr/bin/hello" old
	# Removing the package gives the original back to the base system.
	check pike remove hello
	check out_has "files given back to base-system: 1"
	check contains "$ROOT/usr/bin/hello" old
	check hasnt usr/share/hello/README
	check hasnt var/lib/pike/base/usr/bin/hello
	check contains "$m" usr/bin/hello
	pike owns /usr/bin/hello
	check test "$(cat "$T/out")" = base-system
}

test_upgrade_gives_back_dropped_base_files() {
	recipe linux 1 "" "" boot/bzImage=new1 boot/config=c1
	mkdir -p "$ROOT/boot"
	echo old >"$ROOT/boot/bzImage"
	check pike adopt
	check pike build linux
	check pike install linux
	recipe linux 2 "" "" boot/bzImage=new2
	check pike build linux
	check pike install linux
	check contains "$ROOT/boot/bzImage" new2
	check contains "$ROOT/var/lib/pike/base/boot/bzImage" old
	recipe linux 3 "" "" boot/vmlinuz=new3
	check pike build linux
	check pike install linux
	check out_has "files given back to base-system: 1"
	check contains "$ROOT/boot/bzImage" old
	check hasnt boot/config
	pike owns /boot/bzImage
	check test "$(cat "$T/out")" = base-system
	check test ! -s "$ROOT/var/lib/pike/db/linux/takeover"
	check pike remove linux
	check contains "$ROOT/boot/bzImage" old
	check hasnt boot/vmlinuz
}

test_adopt_skips_package_files() {
	recipe hello 1 "" "" usr/bin/hello=hi
	check pike build hello
	check pike install hello
	mkdir -p "$ROOT/etc"
	echo a >"$ROOT/etc/a"
	check pike adopt
	m=$ROOT/var/lib/pike/db/base-system/manifest
	fails contains "$m" usr/bin/hello
	check contains "$m" usr/bin/
	check contains "$m" etc/a
	pike owns /usr/bin/hello
	check test "$(cat "$T/out")" = hello
	# Running it again records new files and forgets deleted ones.
	rm "$ROOT/etc/a"
	echo b >"$ROOT/etc/b"
	check pike adopt
	fails contains "$m" etc/a
	check contains "$m" etc/b
	fails contains "$m" usr/bin/hello
}

test_base_system_cannot_be_removed() {
	mkdir -p "$ROOT/usr/bin"
	echo sh >"$ROOT/usr/bin/sh"
	check pike adopt
	fails pike remove base-system
	check out_has "base-system cannot be removed"
	check has usr/bin/sh
}

test_makedepends_are_not_recorded() {
	recipe tool 1 "" "" usr/bin/tool=t
	recipe app 1 "" "" usr/bin/app=a
	echo 'makedepends=(tool)' >>"$PIKE_RECIPES/app/recipe"
	pike deps app
	check test "$(cat "$T/out")" = "$(printf 'tool\napp')"
	check pike add app
	check has usr/bin/tool
	check test "$(cat "$ROOT/var/lib/pike/db/app/depends")" = ""
	# Nothing needs the build tool once app is built.
	check pike remove tool
	check has usr/bin/app
}

test_outdated_and_upgrade() {
	recipe hello 1 "" "" usr/bin/hello=1
	check pike add hello
	pike outdated
	check test ! -s "$T/out"
	# A new version that brings in a dependency.
	recipe lib 1 "" "" usr/lib/lib=l
	recipe hello 2 "lib" "" usr/bin/hello=2
	pike outdated
	check test "$(cat "$T/out")" = "hello 1-1 -> 2-1"
	check pike upgrade
	pike list
	check test "$(cat "$T/out")" = "$(printf 'hello 2-1\nlib 1-1')"
	check test "$(cat "$ROOT/usr/bin/hello")" = 2
	check pike upgrade
	check out_has "nothing to upgrade"
}

test_strip_base_system() {
	command -v cc >/dev/null || return 0
	mkdir -p "$ROOT/usr/bin"
	printf 'int main(void) { return 7; }\n' >"$T/hello.c"
	cc -g -o "$ROOT/usr/bin/hello" "$T/hello.c"
	ln "$ROOT/usr/bin/hello" "$ROOT/usr/bin/hello2"
	echo text >"$ROOT/usr/bin/script"
	check pike adopt
	size=$(stat -c %s "$ROOT/usr/bin/hello")
	check pike strip
	check out_has "stripped 1 files"
	check test "$(stat -c %s "$ROOT/usr/bin/hello")" -lt "$size"
	check test "$ROOT/usr/bin/hello" -ef "$ROOT/usr/bin/hello2"
	check test "$(cat "$ROOT/usr/bin/script")" = text
	rc=0
	"$ROOT/usr/bin/hello2" || rc=$?
	check test "$rc" = 7
	check pike strip
	check out_has "stripped 0 files"
	fails test -e "$ROOT/usr/bin/hello.pikestrip"
}

test_repo_recipes_resolve() {
	local r
	PIKE_RECIPES=$REPO/recipes
	for r in "$PIKE_RECIPES"/*/recipe; do
		r=${r%/recipe}
		check pike deps "${r##*/}"
	done
	# Build tools come first, and sysvinit replaces /sbin/init, so it goes
	# in just before OpenRC, which it runs.
	check pike deps openrc
	check test "$(tr '\n' ' ' <"$T/out")" = "python ninja meson pkgconf libxcrypt shadow base-files util-linux e2fsprogs inetutils sysvinit openrc "
}

test_base_files_recipe() {
	# A stand-in for shadow, so the test does not build it.
	recipe shadow 1 "" "" usr/bin/login=login
	cp -r "$REPO/recipes/base-files" "$PIKE_RECIPES/"
	check pike add base-files
	check has etc/inittab
	check has etc/conf.d/network
	check test -d "$ROOT/run"
	check test "$(stat -c %a "$ROOT/etc/shadow" "$ROOT/etc/gshadow" "$ROOT/root")" = "600
600
700"
	# Every user has a shadow entry and every group a gshadow entry.
	check test "$(cut -d: -f1 "$ROOT/etc/passwd")" = "$(cut -d: -f1 "$ROOT/etc/shadow")"
	check test "$(grep -v '^#' "$ROOT/etc/group" | cut -d: -f1)" = "$(cut -d: -f1 "$ROOT/etc/gshadow")"
	# Every file it installs is a backup file.
	pike files base-files
	grep -v '/$' "$T/out" | sed 's|^/||' >"$T/files"
	cut -d' ' -f2- "$ROOT/var/lib/pike/db/base-files/backup" | sort >"$T/backup"
	check cmp "$T/files" "$T/backup"
}

tests=$(declare -F | sed -n 's/^declare -f \(test_.*\)/\1/p')
for t in $tests; do
	run "$t"
done
printf '\n%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
