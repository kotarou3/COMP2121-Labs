#!/bin/sh

cd $(dirname "$1")
make upload-$(basename "$1")
