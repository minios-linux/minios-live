# apt2sb

The `apt2sb` script installs packages from repositories and packages them into a module.

## Usage

```
apt2sb [OPTIONS] PACKAGE1 [PACKAGE2] [...]
```

## Options

- `-f`, `--file=FILE` - use `FILE` as the filename for the module instead of `PACKAGE1.sb`
- `-l`, `--level=LEVEL` - use `LEVEL` as the filter level
- `--help` - display help and exit
- `--version` - display version information and exit

## Creating modules

1. Run the script with root privileges using the `sudo` command.
2. Specify one or more package names as arguments.
3. Optionally, you can specify a filename for saving changes using the `--file=FILE` option, where `FILE` is the filename. If this option is not specified, the filename will be generated automatically based on the name of the first package.
4. Optionally, you can specify a filtering level using the `--level=LEVEL` option, where `LEVEL` is a numeric value. This option is used to filter overlay filesystem layers.

For example, to install packages `chromium` and `chromium-sandbox` and save changes to file `mymodule.sb`, you can use the following command:

```
sudo apt2sb chromium chromium-sandbox --file=mymodule.sb
```

If you want to filter overlay filesystem layers by level 3, you can use the following command:

```
sudo apt2sb chromium chromium-sandbox --file=mymodule.sb --level=3
```

If you do not specify options `--file` and `--level`, they are not used. If you do not specify option `--file`, then a filename for saving changes is generated automatically based on the name of the first package.

The filtering level is used to filter overlay filesystem layers. For example, if you specify a filtering level of 3 using option `--level=3`, then all overlay filesystem layers with a number greater than 3 will be filtered out and module assembly will be launched based on modules with numbers 00-03. In MiniOS number 03 has module 03-xorg, which means that assembled module will be able to work both in system where modules with larger layer numbers are absent and with presence of such modules since it will include all packages necessary for work on basis of 3rd level.