{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "s3:ListAllMyBuckets",
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "s3:CreateBucket",
                "s3:DeleteBucket",
                "s3:GetBucketLocation",
                "s3:GetBucketTagging",
                "s3:ListBucket",
                "s3:ListBucketMultipartUploads",
                "s3:PutBucketTagging"
            ],
            "Resource": "arn:${awsPartition}:s3:::avi-se-*"
        },
        {
            "Sid": "VisualEditor2",
            "Effect": "Allow",
            "Action": [
                "s3:AbortMultipartUpload",
                "s3:DeleteObject",
                "s3:ListMultipartUploadParts",
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": "arn:${awsPartition}:s3:::avi-se-*/*"
        }
    ]
}