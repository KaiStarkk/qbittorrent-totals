#!/bin/bash

# Replace with your actual credentials
#USERNAME="YOUR_USERNAME"
#PASSWORD="YOUR_PASSWORD"
#DOMAIN="YOUR_DOMAIN"

# Login and capture the cookie in memory
COOKIE=$(curl -s -i --data "username=$USERNAME&password=$PASSWORD" https://$DOMAIN/api/v2/auth/login | grep -Fi Set-Cookie | sed -E 's/Set-Cookie: ([^;]+).*/\1/')

# Fetch torrents info and process with jq
curl -s --cookie "$COOKIE" https://$DOMAIN/api/v2/torrents/info | jq -r '
def hr(bytes):
  if bytes >= 1024*1024*1024 then
    ((bytes / (1024*1024*1024)) * 100 | floor / 100 | tostring) + " GB"
  elif bytes >= 1024*1024 then
    ((bytes / (1024*1024)) * 100 | floor / 100 | tostring) + " MB"
  elif bytes >= 1024 then
    ((bytes / 1024) * 100 | floor / 100 | tostring) + " KB"
  else
    (bytes | tostring) + " B"
  end;

def sum_field(rows; field):
  rows | map(.["\(field)_size"]) | add // 0;

group_by(.category) | map({
  category: .[0].category,
  seeding_size: (map(select(.state | test("uploading|stalledUP|forcedUP")) | .total_size) | add // 0),
  leeching_size: (map(select(.state | test("downloading|stalledDL|forcedDL")) | .total_size) | add // 0),
  queued_size: (map(select(.state == "queuedDL") | .total_size) | add // 0)
}) as $rows |

(
  ["Category", "Seeding", "Leeching", "Queued"],
  ["--------", "-------", "--------", "------"]
),
(
  $rows[] | [ .category, hr(.seeding_size), hr(.leeching_size), hr(.queued_size) ]
),
(
  ["--------", "-------", "--------", "------"],
  [ "TOTAL",
    hr( sum_field($rows; "seeding") ),
    hr( sum_field($rows; "leeching") ),
    hr( sum_field($rows; "queued") )
  ],
  [ "TOTAL DOWNLOADING + QUEUED", "", hr( sum_field($rows; "leeching") + sum_field($rows; "queued") ), "" ]
)
| @tsv' | column -t -s $'\t'

echo
# Wait for any key to close
read -n 1 -s -r -p "Press any key to close..."
