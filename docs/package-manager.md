# pike

Small source-based package manager written in Bash, in the spirit of CRUX pkgutils and KISS. It uses only what is already in the image: bash, tar, xz, sha256sum and curl.

### Install

pike is in the image as the `pike` package: `/usr/bin/pike` and the recipes in `/usr/share/pike/recipes`. On a system without it, the first copy goes in with:

```
make -C pike DESTDIR=/mnt/rawlinux install
```

The `pike` recipe packages pike itself: the script that runs the build and the recipes it reads. To bring a newer checkout of this repository to the system:

```
git clone https://github.com/JakubBialoskorski/RawLinux
cd RawLinux
PIKE_RECIPES=$PWD/recipes pike/pike upgrade
```

This rebuilds every outdated package with the recipes of the checkout, `pike` among them. On v0.4, where pike is not a package yet, run `PIKE_RECIPES=$PWD/recipes pike/pike add pike` first, then `pike upgrade`.

### Usage

```
pike adopt
pike add less
pike list
pike owns /bin/less
pike files less
pike remove less
```

`adopt` records every file that no package owns as the `base-system` package, so `owns` works for the hand-built system too. Run it again to pick up new files. `add` builds and installs a package with its dependencies, and leaves installed ones alone. `outdated` lists installed packages whose recipe has another version or release, `upgrade` builds and installs them, dependencies first. `strip` removes debug info from the ELF files of `base-system`, see [How it works](#how-it-works). `build`, `install`, `deps` and `checksum` do single steps, see `pike help`.

### Recipes

`recipes/<name>/recipe`:

```bash
name=less
version=679
release=1
depends=()
makedepends=()
source=("https://www.greenwoodsoftware.com/less/less-$version.tar.gz")
sha256=(9b68820c34fa8a0af6b0e01b74f0298bcdd40a0489c61649b47058908a153d78)

build() {
	cd "less-$version"
	./configure --prefix=/usr --sysconfdir=/etc
	make
	make DESTDIR="$PKG" install
}
```

`depends` are needed at run time, `makedepends` only to build, as meson for OpenRC. Both are installed before the build, but only `depends` is recorded, so nothing stops removing a build tool later. `build()` runs in `$SRC` with the sources unpacked and installs into `$PKG`. A source without `://` is a file next to the recipe, as in `base-files`. `pike checksum <name>` prints the `sha256` array for a new recipe.

Config files go to `backup=(etc/foo.conf)`. On upgrade, a locally changed file is kept, and if the package ships a new default, it lands next to it as `.new`. On remove, a changed file is saved as `.pikesave`.

### How it works

- built packages: `/var/cache/pike/packages/<name>#<version>-<release>.tar.xz`
- database: `/var/lib/pike/db/<name>/{version,depends,backup,manifest,takeover}`, plain text
- install refuses files owned by another package and untracked files already on disk
- files of `base-system` are taken over by the package; the originals are kept in `/var/lib/pike/base` and come back when the package is removed or stops shipping them
- `adopt` skips `/home`, `/root`, `/tmp`, `/var/tmp`, `/var/cache` and other filesystems; `base-system` cannot be removed
- upgrade removes files the new version no longer ships
- packages are stripped at build time; `strip` does the same for `base-system`, in a copy renamed over each file, so running programs keep the old one
- `/bin`, `/sbin`, `/lib` and `/lib64` are symlinks to `/usr`, so packages install into `/usr`
- `ROOT=/mnt/target pike install less` installs into another root

### Tests

`make check` in `pike/` runs shellcheck and `tests/run.sh`.

### Limitations

- no signatures, sources are checked only against sha256 from the recipe
- upgrade is not atomic
- `build()` runs as root, without a sandbox
- files created after `pike adopt` are untracked until it runs again, so a package shipping one conflicts with it
- `outdated` compares versions as text, so a recipe with an older version than the installed one counts too
