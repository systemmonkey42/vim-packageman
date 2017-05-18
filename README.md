
# vim-packageman

Package management for Ubuntu is already pretty simple, with apt-get, apt-cache, apt-config

This package provides an interface for selecting actions on packages which are either already installed
or available to install


The following commands are available:

- PackageMan[!]

  Initiates the PackageMan plugin, loading all package information and displaying the package editor window.
  The default behaviour is to use the list of installed packages.

  Use **Packageman!** to use the list of _available_ packages.  This includes all installed, and net yet installed
  packages available to apt-get.

  *WARNING:* Packages are retrieved from the dpkg 'avail' list.   To generate this list (or update it if
  apt-get&nbsp;update has been performed, use the [PackageManRefresh](#refresh) command.

- [m[,n]]PackageManInstall

  Mark package(s) on line _m_ to _n_ as "to be installed".

- [m[,n]]PackageManRemove

  Mark package(s) on line _m_ to _n_ as "to be uninstalled".
  Once the uninstallation is complete, many packages leave their configuration behind, in case they are reinstalled.
  These show up marked with an **'r'**.    To completely purge these packages, use the Purge command below

- [m[,n]]PackageManPurge

  Mark package(s) on line _m_ to _n_ as "to be purged".
  A package can be purged whether it is installed, or has been recently removed but left configuration files behind.
  Once purged, the package will no longer be visible in the package list.

- [m[,n]]PackageManHold

- PackageManRepeat
- PackageManInfo

- PackageManUndo

- PackageManPurgeAll

- PackageManNextMark
- PackageManPrevMark

- <a name="refresh"></a>PackageManRefresh

- PackageManRefresh

- PackageManView
- PackageManExecute

# vim-packageman
--------------

Simple and lightweight Ubuntu/Debian package management from within VIM

This package provides an interface for selecting actions on packages which are either already installed
or available to install.

# Features

*  Simple vimscript only implementation
*  Requires only `dpkg-query` to retrieve package information, and `dpkg` to store changes.
*  Highlights package
*  Understands the need to preserve __essential__ packages, and highlights them appropriately
*  Supports previewing and saving the package selection
*  Saves the package selection change on write

# Installation

# Configuration
`:help packageman`

# Commands

The following commands are available:

PackageMan

* PackageManHold
* PackageManInstall
* PackageManPurge
* PackageManRemove
* PackageManRepeat

* PackageManUndo
*
* PackageManPurgeAll
*
* PackageManNextMark
* PackageManPrevMark
*
* PackageManRefresh
*
* PackageManView
* PackageManExecute

# Default Mappings

# Customization

# FAQ


# Features

#### whitespace
![image](https://f.cloud.github.com/assets/306502/962401/2a75385e-04ef-11e3-935c-e3b9f0e954cc.png)

## Configurable and extensible

#### Fine-tuned configuration

Every section is composed of parts, and you can reorder and reconfigure them at will.

![image](https://f.cloud.github.com/assets/306502/1073278/f291dd4c-14a3-11e3-8a83-268e2753f97d.png)

Sections can contain accents, which allows for very granular control of visuals (see configuration [here](https://github.com/vim-airline/vim-airline/issues/299#issuecomment-25772886)).

![image](https://f.cloud.github.com/assets/306502/1195815/4bfa38d0-249d-11e3-823e-773cfc2ca894.png)

#### Extensible pipeline

Completely transform the statusline to your liking.  Build out the statusline as you see fit by extracting colors from the current colorscheme's highlight groups.

![allyourbase](https://f.cloud.github.com/assets/306502/1022714/e150034a-0da7-11e3-94a5-ca9d58a297e8.png)

# Rationale

There's already [powerline][2], why yet another statusline?

*  100% vimscript; no python needed.

What about [vim-powerline][1]?

*  vim-powerline has been deprecated in favor of the newer, unifying powerline, which is under active development; the new version is written in python at the core and exposes various bindings such that it can style statuslines not only in vim, but also tmux, bash, zsh, and others.

# Where did the name come from?

I wrote the initial version on an airplane, and since it's light as air it turned out to be a good name.  Thanks for flying vim!

# Installation

This plugin follows the standard runtime path structure, and as such it can be installed with a variety of plugin managers:

| Plugin Manager | Install with... |
| ------------- | ------------- |
| [Pathogen][11] | `git clone https://github.com/vim-airline/vim-airline ~/.vim/bundle/vim-airline`<br/>Remember to run `:Helptags` to generate help tags |
| [NeoBundle][12] | `NeoBundle 'vim-airline/vim-airline'` |
| [Vundle][13] | `Plugin 'vim-airline/vim-airline'` |
| [Plug][40] | `Plug 'vim-airline/vim-airline'` |
| [VAM][22] | `call vam#ActivateAddons([ 'vim-airline' ])` |
| [Dein][52] | `call dein#add('vim-airline/vim-airline')` |
| manual | copy all of the files into your `~/.vim` directory |

# Configuration

`:help airline`

The default setting of 'laststatus' is for the statusline to not appear until a split is created. If you want it to appear all the time, add the following to your vimrc:
`set laststatus=2`

# Integrating with powerline fonts

For the nice looking powerline symbols to appear, you will need to install a patched font.  Instructions can be found in the official powerline [documentation][20].  Prepatched fonts can be found in the [powerline-fonts][3] repository.

Finally, you can add the convenience variable `let g:airline_powerline_fonts = 1` to your vimrc which will automatically populate the `g:airline_symbols` dictionary with the powerline symbols.

# FAQ

Solutions to common problems can be found in the [Wiki][27].

# Performance

Whoa!  Everything got slow all of a sudden...

vim-airline strives to make it easy to use out of the box, which means that by default it will look for all compatible plugins that you have installed and enable the relevant extension.

Many optimizations have been made such that the majority of users will not see any performance degradation, but it can still happen.  For example, users who routinely open very large files may want to disable the `tagbar` extension, as it can be very expensive to scan for the name of the current function.

The [minivimrc][7] project has some helper mappings to troubleshoot performance related issues.

If you don't want all the bells and whistles enabled by default, you can define a value for `g:airline_extensions`.  When this variable is defined, only the extensions listed will be loaded; an empty array would effectively disable all extensions.

# Screenshots

A full list of screenshots for various themes can be found in the [Wiki][14].

# Maintainers

The project is currently being maintained by [Bailey Ling][41], [Christian Brabandt][42], and [Mike Hartington][44].

If you are interested in becoming a maintainer (we always welcome more maintainers), please [go here][43].

# License

MIT License. Copyright (c) 2013-2016 Bailey Ling.

[1]: https://github.com/Lokaltog/vim-powerline
[2]: https://github.com/Lokaltog/powerline
[3]: https://github.com/Lokaltog/powerline-fonts
[4]: https://github.com/tpope/vim-fugitive
[5]: https://github.com/scrooloose/syntastic
[6]: https://github.com/bling/vim-bufferline
[7]: https://github.com/bling/minivimrc
[8]: http://en.wikipedia.org/wiki/Open/closed_principle
[9]: https://github.com/Shougo/unite.vim
[10]: https://github.com/ctrlpvim/ctrlp.vim
[11]: https://github.com/tpope/vim-pathogen
[12]: https://github.com/Shougo/neobundle.vim
[13]: https://github.com/gmarik/vundle
[14]: https://github.com/vim-airline/vim-airline/wiki/Screenshots
[15]: https://github.com/techlivezheng/vim-plugin-minibufexpl
[16]: https://github.com/sjl/gundo.vim
[17]: https://github.com/mbbill/undotree
[18]: https://github.com/scrooloose/nerdtree
[19]: https://github.com/majutsushi/tagbar
[20]: https://powerline.readthedocs.org/en/master/installation.html#patched-fonts
[21]: https://bitbucket.org/ludovicchabant/vim-lawrencium
[22]: https://github.com/MarcWeber/vim-addon-manager
[23]: https://github.com/altercation/solarized
[24]: https://github.com/chriskempson/tomorrow-theme
[25]: https://github.com/tomasr/molokai
[26]: https://github.com/nanotech/jellybeans.vim
[27]: https://github.com/vim-airline/vim-airline/wiki/FAQ
[28]: https://github.com/chrisbra/csv.vim
[29]: https://github.com/airblade/vim-gitgutter
[30]: https://github.com/mhinz/vim-signify
[31]: https://github.com/jmcantrell/vim-virtualenv
[32]: https://github.com/chriskempson/base16-vim
[33]: https://github.com/vim-airline/vim-airline/wiki/Test-Plan
[34]: http://eclim.org
[35]: https://github.com/edkolev/tmuxline.vim
[36]: https://github.com/edkolev/promptline.vim
[37]: https://github.com/gcmt/taboo.vim
[38]: https://github.com/szw/vim-ctrlspace
[39]: https://github.com/tomtom/quickfixsigns_vim
[40]: https://github.com/junegunn/vim-plug
[41]: https://github.com/bling
[42]: https://github.com/chrisbra
[43]: https://github.com/vim-airline/vim-airline/wiki/Becoming-a-Maintainer
[44]: https://github.com/mhartington
[45]: https://github.com/vim-airline/vim-airline/commit/d7fd8ca649e441b3865551a325b10504cdf0711b
[46]: https://github.com/vim-airline/vim-airline#themes
[47]: https://github.com/mildred/vim-bufmru
[48]: https://github.com/ierton/xkb-switch
[49]: https://github.com/vovkasm/input-source-switcher
[50]: https://github.com/jreybert/vimagit
[51]: https://github.com/Shougo/denite.nvim
[52]: https://github.com/Shougo/dein.vim
[53]: https://github.com/lervag/vimtex
