cd environments/demo
API=$(terraform output -raw api_url)
BUCKET=$(terraform output -raw bucket_name)
LG=$(terraform output -raw lambda_log_group)

echo "== 1. Text upload (expect 200) =="
echo "hello $(date -u +%FT%TZ)" > /tmp/test.txt
curl -s -X POST "$API/upload?filename=test.txt" -H "Content-Type: text/plain" --data-binary @/tmp/test.txt; echo

echo "== 2. Binary upload, exercises the base64 path (expect 200) =="
head -c 2000 /dev/urandom > /tmp/test.png
curl -s -X POST "$API/upload?filename=test.png" -H "Content-Type: image/png" --data-binary @/tmp/test.png; echo

echo "== 3. Bad extension (expect 400) =="
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$API/upload?filename=evil.exe" --data-binary "x"

echo "== 4. Empty body (expect 400) =="
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$API/upload?filename=empty.txt"

echo "== 5. Too large, 4.3 MB (expect 413) =="
head -c 4300000 /dev/urandom > /tmp/big.png
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$API/upload?filename=big.png" -H "Content-Type: image/png" --data-binary @/tmp/big.png

echo "== 6. S3 listing =="
aws s3 ls "s3://$BUCKET/uploads/"

echo "== 7. Lambda logs =="
aws logs tail "$LG" --since 10m | tail -n 20