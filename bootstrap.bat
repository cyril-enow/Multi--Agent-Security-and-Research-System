@echo off
setlocal
set "AWS_PAGER="
set "REGION=us-east-1"
set "ACCOUNT_ID="

rem Identify the AWS account used by the current credentials.
for /f "delims=" %%A in ('aws sts get-caller-identity --query Account --output text --region %REGION%') do set "ACCOUNT_ID=%%A"

if not defined ACCOUNT_ID (
    echo ERROR: Could not identify the AWS account.
    exit /b 1
)

set "BUCKET=research-agent-tfstate-%ACCOUNT_ID%-%REGION%"

echo AWS account: %ACCOUNT_ID%
echo State bucket: %BUCKET%
echo.

rem Reuse the bucket only when accessible under the expected owner.
aws s3api head-bucket --bucket "%BUCKET%" --expected-bucket-owner "%ACCOUNT_ID%" --region "%REGION%"

if errorlevel 1 (
    echo Bucket access check failed. Attempting creation...
    aws s3api create-bucket --bucket "%BUCKET%" --region "%REGION%"
    if errorlevel 1 goto :failed
)

rem Verify ownership and access before changing bucket settings.
aws s3api head-bucket --bucket "%BUCKET%" --expected-bucket-owner "%ACCOUNT_ID%" --region "%REGION%"
if errorlevel 1 goto :failed

echo Enabling versioning...
aws s3api put-bucket-versioning --bucket "%BUCKET%" --expected-bucket-owner "%ACCOUNT_ID%" --versioning-configuration Status=Enabled --region "%REGION%"
if errorlevel 1 goto :failed

echo Blocking public access...
aws s3api put-public-access-block --bucket "%BUCKET%" --expected-bucket-owner "%ACCOUNT_ID%" --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true --region "%REGION%"
if errorlevel 1 goto :failed

echo Enabling server-side encryption...
aws s3api put-bucket-encryption --bucket "%BUCKET%" --expected-bucket-owner "%ACCOUNT_ID%" --server-side-encryption-configuration "{\"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"AES256\"}}]}" --region "%REGION%"
if errorlevel 1 goto :failed

echo.
echo Bootstrap completed successfully.
echo Bucket: %BUCKET%
echo Update the Terraform backend bucket to this exact name.
echo Locking: S3 lockfile; DynamoDB is not required.
endlocal
exit /b 0

:failed
echo.
echo ERROR: Bootstrap failed. Review the AWS error above.
echo Do not initialise against this bucket until the issue is resolved.
endlocal
exit /b 1