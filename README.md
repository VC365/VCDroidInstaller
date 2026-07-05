# VCDroidInstaller
VCDroidInstaller is a tool for installing Android-x86 and generating boot entries on GRUB-based systems.
It automates ISO analysis, system extraction(Full Installation), and GRUB entry generation to simplify dual-boot setup for Android-x86 distributions.

## Features
- ISO inspection and validation.
- GRUB configuration generator.
- Optional data partition/image creation.
- Basic Information.
  example:
  ```
  ###### Information ######
  Kernel version: 4.9.194-android-x86-gdcaac9a77ef9
  Kernel parametrs: root=/dev/ram0 androidboot.selinux=permissive buildvariant=userdebug quiet
  Android Version: (android_x86) 7.1.2
  ABI Supported: x86,armeabi-v7a,armeabi
  OpenGL ES: 3.0
  ```
## ⚙️ Requirements
- Linux (any GRUB-based system).
- root access (for Full installation)
- bsdtar
- libcdio
- mkfs.ext4 (optional for data image creation)

## Usage
```
Usage: vcdroid-installer [ISO Path | -i,--iso | -f,--folder | -h,--help | -v,--version]
    -i ISO, --iso=ISO                Set iso path.
    -f DIR, --folder=DIR             Set installation folder.
    -h, --help                       Show this help.
    -v, --version                    Print the VCDroidInstaller version.
```
## Build from source
```bash
git clone https://github.com/yourname/vcdroid
cd vcdroid
shards build
```

## Contributing

1. Fork it (<https://github.com/VC365/VCDroidInstaller/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [VC365](https://github.com/VC365) - creator and maintainer
