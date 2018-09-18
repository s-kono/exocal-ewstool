#!/usr/bin/env python
# -*- coding: utf-8 -*-

import cgi
import sys


def main():
    print(cgi.escape(
          sys.stdin.read().replace("\r", "").replace("\n", "<br/>"),
          quote=True)),


if __name__ == '__main__':
    main()
