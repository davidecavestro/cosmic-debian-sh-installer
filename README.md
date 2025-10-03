# Cosmic DE shell installer for Debian
A Cosmic Desktop Environment shell installer for Debian

[![GitHub Activity][commits-shield]][commits]
[![License][license-shield]](LICENSE)

## Status

I see it working on my Debian Trixie notebook.

### Known issues
- unlock screen not working ("permission denied" on the unlock dialog)
- seems it cannot recognize active ethernet connection

## Usage

To download packages and install
```sh
sh setup.sh --install
```

## License

Blindly converted by free AI from [ashimokawa/cosmic-debian-installer](https://codeberg.org/ashimokawa/cosmic-debian-installer)
with some minor cosmetic tweaks.

So - as a derivative work of GPL code - this is distributed under GPL as well.


## Dependencies

- POSIX sh
- curl
- gunzip or gzip
- awk
- grep
- basename

***

[commits-shield]: https://img.shields.io/github/commit-activity/y/davidecavestro/cosmic-debian-sh-installer.svg?style=flat-square
[commits]: https://github.com/davidecavestro/cosmic-debian-sh-installer/commits/main
[license-shield]: https://img.shields.io/github/license/davidecavestro/cosmic-debian-sh-installer.svg?style=flat-square
