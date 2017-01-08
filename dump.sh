#!/bin/bash

set -e

echo "Job started: $(date)"

DATE=$(date +%Y%m%d_%H%M%S)
FILENAME="$PREFIX-$DATE.sqlc"
FILE="/dump/${FILENAME}"

pg_dump -Fc -h "$PGHOST" -U "$PGUSER" -f "$FILE" -d "$PGDB"

if [[ -n "$S3_BUCKET" ]] && [[ -n "$S3_ACCESS_KEY" ]] && [[ -n "$S3_SECRET_KEY" ]]; then

    echo "Uploading to https://${S3_BUCKET}.s3.amazonaws.com/${FILENAME}"
    day_of_month=`date '+%d'`
    day_of_year=`date '+%j'`
    lifecycle_tag=daily

    if [ $(expr $day_of_year % 7) -eq "1" ]; then
        # 1st, 8th, 15th, ... day of year
        lifecycle_tag=weekly
    fi

    if [ $day_of_month -eq "1" ]; then
        lifecycle_tag=monthly
    fi

    if [ $day_of_year -eq "1" ]; then
        lifecycle_tag=yearly
    fi

    lifecycle_tag="${lifecycle_tag}=true"

    # upload to s3 via bash from http://superuser.com/a/823599/51440
    resource="/${S3_BUCKET}/${FILENAME}"
    contentType="application/octet-stream"
    amzTags="x-amz-tagging:${lifecycle_tag}"
    dateValue=`date -R`
    stringToSign="PUT\n\n${contentType}\n${dateValue}\n${amzTags}\n${resource}"
    signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${S3_SECRET_KEY} -binary | base64`
    curl -L -X PUT -T "${FILE}" \
      -H "Host: ${S3_BUCKET}.s3.amazonaws.com" \
      -H "Date: ${dateValue}" \
      -H "Content-Type: ${contentType}" \
      -H "x-amz-tagging: ${lifecycle_tag}" \
      -H "Authorization: AWS ${S3_ACCESS_KEY}:${signature}" \
      https://${S3_BUCKET}.s3.amazonaws.com/${FILENAME}

fi

if [ ! -z "$DELETE_OLDER_THAN" ]; then
	echo "Deleting old backups: $DELETE_OLDER_THAN"
	find /dump/* -mmin "+$DELETE_OLDER_THAN" -exec rm {} \;
fi


echo "Job finished: $(date) - ${PREFIX}-${DATE}.sqlc"
