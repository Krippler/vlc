# Linux AppImage

`build-appimage.sh` builds VLC with the Qt interface and packages it as a
single `VLC-<version>-x86_64.AppImage` file, runnable on most x86_64 Linux
distributions with glibc 2.39 or newer (Ubuntu 24.04, Debian 13, Fedora 40
and later).

As for every AppImage, a few base libraries present on any desktop
installation are not bundled: OpenGL, ALSA, X11 session management,
HarfBuzz, FriBidi, libgpg-error and libcom_err.

To run it:

```sh
chmod +x VLC-*-x86_64.AppImage
./VLC-*-x86_64.AppImage
```

On distributions without FUSE 2 (`libfuse2`), set
`APPIMAGE_EXTRACT_AND_RUN=1` or run it with `--appimage-extract-and-run`.

## Building locally

On Ubuntu 24.04:

```sh
sudo apt-get install $(grep -v '^\s*#' extras/package/appimage/ubuntu-deps.txt | grep -v '^\s*$')
extras/package/appimage/build-appimage.sh
```

The AppImage is written to `build-appimage/`. `WORK_DIR`, `VERSION` and
`JOBS` can be set in the environment, see the top of the script.

## Releases

The `Linux AppImage` workflow (`.github/workflows/linux-appimage.yml`) builds
the AppImage on every push and attaches it to the workflow run.

A GitHub release with the AppImage and its `SHA256SUMS` is published in two
ways:

- bump the version in `extras/package/appimage/VERSION` and push: when no
  tag exists for that version yet, the workflow creates the `v<version>` tag
  on the pushed commit and publishes the release

  ```sh
  echo 0.2.0 > extras/package/appimage/VERSION
  git commit -am "release 0.2.0"
  git push
  ```

- or push a version tag directly:

  ```sh
  git tag -a v0.2.0 -m "VLC v0.2.0"
  git push origin v0.2.0
  ```

Versions follow [semantic versioning](https://semver.org), tags get a `v`
prefix. Versions with a suffix, such as `0.2.0-rc.1`, are published as
pre-releases. The release notes are generated from the commits since the
previous release.
