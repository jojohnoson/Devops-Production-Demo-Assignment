#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/../environments/demo"

API=$(terraform output -raw api_url)
BUCKET=$(terraform output -raw bucket_name)
LAMBDA_LG=$(terraform output -raw lambda_log_group)
ECS_LG=$(terraform output -raw ecs_log_group)
ALB=$(terraform output -raw alb_dns_name)
TMP=$(mktemp -d)
PASS=0; FAIL=0

check() {   # name, expected code, actual code
  if [ "$2" = "$3" ]; then echo "PASS  $1 (HTTP $3)"; PASS=$((PASS+1))
  else echo "FAIL  $1 (expected $2, got $3)"; FAIL=$((FAIL+1)); fi
}
post() { curl -s -o "$TMP/body" -w "%{http_code}" -X POST "$@"; }

echo "===== API: $API ====="
echo "===== Bucket: $BUCKET ====="
echo

echo "--- Valid uploads (expect 200) ---"
echo "hello from test $(date -u +%FT%TZ)" > "$TMP/test.txt"
CODE=$(post "$API/upload?filename=test.txt" -H "Content-Type: text/plain" --data-binary @"$TMP/test.txt")
check "text file" 200 "$CODE"
cat "$TMP/body"; echo
KEY=$(grep -o '"key": "[^"]*"' "$TMP/body" | cut -d'"' -f4)

head -c 2000 /dev/urandom > "$TMP/test.png"
CODE=$(post "$API/upload?filename=test.png" -H "Content-Type: image/png" --data-binary @"$TMP/test.png")
check "binary png (base64 path)" 200 "$CODE"

echo '{"ok": true}' > "$TMP/data.json"
CODE=$(post "$API/upload?filename=data.json" -H "Content-Type: application/json" --data-binary @"$TMP/data.json")
check "json file" 200 "$CODE"

echo
echo "--- Rejected uploads ---"
CODE=$(post "$API/upload?filename=evil.exe" --data-binary "x")
check "bad extension .exe" 400 "$CODE"

CODE=$(post "$API/upload?filename=../x.txt" --data-binary "x")
check "path traversal name" 400 "$CODE"

CODE=$(post "$API/upload" --data-binary "x")
check "missing filename" 400 "$CODE"

CODE=$(post "$API/upload?filename=empty.txt")
check "empty body" 400 "$CODE"

head -c 4300000 /dev/urandom > "$TMP/big.png"
CODE=$(post "$API/upload?filename=big.png" -H "Content-Type: image/png" --data-binary @"$TMP/big.png")
check "file over 4 MB" 413 "$CODE"

CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API/upload")
check "GET instead of POST" 404 "$CODE"

echo
echo "--- S3 verification ---"
aws s3 ls "s3://$BUCKET/uploads/"
aws s3 cp "s3://$BUCKET/$KEY" "$TMP/downloaded.txt" --quiet
if diff -q "$TMP/test.txt" "$TMP/downloaded.txt" >/dev/null; then
  echo "PASS  downloaded object matches the uploaded file"; PASS=$((PASS+1))
else
  echo "FAIL  downloaded object differs"; FAIL=$((FAIL+1))
fi
echo -n "Encryption on object: "
aws s3api head-object --bucket "$BUCKET" --key "$KEY" --query ServerSideEncryption --output text

echo
echo "--- Generating ECS traffic ---"
for i in $(seq 1 10); do curl -s "http://$ALB/" >/dev/null; done
sleep 8   # CloudWatch needs a few seconds

echo
echo "--- Lambda logs (upload_ok and rejected lines) ---"
aws logs tail "$LAMBDA_LG" --since 5m --format short | grep -E "upload_ok|rejected"

echo
echo "--- ECS container logs: nginx-a ---"
aws logs tail "$ECS_LG" --log-stream-name-prefix nginx-a --since 5m | tail -n 5
echo "--- ECS container logs: nginx-b ---"
aws logs tail "$ECS_LG" --log-stream-name-prefix nginx-b --since 5m | tail -n 5

echo
echo "===== RESULT: $PASS passed, $FAIL failed ====="
rm -rf "$TMP"
[ "$FAIL" -eq 0 ]