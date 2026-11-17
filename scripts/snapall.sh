#!/bin/bash
# 計測できる 画面を ぜんぶ 撮って score を 出す(DEBUG ビルドを 入れた シミュレータで)
cd "$(dirname "$0")/.."
H="-debugBackdrop 1 -debugRequests 1"
r(){ id=$1; route=$2; shift 2; printf "%-28s %s\n" "$id" "$(SNAP_WAIT=9 scripts/snapto.sh $id $route -- "$@" | head -1 | sed 's/ *->.*//')"; }
r H01_home home $H -debugHint 1 -debugPhoto d
r H02_home_hint home $H -debugHint 1 -debugVeil 1 -debugPhoto d
r H03_home_press home $H -debugFocus 1 -debugPhoto d
r H04_home_1shot home $H -debugShots 1 -debugPhoto d
r H05_home_2shot home $H -debugShots 2 -debugPhoto d
r H06_home_3shot home $H -debugShots 3 -debugPhoto a
r H07_home_friends home $H -debugFriends 3 -debugFaces 2 -debugPhoto b
r H08_home_firstday home $H -debugFirstDay 1 -debugPhoto d
r H09_home_night home $H -debugNight 1 -debugPhoto d
r H10_live_panel home $H -debugHint 1 -debugLive 1 -debugPhoto d
r H11_page_friends home $H -debugPage 1 -debugPhoto d
r H12_page_friends_filled home $H -debugPage 1 -debugFriends 3 -debugPhoto d
r H13_page_trip home $H -debugPage 2 -debugPhoto d
r H14_page_mondo_locked home $H -debugPage 3 -debugPhoto d
r H15_page_mondo_open home $H -debugPage 3 -debugShots 1 -debugPhoto d
r H16_page_yesterday home $H -debugPage 4 -debugPhoto d
r H17_page_yesterday_open home $H -debugPage 4 -debugShots 1 -debugOpened 1 -debugPhoto d
r H18_page_yesterday_firstday home $H -debugPage 4 -debugFirstDay 1 -debugPhoto d
r L01_today home $H -debugSection sec-active:176
r L02_active home $H -debugSection sec-active:188
r L03_yesterday home $H -debugSection sec-yesterday:96
r L04_yesterday_open home $H -debugSection sec-yesterday:96 -debugShots 1 -debugOpened 1
r L05_mondo_row home $H -debugSection sec-mondo:156 -debugShots 1 -debugOpened 1
r L06_albums home $H -debugSection sec-albums:138
r L07_onthisday home $H -debugSection sec-onthisday:109
r L08_friends_card_empty home $H -debugSection sec-friends:136
r L09_friends_card home $H -debugSection sec-friends:190 -debugFriends 3
r L10_firstday_yesterday home $H -debugSection sec-yesterday:200 -debugFirstDay 1
r L11_develop_view develop
r Y01_yesterday_locked yesterday -debugShots 0 -debugRequests 1
r Y02_yesterday_open yesterday -debugShots 2 -debugRequests 1
r Y03_yesterday_mondo_tab yesterday -debugShots 2 -debugTab 1
r Y04_yesterday_friends_tab yesterday -debugShots 2 -debugRequests 1 -debugShotFriends 2
r Y05_yesterday_scroll yesterday -debugShots 2 -debugScrollMe 1
r Y06_photo_viewer yesterday -debugShots 2 -debugViewing m
r C01_tag tag
