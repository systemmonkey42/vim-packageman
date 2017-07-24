
# VIM-PackageMan

Simple and lightweight Ubuntu/Debian package management from within VIM

This package provides an interface for selecting actions on packages which are
either already installed or available to install

# Features

*  Simple vimscript only implementation.
*  Requires only [dpkg-query][8] to retrieve package information, and [dpkg][7] to store changes.
*  Highlights package.
*  Understands the need to preserve __essential__ packages, and highlights them appropriately
*  Supports previewing and saving the package selection
*  Saves the package selection change on write and will show the saved state on load
*  Uses bash, awk and sort under the covers to speed up text processing)

# Installation

This plugin follows the standard runtime path structure, and as such it can be
installed with a variety of plugin managers:

| Plugin&nbsp;Manager | Install with...                                  |
| ------------------- | ------------------------------------------------ |
| [Pathogen][1]         | `git clone https://github.com/systemmonkey42/vim-packageman ~/.vim/bundle/vim-packageman`<br/>Remember to run `:Helptags` to generate help tags          |
| [NeoBundle][2]        | `NeoBundle 'systemmonkey42/vim-packageman'`        |
| [Vundle][3]           | `Plugin 'systemmonkey42/vim-packageman'`           |
| [Plug][4]             | `Plug 'systemmonkey42/vim-packageman'`             |
| [VAM][5]              | `call vam#ActivateAddons([ 'vim-packageman' ])`    |
| [Dein][6]             | `call dein#add('systemmonkey42/vim-packageman')`   |
| manual              | copy all of the files into your `~/.vim` directory |


# Commands

The following commands are available:

- PackageMan[!]

  Initiates the PackageMan plugin, loading all package information and displaying the package editor window.
  The default behaviour is to use the list of installed packages.

  Use **Packageman!** to use the list of _available_ packages.  This includes all installed, and not yet installed
  packages available to [apt-get][9].

  *WARNING:* Packages are retrieved from the dpkg 'avail' list.   To generate (or update) this list after
  [apt-get update][9] has been performed, use the [PackageManRefresh](#refresh) command.

- [m[,n]]PackageManInstall

  Mark package(s) on line _m_ to _n_ as "to be installed".  This will show an **'i'** next to the package name if the
  package is not already installed.

- [m[,n]]PackageManRemove

  Mark package(s) on line _m_ to _n_ as "to be uninstalled".
  Once the uninstallation is complete, many packages leave their configuration
  behind, in case they are reinstalled. These show up marked with an **'r'**.
  To completely purge these packages, use the Purge command below

- [m[,n]]PackageManPurge

  Mark package(s) on line _m_ to _n_ as "to be purged".

  A package can be purged whether it is installed, or has been recently removed 
  but left configuration files behind. Once purged, the package will no longer
  be visible in the package list.  This will show an **'p'** next to the package 
  name.

- [m[,n]]PackageManHold

  Mark package(s) on line _m_ to _n_ as "to be held".

  A package in the _hold_ state will never upgrade automatically via
  [apt-get dist-upgrade][9].  This will show an **'h'** next to the package name.

- PackageManRepeat

  Repeat the last command.   After executing _PackageManInstall_ for example, 
  pressing a key bound to _PackageManRepeat_ will cause subsequent packages to be 
  marked for installation.  This will move to the next line after marking the 
  package.

- PackageManInfo

  Display detailed information about the package in the VIM preview window.
  Executing this a second time on the same package will close the preview
  window.  Executing this on another package will update the preview window.

- PackageManUndo

  Completely undo the last change.  If a number of packages are marked for
  install, this will reset them to their original state.
  Note that if you commit the changes, the you will need to commit the undo for
  it to have any effect. When marking a package for install, dependencies are
  automatically marked for installation.  Toggling the Install will only reset
  the package you toggle.  Undo however, will reset the package and all dependencies.

- PackageManPurgeAll

  Where packages are visible in the **'r'** or removed state, this will mark
  all to be purged.  You must commit this before it will take effect.

- PackageManNextMark and PackageManPrevMark

  Navigate to the next or previous block of marked packages.

- <a name="refresh"></a>PackageManRefresh[!]

  Using the _apt-get_ utility, this will retrieve the details of all known
  packages and import them.  This allows _PackageMan!_ to accurately display
  uninstalled packages.

  The use of '!' will force an 'apt-get update' as part of the refresh.

- PackageManView

  Display a preview of all changes which are pending for the next commit.

- PackageManExecute

  Commit all changes and execute the command [apt-get dselect-upgrade][9] to
  trigger the installation/removal of packages.

# Key Bindings

Default key bindings are as follows:

| Normal Mode  |         Action       |
| -----------: | -------------------- |
|            I | PackageManInstall    |
|            R | PackageManRemove     |
|            D | PackageManRemove (mnemonic: delete package)|
|            P | PackageManPurge      |
|            H | PackageManHold       |
|            V | PackageManView       |
|            E | PackageManExecute    |
|       U or u | PackageManUndo       |
|&lt;Space&gt; | PackageManRepeat     |
|     ]s or ]c | PackageManNextMark   |
|     [s or [c | PackageManPrevMark   |

<br> <br>

| Visual Mode  |    Action            |
| -----------: | -------------------- |
|            I | PackageManInstall    |
|            R | PackageManRemove     |
|            D | PackageManRemove (mnemonic: delete package)|
|            P | PackageManPurge      |
|            H | PackageManHold       |

# Configuration

Find everything you need here;

`:help packageman`

By default, packages which are removed, but maintain their configuration files
on disk, are marked 'removed', while a fully uninstalled package will simply
disappear.

Use the following global to hide packages in the 'removed' state, as if they
were completely gone.

`let g:packageman_hide_removed = 1`

# FAQ

- This is not much of an FAQ

# Performance

When using _PackageMan_ to manage installed packages, things should be nice and
snappy with even a few thousand installed packages.

However... when using _PackageMan!_ with the APT cache of all possible
packages, things get a tad slow.
The problem lies in how a complete APT cache currently has almost 50,000
packages, and PackageMan will be managing potentially thousands of signs.

Hopefully this can be resolved with performance tweaks.. Most of the issues
occur during initial loading due to the overhead of parsing the package data.

# License

GPLv3

[1]: https://github.com/tpope/vim-pathogen
[2]: https://github.com/Shougo/neobundle.vim
[3]: https://github.com/gmarik/vundle
[4]: https://github.com/junegunn/vim-plug
[5]: https://github.com/MarcWeber/vim-addon-manager
[6]: https://github.com/Shougo/dein.vim
[7]: http://manpages.ubuntu.com/manpages/xenial/man1/dpkg.1.html
[8]: http://manpages.ubuntu.com/manpages/xenial/man1/dpkg-query.1.html
[9]: http://manpages.ubuntu.com/manpages/xenial/man8/apt-get.8.html
