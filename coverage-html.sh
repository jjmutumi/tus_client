#!/usr/bin/env bash

sed -i 's/\\/\//g' coverage/lcov.info
genhtml coverage/lcov.info --output-directory coverage/out