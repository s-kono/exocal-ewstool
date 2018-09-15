#!/usr/bin/env python
# -*- coding: utf-8 -*-

import datetime
import json
import sys

event_json = json.load(sys.stdin, encoding='utf-8')
event_json['TotalItemsInView'] = int(event_json['TotalItemsInView'])
items = event_json['Items']['CalendarItem']


def JSTnize(item_list):
    for key in item_list.keys():
        try:
            item_list[key] = (
              datetime.datetime.strptime(
                item_list[key], "%Y-%m-%dT%H:%M:%SZ"
                                        ) + datetime.timedelta(hours=9)
                        ).strftime("%Y-%m-%d %H:%M (JST)")
        except TypeError:
            pass
        except ValueError:
            pass


def main():
    if isinstance(items, dict):
        item = items
        JSTnize(item)
    elif isinstance(items, list):
        for item in items:
            JSTnize(item)
    else:
        print(json.dumps(event_json))
        raise

    print(json.dumps(event_json))


if __name__ == '__main__':
    main()
