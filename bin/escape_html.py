#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import html
import sys


def main():
    print(html.escape(
          sys.stdin.read().replace("\r", "").replace("\n", "<br/>"),
          quote=True), end="")


if __name__ == '__main__':
    main()
