{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:ListBucket",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:${awsPartition}:s3:::${s3_bucket}",
                "arn:${awsPartition}:s3:::*/*"
            ]
        }
    ]
}