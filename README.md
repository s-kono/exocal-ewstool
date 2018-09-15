# Test calendar-tool for Exchange Online EWS (BasicAuth)

 * Upcoming changes to Exchange Web Services (EWS) API for Office 365 - Office 365 Developer Blog
   * https://developer.microsoft.com/en-us/graph/blogs/upcoming-changes-to-exchange-web-services-ews-api-for-office-365/
```
Today we are sharing our plans for the roadmap of Exchange Web Services (EWS)
 and the planned deprecation of Basic Auth access for EWS in October 13th, 2020.
```

---

 * 要 jq, xmllint

## init

```sh
% git clone https://github.com/s-kono/exocal-ewstool.git ${REPO_DIR}
% cd ${REPO_DIR}/
% git clone https://github.com/s-kono/xml2json.git
%
% cat conf/netrc_EWS.sample
machine outlook.office365.com login Your.Account@YourDomain.example.jp password Your.Pass.word
%
% vi  conf/netrc_EWS
%
% vi bin/SHELLSCRIPT_CONFIG
DEF_DOMAIN
CURL_PROXYOPT
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

### get ServerTimeZones

```sh
% bash -c '. bin/SHELLSCRIPT_CONFIG; ${EX_CURL[@]} -d@tmpl/GetServerTimeZones.xml | xmllint --format -'
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

