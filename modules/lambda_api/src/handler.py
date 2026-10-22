import base64
import binascii
import json
import logging
import os
import re
import uuid

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
BUCKET = os.environ["BUCKET"]
MAX_BYTES = int(os.environ.get("MAX_BYTES", 4 * 1024 * 1024))
ALLOWED_EXT = {".txt", ".png", ".jpg", ".jpeg", ".pdf", ".csv", ".json"}
NAME_RE = re.compile(r"^[A-Za-z0-9._-]{1,100}$")


def _resp(code, body):
    return {
        "statusCode": code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event, context):
    params = event.get("queryStringParameters") or {}
    filename = params.get("filename", "")
    ext = os.path.splitext(filename)[1].lower()

    # 1. Validate the filename and extension
    if not NAME_RE.match(filename) or ext not in ALLOWED_EXT:
        logger.warning(json.dumps({"event": "rejected", "reason": "bad_filename", "filename": filename}))
        return _resp(400, {"error": "invalid or missing filename; allowed: " + ", ".join(sorted(ALLOWED_EXT))})

    # 2. Decode the body (API Gateway base64-encodes binary payloads)
    raw = event.get("body") or ""
    try:
        data = base64.b64decode(raw) if event.get("isBase64Encoded") else raw.encode("utf-8")
    except (binascii.Error, ValueError):
        logger.warning(json.dumps({"event": "rejected", "reason": "bad_body"}))
        return _resp(400, {"error": "body could not be decoded"})

    # 3. Validate the size
    if not data:
        logger.warning(json.dumps({"event": "rejected", "reason": "empty_body"}))
        return _resp(400, {"error": "empty body"})
    if len(data) > MAX_BYTES:
        logger.warning(json.dumps({"event": "rejected", "reason": "too_large", "size": len(data)}))
        return _resp(413, {"error": f"file too large (max {MAX_BYTES} bytes)"})

    # 4. Store in S3 under uploads/ (the only prefix the IAM role may write to)
    headers = event.get("headers") or {}
    key = f"uploads/{uuid.uuid4().hex}-{filename}"
    try:
        s3.put_object(
            Bucket=BUCKET,
            Key=key,
            Body=data,
            ContentType=headers.get("content-type", "application/octet-stream"),
            ServerSideEncryption="AES256",
        )
    except ClientError as err:
        logger.error(json.dumps({"event": "s3_error", "error": str(err)}))
        return _resp(500, {"error": "could not store file"})

    logger.info(json.dumps({"event": "upload_ok", "key": key, "size": len(data)}))
    return _resp(200, {"message": "uploaded", "key": key, "size": len(data)})