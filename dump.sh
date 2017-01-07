#!/bin/bash

set -e

echo "Job started: $(date)"

DATE=$(date +%Y%m%d_%H%M%S)
FILE="/dump/$PREFIX-$DATE.sqlc"

pg_dump -Fc -h "$PGHOST" -U "$PGUSER" -f "$FILE" -d "$PGDB"

if [[ -n "$S3_BUCKET" ]] && [[ -n "$S3_ACCESS_KEY" ]] && [[ -n "$S3_SECRET_KEY" ]]; then

    # upload to s3 via bash from http://superuser.com/a/823599/51440
    resource="/${S3_BUCKET}/${FILE}"
    contentType="application/octet-stream"
    dateValue=`date -R`
    stringToSign="PUT\n\n${contentType}\n${dateValue}\n${resource}"
    signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${S3_SECRET_KEY} -binary | base64`
    curl -L -X PUT -T "${FILE}" \
      -H "Host: ${S3_BUCKET}.s3.amazonaws.com" \
      -H "Date: ${dateValue}" \
      -H "Content-Type: ${contentType}" \
      -H "Authorization: AWS ${S3_ACCESS_KEY}:${signature}" \
      https://${S3_BUCKET}.s3.amazonaws.com/${FILE}
fi

if [ ! -z "$DELETE_OLDER_THAN" ]; then
	echo "Deleting old backups: $DELETE_OLDER_THAN"
	find /dump/* -mmin "+$DELETE_OLDER_THAN" -exec rm {} \;
fi


echo "Job finished: $(date)"
