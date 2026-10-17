#!/bin/bash
#
# Tests for pike. Every test runs in a fresh sandbox with its own ROOT,
# recipes and cache, so nothing outside the sandbox is touched and root
# is not needed. Usage: tests/run.sh

set -u -o pipefail
export LC_ALL=C

PIKE=$(cd "$(dirname "$0")/.." && pwd)/pike/pike
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
	sed -i 's/^sha256=(.*/sha256=(0000)/' "$PIKE_RECIPES/hello/recipe"
	fails pike build hello
	check out_has "sha256 mismatch"
	check test ! -e "$PIKE_CACHE/packages/hello#1-1.tar.xz"
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
	# The kept file is still modified compared to what version 2 ships.
	rm "$ROOT/etc/hello.conf.new"
	check pike install hello
	check contains "$ROOT/etc/hello.conf" changed
	check has etc/hello.conf.new
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

tests=$(declare -F | sed -n 's/^declare -f \(test_.*\)/\1/p')
for t in $tests; do
	run "$t"
done
printf '\n%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
