#!/bin/bash
set -e

BUCKET_NAME="${1:-$TF_STATE_BUCKET}"

if [ -z "$BUCKET_NAME" ]; then
    echo "❌ Error: S3 bucket name is required."
    echo "Usage: ./destroy_s3.sh <bucket-name>"
    exit 1
fi

REGION="${AWS_DEFAULT_REGION:-ap-south-1}"

echo "⚠️ WARNING: You are about to permanently destroy S3 bucket '$BUCKET_NAME'."
read -p "Type the full bucket name to confirm destruction: " CONFIRMATION

if [ "$CONFIRMATION" != "$BUCKET_NAME" ]; then
    echo "❌ Bucket name mismatch. Destruction aborted."
    exit 1
fi

echo "🗑️ Starting destruction of bucket '$BUCKET_NAME'..."

if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "⚠️ Bucket '$BUCKET_NAME' does not exist or access is denied."
    exit 0
fi

HAS_VERSIONS=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --region "$REGION" --query 'Versions[0].Key' --output text)
if [ "$HAS_VERSIONS" != "None" ] && [ -n "$HAS_VERSIONS" ]; then
    echo "🧹 Purging object versions..."
    VERSIONS=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --region "$REGION" --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)
    aws s3api delete-objects --bucket "$BUCKET_NAME" --region "$REGION" --delete "$VERSIONS" >/dev/null
fi

HAS_MARKERS=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --region "$REGION" --query 'DeleteMarkers[0].Key' --output text)
if [ "$HAS_MARKERS" != "None" ] && [ -n "$HAS_MARKERS" ]; then
    echo "🧹 Purging delete markers..."
    MARKERS=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --region "$REGION" --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json)
    aws s3api delete-objects --bucket "$BUCKET_NAME" --region "$REGION" --delete "$MARKERS" >/dev/null
fi

echo "🔥 Deleting bucket '$BUCKET_NAME'..."
aws s3api delete-bucket --bucket "$BUCKET_NAME" --region "$REGION"

echo "✅ S3 bucket '$BUCKET_NAME' destroyed successfully."