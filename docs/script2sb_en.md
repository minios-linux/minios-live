# script2sb

The `script2sb` application is designed to create modules based on an installation script.

## Usage

```
script2sb [OPTIONS]... --script=FILE
```

## Options

- `-d`, `--directory=DIR` - copy the contents of `DIR` to the root of the module

- `-f`, `--file=FILE` - use `FILE` as the filename for the module

- `-l`, `--level=LEVEL` - use `LEVEL` as the filtering level

- `-s`, `--script=FILE` - use `FILE` as the installation script

- `--help` - display help and exit

- `--version` - display version information and exit

## Creating modules
  
1. Run the script with root privileges using the `sudo` command.
2. Specify the installation script using the `--script=FILE` option, where `FILE` is the path to the installation script.
3. Optionally, you can specify a directory using the `--directory=DIR` option, where `DIR` is the path to the directory. The contents of this directory will be copied to the overlay filesystem before running the installation script.
4. Optionally, you can specify a filename for saving changes using the `--file=FILE` option, where `FILE` is the filename. If this option is not specified, the filename will be generated automatically based on the name of the installation script.
5. Optionally, you can specify a filtering level using the `--level=LEVEL` option, where `LEVEL` is a numeric value. This option is used to filter overlay filesystem layers.

For example, to run the installation script `/path/to/install.sh` and save changes to file `mymodule.sb`, you can use the following command:

```
sudo script2sb --script=/path/to/install.sh --file=mymodule.sb
```

If you want to specify a directory `/path/to/dir` for copying contents before running the installation script, you can use the following command:

```
sudo script2sb --script=/path/to/install.sh --file=mymodule.sb --directory=/path/to/dir
```

If you want to filter overlay filesystem layers by level 3, you can use the following command:

```
sudo script2sb --script=/path/to/install.sh --file=mymodule.sb --level=3
```

If you do not specify options `--directory`, `--file`, and `--level`, they are not used. If you do not specify option `--file`, then a filename for saving changes is generated automatically based on the name of the installation script.

The filtering level is used to filter overlay filesystem layers. For example, if you specify a filtering level of 3 using option `--level=3`, then all overlay filesystem layers with a number greater than 3 will be filtered out and module assembly will be launched based on modules with numbers 00-03. In MiniOS number 03 has module 03-xorg, which means that assembled module will be able to work both in system where modules with larger layer numbers are absent and with presence of such modules since it will include all packages necessary for work on basis of 3rd level.

The installation script specified using option `--script` can be any executable script that performs desired installation steps. The script will be run in chroot environment inside overlay filesystem so it should be written with this in mind.

## Example Script 

Here's an example of a simple installation script that installs text editor `nano` using package manager `apt-get`:

```bash
#!/bin/bash

# Update package lists
apt-get update

# Install nano
apt-get install -y nano
```

This script updates package lists and then installs package `nano` using command `apt-get`. Of course this is just a simple example and real installation script could be much more complex and perform wide range of tasks.