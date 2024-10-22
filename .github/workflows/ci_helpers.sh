#!/bin/sh

success() {
	color_out 32 "$1"
}

info() {
	color_out 36 "$1"
}

err() {
	color_out 31 "$1"
}

warn() {
	color_out 33 "$1"
}

err_die() {
	err "$1"
	exit 1
}
