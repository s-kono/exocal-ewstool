#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import datetime
import json
import sys

event_json = json.load(sys.stdin, encoding='utf-8')
try:
    event_json['TotalItemsInView'] = int(event_json['TotalItemsInView'])
except KeyError:
    pass
items = event_json['Items']['CalendarItem']

viewurl = (
  "https://outlook.office365.com"
  "/calendar/item/"
)
viewurl_old = (
  "https://outlook.office365.com"
  "/owa/?exvsurl=1&path=/calendar/item&itemid="
)
# https://docs.microsoft.com/en-us/graph/api/resources/event?view=graph-rest-1.0
#  For work or school accounts: outlook.office365.com
#  For Microsoft accounts: outlook.live.com


def JSTnize(item_list):
    for key in item_list.keys():
        try:
            """
            item_list[key] = (
              datetime.datetime.strptime(
                item_list[key], "%Y-%m-%dT%H:%M:%SZ"
                                        ) + datetime.timedelta(hours=9)
                        ).strftime("%Y-%m-%d %H:%M (JST)")
            """
            item_list[key] = (
              datetime.datetime.strptime(
                item_list[key], "%Y-%m-%dT%H:%M:%S+09:00"
                                        )
                        ).strftime("%Y-%m-%d %H:%M")
        except TypeError:
            continue
        except ValueError:
            continue


def addItemURL(item_list):
    for key in item_list.keys():
        if key != "ItemId":
            continue
        itemid = item_list[key]["Id"]
        encode_itemid = itemid.replace(
          '+', '%2B'
        ).replace(
          '=', '%3D'
        ).replace(
          '/', '%2F'
        )
        item_list[key]["ViewURL"] = viewurl + encode_itemid
        item_list[key]["ViewURL_old"] = viewurl_old + encode_itemid


def main():
    if isinstance(items, dict):
        item = items
        JSTnize(item)
        addItemURL(item)
    elif isinstance(items, list):
        for item in items:
            JSTnize(item)
            addItemURL(item)
    else:
        print(json.dumps(event_json))
        raise

    print(json.dumps(event_json))


if __name__ == '__main__':
    main()
