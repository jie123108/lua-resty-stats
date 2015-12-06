#!/bin/bash

for((i=0;i<10;i++));do
curl http://127.0.0.1:80/byuri/$RANDOM
curl http://127.0.0.1:80/byarg?client_type=pc
curl http://127.0.0.1:80/byarg?client_type=ios
curl http://127.0.0.1:80/byarg?client_type=android
curl http://127.0.0.1:80/byarg/404?client_type=android
curl http://127.0.0.1:80/byuriarg?from=partner
curl http://127.0.0.1:80/byuriarg?from=pc_cli
curl http://127.0.0.1:80/byuriarg?from=mobile_cli
curl http://127.0.0.1:80/byhttpheaderin -H"city: shanghai"
curl http://127.0.0.1:80/byhttpheaderin -H"city: shengzheng"
curl http://127.0.0.1:80/byhttpheaderin -H"city: beijing"
curl http://127.0.0.1:80/byhttpheaderout/hit
curl http://127.0.0.1:80/byhttpheaderout/miss
done;
