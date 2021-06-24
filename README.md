# Test calendar-tool for Exchange Online EWS (BasicAuth)

 * Upcoming changes to Exchange Web Services (EWS) API for Office 365 - Office 365 Developer Blog [2018-07-19]
   * https://developer.microsoft.com/en-us/graph/blogs/upcoming-changes-to-exchange-web-services-ews-api-for-office-365/
```
Today we are sharing our plans for the roadmap of Exchange Web Services (EWS)
 and the planned deprecation of Basic Auth access for EWS in October 13th, 2020.
```

 * Basic Authentication and Exchange Online : April 2020 Update [2020-04-03]
   * https://techcommunity.microsoft.com/t5/exchange-team-blog/basic-authentication-and-exchange-online-april-2020-update/ba-p/1275508

 * Basic Authentication and Exchange Online : July Update - Microsoft Tech Community - 1530163 [2020-07-28]
   * https://techcommunity.microsoft.com/t5/exchange-team-blog/basic-authentication-and-exchange-online-july-update/ba-p/1530163#bodyDisplay:~:text=planning%20to%20disable%20Basic%20Authentication%20for,in%20the%20second%20half%20of%202021
```
Authentication Policies:
  ... the Exchange Team is planning to disable Basic Authentication for the EAS, EWS, POP, IMAP, and RPS protocols in the second half of 2021.
  ... we plan to begin disabling Basic Authentication in existing tenants with no recorded usage as early as October 2020.
```

 * Basic Authentication and Exchange Online - February 2021 Update - Microsoft Tech Community [2021-02-04]
   * https://techcommunity.microsoft.com/t5/exchange-team-blog/basic-authentication-and-exchange-online-february-2021-update/ba-p/2111904
```
The first change is that until further notice, we will not be disabling Basic Auth for any protocols that your tenant is using. When we resume this program, we will provide a minimum of twelve months notice before we block the use of Basic Auth on any protocol being used in your tenant.

We will continue with our plan to disable Basic Auth for protocols that your tenant is not using. …
```


---

 * 要
   * python3
     * xmljson (pip3 install xmljson)
   * jq
   * xmllint
 * JST 前提

## init

```sh
% git clone https://github.com/s-kono/exocal-ewstool.git ${REPO_DIR}
% cd ${REPO_DIR:-exocal-ewstool}/
%
% chmod 700 .tmp/
%
% cat conf/netrc_EWS.sample
machine outlook.office365.com login Your.Account@YourDomain.example.jp password Your.Pass.word
%
% install -m 600 conf/netrc_EWS{.sample,}
% vi conf/netrc_EWS
%
% vi bin/SHELLSCRIPT_CONFIG
### Edit as necessary
DEF_DOMAIN=
CURL_PROXYOPT=
REGISTERABLE_START_SHIFTDAYS=
```

## Example

### get UserSchedule

```sh
% ./bin/get-usercal.sh -h
%
% ./bin/get-usercal.sh -u s-kono
% ./bin/get-usercal.sh -s -7
% ./bin/get-usercal.sh -s 12/30 -e 5
% ./bin/get-usercal.sh -s 2022-01-01 -q 2>/dev/null
% ./bin/get-usercal.sh -m
% ./bin/get-usercal.sh -f
```

### get RoomSchedule

```sh
create ./conf/room.json

% ./bin/update-roomconf.sh
% more ./conf/room.json
```

```sh
% ./bin/get-roomcal.sh -h
%
% ./bin/get-roomcal.sh -r "<RoomName>"
% ./bin/get-roomcal.sh -r <RoomEmailAddress>
% ./bin/get-roomcal.sh -r "<RoomName>" -s 1
```

### get CalendarItem

```sh
% ./bin/get-calitem.sh -h
%
% ./bin/get-calitem.sh -i "<Calendaritem_Id>" -k "<Calendaritem_ChangeKey>"
```

### create CalendarItem

```sh
% ./bin/create-cal.sh -h
%
% ./bin/create-cal.sh -t Title -s "2020/01/01 15:00" -d -p
% ./bin/create-cal.sh -t "Title hoge" -b "$( cat description.txt )" -s "11/03 23:15" -e "11/04 01:45"
% ./bin/create-cal.sh -t "Title fuga" -s "12/21 22:00" -e 5 -o Organizer -u User1,User2 -r Room
```

### register WeeklyEvent

```sh
% cat conf/weeklyevent.list.sample
% vi conf/weeklyevent.list
```

