cd environments/demo
ALB=$(terraform output -raw alb_dns_name)
API=$(terraform output -raw api_url)
BUCKET=$(terraform output -raw bucket_name)

# 1. Weighted a/b distribution at / (20 requests)
for i in $(seq 1 20); do curl -s "http://$ALB/"; done | sort | uniq -c

# 2. Path routing
curl -s "http://$ALB/a/"
curl -s "http://$ALB/b/"

# 3. Upload through API Gateway -> Lambda -> S3
echo "hello" > /tmp/test.txt
curl -s -X POST "$API/upload?filename=test.txt" -H "Content-Type: text/plain" --data-binary @/tmp/test.txt

# 4. Negative test (expect HTTP 400)
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$API/upload?filename=evil.exe" --data-binary "x"

# 5. Check the object landed in S3
aws s3 ls "s3://$BUCKET/uploads/"