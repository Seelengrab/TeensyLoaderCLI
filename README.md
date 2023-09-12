# TeensyLoaderCLI

A Julia wrapper package for [teensy_loader_cli](), used for interacting with the Teensy family of microcontrollers.

## Installation

On Linux, make sure to run `install_udev()` to install the `udev` definitions for teensy, if you haven't already set them up.

## Functions

These functions are the supported API of this package. Make sure to read their docstrings thoroughly.

 * `list_mcus`
 * `install_udev`
 * `boot!`
 * `program!`
