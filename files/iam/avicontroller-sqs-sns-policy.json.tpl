{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Sid": "VisualEditor0",
          "Effect": "Allow",
          "Action": [
              "autoscaling:DeleteNotificationConfiguration",
              "autoscaling:DescribeNotificationConfigurations",
              "autoscaling:PutNotificationConfiguration",
              "autoscaling:UpdateAutoScalingGroup"
          ],
          "Resource": "*"
      },
      {
          "Sid": "VisualEditor1",
          "Effect": "Allow",
          "Action": [
              "sqs:AddPermission",
              "sqs:CreateQueue",
              "sqs:DeleteQueue",
              "sqs:DeleteMessage",
              "sqs:DeleteMessageBatch",
              "sqs:GetQueueAttributes",
              "sqs:GetQueueUrl",
              "sqs:ListQueueTags",
              "sqs:PurgeQueue",
              "sqs:ReceiveMessage",
              "sqs:SetQueueAttributes",
              "sqs:TagQueue",
              "sqs:UntagQueue"
          ],
          "Resource": "arn:${awsPartition}:sqs:*:*:avi-sqs-cloud-*"
      },
      {
          "Sid": "VisualEditor2",
          "Effect": "Allow",
          "Action": "sns:Subscribe",
          "Resource": "arn:${awsPartition}:sns:*:*:avi-asg-cloud-*"
      },
      {
          "Sid": "VisualEditor3",
          "Effect": "Allow",
          "Action": [
              "sns:ListTopics",
              "sns:GetSubscriptionAttributes",
              "sns:Unsubscribe"
          ],
          "Resource": "*"
      },
      {
          "Sid": "VisualEditor4",
          "Effect": "Allow",
          "Action": [
              "sns:ConfirmSubscription",
              "sns:CreateTopic",
              "sns:DeleteTopic",
              "sns:GetTopicAttributes",
              "sns:ListSubscriptionsByTopic",
              "sns:Publish",
              "sns:SetTopicAttributes"
          ],
          "Resource": "arn:${awsPartition}:sns:*:*:avi-asg-cloud-*"
      }
  ]
}