```
## sample crontab
01  09  *  *  *  /path.to.dir/bin/register_weeklyevent.sh -v
```

### get ServerTimeZones

```sh
% bash -c '. bin/SHELLSCRIPT_CONFIG; ${EX_CURL[@]} -d@tmpl/GetServerTimeZones.xml' | xmllint --format -
```

### ConvertId HexEntryId=>EwsId

```sh
% ./bin/get-convertid-hex2ews.sh -f -i 000000007....
```

## Reference

 * Exchange での認証と EWS | Microsoft Docs
   * https://docs.microsoft.com/ja-jp/exchange/client-developer/exchange-web-services/authentication-and-ews-in-exchange

 * EWS XML elements in Exchange | Microsoft Docs
   * https://docs.microsoft.com/en-us/exchange/client-developer/web-service-reference/ews-xml-elements-in-exchange
 * Item | Microsoft Docs
   * https://docs.microsoft.com/en-us/exchange/client-developer/web-service-reference/item
   * https://docs.microsoft.com/ja-jp/exchange/client-developer/web-service-reference/item
 * CalendarItem | Microsoft Docs
   * https://docs.microsoft.com/en-us/exchange/client-developer/web-service-reference/calendaritem
   * https://docs.microsoft.com/ja-jp/exchange/client-developer/web-service-reference/calendaritem
 * FieldURI | Microsoft Docs
   * https://docs.microsoft.com/en-us/exchange/client-developer/web-service-reference/fielduri

 * Web Services Time Zones in Exchange 2010 | Microsoft Docs
   * https://docs.microsoft.com/en-us/previous-versions/office/developer/exchange-server-2010/hh505683(v%3Dexchg.140)

 * RequestServerVersion | Microsoft Docs
   * https://docs.microsoft.com/en-US/exchange/client-developer/web-service-reference/requestserverversion

 * FindItem | Microsoft Docs
   * https://docs.microsoft.com/en-us/exchange/client-developer/web-service-reference/finditem
 * CalendarView | Microsoft Docs
   * https://docs.microsoft.com/en-us/exchange/client-developer/web-service-reference/calendarview
 * Exchange の EWS を使用して予定と会議を取得する | Microsoft Docs
   * https://docs.microsoft.com/ja-jp/exchange/client-developer/exchange-web-services/how-to-get-appointments-and-meetings-by-using-ews-in-exchange
 * FindItem 操作 | Microsoft Docs
   * https://docs.microsoft.com/ja-jp/exchange/client-developer/web-service-reference/finditem-operation

 * GetItem 操作 (予定表アイテム) | Microsoft Docs
   * https://docs.microsoft.com/ja-JP/exchange/client-developer/web-service-reference/getitem-operation-calendar-item

 * CreateItem | Microsoft Docs
   * https://docs.microsoft.com/en-us/exchange/client-developer/web-service-reference/createitem
 * Exchange 2013 の EWS を使用して予定と会議を作成する | Microsoft Docs
   * https://docs.microsoft.com/ja-jp/exchange/client-developer/exchange-web-services/how-to-create-appointments-and-meetings-by-using-ews-in-exchange-2013
 * CreateItem 操作 (予定表アイテム) | Microsoft Docs
   * https://docs.microsoft.com/ja-jp/exchange/client-developer/web-service-reference/createitem-operation-calendar-item

 * Exchange で EWS を使用して、予定を削除し、会議をキャンセルする | Microsoft Docs
   * https://docs.microsoft.com/ja-jp/exchange/client-developer/exchange-web-services/how-to-delete-appointments-and-cancel-meetings-by-using-ews-in-exchange

 * Exchange で EWS を使用して、会議室一覧を取得する | Microsoft Docs
   * https://docs.microsoft.com/ja-jp/exchange/client-developer/exchange-web-services/how-to-get-room-lists-by-using-ews-in-exchange

 * Property sets and response shapes in EWS in Exchange | Microsoft Docs
   * https://docs.microsoft.com/en-us/exchange/client-developer/exchange-web-services/property-sets-and-response-shapes-in-ews-in-exchange

 * ConvertId Operation | Microsoft Docs
   * https://docs.microsoft.com/en-us/previous-versions/office/developer/exchange-server-2010/bb799665(v=exchg.140)
 * IdFormatType Enum (ExchangeWebServices) | Microsoft Docs
   * https://docs.microsoft.com/en-us/dotnet/api/exchangewebservices.idformattype?view=exchange-ews-proxy

